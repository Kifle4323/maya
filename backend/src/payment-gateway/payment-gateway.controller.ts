import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
} from '@nestjs/common';
import { IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import type { Request } from 'express';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomBytes } from 'crypto';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Payment } from '../payments/payment.entity';
import { Household } from '../households/household.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { CoverageStatus, PaymentMethod, PaymentStatus } from '../common/enums/cbhi.enums';
import { ChapaService } from './chapa.service';

class InitiatePaymentDto {
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  amount!: number;

  @IsOptional()
  @IsString()
  description?: string;
}

@Controller('payments')
export class PaymentGatewayController {
  constructor(
    private readonly chapaService: ChapaService,
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
  ) {}

  /**
   * Initiate a Chapa payment for CBHI premium renewal
   * Returns a checkout URL for the user to complete payment
   */
  @Post('initiate')
  async initiatePayment(
    @CurrentUser() user: User,
    @Body() dto: InitiatePaymentDto,
  ) {
    const household = await this.householdRepository.findOne({
      where: { headUser: { id: user.id } },
      relations: ['headUser'],
    });

    if (!household) {
      throw new BadRequestException('No household found for this account.');
    }

    const coverage = await this.coverageRepository.findOne({
      where: { household: { id: household.id } },
      order: { createdAt: 'DESC' },
    });

    if (!coverage) {
      throw new BadRequestException('No coverage record found for this household.');
    }

    const txRef = `CBHI-${household.householdCode}-${randomBytes(6).toString('hex').toUpperCase()}`;

    const result = await this.chapaService.initiatePayment({
      amount: dto.amount,
      currency: 'ETB',
      email: user.email ?? undefined,
      phoneNumber: user.phoneNumber ?? undefined,
      firstName: user.firstName,
      lastName: user.lastName ?? 'Member',
      txRef,
      description: dto.description ?? `CBHI premium for household ${household.householdCode}`,
      metadata: {
        householdCode: household.householdCode,
        coverageId: coverage.id,
        userId: user.id,
      },
    });

    if (!result.success) {
      throw new BadRequestException(result.message);
    }

    // Create a pending payment record
    await this.paymentRepository.save(
      this.paymentRepository.create({
        transactionReference: txRef,
        amount: dto.amount.toFixed(2),
        method: PaymentMethod.MOBILE_MONEY,
        status: PaymentStatus.PENDING,
        providerName: 'Chapa',
        coverage,
        processedBy: user,
      }),
    );

    return {
      txRef,
      checkoutUrl: result.checkoutUrl,
      amount: dto.amount,
      currency: 'ETB',
      message: result.message,
      isTestMode: (process.env.CHAPA_SECRET_KEY ?? '').includes('TEST') || !process.env.CHAPA_SECRET_KEY,
    };
  }

  /**
   * Verify a payment by transaction reference
   * Call this after the user returns from the Chapa checkout page
   */
  @Get('verify/:txRef')
  async verifyPayment(
    @CurrentUser() user: User,
    @Param('txRef') txRef: string,
  ) {
    const payment = await this.paymentRepository.findOne({
      where: { transactionReference: txRef },
      relations: ['coverage', 'coverage.household'],
    });

    if (!payment) {
      throw new BadRequestException(`Payment ${txRef} not found.`);
    }

    const result = await this.chapaService.verifyPayment(txRef);

    if (result.status === 'success') {
      payment.status = PaymentStatus.SUCCESS;
      payment.paidAt = result.paidAt ? new Date(result.paidAt) : new Date();
      payment.receiptNumber = txRef;
      await this.paymentRepository.save(payment);

      // Activate coverage
      if (payment.coverage) {
        const coverage = payment.coverage;
        const renewedAt = new Date();
        coverage.status = CoverageStatus.ACTIVE;
        coverage.paidAmount = payment.amount;
        coverage.startDate = renewedAt;
        coverage.endDate = new Date(renewedAt.getFullYear() + 1, renewedAt.getMonth(), renewedAt.getDate());
        coverage.nextRenewalDate = coverage.endDate;
        await this.coverageRepository.save(coverage);

        // Activate household
        if (coverage.household) {
          coverage.household.coverageStatus = CoverageStatus.ACTIVE;
          await this.householdRepository.save(coverage.household);
        }

        // Activate all beneficiaries
        await this.beneficiaryRepository
          .createQueryBuilder()
          .update()
          .set({ isEligible: true })
          .where('householdId = :id', { id: coverage.household?.id })
          .execute();
      }
    } else if (result.status === 'failed') {
      payment.status = PaymentStatus.FAILED;
      await this.paymentRepository.save(payment);
    }

    return {
      txRef,
      status: result.status,
      amount: result.amount,
      currency: result.currency,
      paymentMethod: result.paymentMethod,
      paidAt: result.paidAt,
      message: result.message,
      coverageActivated: result.status === 'success',
    };
  }

  /**
   * Chapa webhook — called by Chapa when payment status changes
   * Must be @Public() — no auth token from Chapa
   */
  @Public()
  @Post('webhook/chapa')
  async chapaWebhook(
    @Headers('x-chapa-signature') signature: string,
    @Body() body: Record<string, unknown>,
  ) {
    const rawBody = JSON.stringify(body);

    if (!this.chapaService.verifyWebhookSignature(rawBody, signature)) {
      throw new BadRequestException('Invalid webhook signature.');
    }

    const txRef = body['tx_ref']?.toString() ?? body['trx_ref']?.toString();
    const status = body['status']?.toString();

    if (!txRef) return { received: true };

    const payment = await this.paymentRepository.findOne({
      where: { transactionReference: txRef },
      relations: ['coverage', 'coverage.household'],
    });

    if (!payment) return { received: true };

    if (status === 'success' && payment.status !== PaymentStatus.SUCCESS) {
      payment.status = PaymentStatus.SUCCESS;
      payment.paidAt = new Date();
      payment.receiptNumber = txRef;
      await this.paymentRepository.save(payment);

      if (payment.coverage) {
        const coverage = payment.coverage;
        const renewedAt = new Date();
        coverage.status = CoverageStatus.ACTIVE;
        coverage.paidAmount = payment.amount;
        coverage.startDate = renewedAt;
        coverage.endDate = new Date(renewedAt.getFullYear() + 1, renewedAt.getMonth(), renewedAt.getDate());
        coverage.nextRenewalDate = coverage.endDate;
        await this.coverageRepository.save(coverage);

        if (coverage.household) {
          coverage.household.coverageStatus = CoverageStatus.ACTIVE;
          await this.householdRepository.save(coverage.household);
        }
      }
    }

    return { received: true };
  }
}
