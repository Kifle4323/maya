import { Injectable, Logger, Optional } from '@nestjs/common';
import { DemoSandboxService } from '../demo/demo-sandbox.service';

export interface ChapaInitiatePaymentInput {
  amount: number;
  currency?: string;
  email?: string;
  phoneNumber?: string;
  firstName: string;
  lastName: string;
  txRef: string;
  callbackUrl?: string;
  returnUrl?: string;
  description?: string;
  metadata?: Record<string, string>;
}

export interface ChapaPaymentResult {
  success: boolean;
  checkoutUrl?: string;
  txRef: string;
  message: string;
  data?: Record<string, unknown>;
  isDemo?: boolean;
}

export interface ChapaVerifyResult {
  success: boolean;
  status: 'success' | 'failed' | 'pending';
  txRef: string;
  amount?: number;
  currency?: string;
  paymentMethod?: string;
  paidAt?: string;
  message: string;
  isDemo?: boolean;
}

/**
 * Chapa Payment Gateway — Ethiopian Payment Processor
 *
 * Demo mode (no CHAPA_SECRET_KEY): instant simulated success with visual payment page
 * Live mode: real Chapa API (register free at https://dashboard.chapa.co)
 *
 * Test key format: CHASECK_TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 */
@Injectable()
export class ChapaService {
  private readonly logger = new Logger(ChapaService.name);
  private readonly secretKey = process.env.CHAPA_SECRET_KEY ?? '';
  private readonly baseUrl = 'https://api.chapa.co/v1';

  constructor(
    @Optional() private readonly demo: DemoSandboxService,
  ) {}

  get isConfigured(): boolean {
    return this.secretKey.length > 0;
  }

  async initiatePayment(input: ChapaInitiatePaymentInput): Promise<ChapaPaymentResult> {
    // Demo mode
    if (this.demo?.isActive || !this.isConfigured) {
      return this.demo?.initiatePayment(input) ?? {
        success: true,
        checkoutUrl: `http://localhost:3000/api/v1/demo/payment-page?txRef=${input.txRef}&amount=${input.amount}`,
        txRef: input.txRef,
        message: 'Demo payment — no CHAPA_SECRET_KEY configured',
        isDemo: true,
      };
    }

    try {
      const payload = {
        amount: input.amount.toFixed(2),
        currency: input.currency ?? 'ETB',
        email: input.email ?? `${input.txRef}@cbhi.et`,
        phone_number: input.phoneNumber,
        first_name: input.firstName,
        last_name: input.lastName,
        tx_ref: input.txRef,
        callback_url: input.callbackUrl ?? process.env.CHAPA_CALLBACK_URL,
        return_url: input.returnUrl ?? process.env.CHAPA_RETURN_URL,
        customization: {
          title: 'Maya City CBHI Premium',
          description: input.description ?? 'CBHI membership premium payment',
        },
        meta: input.metadata ?? {},
      };

      const response = await fetch(`${this.baseUrl}/transaction/initialize`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.secretKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const result = await response.json() as {
        status: string;
        message: string;
        data?: { checkout_url?: string };
      };

      if (!response.ok || result.status !== 'success') {
        this.logger.error(`Chapa initiate failed: ${result.message}`);
        return { success: false, txRef: input.txRef, message: result.message ?? 'Payment initiation failed' };
      }

      this.logger.log(`Chapa payment initiated: ${input.txRef} — ${input.amount} ETB`);
      return {
        success: true,
        checkoutUrl: result.data?.checkout_url,
        txRef: input.txRef,
        message: 'Payment initiated successfully',
        data: result.data as Record<string, unknown>,
      };
    } catch (error) {
      this.logger.error(`Chapa initiate exception: ${(error as Error).message}`);
      return { success: false, txRef: input.txRef, message: 'Payment service temporarily unavailable' };
    }
  }

  async verifyPayment(txRef: string): Promise<ChapaVerifyResult> {
    // Demo mode — always succeeds
    if (this.demo?.isActive || !this.isConfigured) {
      return this.demo?.verifyPayment(txRef) ?? {
        success: true,
        status: 'success',
        txRef,
        amount: 120,
        currency: 'ETB',
        message: 'Demo payment verified',
        isDemo: true,
      };
    }

    try {
      const response = await fetch(`${this.baseUrl}/transaction/verify/${txRef}`, {
        headers: { Authorization: `Bearer ${this.secretKey}`, 'Content-Type': 'application/json' },
      });

      const result = await response.json() as {
        status: string;
        message: string;
        data?: { status?: string; amount?: number; currency?: string; payment_method?: string; created_at?: string };
      };

      if (!response.ok) {
        return { success: false, status: 'failed', txRef, message: result.message ?? 'Verification failed' };
      }

      const paymentStatus = result.data?.status === 'success' ? 'success'
        : result.data?.status === 'pending' ? 'pending' : 'failed';

      return {
        success: paymentStatus === 'success',
        status: paymentStatus,
        txRef,
        amount: result.data?.amount,
        currency: result.data?.currency,
        paymentMethod: result.data?.payment_method,
        paidAt: result.data?.created_at,
        message: result.message ?? 'Verification complete',
      };
    } catch (error) {
      this.logger.error(`Chapa verify exception: ${(error as Error).message}`);
      return { success: false, status: 'failed', txRef, message: 'Verification service temporarily unavailable' };
    }
  }

  verifyWebhookSignature(payload: string, signature: string): boolean {
    const webhookSecret = process.env.CHAPA_WEBHOOK_SECRET ?? '';
    if (!webhookSecret) return true;
    const { createHmac } = require('crypto') as typeof import('crypto');
    const expected = createHmac('sha256', webhookSecret).update(payload).digest('hex');
    return expected === signature;
  }
}
