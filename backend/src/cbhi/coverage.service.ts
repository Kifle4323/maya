import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { BenefitPackage } from '../benefit-packages/benefit-package.entity';
import { Coverage } from '../coverages/coverage.entity';
import {
  CoverageStatus,
  IndigentEmploymentStatus,
  MembershipTier,
  MembershipType,
  PaymentMethod,
  PaymentStatus,
} from '../common/enums/cbhi.enums';
import { Household } from '../households/household.entity';
import { Payment } from '../payments/payment.entity';
import { User } from '../users/user.entity';
import { RenewCoverageDto, RegistrationStepTwoDto } from './cbhi.dto';
import { randomBytes } from 'crypto';

export type EligibilityDecision = {
  score: number;
  approved: boolean;
  reason: string;
};

/**
 * FIX ME-2: CoverageService extracted from the god CbhiService.
 * Handles coverage lifecycle: creation, renewal, status resolution, premium calculation.
 */
@Injectable()
export class CoverageService {
  private readonly premiumPerMember = Number(process.env.CBHI_PREMIUM_PER_MEMBER ?? 120);

  // Research-based 4-tier sliding scale (PMC11936286, Jimma University 2022)
  private get tierBasePremiums() {
    return {
      [MembershipTier.INDIGENT]: 0,
      [MembershipTier.LOW_INCOME]: Number(process.env.CBHI_PREMIUM_LOW ?? 350),
      [MembershipTier.MIDDLE_INCOME]: Number(process.env.CBHI_PREMIUM_MIDDLE ?? 500),
      [MembershipTier.HIGH_INCOME]: Number(process.env.CBHI_PREMIUM_HIGH ?? 650),
    };
  }

  private get additionalAdultPremium() {
    return Number(process.env.CBHI_PREMIUM_ADDITIONAL_ADULT ?? 100);
  }

  /**
   * Calculate tier-based premium.
   * Base + (additionalAdults * additionalAdultRate)
   * additionalAdults = max(0, householdSize - 1)  (first adult is base)
   */
  calculateTierPremium(tier: MembershipTier, householdSize: number): number {
    if (tier === MembershipTier.INDIGENT) return 0;
    const base = this.tierBasePremiums[tier];
    const additionalAdults = Math.max(0, householdSize - 1);
    return base + additionalAdults * this.additionalAdultPremium;
  }

  constructor(
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    @InjectRepository(BenefitPackage)
    private readonly benefitPackageRepository: Repository<BenefitPackage>,
  ) {}

  resolveRegistrationEligibility(
    dto: RegistrationStepTwoDto,
    householdSize: number,
    visionResults?: any[],
  ): EligibilityDecision {
    if (dto.membershipType === MembershipType.PAYING) {
      return this.evaluateEligibility(
        dto.membershipType,
        dto.eligibilitySignals?.employmentStatus as any,
        householdSize,
      );
    }

    const proofs = dto.indigentProofUploads ?? [];
    if (proofs.length < 1) {
      throw new BadRequestException(
        'Indigent membership requires at least one supporting document.',
      );
    }

    const decision = this.evaluateEligibility(
      dto.membershipType,
      dto.eligibilitySignals?.employmentStatus as any,
      householdSize,
    );

    // Automation Logic: Two-way proof (Vision API + Score)
    if (visionResults && visionResults.length > 0) {
      const validResults = visionResults.filter(
        (r) => r.isValid && r.confidence >= 0.85,
      );
      if (validResults.length > 0) {
        // Automatically approve if Vision is confident
        decision.approved = true;
        decision.reason += ` | Vision verified: ${validResults[0].documentType}`;
      } else {
        // Vision failed or is low confidence — gate for Admin review
        decision.approved = false;
        const mainIssue = visionResults[0]?.issues?.[0] ?? 'low confidence';
        decision.reason += ` | Vision verification pending: ${mainIssue}`;
      }
    } else {
      decision.approved = false;
      decision.reason += ' | No valid vision results';
    }

    return decision;
  }

