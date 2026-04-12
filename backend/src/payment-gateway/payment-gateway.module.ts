import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Household } from '../households/household.entity';
import { Payment } from '../payments/payment.entity';
import { ChapaService } from './chapa.service';
import { PaymentGatewayController } from './payment-gateway.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Coverage, Payment, Household, Beneficiary]),
  ],
  controllers: [PaymentGatewayController],
  providers: [ChapaService],
  exports: [ChapaService],
})
export class PaymentGatewayModule {}
