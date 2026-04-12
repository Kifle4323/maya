import { Injectable, Logger } from '@nestjs/common';
import { randomBytes } from 'crypto';

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CBHI DEMO SANDBOX SERVICE
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Provides fully working demo responses for ALL external integrations.
 * No API keys, no external accounts, no internet required.
 *
 * Activated by: DEMO_MODE=true in .env (default in development)
 *
 * Simulates:
 *   ✅ SMS OTP delivery (returns code in response + logs to console)
 *   ✅ Chapa payment gateway (instant success simulation)
 *   ✅ Google Vision API (realistic ID/document text extraction)
 *   ✅ Firebase FCM push notifications (logged to console)
 *   ✅ Google Cloud Storage (saves to local disk)
 *   ✅ Fayda National ID verification (simulated approval)
 *   ✅ openIMIS sync (simulated success)
 *
 * Demo test credentials:
 *   Phone: +251912345678  (any valid Ethiopian format works)
 *   OTP:   shown in server console + API response debugCode
 *   Payment: auto-succeeds after 3 seconds
 *   ID verification: always passes for demo
 */

export const DEMO_OTP_STORE = new Map<string, { code: string; expiresAt: number }>();

@Injectable()
export class DemoSandboxService {
  private readonly logger = new Logger('DemoSandbox');

  get isActive(): boolean {
    return (
      process.env.DEMO_MODE === 'true' ||
      (process.env.NODE_ENV === 'development' && !process.env.AT_API_KEY)
    );
  }

  // ── SMS ──────────────────────────────────────────────────────────────────

  sendSmsOtp(phoneNumber: string, code: string): void {
    DEMO_OTP_STORE.set(phoneNumber, {
      code,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });
    this.logger.log(
      `\n${'═'.repeat(60)}\n` +
      `  📱 DEMO SMS — OTP for ${phoneNumber}\n` +
      `  Code: ${code}\n` +
      `  (Also returned as debugCode in API response)\n` +
      `${'═'.repeat(60)}`,
    );
  }

  sendSmsRenewalReminder(phoneNumber: string, householdCode: string, expiryDate: string): void {
    this.logger.log(`[DEMO SMS] Renewal reminder → ${phoneNumber} | HH: ${householdCode} | Expires: ${expiryDate}`);
  }

  sendSmsClaimUpdate(phoneNumber: string, claimNumber: string, status: string): void {
    this.logger.log(`[DEMO SMS] Claim update → ${phoneNumber} | ${claimNumber}: ${status}`);
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  initiatePayment(input: {
    amount: number;
    txRef: string;
    firstName: string;
    lastName: string;
    description?: string;
  }) {
    this.logger.log(
      `\n${'═'.repeat(60)}\n` +
      `  💳 DEMO PAYMENT INITIATED\n` +
      `  TxRef: ${input.txRef}\n` +
      `  Amount: ${input.amount} ETB\n` +
      `  Name: ${input.firstName} ${input.lastName}\n` +
      `  → Call GET /api/v1/payments/verify/${input.txRef} to simulate success\n` +
      `${'═'.repeat(60)}`,
    );

    return {
      success: true,
      checkoutUrl: `http://localhost:3000/api/v1/demo/payment-page?txRef=${input.txRef}&amount=${input.amount}`,
      txRef: input.txRef,
      message: 'Demo payment initiated — visit the checkout URL to simulate payment',
      isDemo: true,
    };
  }

  verifyPayment(txRef: string) {
    this.logger.log(`[DEMO PAYMENT] Verifying ${txRef} → SUCCESS`);
    return {
      success: true,
      status: 'success' as const,
      txRef,
      amount: 120,
      currency: 'ETB',
      paymentMethod: 'demo_telebirr',
      paidAt: new Date().toISOString(),
      message: 'Demo payment verified successfully',
      isDemo: true,
    };
  }

  // ── Vision / Document Validation ─────────────────────────────────────────

  validateIdDocument(imageBase64: string, expectedIdNumber?: string) {
    this.logger.log(`[DEMO VISION] ID document validation → PASSED`);
    const demoFanNumber = expectedIdNumber ?? '123456789012';
    return {
      isValid: true,
      extractedText: `FEDERAL DEMOCRATIC REPUBLIC OF ETHIOPIA\nNATIONAL ID CARD\nFAN: ${demoFanNumber}\nAlemayehu Bekele Tadesse\nDate of Birth: 15/03/1990\nGender: Male\nRegion: Oromia`,
      detectedName: 'Alemayehu Bekele Tadesse',
      detectedIdNumber: demoFanNumber,
      confidence: 0.97,
      issues: [],
      isDemo: true,
    };
  }

  validateIndigentDocument(imageBase64: string) {
    this.logger.log(`[DEMO VISION] Indigent document validation → PASSED`);
    return {
      isValid: true,
      documentType: 'Income Certificate',
      extractedText: 'KEBELE ADMINISTRATION OFFICE\nINCOME CERTIFICATE\nThis is to certify that the bearer earns less than 1000 ETB per month\nKebele: 01, Woreda: Maya City\nDate: 2024-01-15',
      detectedKeywords: ['INCOME', 'CERTIFICATE', 'KEBELE'],
      confidence: 0.94,
      issues: [],
      isDemo: true,
    };
  }

  // ── FCM Push Notifications ────────────────────────────────────────────────

  sendPushNotification(fcmToken: string, title: string, body: string, data?: Record<string, string>): void {
    this.logger.log(
      `[DEMO FCM] Push notification\n` +
      `  Token: ${fcmToken.substring(0, 20)}...\n` +
      `  Title: ${title}\n` +
      `  Body: ${body}`,
    );
  }

  // ── Fayda ID Verification ─────────────────────────────────────────────────

  verifyFaydaId(fanNumber: string, fullName?: string) {
    this.logger.log(`[DEMO FAYDA] Verifying FAN: ${fanNumber} → VERIFIED`);
    return {
      verified: true,
      fanNumber,
      fullName: fullName ?? 'Demo Member',
      dateOfBirth: '1990-03-15',
      gender: 'MALE',
      message: 'Demo identity verified successfully',
      isSimulated: true,
    };
  }

  // ── openIMIS Sync ─────────────────────────────────────────────────────────

  syncHousehold(householdCode: string): boolean {
    this.logger.log(`[DEMO openIMIS] Synced household ${householdCode} → OK`);
    return true;
  }

  syncClaim(claimNumber: string): boolean {
    this.logger.log(`[DEMO openIMIS] Synced claim ${claimNumber} → OK`);
    return true;
  }
}
