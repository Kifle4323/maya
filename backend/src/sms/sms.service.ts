import { Injectable, Logger, Optional } from '@nestjs/common';
import { DemoSandboxService } from '../demo/demo-sandbox.service';

/**
 * SMS Service — Africa's Talking gateway with demo sandbox fallback.
 *
 * Demo mode (no AT_API_KEY): OTP shown in console + returned as debugCode
 * Live mode: real SMS via Africa's Talking (free sandbox at africastalking.com)
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private readonly isProduction = process.env.NODE_ENV === 'production';
  private readonly username = process.env.AT_USERNAME ?? 'sandbox';
  private readonly apiKey = process.env.AT_API_KEY ?? '';
  private readonly senderId = process.env.AT_SENDER_ID ?? 'CBHI';

  constructor(
    @Optional() private readonly demo: DemoSandboxService,
  ) {}

  async sendOtp(phoneNumber: string, code: string): Promise<void> {
    const message = `Your Maya City CBHI verification code is: ${code}. Valid for 5 minutes. Do not share this code.`;

    // Demo mode — no API key configured
    if (this.demo?.isActive || (!this.isProduction && !this.apiKey)) {
      this.demo?.sendSmsOtp(phoneNumber, code) ??
        this.logger.warn(`[DEV SMS] To: ${phoneNumber} | OTP: ${code}`);
      return;
    }

    await this.send(phoneNumber, message);
  }

  async sendRenewalReminder(phoneNumber: string, householdCode: string, expiryDate: string): Promise<void> {
    if (this.demo?.isActive) {
      this.demo.sendSmsRenewalReminder(phoneNumber, householdCode, expiryDate);
      return;
    }
    const message = `Maya City CBHI: Your household (${householdCode}) coverage expires on ${expiryDate}. Please renew to maintain health coverage.`;
    await this.send(phoneNumber, message);
  }

  async sendClaimUpdate(phoneNumber: string, claimNumber: string, status: string): Promise<void> {
    if (this.demo?.isActive) {
      this.demo.sendSmsClaimUpdate(phoneNumber, claimNumber, status);
      return;
    }
    const message = `Maya City CBHI: Claim ${claimNumber} status updated to ${status}. Open the app for details.`;
    await this.send(phoneNumber, message);
  }

  private async send(phoneNumber: string, message: string): Promise<void> {
    if (!this.apiKey) {
      this.logger.warn(`SMS not sent — AT_API_KEY not configured. To: ${phoneNumber}`);
      return;
    }

    try {
      const endpoint = this.username === 'sandbox'
        ? 'https://api.sandbox.africastalking.com/version1/messaging'
        : 'https://api.africastalking.com/version1/messaging';

      const body = new URLSearchParams({
        username: this.username,
        to: phoneNumber,
        message,
        ...(this.senderId ? { from: this.senderId } : {}),
      });

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          apiKey: this.apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`SMS send failed [${response.status}]: ${text}`);
        return;
      }

      const result = (await response.json()) as {
        SMSMessageData?: { Recipients?: Array<{ status: string; number: string }> };
      };

      const recipients = result.SMSMessageData?.Recipients ?? [];
      for (const recipient of recipients) {
        if (recipient.status !== 'Success') {
          this.logger.warn(`SMS delivery issue for ${recipient.number}: ${recipient.status}`);
        } else {
          this.logger.log(`SMS sent to ${recipient.number}`);
        }
      }
    } catch (error) {
      this.logger.error(`SMS send exception: ${(error as Error).message}`);
    }
  }
}
