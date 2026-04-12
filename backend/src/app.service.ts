import { Injectable } from '@nestjs/common';
import { PreferredLanguage, UserRole } from './common/enums/cbhi.enums';

@Injectable()
export class AppService {
  getOverview() {
    return {
      name: 'Member-Based CBHI API',
      status: 'ok',
      purpose:
        'Support Maya City CBHI household registration, identity verification, zero-touch indigent evaluation, digital card issuance, and offline-capable client sync.',
      supportedLanguages: Object.values(PreferredLanguage),
      roles: Object.values(UserRole),
      apiSurface: [
        '/api',
        '/api/health',
        '/api/auth/send-otp',
        '/api/auth/verify-otp',
        '/api/auth/login',
        '/api/auth/forgot-password',
        '/api/auth/reset-password',
        '/api/auth/me',
        '/api/cbhi/registration/step-1',
        '/api/cbhi/registration/step-2',
        '/api/cbhi/me',
        '/api/cbhi/family',
        '/api/indigent/apply',
        '/api/indigent/:id',
      ],
    };
  }

  getHealth() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    };
  }
}
