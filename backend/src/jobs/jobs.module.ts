import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Grievance } from '../grievances/grievance.entity';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import { FcmService } from '../notifications/fcm.service';
import { NotificationService } from '../notifications/notification.service';
import { SmsModule } from '../sms/sms.module';
import { JobsService } from './jobs.service';
import { JobsProcessor, CBHI_JOBS_QUEUE } from './jobs.processor';
import { JobsScheduler } from './jobs.scheduler';

@Module({
  imports: [
    TypeOrmModule.forFeature([Coverage, Household, Notification, Beneficiary, Grievance, Claim]),
    SmsModule,
    BullModule.registerQueue({
      name: CBHI_JOBS_QUEUE,
    }),
  ],
  providers: [JobsService, FcmService, NotificationService, JobsProcessor, JobsScheduler],
  exports: [JobsService],
})
export class JobsModule {}
