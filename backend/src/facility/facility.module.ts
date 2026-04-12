import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { ClaimItem } from '../claim-items/claim-item.entity';
import { Claim } from '../claims/claim.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Document } from '../documents/document.entity';
import { FacilityUser } from '../facility-users/facility-user.entity';
import { Notification } from '../notifications/notification.entity';
import { FacilityController } from './facility.controller';
import { FacilityService } from './facility.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      FacilityUser,
      Beneficiary,
      Coverage,
      Claim,
      ClaimItem,
      Document,
      Notification,
    ]),
  ],
  controllers: [FacilityController],
  providers: [FacilityService],
})
export class FacilityModule {}
