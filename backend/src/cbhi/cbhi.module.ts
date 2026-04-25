import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { BenefitPackage } from '../benefit-packages/benefit-package.entity';
import { ClaimAppeal } from '../claims/claim-appeal.entity';
import { ClaimItem } from '../claim-items/claim-item.entity';
import { Claim } from '../claims/claim.entity';
import { ClaimAppealService } from '../claims/claim-appeal.service';
import { Coverage } from '../coverages/coverage.entity';
import { Document } from '../documents/document.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Household } from '../households/household.entity';
import { IntegrationsModule } from '../integrations/integrations.module';
import { Notification } from '../notifications/notification.entity';
import { Payment } from '../payments/payment.entity';
import { StorageModule } from '../storage/storage.module';
import { VisionModule } from '../vision/vision.module';
import { User } from '../users/user.entity';
import { CbhiController } from './cbhi.controller';
import { CbhiService } from './cbhi.service';
import { CoverageService } from './coverage.service';
import { DigitalCardService } from './digital-card.service';
import { RegistrationService } from './registration.service';

@Module({
  imports: [
    AuthModule,
    AuditModule,
    IntegrationsModule,
    StorageModule,
    VisionModule,
    TypeOrmModule.forFeature([
      User,
      Household,
      Beneficiary,
      BenefitPackage,
      Document,
      Coverage,
      Payment,
      Claim,
      ClaimAppeal,
      ClaimItem,
      Notification,
      HealthFacility,
    ]),
  ],
  controllers: [CbhiController],
  providers: [
    CbhiService,
    CoverageService,
    DigitalCardService,
    RegistrationService,
    ClaimAppealService,
  ],
  exports: [CbhiService, CoverageService, DigitalCardService, ClaimAppealService],
})
export class CbhiModule {}
