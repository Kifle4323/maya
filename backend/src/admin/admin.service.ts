import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Claim } from '../claims/claim.entity';
import {
  ClaimStatus,
  CoverageStatus,
  FacilityUserRole,
  IndigentApplicationStatus,
  MembershipType,
  NotificationType,
  UserRole,
} from '../common/enums/cbhi.enums';
import { CBHIOfficer } from '../cbhi-officers/cbhi-officer.entity';
import { CoverageService } from '../cbhi/coverage.service';
import { FacilityUser } from '../facility-users/facility-user.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Household } from '../households/household.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { IndigentService } from '../indigent/indigent.service';
import { IndigentApplication } from '../indigent/indigent.entity';
import { Notification } from '../notifications/notification.entity';
import { NotificationService } from '../notifications/notification.service';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { Payment } from '../payments/payment.entity';
import { SmsService } from '../sms/sms.service';
import { SystemSetting } from '../system-settings/system-setting.entity';
import { User } from '../users/user.entity';
import { AuditLog } from '../audit/audit-log.entity';
import { Referral } from '../referrals/referral.entity';
import {
  ReportsQueryDto,
  ReviewClaimDto,
  ReviewIndigentApplicationDto,
  UpdateSystemSettingDto,
  CreateFacilityDto,
  UpdateFacilityDto,
  AddFacilityStaffDto,
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
    @InjectRepository(FacilityUser)
    private readonly facilityUserRepository: Repository<FacilityUser>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    @InjectRepository(SystemSetting)
    private readonly settingRepository: Repository<SystemSetting>,
    @InjectRepository(AuditLog)
    private readonly auditLogRepository: Repository<AuditLog>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    @InjectRepository(Referral)
    private readonly referralRepository: Repository<Referral>,
    private readonly indigentService: IndigentService,
    private readonly coverageService: CoverageService,
    private readonly notificationService: NotificationService,
    @Optional() private readonly smsService?: SmsService,
    @Optional() private readonly wsGateway?: NotificationsGateway,
  ) {}

  async getPendingIndigentApplications(userId: string, page = 1, limit = 50) {
    await this.assertOfficerAccess(userId, 'claims');
    const [applications, total] = await this.indigentRepository.findAndCount({
      where: { status: IndigentApplicationStatus.PENDING },
      order: { createdAt: 'ASC' },
      skip: (page - 1) * limit,
      take: limit,
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
      total,
      page,
      limit,
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

    if (user && application.status === IndigentApplicationStatus.APPROVED) {
      // B1: Auto-activate household coverage for approved indigent applications
      const household = await this.householdRepository.findOne({
        where: { headUser: { id: user.id } },
        relations: ['headUser'],
      });

      if (household) {
        try {
          const eligibility = { score: 100, approved: true, reason: 'Indigent application approved by officer.' };
          const coverage = await this.coverageService.upsertCoverage(
            household,
            MembershipType.INDIGENT,
            0,
            eligibility,
          );
          coverage.status = CoverageStatus.ACTIVE;
          // coverageService.upsertCoverage already saves; update status directly
          await this.coverageService['coverageRepository']?.save(coverage);

          household.coverageStatus = CoverageStatus.ACTIVE;
          household.membershipType = MembershipType.INDIGENT;
          await this.householdRepository.save(household);

          // Set all beneficiaries isEligible=true
          await this.beneficiaryRepository
            .createQueryBuilder()
            .update()
            .set({ isEligible: true })
            .where('householdId = :id', { id: household.id })
            .execute();

          // Push WebSocket coverage_sync event
          this.wsGateway?.pushCoverageSync(user.id, {
            coverageNumber: coverage.coverageNumber,
            status: coverage.status,
            endDate: coverage.endDate?.toISOString(),
            membershipType: MembershipType.INDIGENT,
          });
        } catch (err) {
          // Log but don't block the response
          console.error(`Failed to auto-activate coverage for indigent approval: ${(err as Error).message}`);
        }

        // Send SMS notification (fire-and-forget)
        if (user.phoneNumber) {
          try {
            await this.smsService?.sendRenewalReminder(
              user.phoneNumber,
              household.householdCode,
              'active',
            );
          } catch (_) { /* SMS failure must not block */ }
        }
      }
    }

    if (user) {
      // FCM push + persistent notification via NotificationService
      await this.notificationService.createAndSend(
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
      await this.notificationService.createAndSend(
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
      // Real-time WebSocket push
      this.wsGateway?.pushClaimUpdate([recipient.id], {
        claimId: claim.id,
        claimNumber: claim.claimNumber,
        status: claim.status,
        approvedAmount: Number(claim.approvedAmount),
        decisionNote: claim.decisionNote,
      });
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

  async listClaimsForReview(userId: string, page = 1, limit = 50) {
    await this.assertOfficerAccess(userId, 'claims');
    const [claims, total] = await this.claimRepository.findAndCount({
      relations: [
        'beneficiary',
        'beneficiary.userAccount',
        'household',
        'facility',
      ],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
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
      total,
      page,
      limit,
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

  // ── Audit log viewer ────────────────────────────────────────────────────────

  async getAuditLogs(userId: string, entityType?: string, entityId?: string, page = 1, limit = 100) {
    await this.assertOfficerAccess(userId, 'claims');
    const qb = this.auditLogRepository
      .createQueryBuilder('log')
      .orderBy('log.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    if (entityType) qb.andWhere('log.entityType = :entityType', { entityType });
    if (entityId) qb.andWhere('log.entityId = :entityId', { entityId });

    const [logs, total] = await qb.getManyAndCount();
    return {
      logs,
      total,
      page,
      limit,
      hasMore: page * limit < total,
      syncedAt: new Date().toISOString(),
    };
  }

  // ── Facility management ─────────────────────────────────────────────────────

  async listFacilities(userId: string) {
    await this.assertOfficerAccess(userId, 'settings');
    const facilities = await this.facilityRepository.find({
      relations: ['facilityUsers', 'facilityUsers.user'],
      order: { name: 'ASC' },
      take: 200,
    });
    return {
      facilities: facilities.map((f) => this.toFacilitySummary(f)),
      syncedAt: new Date().toISOString(),
    };
  }

  async createFacility(userId: string, dto: CreateFacilityDto) {
    await this.assertOfficerAccess(userId, 'settings');
    const existing = dto.facilityCode
      ? await this.facilityRepository.findOne({ where: { facilityCode: dto.facilityCode } })
      : null;
    if (existing) throw new BadRequestException(`Facility code ${dto.facilityCode} already exists.`);

    const facility = await this.facilityRepository.save(
      this.facilityRepository.create({
        name: dto.name.trim(),
        facilityCode: dto.facilityCode?.trim() || null,
        licenseNumber: dto.licenseNumber?.trim() || null,
        serviceLevel: dto.serviceLevel?.trim() || null,
        phoneNumber: dto.phoneNumber?.trim() || null,
        email: dto.email?.trim().toLowerCase() || null,
        addressLine: dto.addressLine?.trim() || null,
        isAccredited: true,
      }),
    );
    return this.toFacilitySummary(facility);
  }

  async updateFacility(userId: string, facilityId: string, dto: UpdateFacilityDto) {
    await this.assertOfficerAccess(userId, 'settings');
    const facility = await this.facilityRepository.findOne({ where: { id: facilityId } });
    if (!facility) throw new NotFoundException('Facility not found.');

    if (dto.name) facility.name = dto.name.trim();
    if (dto.serviceLevel !== undefined) facility.serviceLevel = dto.serviceLevel?.trim() || null;
    if (dto.phoneNumber !== undefined) facility.phoneNumber = dto.phoneNumber?.trim() || null;
    if (dto.email !== undefined) facility.email = dto.email?.trim().toLowerCase() || null;
    if (dto.addressLine !== undefined) facility.addressLine = dto.addressLine?.trim() || null;
    if (dto.isAccredited !== undefined) facility.isAccredited = dto.isAccredited;

    await this.facilityRepository.save(facility);
    return this.toFacilitySummary(facility);
  }

  async addFacilityStaff(userId: string, facilityId: string, dto: AddFacilityStaffDto) {
    await this.assertOfficerAccess(userId, 'settings');
    const facility = await this.facilityRepository.findOne({ where: { id: facilityId } });
    if (!facility) throw new NotFoundException('Facility not found.');

    const identifier = dto.identifier.trim();
    const isEmail = identifier.includes('@');
    let staffUser = await this.userRepository.findOne({
      where: isEmail ? { email: identifier.toLowerCase() } : { phoneNumber: identifier },
    });

    if (!staffUser) {
      staffUser = await this.userRepository.save(
        this.userRepository.create({
          firstName: dto.firstName?.trim() || 'Staff',
          lastName: dto.lastName?.trim() || null,
          email: isEmail ? identifier.toLowerCase() : null,
          phoneNumber: isEmail ? null : identifier,
          role: UserRole.HEALTH_FACILITY_STAFF,
          isActive: true,
        }),
      );
    } else {
      staffUser.role = UserRole.HEALTH_FACILITY_STAFF;
      await this.userRepository.save(staffUser);
    }

    const existing = await this.facilityUserRepository.findOne({
      where: { user: { id: staffUser.id }, facility: { id: facilityId } },
    });
    if (existing) {
      existing.isActive = true;
      await this.facilityUserRepository.save(existing);
    } else {
      await this.facilityUserRepository.save(
        this.facilityUserRepository.create({
          facility,
          user: staffUser,
          role: FacilityUserRole.REGISTRAR,
          isActive: true,
        }),
      );
    }

    return { message: 'Staff member added to facility.', userId: staffUser.id };
  }

  async deactivateFacilityStaff(userId: string, facilityId: string, staffUserId: string) {
    await this.assertOfficerAccess(userId, 'settings');
    const facilityUser = await this.facilityUserRepository.findOne({
      where: { user: { id: staffUserId }, facility: { id: facilityId } },
    });
    if (!facilityUser) throw new NotFoundException('Staff member not found in this facility.');
    facilityUser.isActive = false;
    await this.facilityUserRepository.save(facilityUser);
    return { message: 'Staff member deactivated.' };
  }

  private toFacilitySummary(facility: HealthFacility) {
    return {
      id: facility.id,
      name: facility.name,
      facilityCode: facility.facilityCode ?? null,
      licenseNumber: facility.licenseNumber ?? null,
      serviceLevel: facility.serviceLevel ?? null,
      phoneNumber: facility.phoneNumber ?? null,
      email: facility.email ?? null,
      addressLine: facility.addressLine ?? null,
      isAccredited: facility.isAccredited,
      staffCount: facility.facilityUsers?.filter((fu) => fu.isActive).length ?? 0,
      createdAt: facility.createdAt?.toISOString() ?? null,
    };
  }

  // ── User management ────────────────────────────────────────────────────────

  async listUsers(userId: string, role?: string, page = 1, limit = 50) {
    await this.assertOfficerAccess(userId, 'settings');
    const qb = this.userRepository.createQueryBuilder('user')
      .orderBy('user.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);
    if (role) qb.where('user.role = :role', { role });
    const [users, total] = await qb.getManyAndCount();
    return {
      users: users.map((u) => ({
        id: u.id,
        displayName: [u.firstName, u.middleName, u.lastName].filter(Boolean).join(' '),
        phoneNumber: u.phoneNumber,
        email: u.email,
        role: u.role,
        isActive: u.isActive,
        lastLoginAt: u.lastLoginAt?.toISOString() ?? null,
        createdAt: u.createdAt.toISOString(),
      })),
      total, page, limit,
    };
  }

  async deactivateUser(adminId: string, targetUserId: string) {
    await this.assertOfficerAccess(adminId, 'settings');
    const user = await this.userRepository.findOne({ where: { id: targetUserId } });
    if (!user) throw new NotFoundException('User not found.');
    user.isActive = false;
    await this.userRepository.save(user);
    return { message: 'User deactivated.' };
  }

  async activateUser(adminId: string, targetUserId: string) {
    await this.assertOfficerAccess(adminId, 'settings');
    const user = await this.userRepository.findOne({ where: { id: targetUserId } });
    if (!user) throw new NotFoundException('User not found.');
    user.isActive = true;
    await this.userRepository.save(user);
    return { message: 'User activated.' };
  }

  async resetUserPassword(adminId: string, targetUserId: string) {
    await this.assertOfficerAccess(adminId, 'settings');
    const user = await this.userRepository.findOne({ where: { id: targetUserId } });
    if (!user) throw new NotFoundException('User not found.');
    // Clear password — user must use OTP to set a new one
    user.passwordHash = null;
    await this.userRepository.save(user);
    return { message: 'Password reset. User must sign in via OTP to set a new password.' };
  }

  // ── Financial dashboard ────────────────────────────────────────────────────

  async getFinancialDashboard(userId: string, query: { from?: string; to?: string }) {
    await this.assertOfficerAccess(userId, 'claims');
    const from = query.from ? new Date(query.from) : null;
    const to = query.to ? new Date(query.to) : null;

    const paymentsQb = this.paymentRepository.createQueryBuilder('payment');
    const claimsQb = this.claimRepository.createQueryBuilder('claim');
    if (from) { paymentsQb.andWhere('payment.createdAt >= :from', { from }); claimsQb.andWhere('claim.createdAt >= :from', { from }); }
    if (to) { paymentsQb.andWhere('payment.createdAt <= :to', { to }); claimsQb.andWhere('claim.createdAt <= :to', { to }); }

    const [payments, claims, households] = await Promise.all([
      paymentsQb.getMany(),
      claimsQb.getMany(),
      this.householdRepository.count(),
    ]);

    const totalRevenue = payments.filter(p => p.status === 'SUCCESS').reduce((s, p) => s + Number(p.amount), 0);
    const totalClaims = claims.reduce((s, c) => s + Number(c.approvedAmount ?? 0), 0);
    const netPosition = totalRevenue - totalClaims;

    return {
      totalRevenue,
      totalClaimsPaid: totalClaims,
      netPosition,
      totalHouseholds: households,
      claimApprovalRate: claims.length > 0
        ? Math.round((claims.filter(c => c.status === 'APPROVED' || c.status === 'PAID').length / claims.length) * 100)
        : 0,
      averageClaimAmount: claims.length > 0 ? totalClaims / claims.length : 0,
      generatedAt: new Date().toISOString(),
    };
  }

  // ── Facility performance ───────────────────────────────────────────────────

  async getFacilityPerformance(userId: string, query: { from?: string; to?: string }) {
    await this.assertOfficerAccess(userId, 'claims');
    const facilities = await this.facilityRepository.find({ relations: ['facilityUsers'] });
    const from = query.from ? new Date(query.from) : null;
    const to = query.to ? new Date(query.to) : null;

    const results = await Promise.all(facilities.map(async (facility) => {
      const qb = this.claimRepository.createQueryBuilder('claim')
        .where('claim.facilityId = :fid', { fid: facility.id });
      if (from) qb.andWhere('claim.createdAt >= :from', { from });
      if (to) qb.andWhere('claim.createdAt <= :to', { to });
      const claims = await qb.getMany();
      const approved = claims.filter(c => c.status === 'APPROVED' || c.status === 'PAID');
      return {
        facilityId: facility.id,
        facilityName: facility.name,
        facilityCode: facility.facilityCode,
        serviceLevel: facility.serviceLevel,
        totalClaims: claims.length,
        approvedClaims: approved.length,
        approvalRate: claims.length > 0 ? Math.round((approved.length / claims.length) * 100) : 0,
        totalClaimedAmount: claims.reduce((s, c) => s + Number(c.claimedAmount), 0),
        totalApprovedAmount: approved.reduce((s, c) => s + Number(c.approvedAmount ?? 0), 0),
        staffCount: facility.facilityUsers?.filter(fu => fu.isActive).length ?? 0,
        referralsIssued: await this.referralRepository.countBy({ issuedByFacility: { id: facility.id } }),
        referralsUsed: await this.referralRepository.countBy({ isUsed: true, code: In(claims.map(c => c.referralCode).filter(Boolean)) }),
      };
    }));

    return { facilities: results.sort((a, b) => b.totalClaims - a.totalClaims), generatedAt: new Date().toISOString() };
  }

  async listPayments(userId: string, status?: string, page = 1, limit = 50) {
    await this.assertOfficerAccess(userId, 'claims');
    const qb = this.paymentRepository.createQueryBuilder('payment')
      .leftJoinAndSelect('payment.coverage', 'coverage')
      .leftJoinAndSelect('coverage.household', 'household')
      .leftJoinAndSelect('payment.processedBy', 'user')
      .orderBy('payment.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    if (status) {
      qb.andWhere('payment.status = :status', { status });
    }

    const [payments, total] = await qb.getManyAndCount();
    return {
      payments: payments.map((p) => ({
        id: p.id,
        txRef: p.transactionReference,
        amount: Number(p.amount),
        currency: p.currency,
        status: p.status,
        method: p.method,
        provider: p.providerName,
        receiptNumber: p.receiptNumber,
        paidAt: p.paidAt?.toISOString() ?? null,
        householdCode: p.coverage?.household?.householdCode ?? null,
        userName: p.processedBy ? `${p.processedBy.firstName} ${p.processedBy.lastName || ''}`.trim() : null,
        createdAt: p.createdAt.toISOString(),
      })),
      total,
      page,
      limit,
      syncedAt: new Date().toISOString(),
    };
  }
}
