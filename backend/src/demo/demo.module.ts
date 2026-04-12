import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Household } from '../households/household.entity';
import { Payment } from '../payments/payment.entity';
import { DemoController } from './demo.controller';
import { DemoSandboxService } from './demo-sandbox.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Payment, Coverage, Household, Beneficiary]),
  ],
  controllers: [DemoController],
  providers: [DemoSandboxService],
  exports: [DemoSandboxService],
})
export class DemoModule {}
