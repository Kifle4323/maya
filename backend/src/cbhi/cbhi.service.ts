import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createCipheriv, createHash, randomBytes } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { basename, extname, join, resolve } from 'path';
import { Repository } from 'typeorm';
import { IndigentApplication } from '../indigent/indigent.entity';
import { IndigentApplicationStatus } from '../common/enums/cbhi.enums';
import { AuthService } from '../auth/auth.service';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import { CacheService } from '../common/cache/cache.service';
import {
  ClaimStatus,
  CoverageStatus,
  DocumentType,
  IdentityDocumentType,
  IdentityVerificationStatus,
  IndigentEmploymentStatus,
  MembershipType,
  NotificationType,
  PaymentStatus,
  PreferredLanguage,
  RelationshipToHouseholdHead,
  UserRole,
} from '../common/enums/cbhi.enums';
import { Document } from '../documents/document.entity';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import { Payment } from '../payments/payment.entity';
import { User } from '../users/user.entity';
import {
  CreateFamilyMemberDto,
  InlineAttachmentDto,
  RegistrationStepOneDto,
  RegistrationStepTwoDto,
  RenewCoverageDto,
  UpdateFamilyMemberDto,
} from './cbhi.dto';

type EligibilityDecision = {
  score: number;
  approved: boolean;
  reason: string;
};

@Injectable()
export class CbhiService {
  private readonly householdBasePremium = Number(
    process.env.CBHI_HOUSEHOLD_BASE_PREMIUM ?? 1200,
  );
  private readonly additionalBeneficiaryPremium = Number(
    process.env.CBHI_ADDITIONAL_BENEFICIARY_PREMIUM ?? 120,
  );

