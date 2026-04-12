import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { ClaimItem } from '../claim-items/claim-item.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Document } from '../documents/document.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Household } from '../households/household.entity';
import { IntegrationsModule } from '../integrations/integrations.module';
import { Notification } from '../notifications/notification.entity';
import { Payment } from '../payments/payment.entity';
import { StorageModule } from '../storage/storage.module';
import { User } from '../users/user.entity';
import { CbhiController } from './cbhi.controller';
import { CbhiService } from './cbhi.service';

@Module({
  imports: [
    AuthModule,
    AuditModule,
    IntegrationsModule,
    StorageModule,
    TypeOrmModule.forFeature([
      User,
      Household,
      Beneficiary,
      Document,
      Coverage,
      Payment,
      Claim,
      ClaimItem,
      Notification,
      HealthFacility,
    ]),
  ],
  controllers: [CbhiController],
  providers: [CbhiService],
  exports: [CbhiService],
})
export class CbhiModule {}
