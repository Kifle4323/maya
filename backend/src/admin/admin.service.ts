import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Claim } from '../claims/claim.entity';
import {
  ClaimStatus,
  IndigentApplicationStatus,
  NotificationType,
  PreferredLanguage,
  UserRole,
} from '../common/enums/cbhi.enums';
import { CBHIOfficer } from '../cbhi-officers/cbhi-officer.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Household } from '../households/household.entity';
import { IndigentService } from '../indigent/indigent.service';
import { IndigentApplication } from '../indigent/indigent.entity';
import { Notification } from '../notifications/notification.entity';
import { Payment } from '../payments/payment.entity';
import { SystemSetting } from '../system-settings/system-setting.entity';
import { User } from '../users/user.entity';
import {
  ReportsQueryDto,
  ReviewClaimDto,
  ReviewIndigentApplicationDto,
  UpdateSystemSettingDto,
} from './admin.dto';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(CBHIOfficer)
    private readonly officerRepository: Repository<CBHIOfficer>,
    @InjectRepository(Claim)
    private readonly claimRepository: Repository<Claim>,
    @InjectRepository(IndigentApplication)
    private readonly indigentRepository: Repository<IndigentApplication>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(HealthFacility)
    private readonly facilityRepository: Repository<HealthFacility>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    @InjectRepository(SystemSetting)
    private readonly settingRepository: Repository<SystemSetting>,
    private readonly indigentService: IndigentService,
  ) {}

  async getPendingIndigentApplications(userId: string) {
    await this.assertOfficerAccess(userId, 'claims');
    const applications = await this.indigentRepository.find({
      where: { status: IndigentApplicationStatus.PENDING },
      order: { createdAt: 'ASC' },
      take: 50,
    });

    return {
      applications: applications.map((application) => ({
        id: application.id,
        userId: application.userId,
        income: application.income,
        employmentStatus: application.employmentStatus,
        familySize: application.familySize,
        hasProperty: application.hasProperty,
        disabilityStatus: application.disabilityStatus,
        documents: application.documents,
        score: application.score,
        status: application.status,
        reason: application.reason,
        createdAt: application.createdAt.toISOString(),
      })),
      syncedAt: new Date().toISOString(),
    };
  }

  async reviewIndigentApplication(
    userId: string,
    applicationId: string,
    dto: ReviewIndigentApplicationDto,
  ) {
    await this.assertOfficerAccess(userId, 'claims');
    const application = await this.indigentService.overrideApplication(
      applicationId,
      dto,
    );

    const user = application.userId
      ? await this.userRepository.findOne({ where: { id: application.userId } })
      : null;
    if (user) {
      await this.createNotification(
        user,
        NotificationType.SYSTEM_ALERT,
        'Indigent application reviewed',
        `Your indigent application was ${application.status.toLowerCase()}.`,
        {
          applicationId: application.id,
          status: application.status,
        },
      );
    }

    return {
      id: application.id,
      status: application.status,
      reason: application.reason,
      reviewedAt: new Date().toISOString(),
    };
  }

  async reviewClaim(userId: string, claimId: string, dto: ReviewClaimDto) {
    await this.assertOfficerAccess(userId, 'claims');
    const reviewer = await this.userRepository.findOne({ where: { id: userId } });
    const claim = await this.claimRepository.findOne({
      where: { id: claimId },
      relations: ['beneficiary', 'beneficiary.userAccount', 'household', 'household.headUser', 'facility'],
    });

    if (!claim) {
      throw new NotFoundException('Claim not found.');
    }

    claim.status = dto.status;
    claim.reviewedAt = new Date();
    claim.reviewedBy = reviewer ?? null;
    claim.decisionNote = dto.decisionNote?.trim() || null;
    claim.approvedAmount =
      dto.approvedAmount != null
        ? Number(dto.approvedAmount).toFixed(2)
        : dto.status === ClaimStatus.APPROVED || dto.status === ClaimStatus.PAID
          ? claim.claimedAmount
          : '0.00';
    await this.claimRepository.save(claim);

    const recipients = [claim.household?.headUser, claim.beneficiary?.userAccount]
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
        NotificationType.CLAIM_UPDATE,
        'Claim decision updated',
        `Claim ${claim.claimNumber} is now ${claim.status.toLowerCase()}.`,
        {
          claimId: claim.id,
          claimNumber: claim.claimNumber,
          status: claim.status,
          approvedAmount: Number(claim.approvedAmount),
        },
      );
    }

    return {
      id: claim.id,
      claimNumber: claim.claimNumber,
      status: claim.status,
      approvedAmount: Number(claim.approvedAmount),
      decisionNote: claim.decisionNote,
      reviewedAt: claim.reviewedAt?.toISOString() ?? null,
    };
  }

  async listClaimsForReview(userId: string) {
    await this.assertOfficerAccess(userId, 'claims');
    const claims = await this.claimRepository.find({
      relations: [
        'beneficiary',
        'beneficiary.userAccount',
        'household',
        'facility',
      ],
      order: { createdAt: 'DESC' },
      take: 50,
    });

    return {
      claims: claims.map((claim) => ({
        id: claim.id,
        claimNumber: claim.claimNumber,
        status: claim.status,
        claimedAmount: Number(claim.claimedAmount),
        approvedAmount: Number(claim.approvedAmount),
        serviceDate: claim.serviceDate.toISOString(),
        submittedAt: claim.submittedAt?.toISOString() ?? null,
        reviewedAt: claim.reviewedAt?.toISOString() ?? null,
        decisionNote: claim.decisionNote ?? null,
        beneficiaryName: claim.beneficiary?.fullName ?? null,
        membershipId: claim.beneficiary?.memberNumber ?? null,
        householdCode: claim.household?.householdCode ?? null,
        facilityName: claim.facility?.name ?? null,
      })),
      syncedAt: new Date().toISOString(),
    };
  }

  async getSystemConfiguration(userId: string) {
    await this.assertOfficerAccess(userId, 'settings');
    await this.ensureDefaultSettings();
    const settings = await this.settingRepository.find({
      order: { key: 'ASC' },
    });

    return {
      settings: settings.map((setting) => ({
        key: setting.key,
        label: setting.label,
        description: setting.description,
        value: setting.value,
        isSensitive: setting.isSensitive,
        updatedAt: setting.updatedAt.toISOString(),
      })),
      syncedAt: new Date().toISOString(),
    };
  }

  async updateSystemConfiguration(
    userId: string,
    key: string,
    dto: UpdateSystemSettingDto,
  ) {
    await this.assertOfficerAccess(userId, 'settings');
    const normalizedKey = key.trim().toLowerCase();
    await this.ensureDefaultSettings();

    const existing = await this.settingRepository.findOne({
      where: { key: normalizedKey },
    });
    const setting =
      existing ??
      this.settingRepository.create({
        key: normalizedKey,
        label: dto.label?.trim() || normalizedKey,
        description: dto.description?.trim() || null,
        value: dto.value,
        isSensitive: dto.isSensitive ?? false,
      });

    setting.label = dto.label?.trim() || setting.label;
    setting.description = dto.description?.trim() || setting.description;
    setting.value = dto.value;
    setting.isSensitive = dto.isSensitive ?? setting.isSensitive;
    await this.settingRepository.save(setting);
    return this.getSystemConfiguration(userId);
  }

  async generateSummaryReport(userId: string, query: ReportsQueryDto) {
    await this.assertOfficerAccess(userId, 'claims');
    const from = query.from ? new Date(query.from) : null;
    const to = query.to ? new Date(query.to) : null;
    const [households, facilities, pendingIndigent] = await Promise.all([
      this.householdRepository.count(),
      this.facilityRepository.count(),
      this.indigentRepository.count({
        where: { status: IndigentApplicationStatus.PENDING },
      }),
    ]);

    const claimsQuery = this.claimRepository.createQueryBuilder('claim');
    const paymentsQuery = this.paymentRepository.createQueryBuilder('payment');

    if (from) {
      claimsQuery.andWhere('claim.createdAt >= :from', { from });
      paymentsQuery.andWhere('payment.createdAt >= :from', { from });
    }
    if (to) {
      claimsQuery.andWhere('claim.createdAt <= :to', { to });
      paymentsQuery.andWhere('payment.createdAt <= :to', { to });
    }

    const claims = await claimsQuery.getMany();
    const payments = await paymentsQuery.getMany();

    return {
      window: {
        from: from?.toISOString() ?? null,
        to: to?.toISOString() ?? null,
      },
      households,
      accreditedFacilities: facilities,
      pendingIndigentApplications: pendingIndigent,
      claims: {
        submitted: claims.length,
        approved: claims.filter((claim) => claim.status === ClaimStatus.APPROVED).length,
        rejected: claims.filter((claim) => claim.status === ClaimStatus.REJECTED).length,
        paid: claims.filter((claim) => claim.status === ClaimStatus.PAID).length,
        totalClaimedAmount: claims.reduce(
          (sum, claim) => sum + Number(claim.claimedAmount),
          0,
        ),
        totalApprovedAmount: claims.reduce(
          (sum, claim) => sum + Number(claim.approvedAmount),
          0,
        ),
      },
      payments: {
        totalTransactions: payments.length,
        totalCollectedAmount: payments.reduce(
          (sum, payment) => sum + Number(payment.amount),
          0,
        ),
      },
      generatedAt: new Date().toISOString(),
    };
  }

  private async assertOfficerAccess(
    userId: string,
    capability: 'claims' | 'settings',
  ) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException(`User ${userId} not found.`);
    }

    if (user.role === UserRole.SYSTEM_ADMIN) {
      return user;
    }

    if (user.role !== UserRole.CBHI_OFFICER) {
      throw new ForbiddenException(
        'Only CBHI officers and system administrators can access this operation.',
      );
    }

    const officer = await this.officerRepository.findOne({
      where: { user: { id: userId } },
      relations: ['user'],
    });
    if (!officer) {
      throw new ForbiddenException(
        'CBHI officer profile was not found for this account.',
      );
    }

    if (capability === 'claims' && !officer.canApproveClaims) {
      throw new ForbiddenException(
        'This CBHI officer is not allowed to review claims or indigent applications.',
      );
    }

    if (capability === 'settings' && !officer.canManageSettings) {
      throw new ForbiddenException(
        'This CBHI officer is not allowed to manage system configuration.',
      );
    }

    return user;
  }

  private async ensureDefaultSettings() {
    const defaults = [
      {
        key: 'notifications.sms_enabled',
        label: 'SMS notifications',
        description: 'Controls whether OTP and alert SMS delivery is enabled.',
        value: { enabled: false },
      },
      {
        key: 'claims.auto_assign_under_review',
        label: 'Auto mark new claims under review',
        description: 'When enabled, newly submitted claims can automatically enter review.',
        value: { enabled: true },
      },
      {
        key: 'membership.default_premium_per_member',
        label: 'Default premium per member',
        description: 'Baseline ETB amount used when the premium is recalculated.',
        value: { amount: Number(process.env.CBHI_PREMIUM_PER_MEMBER ?? 120) },
      },
    ];

    for (const item of defaults) {
      const exists = await this.settingRepository.findOne({
        where: { key: item.key },
      });
      if (!exists) {
        await this.settingRepository.save(
          this.settingRepository.create({
            key: item.key,
            label: item.label,
            description: item.description,
            value: item.value,
            isSensitive: false,
          }),
        );
      }
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

  async exportToCsv(userId: string, query: { type?: string; from?: string; to?: string }) {
    await this.assertOfficerAccess(userId, 'claims');
    const type = query.type ?? 'households';
    const from = query.from ? new Date(query.from) : null;
    const to = query.to ? new Date(query.to) : null;

    const applyDateFilter = <T extends { createdAt: Date }>(items: T[]) =>
      items.filter((item) => {
        if (from && item.createdAt < from) return false;
        if (to && item.createdAt > to) return false;
        return true;
      });

    const toCsv = (headers: string[], rows: string[][]): string => {
      const escape = (v: string) => `"${v.replace(/"/g, '""')}"`;
      return [
        headers.map(escape).join(','),
        ...rows.map((row) => row.map(escape).join(',')),
      ].join('\n');
    };

    if (type === 'households') {
      const households = applyDateFilter(await this.householdRepository.find({
        relations: ['headUser'],
        order: { createdAt: 'DESC' },
        take: 5000,
      }));
      return toCsv(
        ['Household Code', 'Region', 'Zone', 'Woreda', 'Kebele', 'Member Count', 'Coverage Status', 'Membership Type', 'Created At'],
        households.map((h) => [
          h.householdCode, h.region, h.zone, h.woreda, h.kebele,
          String(h.memberCount), h.coverageStatus, h.membershipType ?? '',
          h.createdAt.toISOString(),
        ]),
      );
    }

    if (type === 'claims') {
      const claims = applyDateFilter(await this.claimRepository.find({
        relations: ['beneficiary', 'household', 'facility'],
        order: { createdAt: 'DESC' },
        take: 5000,
      }));
      return toCsv(
        ['Claim Number', 'Status', 'Beneficiary', 'Household Code', 'Facility', 'Claimed Amount', 'Approved Amount', 'Service Date', 'Created At'],
        claims.map((c) => [
          c.claimNumber, c.status,
          c.beneficiary?.fullName ?? '',
          c.household?.householdCode ?? '',
          c.facility?.name ?? '',
          String(c.claimedAmount), String(c.approvedAmount),
          c.serviceDate.toISOString().split('T')[0],
          c.createdAt.toISOString(),
        ]),
      );
    }

    if (type === 'payments') {
      const payments = applyDateFilter(await this.paymentRepository.find({
        order: { createdAt: 'DESC' },
        take: 5000,
      }));
      return toCsv(
        ['Transaction Reference', 'Amount', 'Method', 'Status', 'Provider', 'Receipt Number', 'Paid At', 'Created At'],
        payments.map((p) => [
          p.transactionReference, String(p.amount), p.method, p.status,
          p.providerName ?? '', p.receiptNumber ?? '',
          p.paidAt?.toISOString() ?? '',
          p.createdAt.toISOString(),
        ]),
      );
    }

    if (type === 'indigent') {
      const applications = applyDateFilter(await this.indigentRepository.find({
        order: { createdAt: 'DESC' },
        take: 5000,
      }));
      return toCsv(
        ['ID', 'User ID', 'Income', 'Employment Status', 'Family Size', 'Has Property', 'Disability', 'Score', 'Status', 'Reason', 'Created At'],
        applications.map((a) => [
          a.id, a.userId ?? '', String(a.income), a.employmentStatus,
          String(a.familySize), String(a.hasProperty), String(a.disabilityStatus),
          String(a.score), a.status, a.reason,
          a.createdAt.toISOString(),
        ]),
      );
    }

    return 'No data';
  }
}
