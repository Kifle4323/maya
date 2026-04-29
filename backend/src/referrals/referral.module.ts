import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Referral } from './referral.entity';
import { ReferralService } from './referral.service';
import { ReferralController } from './referral.controller';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { FacilityUser } from '../facility-users/facility-user.entity';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [TypeOrmModule.forFeature([Referral, HealthFacility, Beneficiary, FacilityUser]), AuthModule],
  providers: [ReferralService],
  controllers: [ReferralController],
  exports: [ReferralService],
})
export class ReferralModule {}
