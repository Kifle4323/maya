import { BadRequestException, Injectable, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { Repository } from 'typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Coverage } from '../coverages/coverage.entity';
import { CoverageStatus, NotificationType, PaymentMethod, PaymentStatus } from '../common/enums/cbhi.enums';
import { Household } from '../households/household.entity';
import { Notification } from '../notifications/notification.entity';
import { NotificationService } from '../notifications/notification.service';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { Payment } from '../payments/payment.entity';
import { SmsService } from '../sms/sms.service';
import { User } from '../users/user.entity';
import { ChapaService } from './chapa.service';

/**
 * FIX ME-3: Extracted PaymentService from PaymentGatewayController.
 * All business logic (coverage activation, beneficiary eligibility update,
 * WebSocket push) lives here. The controller is now a thin HTTP adapter.
 */
@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);

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
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    private readonly notificationService: NotificationService,
    @Optional() private readonly smsService?: SmsService,
    @Optional() private readonly wsGateway?: NotificationsGateway,
  ) {}

  async initiatePayment(user: User, amount: number, description?: string) {
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

    // ── Already-paid check: prevent duplicate payments ────────────────────
    const completedPayment = await this.paymentRepository.findOne({
      where: {
        coverage: { id: coverage.id },
        status: PaymentStatus.SUCCESS,
      },
    });
    if (completedPayment) {
      throw new BadRequestException('You have already paid for this coverage period.');
    }

    // ── Pending payment check: reuse existing checkout URL ─────────────────
    const pendingPayment = await this.paymentRepository.findOne({
      where: {
        coverage: { id: coverage.id },
        status: PaymentStatus.PENDING,
      },
    });
    if (pendingPayment) {
      const checkoutUrl = (pendingPayment as any).checkoutUrl ?? null;
      this.logger.log(`Reusing pending payment ${pendingPayment.transactionReference}`);
      return {
        txRef: pendingPayment.transactionReference,
        checkoutUrl,
        amount: parseFloat(pendingPayment.amount),
        currency: pendingPayment.currency,
        message: 'You have a pending payment',
        isTestMode: (process.env.CHAPA_SECRET_KEY ?? '').includes('TEST') || !process.env.CHAPA_SECRET_KEY,
      };
    }

    const txRef = `CBHI-${household.householdCode}-${randomBytes(6).toString('hex').toUpperCase()}`;

    // Build a return URL that routes through backend callback → app deep link
    const appBaseUrl = process.env.APP_BASE_URL ?? 'http://localhost:3000';
    const returnUrl = `${appBaseUrl}/api/v1/payments/callback?tx_ref=${txRef}`;

    const result = await this.chapaService.initiatePayment({
      amount,
      currency: 'ETB',
      email: user.email ?? undefined,
      phoneNumber: user.phoneNumber ?? undefined,
      firstName: user.firstName,
      lastName: user.lastName ?? 'Member',
      txRef,
      returnUrl,
      description: description ?? `CBHI premium for household ${household.householdCode}`,
      metadata: {
        householdCode: household.householdCode,
        coverageId: coverage.id,
        userId: user.id,
      },
    });

    if (!result.success) {
      // Extract the actual Chapa error message for better UX
      const chapaMsg = result.message || 'Payment initiation failed — check Chapa configuration';
      throw new BadRequestException(chapaMsg);
    }

    this.logger.log(`Initiating payment for user ${user.id}: ${amount} ${result.data?.['currency'] || 'ETB'}`);

    const payment = this.paymentRepository.create({
      transactionReference: txRef,
      amount: amount.toFixed(2),
      currency: 'ETB',
      method: PaymentMethod.MOBILE_MONEY,
      status: PaymentStatus.PENDING,
      providerName: 'Chapa',
      coverage,
      processedBy: user,
    });
    // Store checkout URL on payment entity for pending-payment reuse
    (payment as any).checkoutUrl = result.checkoutUrl ?? null;
    await this.paymentRepository.save(payment);

    const isTestMode =
      (process.env.CHAPA_SECRET_KEY ?? '').includes('TEST') ||
      !process.env.CHAPA_SECRET_KEY;

    return {
      txRef,
      checkoutUrl: result.checkoutUrl,
      amount,
      currency: 'ETB',
      message: result.message,
      isTestMode,
    };
  }

  async verifyPayment(txRef: string) {
    const payment = await this.paymentRepository.findOne({
      where: { transactionReference: txRef },
      relations: ['coverage', 'coverage.household', 'coverage.household.headUser'],
    });

    if (!payment) {
      throw new BadRequestException(`Payment ${txRef} not found.`);
    }

    // If already completed, return cached result without re-verifying
    if (payment.status === PaymentStatus.SUCCESS) {
      return {
        txRef,
        status: 'success',
        amount: parseFloat(payment.amount),
        currency: payment.currency,
        paidAt: payment.paidAt?.toISOString?.() ?? null,
        message: 'Payment already verified',
        coverageActivated: true,
        coverageEndDate: payment.coverage?.endDate instanceof Date
          ? payment.coverage.endDate.toISOString()
          : ((payment.coverage?.endDate as unknown as string)?.toString() ?? null),
        company_name: 'Maya City CBHI',
        customer_email: payment.coverage?.household?.headUser?.email ?? 'member@cbhi.et',
      };
    }

    // If still pending, verify with Chapa
    const result = await this.chapaService.verifyPayment(txRef);
    this.logger.log(`Verification result for ${txRef}: ${result.status} - ${result.amount} ${result.currency}`);

    if (result.status === 'success') {
      // Security check: validate amount and currency (skip for demo/test payments)
      const isDemo = result.isDemo || (process.env.CHAPA_SECRET_KEY ?? '').includes('TEST');
      if (!isDemo && result.amount && Math.abs(result.amount - parseFloat(payment.amount)) > 0.01) {
        this.logger.error(`Amount mismatch for ${txRef}: expected ${payment.amount}, got ${result.amount}`);
        throw new BadRequestException('Payment amount mismatch.');
      }
      
      payment.chapaReference = result.data?.['reference']?.toString();
      await this.activateCoverageAfterPayment(payment, txRef);
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
      coverageEndDate: payment.coverage?.endDate instanceof Date
        ? payment.coverage.endDate.toISOString()
        : ((payment.coverage?.endDate as unknown as string)?.toString() ?? null),
      company_name: 'Maya City CBHI',
      customer_email: payment.coverage?.household?.headUser?.email ?? 'member@cbhi.et',
    };
  }

  async handleWebhook(txRef: string, status: string) {
    const payment = await this.paymentRepository.findOne({
      where: { transactionReference: txRef },
      relations: ['coverage', 'coverage.household', 'coverage.household.headUser'],
    });

    if (!payment) return;

    if (status === 'success' && payment.status !== PaymentStatus.SUCCESS) {
      // Verify with Chapa before marking complete (security)
      try {
        const verifyResult = await this.chapaService.verifyPayment(txRef);
        if (verifyResult.status === 'success') {
          await this.activateCoverageAfterPayment(payment, txRef);
          this.logger.log(`Webhook payment completed: ${txRef}`);
        } else {
          this.logger.warn(`Webhook said success but Chapa verify returned: ${verifyResult.status} for ${txRef}`);
        }
      } catch (err) {
        this.logger.error(`Webhook verify error for ${txRef}: ${(err as Error).message}`);
      }
    } else if (status === 'failed') {
      payment.status = PaymentStatus.FAILED;
      await this.paymentRepository.save(payment);
    }
  }

  /**
   * FIX ME-3: Single shared method for coverage activation — eliminates
   * the duplication that existed between verifyPayment and chapaWebhook.
   */
  private async activateCoverageAfterPayment(payment: Payment, txRef: string) {
    payment.status = PaymentStatus.SUCCESS;
    payment.paidAt = new Date();
    payment.receiptNumber = txRef;
    await this.paymentRepository.save(payment);

    if (!payment.coverage) return;

    const coverage = payment.coverage;
    const renewedAt = new Date();
    coverage.status = CoverageStatus.ACTIVE;
    coverage.paidAmount = payment.amount;
    coverage.startDate = renewedAt;
    coverage.endDate = new Date(
      renewedAt.getFullYear() + 1,
      renewedAt.getMonth(),
      renewedAt.getDate(),
    );
    coverage.nextRenewalDate = coverage.endDate;
    await this.coverageRepository.save(coverage);

    if (coverage.household) {
      coverage.household.coverageStatus = CoverageStatus.ACTIVE;
      await this.householdRepository.save(coverage.household);

      await this.beneficiaryRepository
        .createQueryBuilder()
        .update()
        .set({ isEligible: true })
        .where('householdId = :id', { id: coverage.household.id })
        .execute();

      const headUserId = coverage.household.headUser?.id;
      if (headUserId) {
        this.wsGateway?.pushCoverageSync(headUserId, {
          coverageNumber: coverage.coverageNumber,
          status: coverage.status,
          endDate: coverage.endDate instanceof Date
          ? coverage.endDate.toISOString()
          : ((coverage.endDate as unknown as string)?.toString() ?? null),
          paidAmount: payment.amount,
        });

        // B3: Persistent notification + FCM push via NotificationService
        try {
          const headUser = coverage.household.headUser!;
          await this.notificationService.createAndSend(
            headUser,
            NotificationType.PAYMENT_CONFIRMATION,
            'Payment confirmed',
            `Your CBHI premium was received. Coverage active until ${(coverage.endDate instanceof Date ? coverage.endDate.toISOString() : (coverage.endDate as unknown as string)?.toString() ?? 'N/A').split('T')[0]}. Ref: ${txRef}`,
            { txRef, coverageNumber: coverage.coverageNumber, endDate: coverage.endDate instanceof Date ? coverage.endDate.toISOString() : ((coverage.endDate as unknown as string)?.toString() ?? null) },
          );
        } catch (_) { /* non-blocking */ }

        // B3: SMS confirmation (fire-and-forget)
        const headPhone = coverage.household.headUser?.phoneNumber;
        if (headPhone) {
          try {
            await this.smsService?.sendClaimUpdate(headPhone, txRef, 'PAYMENT_CONFIRMED');
          } catch (_) { /* non-blocking */ }
        }
      }
    }
  }
}
