import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { CBHIOfficer } from '../cbhi-officers/cbhi-officer.entity';
import { Claim } from '../claims/claim.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Household } from '../households/household.entity';
import { IndigentModule } from '../indigent/indigent.module';
import { IndigentApplication } from '../indigent/indigent.entity';
import { Notification } from '../notifications/notification.entity';
import { Payment } from '../payments/payment.entity';
import { SystemSetting } from '../system-settings/system-setting.entity';
import { User } from '../users/user.entity';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [
    AuthModule,
    IndigentModule,
    TypeOrmModule.forFeature([
      User,
      CBHIOfficer,
      Claim,
      IndigentApplication,
      Payment,
      Household,
      HealthFacility,
      Notification,
      SystemSetting,
      Beneficiary,
    ]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
