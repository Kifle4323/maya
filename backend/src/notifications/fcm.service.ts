import { Injectable, Logger } from '@nestjs/common';
import { createSign } from 'crypto';

/**
 * Firebase Cloud Messaging (FCM) — Push Notifications
 * Uses FCM HTTP v1 API with Google OAuth2 service account (free tier, unlimited)
 *
 * Setup:
 *   1. Go to https://console.firebase.google.com
 *   2. Create a project (free Spark plan)
 *   3. Project Settings → Service Accounts → Generate new private key
 *   4. Set in .env:
 *      FCM_PROJECT_ID=your-project-id
 *      FCM_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
 *      FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
 *
 * Flutter side: add firebase_messaging package and store FCM token in user profile
 */

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private readonly projectId = process.env.FCM_PROJECT_ID ?? '';
  private readonly clientEmail = process.env.FCM_CLIENT_EMAIL ?? '';
  private readonly privateKey = (process.env.FCM_PRIVATE_KEY ?? '').replace(/\\n/g, '\n');
  private cachedToken: { value: string; expiresAt: number } | null = null;

  async sendToDevice(
    fcmToken: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.projectId || !this.clientEmail || !this.privateKey) {
      this.logger.warn('FCM not configured — push notification skipped');
      return;
    }

    try {
      const accessToken = await this.getAccessToken();
      const endpoint = `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`;

      const message = {
        message: {
          token: fcmToken,
          notification: { title, body },
          data: data ?? {},
          android: {
            priority: 'high',
            notification: { sound: 'default', channelId: 'cbhi_alerts' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        },
      };

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`FCM send failed [${response.status}]: ${text}`);
        return;
      }

      this.logger.log(`FCM push sent to token: ${fcmToken.substring(0, 20)}...`);
    } catch (error) {
      this.logger.error(`FCM exception: ${(error as Error).message}`);
    }
  }

  async sendToMultiple(
    fcmTokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    await Promise.allSettled(
      fcmTokens.map((token) => this.sendToDevice(token, title, body, data)),
    );
  }

  private async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && this.cachedToken.expiresAt > now + 60_000) {
      return this.cachedToken.value;
    }

    // Build JWT for Google OAuth2
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const iat = Math.floor(now / 1000);
    const exp = iat + 3600;
    const payload = Buffer.from(
      JSON.stringify({
        iss: this.clientEmail,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat,
        exp,
      }),
    ).toString('base64url');

    const sign = createSign('RSA-SHA256');
    sign.update(`${header}.${payload}`);
    const signature = sign.sign(this.privateKey, 'base64url');
    const jwt = `${header}.${payload}.${signature}`;

    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }).toString(),
    });

    if (!tokenResponse.ok) {
      throw new Error(`Failed to get FCM access token: ${await tokenResponse.text()}`);
    }

    const tokenData = (await tokenResponse.json()) as { access_token: string; expires_in: number };
    this.cachedToken = {
      value: tokenData.access_token,
      expiresAt: now + tokenData.expires_in * 1000,
    };

    return this.cachedToken.value;
  }
}