  evaluateEligibility(
    membershipType: MembershipType,
    employmentStatus: IndigentEmploymentStatus,
    householdSize: number,
  ): EligibilityDecision {
    if (membershipType === MembershipType.PAYING) {
      return { score: 100, approved: true, reason: 'Paying membership selected; indigent screening bypassed.' };
    }

    let score = 0;
    const reasons: string[] = [];

    switch (employmentStatus) {
      case IndigentEmploymentStatus.UNEMPLOYED: score += 40; reasons.push('unemployed'); break;
      case IndigentEmploymentStatus.DAILY_LABORER: score += 35; reasons.push('daily laborer'); break;
      case IndigentEmploymentStatus.FARMER: score += 30; reasons.push('smallholder farmer'); break;
      case IndigentEmploymentStatus.HOMEMAKER: score += 28; reasons.push('homemaker'); break;
      case IndigentEmploymentStatus.PENSIONER: score += 26; reasons.push('pensioner'); break;
      case IndigentEmploymentStatus.STUDENT: score += 24; reasons.push('student'); break;
      case IndigentEmploymentStatus.MERCHANT: score += 10; reasons.push('merchant'); break;
      case IndigentEmploymentStatus.EMPLOYED: reasons.push('formally employed'); break;
      default: throw new BadRequestException('Unsupported employment status');
    }

    if (householdSize >= 6) { score += 15; reasons.push('large household'); }
    else if (householdSize >= 4) { score += 8; reasons.push('mid-size household'); }

    const approved = score >= 40;
    return {
      score,
      approved,
      reason: approved
        ? `Zero-touch indigent approval: ${reasons.join(', ')}`
        : `Zero-touch indigent rejection: ${reasons.join(', ')}`,
    };
  }

  resolveCoverageStatus(membershipType: MembershipType, eligibility: EligibilityDecision): CoverageStatus {
    if (membershipType === MembershipType.PAYING) return CoverageStatus.PENDING_RENEWAL;
    return eligibility.approved ? CoverageStatus.ACTIVE : CoverageStatus.REJECTED;
  }

  resolvePremiumAmount(
    householdSize: number,
    membershipType: MembershipType,
    requestedPremium: number | undefined,
    eligibility: EligibilityDecision,
    membershipTier?: MembershipTier,
  ): number {
    if (membershipType === MembershipType.INDIGENT && eligibility.approved) return 0;
    // If a tier is specified, use tier-based calculation
    if (membershipTier && membershipTier !== MembershipTier.INDIGENT) {
      return this.calculateTierPremium(membershipTier, householdSize);
    }
    if (membershipType === MembershipType.PAYING && requestedPremium !== undefined && requestedPremium >= 0) return requestedPremium;
    // Default: MIDDLE_INCOME tier (500 ETB base, aligns with research mode)
    return this.calculateTierPremium(MembershipTier.MIDDLE_INCOME, householdSize);
  }

  async upsertCoverage(
    household: Household,
    membershipType: MembershipType,
    requestedPremium: number | undefined,
    eligibility: EligibilityDecision,
    membershipTier?: MembershipTier,
  ) {
    const current = await this.coverageRepository.findOne({
      where: { household: { id: household.id } },
      relations: ['household'],
      order: { createdAt: 'DESC' },
    });

    const coverage = current ?? this.coverageRepository.create({
      coverageNumber: this.generateCode('CVG'),
      household,
    });

    const startDate = new Date();
    const endDate = this.addMonths(startDate, 12);
    const premiumAmount = this.resolvePremiumAmount(household.memberCount, membershipType, requestedPremium, eligibility, membershipTier);

    coverage.startDate = startDate;
    coverage.endDate = endDate;
    coverage.nextRenewalDate = endDate;
    coverage.status = this.resolveCoverageStatus(membershipType, eligibility);
    coverage.premiumAmount = premiumAmount.toFixed(2);
    coverage.paidAmount = coverage.paidAmount ?? '0.00';

    // B1: Link active benefit package
    try {
      const activePkg = await this.benefitPackageRepository.findOne({ where: { isActive: true } });
      if (activePkg) coverage.benefitPackage = activePkg;
    } catch (_) { /* non-blocking */ }

    // B6: Set claimsEligibleFrom — 30-day waiting period for PAYING, immediate for INDIGENT
    if (membershipType === MembershipType.PAYING) {
      const waitEnd = new Date(startDate);
      waitEnd.setDate(waitEnd.getDate() + 30);
      coverage.claimsEligibleFrom = waitEnd;
    } else {
      coverage.claimsEligibleFrom = startDate;
    }

    return this.coverageRepository.save(coverage);
  }

