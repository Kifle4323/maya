import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { basename, extname, join, resolve } from 'path';
import { Repository } from 'typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { BenefitItem, BenefitPackage } from '../benefit-packages/benefit-package.entity';
import { InlineAttachmentDto } from '../cbhi/cbhi.dto';
import { ClaimItem } from '../claim-items/claim-item.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import {
  ClaimStatus,
  CoverageStatus,
  DocumentType,
  FacilityLevel,
  NotificationType,
  UserRole,
} from '../common/enums/cbhi.enums';
import { Document } from '../documents/document.entity';
import { FacilityUser } from '../facility-users/facility-user.entity';
import {
  SubmitServiceClaimDto,
  VerifyEligibilityQueryDto,
} from './facility.dto';
import { Notification } from '../notifications/notification.entity';
import { NotificationService } from '../notifications/notification.service';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { User } from '../users/user.entity';
import { ReferralService } from '../referrals/referral.service';

@Injectable()
export class FacilityService {
  constructor(
    @InjectRepository(FacilityUser)
    private readonly facilityUserRepository: Repository<FacilityUser>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Claim)
    private readonly claimRepository: Repository<Claim>,
    @InjectRepository(ClaimItem)
    private readonly claimItemRepository: Repository<ClaimItem>,
    @InjectRepository(Document)
    private readonly documentRepository: Repository<Document>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    private readonly notificationService: NotificationService,
    private readonly referralService: ReferralService,
    @Optional() private readonly wsGateway?: NotificationsGateway,
  ) {}

  async verifyBeneficiaryEligibility(
    userId: string,
    query: VerifyEligibilityQueryDto,
  ) {
    const context = await this.loadFacilityContext(userId);
    const beneficiary = await this.findBeneficiary(query);
    const coverage = await this.loadCoverage(beneficiary.household.id);
    const isEligible =
      beneficiary.isEligible &&
      beneficiary.household.coverageStatus === CoverageStatus.ACTIVE &&
      coverage?.status === CoverageStatus.ACTIVE;

    return {
      facility: {
        id: context.facility.id,
        name: context.facility.name,
        facilityCode: context.facility.facilityCode ?? null,
      },
      beneficiary: {
        id: beneficiary.id,
        fullName: beneficiary.fullName,
        membershipId: beneficiary.memberNumber,
        householdCode: beneficiary.household.householdCode,
        relationshipToHouseholdHead: beneficiary.relationshipToHouseholdHead,
      },
      coverage: coverage
          ? {
              coverageNumber: coverage.coverageNumber,
              status: coverage.status,
              startDate: coverage.startDate.toISOString(),
              endDate: coverage.endDate.toISOString(),
              nextRenewalDate: coverage.nextRenewalDate?.toISOString() ?? null,
            }
          : null,
      eligibility: {
        isEligible,
        reason: isEligible
            ? 'Beneficiary is active and eligible for covered services.'
            : 'Beneficiary is not currently eligible for covered services.',
      },
      verifiedAt: new Date().toISOString(),
    };
  }

  async submitServiceClaim(userId: string, dto: SubmitServiceClaimDto) {
    const context = await this.loadFacilityContext(userId);
    const beneficiary = await this.findBeneficiary({
      membershipId: dto.membershipId,
      phoneNumber: dto.phoneNumber,
      householdCode: dto.householdCode,
      fullName: dto.fullName,
    });
    const coverage = await this.loadCoverage(beneficiary.household.id);

    if (
      !coverage ||
      coverage.status !== CoverageStatus.ACTIVE ||
      beneficiary.household.coverageStatus !== CoverageStatus.ACTIVE ||
      !beneficiary.isEligible
    ) {
      throw new BadRequestException(
        'This beneficiary does not have an active eligible coverage for claim submission.',
      );
    }

    // EHIS Gap: Referral logic for Hospitals
    const isHospital = [
      FacilityLevel.PRIMARY_HOSPITAL,
      FacilityLevel.GENERAL_HOSPITAL,
      FacilityLevel.SPECIALIZED_HOSPITAL,
    ].includes(context.facility.serviceLevel as FacilityLevel);

    let referral = null;
    if (isHospital) {
      if (!dto.referralCode) {
        throw new BadRequestException(
          'Hospital treatment requires a valid referral code from a Primary Health Center.',
        );
      }
      referral = await this.referralService.validateReferral(dto.referralCode, beneficiary.id);
    }

    // B6: Waiting period enforcement
    if (coverage.claimsEligibleFrom && new Date() < new Date(coverage.claimsEligibleFrom)) {
      const eligibleDate = new Date(coverage.claimsEligibleFrom).toISOString().split('T')[0];
      throw new BadRequestException(
        `Coverage is in the 30-day waiting period. Claims eligible from: ${eligibleDate}`,
      );
    }

    const items = dto.items.map((item) => {
      const totalPrice = Number(item.quantity) * Number(item.unitPrice);
      return this.claimItemRepository.create({
        serviceName: item.serviceName.trim(),
        quantity: Number(item.quantity),
        unitPrice: Number(item.unitPrice).toFixed(2),
        totalPrice: totalPrice.toFixed(2),
        notes: item.notes?.trim() || null,
      });
    });
    let claimedAmount = items.reduce(
      (sum, item) => sum + Number(item.totalPrice),
      0,
    );

    // B2: Benefit package validation + co-payment calculation
    let memberCoPayment = 0;
    if (coverage.benefitPackage) {
      const pkg = coverage.benefitPackage;
      for (const item of dto.items) {
        const matched = pkg.items?.find(
          (bi: BenefitItem) =>
            bi.serviceName.toLowerCase() === item.serviceName.trim().toLowerCase(),
        );
        if (!matched) {
          throw new BadRequestException(
            `Service "${item.serviceName}" is not covered by this household's benefit package.`,
          );
        }
        // Apply maxClaimAmount cap per item
        const itemTotal = Number(item.quantity) * Number(item.unitPrice);
        const maxPerItem = Number(matched.maxClaimAmount ?? 0);
        if (maxPerItem > 0 && itemTotal > maxPerItem) {
          throw new BadRequestException(
            `Service "${item.serviceName}" exceeds the maximum claim amount of ETB ${maxPerItem}.`,
          );
        }
        // Accumulate co-payment
        const coPayRate = matched.coPaymentPercent ?? 0;
        memberCoPayment += itemTotal * (coPayRate / 100);
      }
    }
    const schemeAmount = claimedAmount - memberCoPayment;

    // B7: Duplicate claim detection (same beneficiary + facility + serviceDate, non-rejected, within 24h)
    const existingClaim = await this.claimRepository
      .createQueryBuilder('claim')
      .where('claim.beneficiaryId = :beneficiaryId', { beneficiaryId: beneficiary.id })
      .andWhere('claim.facilityId = :facilityId', { facilityId: context.facility.id })
      .andWhere('claim.serviceDate = :serviceDate', { serviceDate: new Date(dto.serviceDate) })
      .andWhere('claim.status != :rejected', { rejected: ClaimStatus.REJECTED })
      .getOne();

    if (existingClaim) {
      throw new BadRequestException(
        `Duplicate claim detected: ${existingClaim.claimNumber} was already submitted for this beneficiary at this facility on this date.`,
      );
    }

    // B8: Annual ceiling enforcement
    const ceiling = Number(process.env.CBHI_ANNUAL_CEILING_ETB ?? 10000);
    const usedResult = await this.claimRepository
      .createQueryBuilder('claim')
      .select('SUM(CAST(claim.approvedAmount AS DECIMAL))', 'total')
      .where('claim.coverageId = :coverageId', { coverageId: coverage.id })
      .andWhere('claim.status != :rejected', { rejected: ClaimStatus.REJECTED })
      .getRawOne<{ total: string | null }>();
    const used = Number(usedResult?.total ?? 0);
    const remaining = ceiling - used;
    if (used + claimedAmount > ceiling) {
      throw new BadRequestException(
        `Annual claim ceiling of ETB ${ceiling} would be exceeded. Used: ETB ${used.toFixed(2)}, Requested: ETB ${claimedAmount.toFixed(2)}, Remaining: ETB ${remaining.toFixed(2)}.`,
      );
    }

    const claim = await this.claimRepository.save(
      this.claimRepository.create({
        claimNumber: this.generateCode('CLM'),
        status: ClaimStatus.SUBMITTED,
        serviceDate: new Date(dto.serviceDate),
        submittedAt: new Date(),
        claimedAmount: schemeAmount.toFixed(2),
        approvedAmount: '0.00',
        memberCoPayment: memberCoPayment.toFixed(2),
        household: beneficiary.household,
        coverage,
        facility: context.facility,
        submittedBy: context.user,
        beneficiary,
        items,
        referralCode: referral?.code ?? null,
        referredFromFacility: referral?.issuedByFacility ?? null,
      }),
    );

    if (referral) {
      await this.referralService.markAsUsed(referral.id);
    }

    if (dto.supportingDocumentUpload || dto.supportingDocumentPath) {
      await this.upsertClaimDocument(
        claim,
        dto.supportingDocumentPath,
        dto.supportingDocumentUpload,
      );
    }

    await this.notifyClaimStakeholders(
      claim,
      'Claim submitted',
      `Claim ${claim.claimNumber} was submitted by ${context.facility.name} for ${beneficiary.fullName}.`,
    );

    return this.toClaimSummary(claim);
  }

  async listFacilityClaims(userId: string) {
    const context = await this.loadFacilityContext(userId);
    const claims = await this.claimRepository.find({
      where: { facility: { id: context.facility.id } },
      relations: ['facility', 'beneficiary', 'household'],
      order: { createdAt: 'DESC' },
      take: 50,
    });

    return {
      facility: {
        id: context.facility.id,
        name: context.facility.name,
        facilityCode: context.facility.facilityCode ?? null,
      },
      claims: claims.map((claim) => this.toClaimSummary(claim)),
      syncedAt: new Date().toISOString(),
    };
  }

  private async loadFacilityContext(userId: string) {
    const facilityUser = await this.facilityUserRepository.findOne({
      where: { user: { id: userId }, isActive: true },
      relations: ['user', 'facility'],
    });

    if (!facilityUser || !facilityUser.facility) {
      throw new ForbiddenException(
        'This account is not linked to an active health facility profile.',
      );
    }

    if (facilityUser.user.role !== UserRole.HEALTH_FACILITY_STAFF) {
      throw new ForbiddenException(
        'Only health facility staff can access facility operations.',
      );
    }

    return {
      user: facilityUser.user,
      facility: facilityUser.facility,
      facilityUser,
    };
  }

  private async findBeneficiary(query: VerifyEligibilityQueryDto) {
    const builder = this.beneficiaryRepository
      .createQueryBuilder('beneficiary')
      .leftJoinAndSelect('beneficiary.household', 'household')
      .leftJoinAndSelect('household.headUser', 'headUser')
      .leftJoinAndSelect('beneficiary.userAccount', 'userAccount');

    const membershipId = query.membershipId?.trim();
    const phoneNumber = query.phoneNumber?.trim();
    if (membershipId) {
      builder.where('beneficiary.memberNumber = :membershipId', {
        membershipId,
      });
    } else if (phoneNumber) {
      builder.where('userAccount.phoneNumber = :phoneNumber', { phoneNumber });
    } else {
      const householdCode = query.householdCode?.trim();
      const fullName = this.normalizeFullName(query.fullName);
      if (!householdCode || !fullName) {
        throw new BadRequestException(
          'Provide a membership ID, phone number, or the household code and beneficiary full name.',
        );
      }

      builder
        .where('household.householdCode = :householdCode', { householdCode })
        .andWhere('LOWER(TRIM(beneficiary.fullName)) = :fullName', {
          fullName,
        });
    }

    const beneficiary = await builder.getOne();
    if (!beneficiary?.household) {
      throw new NotFoundException('Beneficiary was not found.');
    }

    return beneficiary;
  }

  private async loadCoverage(householdId: string) {
    return this.coverageRepository.findOne({
      where: { household: { id: householdId } },
      relations: ['household', 'benefitPackage', 'benefitPackage.items'],
      order: { createdAt: 'DESC' },
    });
  }

  private async upsertClaimDocument(
    claim: Claim,
    filePath?: string,
    upload?: InlineAttachmentDto,
  ) {
    const storedUpload = upload
      ? await this.persistInlineAttachment(upload, claim.claimNumber)
      : null;
    const normalizedPath = storedUpload?.fileUrl ?? this.clean(filePath);
    if (!normalizedPath) {
      return;
    }

    const existing = await this.documentRepository.findOne({
      where: {
        claim: { id: claim.id },
        type: DocumentType.CLAIM_SUPPORTING,
      },
      relations: ['claim'],
    });

    const fileName = storedUpload?.fileName ?? basename(normalizedPath);
    const mimeType = storedUpload?.mimeType ?? this.resolveMimeType(fileName);
    const document =
      existing ??
      this.documentRepository.create({
        claim,
        type: DocumentType.CLAIM_SUPPORTING,
        isVerified: false,
      });

    document.fileName = fileName;
    document.fileUrl = normalizedPath;
    document.mimeType = mimeType;
    await this.documentRepository.save(document);
  }

  private async persistInlineAttachment(
    upload: InlineAttachmentDto,
    claimNumber: string,
  ) {
    const fileName = this.sanitizeFileName(upload.fileName);
    const uploadsRoot = resolve(process.cwd(), 'uploads', 'claims');
    await mkdir(uploadsRoot, { recursive: true });

    const storedFileName = `${claimNumber}-${Date.now()}-${fileName}`;
    const targetPath = join(uploadsRoot, storedFileName);
    const buffer = Buffer.from(upload.contentBase64, 'base64');
    await writeFile(targetPath, buffer);

    return {
      fileName,
      mimeType: this.clean(upload.mimeType) ?? this.resolveMimeType(fileName),
      fileUrl: `/uploads/claims/${storedFileName}`,
    };
  }

  private async notifyClaimStakeholders(
    claim: Claim,
    title: string,
    message: string,
  ) {
    const recipients = [claim.household?.headUser, claim.beneficiary?.userAccount]
      .filter((user): user is User => !!user?.id)
      .reduce<User[]>((unique, user) => {
        if (!unique.some((item) => item.id === user.id)) {
          unique.push(user);
        }
        return unique;
      }, []);

    for (const recipient of recipients) {
      // FCM push + persistent DB notification via NotificationService
      await this.notificationService.createAndSend(
        recipient,
        NotificationType.CLAIM_UPDATE,
        title,
        message,
        {
          claimId: claim.id,
          claimNumber: claim.claimNumber,
          status: claim.status,
        },
      );
      // Real-time WebSocket push
      this.wsGateway?.pushClaimUpdate([recipient.id], {
        claimId: claim.id,
        claimNumber: claim.claimNumber,
        status: claim.status,
        facilityName: claim.facility?.name ?? null,
      });
    }
  }

  private toClaimSummary(claim: Claim) {
    return {
      id: claim.id,
      claimNumber: claim.claimNumber,
      status: claim.status,
      serviceDate: claim.serviceDate.toISOString(),
      submittedAt: claim.submittedAt?.toISOString() ?? null,
      reviewedAt: claim.reviewedAt?.toISOString() ?? null,
      claimedAmount: Number(claim.claimedAmount),
      approvedAmount: Number(claim.approvedAmount),
      memberCoPayment: Number(claim.memberCoPayment ?? 0),
      facilityName: claim.facility?.name ?? null,
      householdCode: claim.household?.householdCode ?? null,
      beneficiaryId: claim.beneficiary?.id ?? null,
      beneficiaryName: claim.beneficiary?.fullName ?? null,
      decisionNote: claim.decisionNote ?? null,
    };
  }

  private normalizeFullName(value?: string | null) {
    return value?.trim().replace(/\s+/g, ' ').toLowerCase();
  }

  private clean(value?: string | null) {
    const trimmed = value?.trim();
    return trimmed ? trimmed : undefined;
  }

  private sanitizeFileName(fileName: string) {
    return fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  }

  private resolveMimeType(fileName: string) {
    const extension = extname(fileName).toLowerCase();
    return (
      {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.pdf': 'application/pdf',
      }[extension] ?? 'application/octet-stream'
    );
  }

  private generateCode(prefix: string) {
    return `${prefix}-${randomBytes(4).toString('hex').toUpperCase()}`;
  }
}
