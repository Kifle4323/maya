import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Coverage } from '../coverages/coverage.entity';
import {
  CoverageStatus,
  DocumentType,
  IdentityDocumentType,
  IdentityVerificationStatus,
  MembershipType,
  PreferredLanguage,
  RelationshipToHouseholdHead,
  UserRole,
} from '../common/enums/cbhi.enums';
import { Document } from '../documents/document.entity';
import { Household } from '../households/household.entity';
import { User } from '../users/user.entity';
import {
  InlineAttachmentDto,
  RegistrationStepOneDto,
  RegistrationStepTwoDto,
} from './cbhi.dto';
import { CoverageService } from './coverage.service';
import { DigitalCardService } from './digital-card.service';
import { VisionService } from '../vision/vision.service';
import { mkdir, writeFile } from 'fs/promises';
import { basename, extname, join, resolve } from 'path';
import { randomBytes } from 'crypto';

/**
 * FIX ME-2: RegistrationService extracted from the god CbhiService.
 * Handles household registration steps 1 and 2 only.
 */
@Injectable()
export class RegistrationService {
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
    private readonly authService: AuthService,
    private readonly coverageService: CoverageService,
    private readonly digitalCardService: DigitalCardService,
    private readonly visionService: VisionService,
  ) {}

  async registerStepOne(dto: RegistrationStepOneDto) {
    const phoneNumber = this.authService.normalizePhoneNumber(dto.phone) ?? null;
    const email = this.authService.normalizeEmail(dto.email) ?? null;

    await this.ensureAccountTargetAvailable({ phoneNumber, email });

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
        memberNumber: this.generateCode('MBR'),
        fullName: this.composeFullName(dto.firstName, dto.middleName, dto.lastName),
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

    await this.upsertBeneficiaryDocument(beneficiary, DocumentType.IDENTITY_DOCUMENT, dto.idDocumentPath, dto.idDocumentUpload);
    await this.upsertBeneficiaryDocument(beneficiary, DocumentType.BIRTH_CERTIFICATE, dto.birthCertificatePath, dto.birthCertificateUpload);

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

    if (!user) throw new NotFoundException(`Registration ${dto.registrationId} not found`);

    const household = user.household ?? await this.loadHouseholdByUser(user.id);
    const beneficiary = user.beneficiaryProfile ?? await this.loadPrimaryBeneficiary(household.id);

    user.identityType = dto.identityType;
    user.identityNumber = this.cleanRequired(dto.identityNumber, 'identityNumber');
    user.identityVerificationStatus = IdentityVerificationStatus.VERIFIED;
    user.identityVerifiedAt = new Date();
    user.nationalId = dto.identityType === IdentityDocumentType.NATIONAL_ID ? user.identityNumber : null;
    await this.userRepository.save(user);

    beneficiary.identityType = dto.identityType;
    beneficiary.identityNumber = user.identityNumber;
    beneficiary.nationalId = user.nationalId;

    // Automation: Two-way proof for Indigent HHs
    const visionResults = [];
    if (dto.membershipType === MembershipType.INDIGENT && dto.indigentProofUploads?.length) {
      // Validate all proofs in parallel via Google Vision
      const results = await Promise.all(
        dto.indigentProofUploads.map((upload) =>
          this.visionService.validateIndigentDocument(upload.contentBase64),
        ),
      );
      visionResults.push(...results);
    }

    const eligibility = this.coverageService.resolveRegistrationEligibility(
      dto,
      household.memberCount,
      visionResults,
    );
    household.membershipType = dto.membershipType;
    household.coverageStatus = this.coverageService.resolveCoverageStatus(
      dto.membershipType,
      eligibility,
    );
    await this.householdRepository.save(household);

    beneficiary.isEligible = dto.membershipType === MembershipType.PAYING || eligibility.approved;
    await this.beneficiaryRepository.save(beneficiary);

    const coverage = await this.coverageService.upsertCoverage(household, dto.membershipType, dto.premiumAmount, eligibility);

    if (dto.membershipType === MembershipType.INDIGENT && dto.indigentProofUploads?.length) {
      await this.appendIndigentProofDocuments(beneficiary, dto.indigentProofUploads);
    }

    const fullHousehold = await this.loadHouseholdWithMembers(household.id);
    const primaryMember = fullHousehold.beneficiaries.find((b) => b.isPrimaryHolder) ?? fullHousehold.beneficiaries[0];
    const digitalCard = this.digitalCardService.issueDigitalCard({ household: fullHousehold, beneficiary: primaryMember, coverage, eligibility });

    return {
      registrationId: user.id,
      householdCode: fullHousehold.householdCode,
      membershipType: dto.membershipType,
      identityStatus: user.identityVerificationStatus,
      eligibility,
      auth: await this.authService.issueSession(user.id),
    };
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private async ensureAccountTargetAvailable(input: { phoneNumber?: string | null; email?: string | null }) {
    if (input.phoneNumber) {
      const existing = await this.userRepository.findOne({ where: { phoneNumber: input.phoneNumber } });
      if (existing) throw new BadRequestException(`Phone number ${input.phoneNumber} is already registered.`);
    }
    if (input.email) {
      const existing = await this.userRepository.findOne({ where: { email: input.email } });
      if (existing) throw new BadRequestException(`Email ${input.email} is already registered.`);
    }
  }

  private async loadHouseholdByUser(userId: string) {
    const household = await this.householdRepository.findOne({
      where: { headUser: { id: userId } },
      relations: ['headUser', 'beneficiaries'],
    });
    if (!household) throw new NotFoundException(`Household for user ${userId} not found.`);
    return household;
  }

  private async loadPrimaryBeneficiary(householdId: string) {
    const beneficiary = await this.beneficiaryRepository.findOne({
      where: { household: { id: householdId }, isPrimaryHolder: true },
      relations: ['household', 'userAccount'],
    });
    if (!beneficiary) throw new NotFoundException(`Primary beneficiary for household ${householdId} not found.`);
    return beneficiary;
  }

  private async loadHouseholdWithMembers(householdId: string) {
    const household = await this.householdRepository.findOne({
      where: { id: householdId },
      relations: ['headUser', 'beneficiaries', 'beneficiaries.userAccount', 'beneficiaries.documents'],
    });
    if (!household) throw new NotFoundException(`Household ${householdId} not found.`);
    return household;
  }

  private async appendIndigentProofDocuments(beneficiary: Beneficiary, uploads: InlineAttachmentDto[]) {
    for (const upload of uploads) {
      const stored = await this.persistInlineAttachment(DocumentType.OTHER, beneficiary, upload);
      await this.documentRepository.save(
        this.documentRepository.create({
          beneficiary,
          type: DocumentType.OTHER,
          fileName: stored.fileName,
          fileUrl: stored.fileUrl,
          mimeType: stored.mimeType,
          isVerified: false,
        }),
      );
    }
  }

  private async upsertBeneficiaryDocument(
    beneficiary: Beneficiary,
    type: DocumentType,
    filePath?: string,
    upload?: InlineAttachmentDto,
  ) {
    const stored = upload ? await this.persistInlineAttachment(type, beneficiary, upload) : null;
    const normalizedPath = stored?.fileUrl ?? this.clean(filePath);
    if (!normalizedPath) return;

    const existing = await this.documentRepository.findOne({
      where: { beneficiary: { id: beneficiary.id }, type },
    });

    const fileName = stored?.fileName ?? basename(normalizedPath);
    const mimeType = stored?.mimeType ?? this.resolveMimeType(fileName);
    const doc = existing ?? this.documentRepository.create({ beneficiary, type, isVerified: false });
    doc.fileName = fileName;
    doc.fileUrl = normalizedPath;
    doc.mimeType = mimeType;
    await this.documentRepository.save(doc);
  }

  private async persistInlineAttachment(type: DocumentType, beneficiary: Beneficiary, upload: InlineAttachmentDto) {
    const fileName = this.sanitizeFileName(upload.fileName);
    const uploadsRoot = resolve(process.cwd(), 'uploads', type.toLowerCase());
    await mkdir(uploadsRoot, { recursive: true });
    const storedFileName = `${beneficiary.id}-${Date.now()}-${fileName}`;
    const targetPath = join(uploadsRoot, storedFileName);
    await writeFile(targetPath, Buffer.from(upload.contentBase64, 'base64'));
    return {
      fileName,
      mimeType: this.clean(upload.mimeType) ?? this.resolveMimeType(fileName),
      fileUrl: `/uploads/${type.toLowerCase()}/${storedFileName}`,
    };
  }

  private composeFullName(first: string, middle?: string | null, last?: string | null) {
    return [first, middle, last].filter(Boolean).join(' ').trim();
  }

  private cleanRequired(value: string | undefined, field: string) {
    const trimmed = value?.trim();
    if (!trimmed) throw new BadRequestException(`${field} is required.`);
    return trimmed;
  }

  private clean(value?: string | null) {
    const trimmed = value?.trim();
    return trimmed || undefined;
  }

  private sanitizeFileName(fileName: string) {
    return fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  }

  private resolveMimeType(fileName: string) {
    const ext = extname(fileName).toLowerCase();
    return ({ '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.pdf': 'application/pdf' }[ext] ?? 'application/octet-stream');
  }

  private generateCode(prefix: string) {
    return `${prefix}-${randomBytes(4).toString('hex').toUpperCase()}`;
  }
}
