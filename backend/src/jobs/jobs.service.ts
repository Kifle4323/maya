import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, LessThan, Repository } from 'typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Grievance, GrievanceStatus } from '../grievances/grievance.entity';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import {
  ClaimStatus,
  CoverageStatus,
  NotificationType,
  PreferredLanguage,
} from '../common/enums/cbhi.enums';
import { SmsService } from '../sms/sms.service';
import { FcmService } from '../notifications/fcm.service';
import { NotificationService } from '../notifications/notification.service';

/**
 * JobsService — business logic for all scheduled background jobs.
 * Scheduling is handled by JobsScheduler + Bull queue (multi-instance safe).
 */
@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    @InjectRepository(Grievance)
    private readonly grievanceRepository: Repository<Grievance>,
    @InjectRepository(Claim)
    private readonly claimRepository: Repository<Claim>,
    private readonly smsService: SmsService,
    private readonly fcmService: FcmService,
    private readonly notificationService: NotificationService,
  ) {}

  async runDailyJobs(): Promise<void> {
    this.logger.log('Running daily background jobs...');
    await Promise.allSettled([
      this.sendRenewalReminders(),
      this.suspendExpiredCoverages(),
      this.cleanupOldNotifications(),
      this.cleanupIncompleteRegistrations(),
      this.escalateOverdueGrievances(),
      this.escalateOverdueClaims(),
    ]);
    this.logger.log('Daily background jobs complete');
  }

  /**
   * Send renewal reminders 30 days and 7 days before expiry
   */
  async sendRenewalReminders(): Promise<void> {
    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const expiringSoon = await this.coverageRepository
      .createQueryBuilder('coverage')
      .leftJoinAndSelect('coverage.household', 'household')
      .leftJoinAndSelect('household.headUser', 'headUser')
      .where('coverage.status = :status', { status: CoverageStatus.ACTIVE })
      .andWhere('coverage.endDate <= :in30Days', { in30Days })
      .andWhere('coverage.endDate > :now', { now })
      .getMany();

    let reminded = 0;
    for (const coverage of expiringSoon) {
      try {
        const household = coverage.household;
        const headUser = household?.headUser;
        if (!headUser) continue;

        const endDate = coverage.endDate instanceof Date ? coverage.endDate : new Date(coverage.endDate);
        const daysLeft = Math.ceil(
          (endDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
        );

        const isUrgent = daysLeft <= 7;
        const expiryDate = endDate.toISOString().split('T')[0];

        await this.notificationService.createAndSend(
          headUser,
          NotificationType.RENEWAL_REMINDER,
          isUrgent ? 'Urgent: Coverage expiring soon!' : 'Coverage renewal reminder',
          `Your household coverage (${household.householdCode}) expires on ${expiryDate}. ${isUrgent ? 'Renew immediately to avoid service interruption.' : 'Please renew within 30 days.'}`,
          { householdCode: household.householdCode, expiryDate, daysLeft },
        );

        if (headUser.phoneNumber) {
          try {
            await this.smsService.sendRenewalReminder(
              headUser.phoneNumber,
              household.householdCode,
              expiryDate,
            );
          } catch (smsErr) {
            this.logger.warn(`SMS renewal reminder failed for ${headUser.phoneNumber}: ${(smsErr as Error).message}`);
          }
        }

        reminded++;
      } catch (err) {
        this.logger.error(`Error sending renewal reminder for coverage ${coverage.id}: ${(err as Error).message}`);
      }
    }

    if (reminded > 0) {
      this.logger.log(`Sent ${reminded} renewal reminders`);
    }
  }

  /**
   * B2 — Suspend expired coverages, set isEligible=false, send SMS
   */
  async suspendExpiredCoverages(): Promise<void> {
    const now = new Date();

    const expired = await this.coverageRepository.find({
      where: {
        status: CoverageStatus.ACTIVE,
        endDate: LessThan(now),
      },
      relations: ['household', 'household.headUser'],
    });

    let suspended = 0;
    for (const coverage of expired) {
      try {
        coverage.status = CoverageStatus.EXPIRED;
        await this.coverageRepository.save(coverage);

        if (coverage.household) {
          coverage.household.coverageStatus = CoverageStatus.EXPIRED;
          await this.householdRepository.save(coverage.household);

          // B2: Bulk-set isEligible=false for all beneficiaries in this household
          await this.beneficiaryRepository
            .createQueryBuilder()
            .update()
            .set({ isEligible: false })
            .where('householdId = :id', { id: coverage.household.id })
            .execute();

          // B2: Send SMS to household head
          const headUser = coverage.household.headUser;
          if (headUser?.phoneNumber) {
            try {
              const endDate = coverage.endDate instanceof Date ? coverage.endDate : new Date(coverage.endDate);
              const expiryDate = endDate.toISOString().split('T')[0];
              await this.smsService.sendRenewalReminder(
                headUser.phoneNumber,
                coverage.household.householdCode,
                expiryDate,
              );
            } catch (smsErr) {
              this.logger.warn(`SMS expiry notification failed: ${(smsErr as Error).message}`);
            }
          }

          // B2: Create persistent expiry notification with FCM push
          if (coverage.household.headUser) {
            try {
              await this.notificationService.createAndSend(
                coverage.household.headUser,
                NotificationType.COVERAGE_EXPIRY,
                'Coverage expired',
                `Your household coverage (${coverage.household.householdCode}) has expired. Please renew to restore access to health services.`,
                {
                  householdCode: coverage.household.householdCode,
                  coverageNumber: coverage.coverageNumber,
                  expiredAt: (coverage.endDate instanceof Date ? coverage.endDate : new Date(coverage.endDate)).toISOString(),
                },
              );
            } catch (notifErr) {
              this.logger.warn(`Expiry notification failed: ${(notifErr as Error).message}`);
            }
          }
        }
        suspended++;
      } catch (err) {
        this.logger.error(`Error suspending coverage ${coverage.id}: ${(err as Error).message}`);
      }
    }

    if (suspended > 0) {
      this.logger.log(`Suspended ${suspended} expired coverages`);
    }
  }

  /**
   * Clean up read notifications older than 90 days
   */
  async cleanupOldNotifications(): Promise<void> {
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const result = await this.notificationRepository
      .createQueryBuilder()
      .delete()
      .where('isRead = :isRead', { isRead: true })
      .andWhere('createdAt < :cutoff', { cutoff })
      .execute();

    if ((result.affected ?? 0) > 0) {
      this.logger.log(`Cleaned up ${result.affected} old notifications`);
    }
  }

  /**
   * B5 — Clean up incomplete registrations (no beneficiaries, no coverage, >7 days old)
   */
  async cleanupIncompleteRegistrations(): Promise<void> {
    try {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

      const incomplete = await this.householdRepository
        .createQueryBuilder('household')
        .where('household.memberCount = :count', { count: 0 })
        .andWhere('household.createdAt < :cutoff', { cutoff })
        .andWhere('household.coverageStatus = :status', { status: CoverageStatus.PENDING_RENEWAL })
        .getMany();

      if (incomplete.length === 0) return;

      for (const household of incomplete) {
        household.coverageStatus = CoverageStatus.INACTIVE as CoverageStatus;
        await this.householdRepository.save(household);
      }

      this.logger.log(`Marked ${incomplete.length} incomplete registrations as INACTIVE`);
    } catch (err) {
      this.logger.error(`cleanupIncompleteRegistrations error: ${(err as Error).message}`);
    }
  }

  /**
   * B6 — Escalate grievances open for more than 14 days (SLA)
   */
  async escalateOverdueGrievances(): Promise<void> {
    try {
      const cutoff = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);

      const overdue = await this.grievanceRepository
        .createQueryBuilder('grievance')
        .where('grievance.status IN (:...statuses)', {
          statuses: [GrievanceStatus.OPEN, GrievanceStatus.UNDER_REVIEW],
        })
        .andWhere('grievance.createdAt < :cutoff', { cutoff })
        .getMany();

      if (overdue.length === 0) return;

      for (const grievance of overdue) {
        grievance.status = GrievanceStatus.ESCALATED;
        await this.grievanceRepository.save(grievance);
      }

      this.logger.log(`Escalated ${overdue.length} overdue grievances (>14 days)`);
    } catch (err) {
      this.logger.error(`escalateOverdueGrievances error: ${(err as Error).message}`);
    }
  }

  /**
   * B7 — Escalate claims in SUBMITTED/UNDER_REVIEW for more than 30 days (SLA)
   */
  async escalateOverdueClaims(): Promise<void> {
    try {
      const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const overdue = await this.claimRepository
        .createQueryBuilder('claim')
        .where('claim.status IN (:...statuses)', {
          statuses: [ClaimStatus.SUBMITTED, ClaimStatus.UNDER_REVIEW],
        })
        .andWhere('claim.submittedAt < :cutoff', { cutoff })
        .getMany();

      if (overdue.length === 0) return;

      for (const claim of overdue) {
        claim.status = ClaimStatus.ESCALATED;
        await this.claimRepository.save(claim);
      }

      this.logger.log(`Escalated ${overdue.length} overdue claims (>30 days)`);
    } catch (err) {
      this.logger.error(`escalateOverdueClaims error: ${(err as Error).message}`);
    }
  }
}