  private readonly cardSecret = process.env.DIGITAL_CARD_SECRET ?? 'cbhi-card';

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    @InjectRepository(Document)
    private readonly documentRepository: Repository<Document>,
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Claim)
    private readonly claimRepository: Repository<Claim>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    @InjectRepository(IndigentApplication)
    private readonly indigentApplicationRepository: Repository<IndigentApplication>,
    private readonly authService: AuthService,
    private readonly cacheService: CacheService,
  ) {}

  async registerStepOne(dto: RegistrationStepOneDto) {
    const phoneNumber =
      this.authService.normalizePhoneNumber(dto.phone) ?? null;
    const email = this.authService.normalizeEmail(dto.email) ?? null;
    await this.ensureAccountTargetAvailable({
      phoneNumber,
      email,
    });

    const user = await this.userRepository.save(
      this.userRepository.create({
        firstName: this.cleanRequired(dto.firstName, 'firstName'),
        middleName: this.clean(dto.middleName),
        lastName: this.cleanRequired(dto.lastName, 'lastName'),
        phoneNumber,
        email,
        preferredLanguage: dto.preferredLanguage ?? PreferredLanguage.ENGLISH,
        role: UserRole.HOUSEHOLD_HEAD,
        identityVerificationStatus: IdentityVerificationStatus.PENDING,
        isActive: true,
      }),
    );

    const household = await this.householdRepository.save(
      this.householdRepository.create({
        householdCode: this.generateCode('HH'),
        region: this.cleanRequired(dto.address.region, 'region'),
        zone: this.cleanRequired(dto.address.zone, 'zone'),
        woreda: this.clean(dto.address.woreda) ?? '',
        kebele: this.clean(dto.address.kebele) ?? '',
        phoneNumber,
        memberCount: dto.householdSize,
        coverageStatus: CoverageStatus.PENDING_RENEWAL,
        headUser: user,
      }),
    );

    user.household = household;
    await this.userRepository.save(user);

    const beneficiary = await this.beneficiaryRepository.save(
      this.beneficiaryRepository.create({
        memberNumber: this.generateCode('MBR'), // finalized in step 2 with structured ID
        fullName: this.composeFullName(
          dto.firstName,
          dto.middleName,
          dto.lastName,
        ),
        dateOfBirth: new Date(dto.dateOfBirth),
        gender: dto.gender,
        birthCertificateRef: this.clean(dto.birthCertificateRef),
        relationshipToHouseholdHead: RelationshipToHouseholdHead.HEAD,
        isPrimaryHolder: true,
        isEligible: false,
        household,
        userAccount: user,
      }),
    );

    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.IDENTITY_DOCUMENT,
      dto.idDocumentPath,
      dto.idDocumentUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BIRTH_CERTIFICATE,
      dto.birthCertificatePath,
      dto.birthCertificateUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BENEFICIARY_PHOTO,
      dto.beneficiaryPhotoPath,
      dto.beneficiaryPhotoUpload,
    );

    return {
      registrationId: user.id,
      householdCode: household.householdCode,
      householdId: household.id,
      beneficiaryId: beneficiary.id,
      step: 'IDENTITY_PENDING',
    };
  }

  async registerStepTwo(dto: RegistrationStepTwoDto) {
    const user = await this.userRepository.findOne({
      where: { id: dto.registrationId },
      relations: ['household', 'beneficiaryProfile'],
    });

    if (!user) {
      throw new NotFoundException(
        `Registration ${dto.registrationId} not found`,
      );
    }

    const household =
      user.household ?? (await this.loadHouseholdByUser(user.id));
    const beneficiary =
      user.beneficiaryProfile ??
      (await this.loadPrimaryBeneficiary(household.id));

    user.identityType = dto.identityType;
    user.identityNumber = this.cleanRequired(
      dto.identityNumber,
      'identityNumber',
    );
    user.identityVerificationStatus = IdentityVerificationStatus.VERIFIED;
    user.identityVerifiedAt = new Date();
    user.nationalId =
      dto.identityType === IdentityDocumentType.NATIONAL_ID
        ? user.identityNumber
        : null;
    await this.userRepository.save(user);

    beneficiary.identityType = dto.identityType;
    beneficiary.identityNumber = user.identityNumber;
    beneficiary.nationalId = user.nationalId;

    const eligibility = this.resolveRegistrationEligibility(
      dto,
      household.memberCount,
    );

    household.membershipType = dto.membershipType;
    household.coverageStatus = this.resolveCoverageStatus(
      dto.membershipType,
      eligibility,
    );
    await this.householdRepository.save(household);

    // ── Assign structured Membership ID now that we know the membership type ──
    // Format: PM-<KEBELE>-<HHSEQ>-01 (paying) or IM-<KEBELE>-<HHSEQ>-01 (indigent)
    const hhSeq = await this.nextHouseholdSeqForKebele(household.kebele);
    beneficiary.memberNumber = await this.generateMembershipId(
      dto.membershipType,
      household.kebele,
      hhSeq,
      1, // household head is always member 01
    );

    beneficiary.isEligible =
      dto.membershipType === MembershipType.PAYING ||
      dto.membershipType === MembershipType.INDIGENT ||
      eligibility.approved;
    await this.beneficiaryRepository.save(beneficiary);

    await this.upsertCoverage(
      household,
      dto.membershipType,
      dto.premiumAmount,
      eligibility,
    );

    if (
      dto.membershipType === MembershipType.INDIGENT &&
      dto.indigentProofUploads?.length
    ) {
      await this.appendIndigentProofDocuments(
        beneficiary,
        dto.indigentProofUploads,
      );
    }

    // ── Create IndigentApplication for admin review when INDIGENT ──────────
    if (dto.membershipType === MembershipType.INDIGENT) {
      await this.indigentApplicationRepository.save(
        this.indigentApplicationRepository.create({
          user: { id: user.id },
          income: 0,
          employmentStatus: dto.eligibilitySignals?.employmentStatus ?? IndigentEmploymentStatus.UNEMPLOYED,
          familySize: household.memberCount,
          hasProperty: false,
          disabilityStatus: false,
          documents: dto.indigentProofUploads?.map(u => u.fileName ?? '') ?? [],
          status: IndigentApplicationStatus.PENDING,
          score: 0,
          reason: 'Indigent application from registration — pending admin review',
        }),
      );
    }

    const fullHousehold = await this.loadHouseholdWithMembers(household.id);
    const fullCoverage = await this.loadLatestCoverage(household.id);
    const primaryMember = this.getPrimaryMember(fullHousehold);
    const digitalCard = fullCoverage
      ? this.issueDigitalCard({
          household: fullHousehold,
          beneficiary: primaryMember,
          coverage: fullCoverage,
          eligibility,
        })
      : null;

    return {
      registrationId: user.id,
      householdCode: fullHousehold.householdCode,
      membershipType: dto.membershipType,
      identityStatus: user.identityVerificationStatus,
      eligibility,
      household: this.toHouseholdSummary(fullHousehold),
      viewer: this.toViewerSummary(user, primaryMember, true),
      familyMembers: this.toFamilyMembers(fullHousehold),
      coverage: fullCoverage ? this.toCoverageSummary(fullCoverage) : null,
      digitalCards: fullCoverage
        ? this.buildDigitalCards(fullHousehold, fullCoverage)
        : [],
      digitalCard,
      payments: await this.loadPaymentSummaries(household.id),
      auth: await this.authService.issueSession(user.id),
      claims: await this.loadClaimSummaries({
        householdId: household.id,
        isHouseholdHead: true,
      }),
      notifications: await this.loadNotificationSummaries(user.id),
      syncedAt: new Date().toISOString(),
    };
  }

  async getMemberSnapshot(userId: string) {
    const cacheKey = `snapshot:${userId}`;
    return this.cacheService.getOrSet(
      cacheKey,
      () => this._buildMemberSnapshot(userId),
      3 * 60 * 1000, // 3 minute TTL
    );
  }

  private async _buildMemberSnapshot(userId: string) {
    const access = await this.resolveAccessContext(userId);
    const coverage = await this.loadLatestCoverage(access.household.id);
    const currentMember =
      access.household.beneficiaries.find(
        (item) => item.id === access.beneficiary.id,
      ) ?? this.getPrimaryMember(access.household);
    const eligibility = {
      score: currentMember.isEligible ? 100 : 0,
      approved: currentMember.isEligible,
      reason: currentMember.isEligible
        ? 'Household member is eligible for current coverage.'
        : 'Household member is not currently eligible.',
    };

    return {
      household: this.toHouseholdSummary(access.household),
      viewer: this.toViewerSummary(
        access.user,
        currentMember,
        access.isHouseholdHead,
      ),
      familyMembers: this.toFamilyMembers(access.household),
      coverage: coverage ? this.toCoverageSummary(coverage) : null,
      eligibility,
      digitalCards:
        coverage && currentMember
          ? this.buildDigitalCards(
              access.household,
              coverage,
              access.isHouseholdHead ? undefined : access.beneficiary.id,
            )
          : [],
      digitalCard:
        coverage && currentMember
          ? this.issueDigitalCard({
              household: access.household,
              beneficiary: currentMember,
              coverage,
              eligibility,
            })
          : null,
      payments: await this.loadPaymentSummaries(access.household.id),
      claims: await this.loadClaimSummaries({
        householdId: access.household.id,
        isHouseholdHead: access.isHouseholdHead,
        beneficiaryId: access.beneficiary.id,
      }),
      notifications: await this.loadNotificationSummaries(access.user.id),
      syncedAt: new Date().toISOString(),
    };
  }

  async getFamily(userId: string) {
    const access = await this.resolveAccessContext(userId);
    return {
      householdCode: access.household.householdCode,
      coverageStatus: access.household.coverageStatus,
      members: this.toFamilyMembers(access.household),
      syncedAt: new Date().toISOString(),
    };
  }

  async getProfile(userId: string) {
    const access = await this.resolveAccessContext(userId);
    const currentMember =
      access.household.beneficiaries.find(
        (item) => item.id === access.beneficiary.id,
      ) ?? access.beneficiary;
    const coverage = await this.loadLatestCoverage(access.household.id);

    return {
      household: this.toHouseholdSummary(access.household),
      viewer: this.toViewerSummary(
        access.user,
        currentMember,
        access.isHouseholdHead,
      ),
      member: this.toFamilyMemberSummary(currentMember, access.household),
      coverage: coverage ? this.toCoverageSummary(coverage) : null,
      eligibility: this.buildEligibilitySummary(currentMember, access.household),
      syncedAt: new Date().toISOString(),
    };
  }

  async getViewerEligibility(userId: string) {
    const access = await this.resolveAccessContext(userId);
    return {
      householdCode: access.household.householdCode,
      member: this.toFamilyMemberSummary(access.beneficiary, access.household),
      eligibility: this.buildEligibilitySummary(access.beneficiary, access.household),
      syncedAt: new Date().toISOString(),
    };
  }

  async getPaymentHistory(userId: string) {
    const access = await this.resolveAccessContext(userId);
    return {
      householdCode: access.household.householdCode,
      payments: await this.loadPaymentSummaries(access.household.id),
      syncedAt: new Date().toISOString(),
    };
  }

  async renewCoverage(userId: string, dto: RenewCoverageDto) {
    const access = await this.resolveAccessContext(userId);
    if (!access.isHouseholdHead) {
      throw new BadRequestException(
        'Coverage renewal must be completed by the household head.',
      );
    }

    const membershipType = access.household.membershipType;
    if (!membershipType) {
      throw new BadRequestException(
        'Household membership type is not configured yet.',
      );
    }

    const coverage = await this.loadLatestCoverage(access.household.id);
    if (!coverage) {
      throw new NotFoundException(
        `Coverage for household ${access.household.householdCode} not found.`,
      );
    }

    const premiumAmount = this.resolvePremiumAmount(
      access.household.memberCount,
      membershipType,
      dto.amount,
      {
        approved: access.beneficiary.isEligible,
        reason: access.beneficiary.isEligible
            ? 'Household remains eligible.'
            : 'Household is not eligible.',
        score: access.beneficiary.isEligible ? 100 : 0,
      },
    );

    if (premiumAmount > 0 && !dto.paymentMethod) {
      throw new BadRequestException(
        'A payment method is required to renew a paying household coverage.',
      );
    }

    const renewedAt = new Date();
    coverage.startDate = renewedAt;
    coverage.endDate = this.addMonths(renewedAt, 12);
    coverage.nextRenewalDate = coverage.endDate;
    coverage.status = CoverageStatus.ACTIVE;
    coverage.premiumAmount = premiumAmount.toFixed(2);
    coverage.paidAmount = premiumAmount.toFixed(2);
    await this.coverageRepository.save(coverage);

    access.household.coverageStatus = CoverageStatus.ACTIVE;
    await this.householdRepository.save(access.household);

    await this.beneficiaryRepository
      .createQueryBuilder()
      .update(Beneficiary)
      .set({ isEligible: true })
      .where('householdId = :householdId', { householdId: access.household.id })
      .execute();

    if (premiumAmount > 0 && dto.paymentMethod) {
      const payment = this.paymentRepository.create({
        transactionReference: this.generateCode('PAY'),
        amount: premiumAmount.toFixed(2),
        method: dto.paymentMethod,
        status: PaymentStatus.SUCCESS,
        providerName: this.clean(dto.providerName) ?? null,
        receiptNumber: this.clean(dto.receiptNumber) ?? null,
        paidAt: renewedAt,
        coverage,
        processedBy: access.user,
      });
      await this.paymentRepository.save(payment);
    }

    await this.notifyHouseholdUsers(
      access.household.id,
      NotificationType.RENEWAL_REMINDER,
      'Coverage renewed',
      `Coverage for ${access.household.householdCode} is active until ${(coverage.endDate instanceof Date ? coverage.endDate.toISOString() : (coverage.endDate as unknown as string)?.toString() ?? 'N/A').split('T')[0]}.`,
      {
        coverageNumber: coverage.coverageNumber,
        householdCode: access.household.householdCode,
      },
    );

    // Invalidate snapshot cache after renewal
    await this.cacheService.del(`snapshot:${userId}`);
    return this.getMemberSnapshot(userId);
  }

  async getDigitalCards(userId: string) {
    const access = await this.resolveAccessContext(userId);
    const coverage = await this.loadLatestCoverage(access.household.id);
    if (!coverage) {
      return {
        cards: [],
        syncedAt: new Date().toISOString(),
      };
    }

    return {
      cards: this.buildDigitalCards(
        access.household,
        coverage,
        access.isHouseholdHead ? undefined : access.beneficiary.id,
      ),
      syncedAt: new Date().toISOString(),
    };
  }

  async getNotifications(userId: string) {
    return {
      notifications: await this.loadNotificationSummaries(userId),
      syncedAt: new Date().toISOString(),
    };
  }

  async markNotificationRead(userId: string, notificationId: string) {
    const notification = await this.notificationRepository.findOne({
      where: { id: notificationId, recipient: { id: userId } },
      relations: ['recipient'],
    });

    if (!notification) {
      throw new NotFoundException('Notification not found.');
    }

    notification.isRead = true;
    notification.readAt = new Date();
    await this.notificationRepository.save(notification);
    return this.getNotifications(userId);
  }

  async addFamilyMember(userId: string, dto: CreateFamilyMemberDto) {
    const household = await this.loadHouseholdByUser(userId);
    const phoneNumber =
      this.authService.normalizePhoneNumber(dto.phoneNumber) ?? null;
    this.assertBeneficiaryPhonePolicy(
      dto.relationshipToHouseholdHead,
      phoneNumber,
      'create',
    );
    await this.ensureAccountTargetAvailable({
      phoneNumber,
    });
    const dateOfBirth = new Date(dto.dateOfBirth);
    // Determine next member sequence for this household
    const memberSeq = await this.nextMemberSeqForHousehold(household.id);
    const memberNumber = await this.generateMembershipId(
      household.membershipType,
      household.kebele,
      // Re-derive the household sequence from the head's memberNumber (e.g. PM-MAYA-0001-01 → 1)
      this.extractHouseholdSeq(
        await this.loadPrimaryBeneficiary(household.id).then((b) => b.memberNumber),
      ),
      memberSeq,
    );
    const beneficiary = await this.beneficiaryRepository.save(
      this.beneficiaryRepository.create({
        household,
        memberNumber,
        fullName: this.composeFullName(
          dto.firstName,
          dto.middleName,
          dto.lastName,
        ),
        gender: dto.gender,
        dateOfBirth,
        relationshipToHouseholdHead: dto.relationshipToHouseholdHead,
        birthCertificateRef: this.clean(dto.birthCertificateRef),
        identityType: dto.identityType ?? null,
        identityNumber: this.clean(dto.identityNumber) ?? null,
        nationalId:
          dto.identityType === IdentityDocumentType.NATIONAL_ID
            ? (this.clean(dto.identityNumber) ?? null)
            : null,
        phoneNumber: phoneNumber,
        isPrimaryHolder: false,
        isEligible: household.coverageStatus === CoverageStatus.ACTIVE,
      }),
    );

    const accountResult = await this.upsertBeneficiaryUserAccount(beneficiary, household, {
      firstName: dto.firstName,
      middleName: dto.middleName,
      lastName: dto.lastName,
      phoneNumber,
      identityType: dto.identityType,
      identityNumber: dto.identityNumber,
    });
    const setupCode = accountResult && 'setupCode' in accountResult ? accountResult.setupCode : null;

    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.IDENTITY_DOCUMENT,
      dto.idDocumentPath,
      dto.idDocumentUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BIRTH_CERTIFICATE,
      dto.birthCertificatePath,
      dto.birthCertificateUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BENEFICIARY_PHOTO,
      dto.beneficiaryPhotoPath,
      dto.beneficiaryPhotoUpload,
    );
    await this.recountHouseholdMembers(household.id);

    // B11: Recalculate premium when family size changes for paying members
    if (household.membershipType === MembershipType.PAYING) {
      try {
        const updatedHousehold = await this.householdRepository.findOne({ where: { id: household.id } });
        if (updatedHousehold) {
          const coverage = await this.coverageRepository.findOne({
            where: { household: { id: household.id } },
            order: { createdAt: 'DESC' },
          });
          if (coverage) {
            const newPremium = this.calculatePremium(updatedHousehold.memberCount);
            coverage.premiumAmount = newPremium.toFixed(2);
            await this.coverageRepository.save(coverage);
          }
        }
      } catch (_) { /* non-blocking */ }
    }

    const family = await this.getFamily(userId);
    if (setupCode) {
      return { ...family, setupCode };
    }
    return family;
  }

  async updateFamilyMember(
    userId: string,
    memberId: string,
    dto: UpdateFamilyMemberDto,
  ) {
    const household = await this.loadHouseholdByUser(userId);
    const beneficiary = await this.findHouseholdBeneficiary(
      household.id,
      memberId,
    );
    const phoneNumber =
      this.authService.normalizePhoneNumber(dto.phoneNumber) ?? null;
    if (phoneNumber) {
      await this.ensureAccountTargetAvailable({
        phoneNumber,
        excludeUserId: beneficiary.userAccount?.id,
      });
    }

    const updatedName = this.composeFullName(
      dto.firstName ?? this.namePart(beneficiary.fullName, 0),
      dto.middleName ?? this.namePart(beneficiary.fullName, 1),
      dto.lastName ?? this.namePart(beneficiary.fullName, 2),
    );

    beneficiary.fullName = updatedName;
    beneficiary.gender = dto.gender ?? beneficiary.gender;
    beneficiary.dateOfBirth = dto.dateOfBirth
      ? new Date(dto.dateOfBirth)
      : beneficiary.dateOfBirth;
    beneficiary.relationshipToHouseholdHead =
      dto.relationshipToHouseholdHead ??
      beneficiary.relationshipToHouseholdHead;
    beneficiary.birthCertificateRef =
      dto.birthCertificateRef ?? beneficiary.birthCertificateRef;
    beneficiary.identityType = dto.identityType ?? beneficiary.identityType;
    beneficiary.identityNumber =
      this.clean(dto.identityNumber) ?? beneficiary.identityNumber;
    beneficiary.phoneNumber = phoneNumber ?? beneficiary.phoneNumber;
    this.assertBeneficiaryPhonePolicy(
      beneficiary.relationshipToHouseholdHead,
      beneficiary.phoneNumber ?? beneficiary.userAccount?.phoneNumber ?? null,
      'update',
    );
    beneficiary.nationalId =
      beneficiary.identityType === IdentityDocumentType.NATIONAL_ID
        ? (beneficiary.identityNumber ?? beneficiary.nationalId)
        : null;
    await this.beneficiaryRepository.save(beneficiary);

    const accountResult = await this.upsertBeneficiaryUserAccount(beneficiary, household, {
      firstName: dto.firstName ?? this.namePart(beneficiary.fullName, 0),
      middleName: dto.middleName ?? this.namePart(beneficiary.fullName, 1),
      lastName: dto.lastName ?? this.namePart(beneficiary.fullName, 2),
      phoneNumber,
      identityType: beneficiary.identityType ?? undefined,
      identityNumber: beneficiary.identityNumber ?? undefined,
    });
    const setupCode = accountResult && 'setupCode' in accountResult ? accountResult.setupCode : null;

    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.IDENTITY_DOCUMENT,
      dto.idDocumentPath,
      dto.idDocumentUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BIRTH_CERTIFICATE,
      dto.birthCertificatePath,
      dto.birthCertificateUpload,
    );
    await this.upsertBeneficiaryDocument(
      beneficiary,
      DocumentType.BENEFICIARY_PHOTO,
      dto.beneficiaryPhotoPath,
      dto.beneficiaryPhotoUpload,
    );

    const family = await this.getFamily(userId);
    if (setupCode) {
      return { ...family, setupCode };
    }
    return family;
  }

  async removeFamilyMember(userId: string, memberId: string) {
    const household = await this.loadHouseholdByUser(userId);
    const beneficiary = await this.findHouseholdBeneficiary(
      household.id,
      memberId,
    );

    if (beneficiary.isPrimaryHolder) {
      throw new BadRequestException(
        'The household head cannot be removed from the household.',
      );
    }

    if (beneficiary.userAccount) {
      beneficiary.userAccount.isActive = false;
      await this.userRepository.save(beneficiary.userAccount);
    }

    // Soft-delete preserves claim history — deletedAt is set, record stays in DB
    await this.beneficiaryRepository.softRemove(beneficiary);
    await this.recountHouseholdMembers(household.id);

    return this.getFamily(userId);
  }

  /**
   * Indigent registration uses uploaded proof documents only (no extra form fields).
   * Paying members use standard premium flow.
   */
  private resolveRegistrationEligibility(
    dto: RegistrationStepTwoDto,
    householdSize: number,
  ): EligibilityDecision {
    if (dto.membershipType === MembershipType.PAYING) {
      return this.evaluateEligibility(
        dto.membershipType,
        dto.eligibilitySignals.employmentStatus,
        householdSize,
      );
    }

    // Indigent pathway: always pending until admin approves
    return {
      score: 0,
      approved: false,
      reason:
        'Indigent application submitted — pending admin review.',
    };
  }

  private async appendIndigentProofDocuments(
    beneficiary: Beneficiary,
    uploads: InlineAttachmentDto[],
  ) {
    for (const upload of uploads) {
      const stored = await this.persistInlineAttachment(
        DocumentType.OTHER,
        beneficiary,
        upload,
      );
      const document = this.documentRepository.create({
        beneficiary,
        type: DocumentType.OTHER,
        fileName: stored.fileName,
        fileUrl: stored.fileUrl,
        mimeType: stored.mimeType,
        isVerified: false,
      });
      await this.documentRepository.save(document);
    }
  }

  private evaluateEligibility(
    membershipType: MembershipType,
    employmentStatus: IndigentEmploymentStatus,
    householdSize: number,
  ): EligibilityDecision {
    if (membershipType === MembershipType.PAYING) {
      return {
        score: 100,
        approved: true,
        reason: 'Paying membership selected; indigent screening bypassed.',
      };
    }

    let score = 0;
    const reasons: string[] = [];

    switch (employmentStatus) {
      case IndigentEmploymentStatus.UNEMPLOYED:
        score += 40;
        reasons.push('unemployed');
        break;
      case IndigentEmploymentStatus.DAILY_LABORER:
        score += 35;
        reasons.push('daily laborer');
        break;
      case IndigentEmploymentStatus.FARMER:
        score += 30;
        reasons.push('smallholder farmer');
        break;
      case IndigentEmploymentStatus.HOMEMAKER:
        score += 28;
        reasons.push('homemaker');
        break;
      case IndigentEmploymentStatus.PENSIONER:
        score += 26;
        reasons.push('pensioner');
        break;
      case IndigentEmploymentStatus.STUDENT:
        score += 24;
        reasons.push('student');
        break;
      case IndigentEmploymentStatus.MERCHANT:
        score += 10;
        reasons.push('merchant');
        break;
      case IndigentEmploymentStatus.EMPLOYED:
        reasons.push('formally employed');
        break;
      default:
        throw new BadRequestException('Unsupported employment status');
    }

    if (householdSize >= 6) {
      score += 15;
      reasons.push('large household');
    } else if (householdSize >= 4) {
      score += 8;
      reasons.push('mid-size household');
    }

    const approved = score >= 40;
    return {
      score,
      approved,
      reason: approved
        ? `Zero-touch indigent approval: ${reasons.join(', ')}`
        : `Zero-touch indigent rejection: ${reasons.join(', ')}`,
    };
  }

  private async upsertCoverage(
    household: Household,
    membershipType: MembershipType,
    requestedPremium: number | undefined,
    eligibility: EligibilityDecision,
  ) {
    const current = await this.coverageRepository.findOne({
      where: { household: { id: household.id } },
      relations: ['household'],
      order: { createdAt: 'DESC' },
    });

    const coverage =
      current ??
      this.coverageRepository.create({
        coverageNumber: this.generateCode('CVG'),
        household,
      });

    const startDate = new Date();
    const endDate = this.addMonths(startDate, 12);
    const premiumAmount = this.resolvePremiumAmount(
      household.memberCount,
      membershipType,
      requestedPremium,
      eligibility,
    );

    coverage.startDate = startDate;
    coverage.endDate = endDate;
    coverage.nextRenewalDate = endDate;
    coverage.status = this.resolveCoverageStatus(membershipType, eligibility);
    coverage.premiumAmount = premiumAmount.toFixed(2);
    coverage.paidAmount = coverage.paidAmount ?? '0.00';

    return this.coverageRepository.save(coverage);
  }

  private resolvePremiumAmount(
    householdSize: number,
    membershipType: MembershipType,
    _requestedPremium: number | undefined,
    eligibility: EligibilityDecision,
  ) {
    if (membershipType === MembershipType.INDIGENT && eligibility.approved) {
      return 0;
    }

    // Always calculate from household size — ignore client-sent value
    return this.calculatePremium(householdSize);
  }

  private resolveCoverageStatus(
    membershipType: MembershipType,
    eligibility: EligibilityDecision,
  ) {
    if (membershipType === MembershipType.PAYING) {
      return CoverageStatus.PENDING_RENEWAL;
    }

    // Indigent: PENDING until admin approves, then ACTIVE
    if (!eligibility.approved) {
      return CoverageStatus.PENDING;
    }

    return CoverageStatus.ACTIVE;
  }

  private calculatePremium(memberCount: number) {
    // Base premium covers the household; each additional beneficiary beyond 1 costs extra
    const additionalBeneficiaries = Math.max(memberCount - 1, 0);
    return this.householdBasePremium + additionalBeneficiaries * this.additionalBeneficiaryPremium;
  }

  private issueDigitalCard(input: {
    household: Household;
    beneficiary: Beneficiary;
    coverage: Coverage;
    eligibility: EligibilityDecision;
  }) {
    const payload = {
      cardId: this.generateCode('CARD'),
      householdCode: input.household.householdCode,
      coverageNumber: input.coverage.coverageNumber,
      memberName: input.beneficiary.fullName,
      memberCount: input.household.memberCount,
      membershipType: input.household.membershipType,
      coverageStatus: input.coverage.status,
      eligibilityApproved: input.eligibility.approved,
      validUntil: input.coverage.endDate instanceof Date
        ? input.coverage.endDate.toISOString()
        : ((input.coverage.endDate as unknown as string)?.toString() ?? null),
      issuedAt: new Date().toISOString(),
    };

    return {
      token: this.signPayload(payload),
      qrPayload: payload,
      summary: this.toCoverageSummary(input.coverage),
    };
  }

  private buildDigitalCards(
    household: Household,
    coverage: Coverage,
    beneficiaryId?: string,
  ) {
    const members = beneficiaryId
      ? household.beneficiaries.filter((member) => member.id === beneficiaryId)
      : household.beneficiaries;

    return members.map((member) => {
      const eligibility = {
        score: member.isEligible ? 100 : 0,
        approved: member.isEligible,
        reason: member.isEligible
          ? 'Member is eligible for covered services.'
          : 'Member is not currently eligible for covered services.',
      };
      const card = this.issueDigitalCard({
        household,
        beneficiary: member,
        coverage,
        eligibility,
      });
      return {
        memberId: member.id,
        membershipId: member.memberNumber,
        memberName: member.fullName,
        relationshipToHouseholdHead: member.relationshipToHouseholdHead,
        coverageStatus: coverage.status,
        token: card.token,
        qrPayload: card.qrPayload,
      };
    });
  }

  private buildEligibilitySummary(beneficiary: Beneficiary, household: Household) {
    return {
      approved: beneficiary.isEligible,
      isAdult: beneficiary.dateOfBirth
        ? this.calculateAge(beneficiary.dateOfBirth) >= 18
        : false,
      canLoginIndependently: beneficiary.userAccount?.isActive === true,
      relationshipToHouseholdHead: beneficiary.relationshipToHouseholdHead,
      coverageStatus: household.coverageStatus,
      reason: beneficiary.isEligible
        ? 'Member is eligible for the household coverage.'
        : 'Member is not currently eligible for the household coverage.',
    };
  }

  private async resolveAccessContext(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: [
        'household',
        'beneficiaryProfile',
        'beneficiaryProfile.household',
      ],
    });

    if (!user) {
      throw new NotFoundException(`User ${userId} not found.`);
    }

    if (user.household?.id) {
      const household = await this.loadHouseholdWithMembers(user.household.id);
      return {
        user,
        household,
        beneficiary: this.getPrimaryMember(household),
        isHouseholdHead: true,
      };
    }

    const beneficiary = await this.beneficiaryRepository.findOne({
      where: { userAccount: { id: userId } },
      relations: ['household', 'userAccount'],
    });

    if (!beneficiary?.household) {
      throw new NotFoundException(
        `No beneficiary profile found for ${userId}.`,
      );
    }

    const household = await this.loadHouseholdWithMembers(
      beneficiary.household.id,
    );
    return {
      user,
      household,
      beneficiary,
      isHouseholdHead: false,
    };
  }

  private async loadHouseholdByUser(userId: string) {
    const household = await this.householdRepository.findOne({
      where: { headUser: { id: userId } },
      relations: ['headUser'],
    });

    if (!household) {
      throw new NotFoundException(`Household for user ${userId} not found`);
    }

    return household;
  }

  private async loadHouseholdWithMembers(householdId: string) {
    const household = await this.householdRepository.findOne({
      where: { id: householdId },
      relations: [
        'headUser',
        'beneficiaries',
        'beneficiaries.documents',
        'beneficiaries.userAccount',
      ],
    });

    if (!household) {
      throw new NotFoundException(`Household ${householdId} not found`);
    }

    household.beneficiaries.sort((left, right) => {
      if (left.isPrimaryHolder == right.isPrimaryHolder) {
        return left.fullName.localeCompare(right.fullName);
      }
      return left.isPrimaryHolder ? -1 : 1;
    });
    return household;
  }

  private async loadPrimaryBeneficiary(householdId: string) {
    const beneficiary = await this.beneficiaryRepository.findOne({
      where: { household: { id: householdId }, isPrimaryHolder: true },
      relations: ['userAccount'],
    });

    if (!beneficiary) {
      throw new NotFoundException(
        `Primary beneficiary for household ${householdId} not found`,
      );
    }

    return beneficiary;
  }

  private async loadLatestCoverage(householdId: string) {
    return this.coverageRepository.findOne({
      where: { household: { id: householdId } },
      relations: ['household'],
      order: { createdAt: 'DESC' },
    });
  }

  private getPrimaryMember(household: Household) {
    const beneficiary = household.beneficiaries.find(
      (item) => item.isPrimaryHolder,
    );
    if (!beneficiary) {
      throw new NotFoundException(
        `Primary beneficiary for household ${household.id} not found`,
      );
    }
    return beneficiary;
  }

  private async findHouseholdBeneficiary(
    householdId: string,
    memberId: string,
  ) {
    const beneficiary = await this.beneficiaryRepository.findOne({
      where: { id: memberId, household: { id: householdId } },
      relations: ['documents', 'userAccount'],
    });

    if (!beneficiary) {
      throw new NotFoundException('Family member not found.');
    }

    return beneficiary;
  }

  private async upsertBeneficiaryDocument(
    beneficiary: Beneficiary,
    type: DocumentType,
    filePath?: string | null,
    upload?: InlineAttachmentDto | null,
  ) {
    const storedUpload = upload
      ? await this.persistInlineAttachment(type, beneficiary, upload)
      : null;
    const normalizedPath = storedUpload?.fileUrl ?? this.clean(filePath);
    if (!normalizedPath) {
      return;
    }

    const existing = await this.documentRepository.findOne({
      where: {
        beneficiary: { id: beneficiary.id },
        type,
      },
      relations: ['beneficiary'],
    });

    const fileName = storedUpload?.fileName ?? basename(normalizedPath);
    const mimeType = storedUpload?.mimeType ?? this.resolveMimeType(fileName);
    const document =
      existing ??
      this.documentRepository.create({
        beneficiary,
        type,
        isVerified: false,
      });

    document.fileName = fileName;
    document.fileUrl = normalizedPath;
    document.mimeType = mimeType;
    await this.documentRepository.save(document);
  }

  private async upsertBeneficiaryUserAccount(
    beneficiary: Beneficiary,
    household: Household,
    input: {
      firstName?: string;
      middleName?: string | null;
      lastName?: string;
      phoneNumber?: string | null;
      identityType?: IdentityDocumentType;
      identityNumber?: string;
    },
  ) {
    const phoneNumber =
      this.clean(input.phoneNumber) ?? beneficiary.phoneNumber ?? beneficiary.userAccount?.phoneNumber;
    const eligibleForIndependentAccess = this.canBeneficiaryLoginIndependently(
      beneficiary.relationshipToHouseholdHead,
      beneficiary.dateOfBirth ?? null,
    );

    if (!eligibleForIndependentAccess || !phoneNumber) {
      if (beneficiary.userAccount) {
        beneficiary.userAccount.isActive = false;
        beneficiary.userAccount.phoneNumber = phoneNumber ?? null;
        await this.userRepository.save(beneficiary.userAccount);
      }
      return beneficiary.userAccount
        ? { user: beneficiary.userAccount, setupCode: null }
        : null;
    }

    const user =
      beneficiary.userAccount ??
      this.userRepository.create({
        role: UserRole.BENEFICIARY,
        preferredLanguage:
          household.headUser?.preferredLanguage ?? PreferredLanguage.ENGLISH,
        identityVerificationStatus: IdentityVerificationStatus.PENDING,
      });

    user.firstName = this.cleanRequired(
      input.firstName,
      'beneficiary.firstName',
    );
    user.middleName = this.clean(input.middleName) ?? null;
    user.lastName = this.cleanRequired(input.lastName, 'beneficiary.lastName');
    user.phoneNumber = phoneNumber;
    user.identityType = input.identityType ?? user.identityType ?? null;
    user.identityNumber =
      this.clean(input.identityNumber) ?? user.identityNumber;
    user.nationalId =
      user.identityType === IdentityDocumentType.NATIONAL_ID
        ? (user.identityNumber ?? null)
        : null;
    user.isActive = true;

    const isNewAccount = !beneficiary.userAccount;
    const savedUser = await this.userRepository.save(user);
    if (isNewAccount) {
      beneficiary.userAccount = savedUser;
      await this.beneficiaryRepository.save(beneficiary);
    }

    // Generate a setup code for new accounts so the family member can set their password
    let setupCode: string | null = null;
    if (isNewAccount && eligibleForIndependentAccess && phoneNumber) {
      setupCode = this.generateCode('SC').slice(-6); // 6-digit code
      // Store the setup code as the initial password so the member can sign in
      savedUser.passwordHash = this.authService.hashPassword(setupCode);
      await this.userRepository.save(savedUser);
    }

    return { user: savedUser, setupCode };
  }

  private async recountHouseholdMembers(householdId: string) {
    const count = await this.beneficiaryRepository.count({
      where: { household: { id: householdId } },
    });
    await this.householdRepository.update(householdId, {
      memberCount: Math.max(count, 1),
    });
  }

  private toHouseholdSummary(household: Household) {
    const primaryMember = this.getPrimaryMember(household);
    return {
      householdCode: household.householdCode,
      address: {
        region: household.region,
        zone: household.zone,
        woreda: household.woreda,
        kebele: household.kebele,
      },
      phoneNumber: household.phoneNumber,
      memberCount: household.memberCount,
      membershipType: household.membershipType,
      coverageStatus: household.coverageStatus,
      headUser: {
        firstName: household.headUser?.firstName,
        middleName: household.headUser?.middleName,
        lastName: household.headUser?.lastName,
        phoneNumber: household.headUser?.phoneNumber,
        email: household.headUser?.email,
        identityType: household.headUser?.identityType,
        identityNumber: household.headUser?.identityNumber,
        identityVerificationStatus:
          household.headUser?.identityVerificationStatus,
        preferredLanguage: household.headUser?.preferredLanguage,
      },
      primaryMember: this.toFamilyMemberSummary(primaryMember, household),
    };
  }

  private toFamilyMembers(household: Household) {
    return household.beneficiaries.map((beneficiary) =>
      this.toFamilyMemberSummary(beneficiary, household),
    );
  }

  private toFamilyMemberSummary(
    beneficiary: Beneficiary,
    household: Household,
  ) {
    const identityDocument = beneficiary.documents?.find(
      (document) => document.type === DocumentType.IDENTITY_DOCUMENT,
    );
    const birthCertificate = beneficiary.documents?.find(
      (document) => document.type === DocumentType.BIRTH_CERTIFICATE,
    );
    const beneficiaryPhoto = beneficiary.documents?.find(
      (document) => document.type === DocumentType.BENEFICIARY_PHOTO,
    );

    return {
      id: beneficiary.id,
      membershipId: beneficiary.memberNumber,
      fullName: beneficiary.fullName,
      gender: beneficiary.gender,
      dateOfBirth: beneficiary.dateOfBirth instanceof Date
        ? beneficiary.dateOfBirth.toISOString()
        : ((beneficiary.dateOfBirth as unknown as string)?.toString() ?? null),
      relationshipToHouseholdHead: beneficiary.relationshipToHouseholdHead,
      identityType:
        beneficiary.identityType ??
        beneficiary.userAccount?.identityType ??
        null,
      identityNumber:
        beneficiary.identityNumber ??
        beneficiary.userAccount?.identityNumber ??
        null,
      birthCertificateRef: beneficiary.birthCertificateRef,
      birthCertificatePath: birthCertificate?.fileUrl ?? null,
      idDocumentPath: identityDocument?.fileUrl ?? null,
      photoPath: beneficiaryPhoto?.fileUrl ?? null,
      phoneNumber: beneficiary.phoneNumber ?? beneficiary.userAccount?.phoneNumber ?? null,
      canLoginIndependently:
        beneficiary.userAccount?.isActive === true &&
        beneficiary.userAccount?.role === UserRole.BENEFICIARY,
      coverageStatus: household.coverageStatus,
      isPrimaryHolder: beneficiary.isPrimaryHolder,
      isEligible: beneficiary.isEligible,
    };
  }

  private toViewerSummary(
    user: User,
    beneficiary: Beneficiary,
    isHouseholdHead: boolean,
  ) {
    const beneficiaryPhoto = beneficiary.documents?.find(
      (document) => document.type === DocumentType.BENEFICIARY_PHOTO,
    );

    return {
      userId: user.id,
      role: user.role,
      isHouseholdHead,
      beneficiaryId: beneficiary.id,
      membershipId: beneficiary.memberNumber,
      fullName: beneficiary.fullName,
      phoneNumber: user.phoneNumber ?? null,
      photoPath: beneficiaryPhoto?.fileUrl ?? null,
    };
  }

  private toCoverageSummary(coverage: Coverage) {
    return {
      coverageNumber: coverage.coverageNumber,
      status: coverage.status,
      startDate: coverage.startDate,
      endDate: coverage.endDate,
      premiumAmount: Number(coverage.premiumAmount),
      paidAmount: Number(coverage.paidAmount),
      nextRenewalDate: coverage.nextRenewalDate,
    };
  }

  private composeFullName(
    firstName?: string,
    middleName?: string | null,
    lastName?: string,
  ) {
    return [firstName, middleName, lastName]
      .map((value) => this.clean(value))
      .filter(Boolean)
      .join(' ');
  }

  private namePart(fullName: string, index: number) {
    const parts = fullName
      .split(' ')
      .filter((value) => value.trim().length > 0);
    if (parts.length === 0) {
      return '';
    }

    if (parts.length === 1) {
      return index === 0 ? parts[0] : '';
    }

    if (parts.length === 2) {
      return index === 0 ? parts[0] : index === 2 ? parts[1] : '';
    }

    if (index === 0) {
      return parts.at(0) ?? '';
    }

    if (index === 2) {
      return parts.at(-1) ?? '';
    }

    return parts.slice(1, -1).join(' ');
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

  private async persistInlineAttachment(
    type: DocumentType,
    beneficiary: Beneficiary,
    upload: InlineAttachmentDto,
  ) {
    const fileName = this.sanitizeFileName(upload.fileName);
    const uploadsRoot = resolve(process.cwd(), 'uploads', 'cbhi');
    const folderName = type.toLowerCase();
    const directory = join(uploadsRoot, folderName);
    await mkdir(directory, { recursive: true });

    const storedFileName = `${beneficiary.memberNumber}-${Date.now()}-${fileName}`;
    const targetPath = join(directory, storedFileName);
    const buffer = Buffer.from(upload.contentBase64, 'base64');
    await writeFile(targetPath, buffer);

    return {
      fileName,
      mimeType: this.clean(upload.mimeType) ?? this.resolveMimeType(fileName),
      fileUrl: `/uploads/cbhi/${folderName}/${storedFileName}`,
    };
  }

  private clean(value?: string | null) {
    const trimmed = value?.trim();
    return trimmed ? trimmed : undefined;
  }

  private cleanRequired(value: string | undefined, field: string) {
    const trimmed = value?.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} is required`);
    }
    return trimmed;
  }

  private assertBeneficiaryPhonePolicy(
    relationship: RelationshipToHouseholdHead,
    phoneNumber: string | null,
    action: 'create' | 'update',
  ) {
    // Phone is optional — beneficiaries without a phone simply won't get a login account
  }

  private canBeneficiaryLoginIndependently(
    relationship: RelationshipToHouseholdHead,
    dateOfBirth: Date | string | null,
  ) {
    // Any beneficiary with a phone number can log in independently
    return true;
  }

  private calculateAge(dateOfBirth: Date | string) {
    const dob = dateOfBirth instanceof Date ? dateOfBirth : new Date(dateOfBirth);
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const monthDelta = today.getMonth() - dob.getMonth();
    if (
      monthDelta < 0 ||
      (monthDelta === 0 && today.getDate() < dob.getDate())
    ) {
      age -= 1;
    }
    return age;
  }

  private sanitizeFileName(fileName: string) {
    return fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  }

  private async loadClaimSummaries(input: {
    householdId?: string;
    isHouseholdHead?: boolean;
    beneficiaryId?: string;
    facilityId?: string;
  }) {
    const claims = await this.claimRepository.find({
      where: input.facilityId
        ? { facility: { id: input.facilityId } }
        : input.isHouseholdHead
          ? { household: { id: input.householdId } }
          : { beneficiary: { id: input.beneficiaryId } },
      relations: ['facility', 'beneficiary'],
      order: { createdAt: 'DESC' },
      take: 20,
    });

    return claims.map((claim) => ({
      id: claim.id,
      claimNumber: claim.claimNumber,
      beneficiaryId: claim.beneficiary?.id ?? null,
      beneficiaryName: claim.beneficiary?.fullName ?? null,
      status: claim.status ?? ClaimStatus.DRAFT,
      claimedAmount: Number(claim.claimedAmount),
      approvedAmount: Number(claim.approvedAmount),
      serviceDate:
        claim.serviceDate instanceof Date
          ? claim.serviceDate.toISOString()
          : ((claim.serviceDate as unknown as string)?.toString() ?? null),
      submittedAt: claim.submittedAt instanceof Date
        ? claim.submittedAt.toISOString()
        : ((claim.submittedAt as unknown as string)?.toString() ?? null),
      reviewedAt: claim.reviewedAt instanceof Date
        ? claim.reviewedAt.toISOString()
        : ((claim.reviewedAt as unknown as string)?.toString() ?? null),
      facilityName: claim.facility?.name ?? null,
      decisionNote: claim.decisionNote ?? null,
    }));
  }

  private async loadPaymentSummaries(householdId: string) {
    const payments = await this.paymentRepository.find({
      where: { coverage: { household: { id: householdId } } },
      relations: ['coverage'],
      order: { createdAt: 'DESC' },
      take: 30,
    });

    return payments.map((payment) => ({
      id: payment.id,
      transactionReference: payment.transactionReference,
      amount: Number(payment.amount),
      method: payment.method,
      status: payment.status,
      providerName: payment.providerName ?? null,
      receiptNumber: payment.receiptNumber ?? null,
      paidAt: payment.paidAt instanceof Date
        ? payment.paidAt.toISOString()
        : ((payment.paidAt as unknown as string)?.toString() ?? null),
      coverageNumber: payment.coverage?.coverageNumber ?? null,
      createdAt: payment.createdAt instanceof Date
        ? payment.createdAt.toISOString()
        : ((payment.createdAt as unknown as string)?.toString() ?? new Date().toISOString()),
    }));
  }

  private async loadNotificationSummaries(userId: string) {
    const notifications = await this.notificationRepository.find({
      where: { recipient: { id: userId } },
      order: { createdAt: 'DESC' },
      take: 30,
    });

    return notifications.map((notification) => ({
      id: notification.id,
      title: notification.title,
      message: notification.message,
      type: notification.type,
      isRead: notification.isRead,
      readAt: notification.readAt instanceof Date
        ? notification.readAt.toISOString()
        : ((notification.readAt as unknown as string)?.toString() ?? null),
      createdAt: notification.createdAt instanceof Date
        ? notification.createdAt.toISOString()
        : ((notification.createdAt as unknown as string)?.toString() ?? new Date().toISOString()),
      payload: notification.payload ?? null,
    }));
  }

  private async notifyHouseholdUsers(
    householdId: string,
    type: NotificationType,
    title: string,
    message: string,
    payload?: Record<string, unknown>,
  ) {
    const household = await this.loadHouseholdWithMembers(householdId);
    const recipients = [
      household.headUser,
      ...household.beneficiaries
          .map((member) => member.userAccount)
          .filter((user): user is User => !!user?.isActive),
    ]
      .filter((user): user is User => !!user?.id)
      .reduce<User[]>((unique, user) => {
        if (!unique.some((item) => item.id === user.id)) {
          unique.push(user);
        }
        return unique;
      }, []);

    for (const recipient of recipients) {
      await this.createNotification(
        recipient,
        type,
        title,
        message,
        payload,
      );
    }
  }

  private async createNotification(
    recipient: User,
    type: NotificationType,
    title: string,
    message: string,
    payload?: Record<string, unknown>,
  ) {
    await this.notificationRepository.save(
      this.notificationRepository.create({
        recipient,
        type,
        title,
        message,
        payload: payload ?? null,
        language: recipient.preferredLanguage ?? PreferredLanguage.ENGLISH,
        isRead: false,
      }),
    );
  }

  private async ensureAccountTargetAvailable(input: {
    phoneNumber?: string | null;
    email?: string | null;
    excludeUserId?: string;
  }) {
    const { phoneNumber, email, excludeUserId } = input;
    if (phoneNumber) {
      const existing = await this.userRepository.findOne({
        where: { phoneNumber },
      });
      if (existing && existing.id !== excludeUserId) {
        throw new BadRequestException(
          'That phone number is already registered.',
        );
      }
    }

    if (email) {
      const existing = await this.userRepository
        .createQueryBuilder('user')
        .where('LOWER(user.email) = :email', { email: email.toLowerCase() })
        .getOne();
      if (existing && existing.id !== excludeUserId) {
        throw new BadRequestException('That email is already registered.');
      }
    }
  }

  /** Real-time phone availability check — used by Flutter registration form */
  async checkPhoneAvailability(rawPhone: string) {
    let phoneNumber: string | undefined;
    try {
      phoneNumber = this.authService.normalizePhoneNumber(rawPhone);
    } catch {
      // Partial/invalid number while user is still typing — not an error
      return { available: false, message: 'Invalid phone number format.' };
    }
    if (!phoneNumber) {
      return { available: false, message: 'Invalid phone number format.' };
    }
    const existing = await this.userRepository.findOne({ where: { phoneNumber } });
    return {
      available: !existing,
      message: existing ? 'That phone number is already registered.' : null,
    };
  }

  /** Real-time ID number availability check — used by Flutter registration form */
  async checkIdAvailability(idNumber: string) {
    const trimmed = idNumber?.trim();
    if (!trimmed || trimmed.length < 4) {
      return { available: true, message: null };
    }
    const existing = await this.userRepository.findOne({
      where: { identityNumber: trimmed },
    });
    return {
      available: !existing,
      message: existing ? 'That ID number is already registered.' : null,
    };
  }

  private generateCode(prefix: string) {
    return `${prefix}-${randomBytes(4).toString('hex').toUpperCase()}`;
  }

  /**
   * Generates a structured Membership ID:
   *   PM-<KEBELE>-<HHSEQ>-<MEMBERSEQ>  (paying)
   *   IM-<KEBELE>-<HHSEQ>-<MEMBERSEQ>  (indigent)
   *
   * KEBELE   = kebele name, uppercased, spaces→hyphens, max 10 chars
   * HHSEQ    = zero-padded count of households in that kebele (e.g. 0001)
   * MEMBERSEQ= 01 for household head, 02/03/... for each family member
   */
  private async generateMembershipId(
    membershipType: MembershipType | null | undefined,
    kebele: string,
    householdSeq: number,
    memberSeq: number,
  ): Promise<string> {
    const prefix = membershipType === MembershipType.INDIGENT ? 'IM' : 'PM';
    const kebeleCode = kebele
      .toUpperCase()
      .replace(/\s+/g, '-')
      .replace(/[^A-Z0-9\-]/g, '')
      .substring(0, 10);
    const hhPart = String(householdSeq).padStart(4, '0');
    const memberPart = String(memberSeq).padStart(2, '0');
    return `${prefix}-${kebeleCode}-${hhPart}-${memberPart}`;
  }

  /** Count existing households in a kebele to derive the next sequence number */
  private async nextHouseholdSeqForKebele(kebele: string): Promise<number> {
    const count = await this.householdRepository.count({
      where: { kebele },
    });
    return count + 1;
  }

  /** Count existing beneficiaries in a household to derive the next member seq */
  private async nextMemberSeqForHousehold(householdId: string): Promise<number> {
    const count = await this.beneficiaryRepository.count({
      where: { household: { id: householdId } },
      withDeleted: false,
    });
    return count + 1;
  }

  /**
   * Extracts the household sequence number from an existing memberNumber.
   * e.g. "PM-MAYA-0003-01" → 3
   * Falls back to a random number if the format doesn't match.
   */
  private extractHouseholdSeq(memberNumber: string): number {
    const parts = memberNumber.split('-');
    // Format: PREFIX-KEBELE-HHSEQ-MEMBERSEQ (4+ parts, HHSEQ is second-to-last)
    if (parts.length >= 4) {
      const seq = parseInt(parts[parts.length - 2], 10);
      if (!isNaN(seq)) return seq;
    }
    return Math.floor(Math.random() * 9999) + 1;
  }

  private addMonths(base: Date, months: number) {
    const next = new Date(base);
    next.setMonth(next.getMonth() + months);
    return next;
  }

  private signPayload(payload: Record<string, unknown>) {
    const key = createHash('sha256').update(this.cardSecret).digest();
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    const encrypted = Buffer.concat([
      cipher.update(JSON.stringify(payload), 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    return [iv, encrypted, tag]
      .map((part) => part.toString('base64url'))
      .join('.');
  }

  // ── Coverage History ────────────────────────────────────────────────────────

  /**
   * Returns all coverage periods for the household (past and current).
   * Used by the member app's Coverage History screen.
   */
  async getCoverageHistory(userId: string) {
    const access = await this.resolveAccessContext(userId);
    const coverages = await this.coverageRepository.find({
      where: { household: { id: access.household.id } },
      order: { createdAt: 'DESC' },
    });

    return {
      householdCode: access.household.householdCode,
      coverages: coverages.map((c) => ({
        id: c.id,
        coverageNumber: c.coverageNumber,
        status: c.status,
        startDate: c.startDate instanceof Date
          ? c.startDate.toISOString()
          : ((c.startDate as unknown as string)?.toString() ?? null),
        endDate: c.endDate instanceof Date
          ? c.endDate.toISOString()
          : ((c.endDate as unknown as string)?.toString() ?? null),
        nextRenewalDate: c.nextRenewalDate instanceof Date
          ? c.nextRenewalDate.toISOString()
          : ((c.nextRenewalDate as unknown as string)?.toString() ?? null),
        premiumAmount: Number(c.premiumAmount ?? 0),
        paidAmount: Number(c.paidAmount ?? 0),
        membershipType: access.household.membershipType ?? null,
        createdAt: c.createdAt instanceof Date
          ? c.createdAt.toISOString()
          : ((c.createdAt as unknown as string)?.toString() ?? null),
      })),
      syncedAt: new Date().toISOString(),
    };
  }
}
