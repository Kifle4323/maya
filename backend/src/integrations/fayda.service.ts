import { Injectable, Logger } from '@nestjs/common';

/**
 * Fayda National ID Verification Service
 *
 * Fayda is Ethiopia's national digital ID system (FAN = Fayda Authentication Number).
 * This service verifies identity numbers against the national registry.
 *
 * Setup:
 *   1. Apply for API access at https://id.et
 *   2. Set NATIONAL_ID_API_BASE_URL and NATIONAL_ID_API_KEY in .env
 *
 * Note: In development, this returns a simulated response.
 */

export interface FaydaVerifyResult {
  verified: boolean;
  fanNumber?: string;
  fullName?: string;
  dateOfBirth?: string;
  gender?: string;
  message: string;
  isSimulated: boolean;
}

@Injectable()
export class FaydaService {
  private readonly logger = new Logger(FaydaService.name);
  private readonly baseUrl = process.env.NATIONAL_ID_API_BASE_URL ?? '';
  private readonly apiKey = process.env.NATIONAL_ID_API_KEY ?? '';

  get isConfigured(): boolean {
    return this.baseUrl.length > 0 && this.apiKey.length > 0;
  }

  /**
   * Verify a FAN (Fayda Authentication Number) against the national registry
   */
  async verifyFan(fanNumber: string, fullName?: string): Promise<FaydaVerifyResult> {
    if (!this.isConfigured) {
      this.logger.warn('Fayda API not configured — returning simulated verification');
      return {
        verified: true,
        fanNumber,
        fullName: fullName ?? 'Verified Member',
        message: 'Simulated verification (NATIONAL_ID_API not configured)',
        isSimulated: true,
      };
    }

    try {
      const response = await fetch(`${this.baseUrl}/verify`, {
        method: 'POST',
        headers: {
          'X-API-Key': this.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fanNumber: fanNumber.trim(),
          fullName: fullName?.trim(),
        }),
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`Fayda verification failed [${response.status}]: ${text}`);
        return {
          verified: false,
          fanNumber,
          message: 'Identity verification service unavailable',
          isSimulated: false,
        };
      }

      const result = await response.json() as {
        verified: boolean;
        fanNumber?: string;
        fullName?: string;
        dateOfBirth?: string;
        gender?: string;
        message?: string;
      };

      return {
        verified: result.verified,
        fanNumber: result.fanNumber ?? fanNumber,
        fullName: result.fullName,
        dateOfBirth: result.dateOfBirth,
        gender: result.gender,
        message: result.message ?? (result.verified ? 'Identity verified' : 'Identity not found'),
        isSimulated: false,
      };
    } catch (error) {
      this.logger.error(`Fayda exception: ${(error as Error).message}`);
      return {
        verified: false,
        fanNumber,
        message: 'Identity verification service temporarily unavailable',
        isSimulated: false,
      };
    }
  }
}
