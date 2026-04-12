import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Coverage } from '../coverages/coverage.entity';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import { FcmService } from '../notifications/fcm.service';
import { SmsModule } from '../sms/sms.module';
import { JobsService } from './jobs.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Coverage, Household, Notification]),
    SmsModule,
  ],
  providers: [JobsService, FcmService],
  exports: [JobsService],
})
export class JobsModule {}
