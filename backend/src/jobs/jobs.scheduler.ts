import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { CBHI_JOBS_QUEUE, JOB_DAILY } from './jobs.processor';

/**
 * JobsScheduler — uses BullMQ cron scheduling so only one instance in a
 * multi-container deployment runs the job at any given time.
 *
 * Gracefully degrades when Redis is unavailable (dev without Redis).
 */
@Injectable()
export class JobsScheduler implements OnModuleInit {
  private readonly logger = new Logger(JobsScheduler.name);

  constructor(
    @InjectQueue(CBHI_JOBS_QUEUE)
    private readonly jobsQueue: Queue,
  ) {}

  async onModuleInit(): Promise<void> {
    // Skip scheduling if Redis is not configured
    if (!process.env.REDIS_HOST) {
      this.logger.warn(
        'REDIS_HOST not set — BullMQ job scheduling disabled. ' +
        'Set REDIS_HOST to enable background jobs.',
      );
      return;
    }

    try {
      // Remove stale repeatable jobs from previous deployments
      const repeatableJobs = await this.jobsQueue.getRepeatableJobs();
      for (const job of repeatableJobs) {
        await this.jobsQueue.removeRepeatableByKey(job.key);
      }

      // Schedule daily job at 00:05 UTC
      await this.jobsQueue.add(
        JOB_DAILY,
        {},
        {
          repeat: { pattern: '5 0 * * *' },
          removeOnComplete: { count: 10 },
          removeOnFail: { count: 20 },
          attempts: 3,
          backoff: { type: 'exponential', delay: 60_000 },
        },
      );

      this.logger.log('Daily job scheduled via BullMQ (cron: 5 0 * * *)');

      // Run once on startup after 30s to catch up on missed jobs
      await this.jobsQueue.add(
        JOB_DAILY,
        { reason: 'startup' },
        { delay: 30_000, removeOnComplete: true, attempts: 2 },
      );

      this.logger.log('Startup job queued (runs in 30s)');
    } catch (err) {
      this.logger.error(
        `Failed to schedule BullMQ jobs (Redis may be unavailable): ${(err as Error).message}`,
      );
      // Don't crash the app — jobs will be scheduled on next restart
    }
  }
}