  async renewCoverage(userId: string, household: Household, beneficiary: Beneficiary, user: User, dto: RenewCoverageDto) {
    const membershipType = household.membershipType;
    if (!membershipType) throw new BadRequestException('Household membership type is not configured yet.');

    const coverage = await this.coverageRepository.findOne({
      where: { household: { id: household.id } },
      order: { createdAt: 'DESC' },
    });
    if (!coverage) throw new NotFoundException(`Coverage for household ${household.householdCode} not found.`);

    const eligibility: EligibilityDecision = {
      score: beneficiary.isEligible ? 100 : 0,
      approved: beneficiary.isEligible,
      reason: beneficiary.isEligible ? 'Household remains eligible.' : 'Household is not eligible.',
    };

    const premiumAmount = this.resolvePremiumAmount(household.memberCount, membershipType, dto.amount, eligibility);

    if (premiumAmount > 0 && !dto.paymentMethod) {
      throw new BadRequestException('A payment method is required to renew a paying household coverage.');
    }

    const renewedAt = new Date();
    coverage.startDate = renewedAt;
    coverage.endDate = this.addMonths(renewedAt, 12);
    coverage.nextRenewalDate = coverage.endDate;
    coverage.status = CoverageStatus.ACTIVE;
    coverage.premiumAmount = premiumAmount.toFixed(2);
    coverage.paidAmount = premiumAmount.toFixed(2);
    await this.coverageRepository.save(coverage);

    household.coverageStatus = CoverageStatus.ACTIVE;
    await this.householdRepository.save(household);

    await this.beneficiaryRepository
      .createQueryBuilder()
      .update(Beneficiary)
      .set({ isEligible: true })
      .where('householdId = :householdId', { householdId: household.id })
      .execute();

    if (premiumAmount > 0 && dto.paymentMethod) {
      await this.paymentRepository.save(
        this.paymentRepository.create({
          transactionReference: this.generateCode('PAY'),
          amount: premiumAmount.toFixed(2),
          method: dto.paymentMethod,
          status: PaymentStatus.SUCCESS,
          providerName: dto.providerName ?? null,
          receiptNumber: dto.receiptNumber ?? null,
          paidAt: renewedAt,
          coverage,
          processedBy: user,
        }),
      );
    }

    return coverage;
  }

  async loadLatestCoverage(householdId: string) {
    return this.coverageRepository.findOne({
      where: { household: { id: householdId } },
      order: { createdAt: 'DESC' },
    });
  }

  toCoverageSummary(coverage: Coverage) {
    return {
      coverageNumber: coverage.coverageNumber,
      status: coverage.status,
      startDate: coverage.startDate?.toISOString() ?? null,
      endDate: coverage.endDate?.toISOString() ?? null,
      nextRenewalDate: coverage.nextRenewalDate?.toISOString() ?? null,
      premiumAmount: Number(coverage.premiumAmount ?? 0),
      paidAmount: Number(coverage.paidAmount ?? 0),
      annualCeiling: Number(coverage.benefitPackage?.annualCeiling ?? 0),
      benefitPackageId: coverage.benefitPackage?.id ?? null,
    };
  }

  private addMonths(date: Date, months: number) {
    const result = new Date(date);
    result.setMonth(result.getMonth() + months);
    return result;
  }

  private generateCode(prefix: string) {
    return `${prefix}-${randomBytes(4).toString('hex').toUpperCase()}`;
  }
}
