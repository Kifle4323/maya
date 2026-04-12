import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';
import { Coverage } from '../coverages/coverage.entity';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import { CoverageStatus, NotificationType, PreferredLanguage } from '../common/enums/cbhi.enums';
import { SmsService } from '../sms/sms.service';
import { FcmService } from '../notifications/fcm.service';

/**
 * Background job processor — runs scheduled tasks without external queue.
 * Uses Node.js setInterval for simplicity (no Redis/Bull required).
 *
 * Jobs:
 *   1. Coverage expiry reminders — daily at midnight
 *   2. Expired coverage suspension — daily
 *   3. Notification cleanup — weekly
 */
@Injectable()
export class JobsService implements OnModuleInit {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    private readonly smsService: SmsService,
    private readonly fcmService: FcmService,
  ) {}

  onModuleInit() {
    // Run daily jobs every 24 hours
    const DAILY_MS = 24 * 60 * 60 * 1000;

    // Run once on startup (after 30s delay to let DB settle)
    setTimeout(() => {
      void this.runDailyJobs();
    }, 30_000);

    // Then every 24 hours
    setInterval(() => {
      void this.runDailyJobs();
    }, DAILY_MS);

    this.logger.log('Background jobs scheduled (daily)');
  }

  async runDailyJobs(): Promise<void> {
    this.logger.log('Running daily background jobs...');
    await Promise.allSettled([
      this.sendRenewalReminders(),
      this.suspendExpiredCoverages(),
      this.cleanupOldNotifications(),
    ]);
    this.logger.log('Daily background jobs complete');
  }

  /**
   * Send renewal reminders 30 days and 7 days before expiry
   */
  async sendRenewalReminders(): Promise<void> {
    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const in7Days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

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
      const household = coverage.household;
      const headUser = household?.headUser;
      if (!headUser) continue;

      const daysLeft = Math.ceil(
        (coverage.endDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
      );

      const isUrgent = daysLeft <= 7;
      const expiryDate = coverage.endDate.toISOString().split('T')[0];

      // Create in-app notification
      await this.notificationRepository.save(
        this.notificationRepository.create({
          recipient: headUser,
          type: NotificationType.RENEWAL_REMINDER,
          title: isUrgent ? 'Urgent: Coverage expiring soon!' : 'Coverage renewal reminder',
          message: `Your household coverage (${household.householdCode}) expires on ${expiryDate}. ${isUrgent ? 'Renew immediately to avoid service interruption.' : 'Please renew within 30 days.'}`,
          payload: {
            householdCode: household.householdCode,
            expiryDate,
            daysLeft,
          },
          language: headUser.preferredLanguage ?? PreferredLanguage.ENGLISH,
          isRead: false,
        }),
      );

      // Send SMS if phone available
      if (headUser.phoneNumber) {
        await this.smsService.sendRenewalReminder(
          headUser.phoneNumber,
          household.householdCode,
          expiryDate,
        );
      }

      reminded++;
    }

    if (reminded > 0) {
      this.logger.log(`Sent ${reminded} renewal reminders`);
    }
  }

  /**
   * Suspend coverages that have passed their end date
   */
  async suspendExpiredCoverages(): Promise<void> {
    const now = new Date();

    const expired = await this.coverageRepository.find({
      where: {
        status: CoverageStatus.ACTIVE,
        endDate: LessThan(now),
      },
      relations: ['household'],
    });

    let suspended = 0;
    for (const coverage of expired) {
      coverage.status = CoverageStatus.EXPIRED;
      await this.coverageRepository.save(coverage);

      if (coverage.household) {
        coverage.household.coverageStatus = CoverageStatus.EXPIRED;
        await this.householdRepository.save(coverage.household);
      }
      suspended++;
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
}
