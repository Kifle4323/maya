import { Injectable, Logger } from '@nestjs/common';
import { createSign } from 'crypto';
import { createWriteStream, existsSync, mkdirSync } from 'fs';
import { join, extname } from 'path';
import { randomBytes } from 'crypto';

/**
 * Google Cloud Storage — Document Storage
 * Free tier: 5 GB storage, 1 GB egress/month
 *
 * Setup:
 *   1. Go to https://console.cloud.google.com/storage
 *   2. Create a bucket (e.g., "cbhi-documents")
 *   3. Set bucket to "Uniform access control"
 *   4. Create a Service Account with "Storage Object Admin" role
 *   5. Set in .env:
 *      GCS_BUCKET=cbhi-documents
 *      GCS_CLIENT_EMAIL=storage-sa@your-project.iam.gserviceaccount.com
 *      GCS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
 *      GCS_PROJECT_ID=your-project-id
 *
 * Falls back to local disk storage if GCS is not configured.
 */

export interface UploadResult {
  fileUrl: string;
  fileName: string;
  storedLocally: boolean;
}

const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]);

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly bucket = process.env.GCS_BUCKET ?? '';
  private readonly clientEmail = process.env.GCS_CLIENT_EMAIL ?? '';
  private readonly privateKey = (process.env.GCS_PRIVATE_KEY ?? '').replace(/\\n/g, '\n');
  private readonly projectId = process.env.GCS_PROJECT_ID ?? '';
  private readonly localUploadDir = join(process.cwd(), 'uploads');
  private readonly baseUrl = process.env.APP_BASE_URL ?? 'http://localhost:3000';
  private cachedToken: { value: string; expiresAt: number } | null = null;

  async uploadBase64(
    base64Content: string,
    mimeType: string,
    fileName: string,
    folder = 'documents',
  ): Promise<UploadResult> {
    // Validate mime type
    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      throw new Error(`File type ${mimeType} is not allowed. Allowed: ${[...ALLOWED_MIME_TYPES].join(', ')}`);
    }

    // Validate file size
    const buffer = Buffer.from(base64Content, 'base64');
    if (buffer.length > MAX_FILE_SIZE_BYTES) {
      throw new Error(`File size ${(buffer.length / 1024 / 1024).toFixed(1)}MB exceeds the 5MB limit.`);
    }

    const ext = mimeType === 'application/pdf' ? '.pdf' : extname(fileName) || '.jpg';
    const safeFileName = `${folder}/${randomBytes(16).toString('hex')}${ext}`;

    if (this.bucket && this.clientEmail && this.privateKey) {
      return this.uploadToGcs(buffer, safeFileName, mimeType);
    }

    // Fallback: local disk
    return this.saveLocally(buffer, safeFileName);
  }

  private async uploadToGcs(
    buffer: Buffer,
    objectName: string,
    mimeType: string,
  ): Promise<UploadResult> {
    try {
      const accessToken = await this.getGcsAccessToken();
      const endpoint = `https://storage.googleapis.com/upload/storage/v1/b/${this.bucket}/o?uploadType=media&name=${encodeURIComponent(objectName)}`;

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': mimeType,
          'Content-Length': buffer.length.toString(),
        },
        body: buffer as unknown as BodyInit,
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`GCS upload failed [${response.status}]: ${text}`);
        // Fallback to local
        return this.saveLocally(buffer, objectName);
      }

      const fileUrl = `https://storage.googleapis.com/${this.bucket}/${objectName}`;
      this.logger.log(`Uploaded to GCS: ${fileUrl}`);
      return { fileUrl, fileName: objectName, storedLocally: false };
    } catch (error) {
      this.logger.error(`GCS upload exception: ${(error as Error).message}`);
      return this.saveLocally(buffer, objectName);
    }
  }

  private saveLocally(buffer: Buffer, objectName: string): UploadResult {
    const parts = objectName.split('/');
    const subDir = parts.length > 1 ? join(this.localUploadDir, parts[0]) : this.localUploadDir;

    if (!existsSync(subDir)) {
      mkdirSync(subDir, { recursive: true });
    }

    const localPath = join(this.localUploadDir, objectName);
    require('fs').writeFileSync(localPath, buffer);

    const fileUrl = `${this.baseUrl}/uploads/${objectName}`;
    this.logger.log(`Saved locally: ${localPath}`);
    return { fileUrl, fileName: objectName, storedLocally: true };
  }

  private async getGcsAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && this.cachedToken.expiresAt > now + 60_000) {
      return this.cachedToken.value;
    }

    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const iat = Math.floor(now / 1000);
    const exp = iat + 3600;
    const payload = Buffer.from(
      JSON.stringify({
        iss: this.clientEmail,
        scope: 'https://www.googleapis.com/auth/devstorage.read_write',
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
      throw new Error(`GCS token error: ${await tokenResponse.text()}`);
    }

    const data = (await tokenResponse.json()) as { access_token: string; expires_in: number };
    this.cachedToken = { value: data.access_token, expiresAt: now + data.expires_in * 1000 };
    return this.cachedToken.value;
  }
}
