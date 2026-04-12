import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('should return the CBHI app overview', () => {
      expect(appController.getOverview()).toEqual({
        name: 'Member-Based CBHI API',
        status: 'ok',
        purpose:
          'Support Maya City CBHI household registration, identity verification, zero-touch indigent evaluation, digital card issuance, and offline-capable client sync.',
        supportedLanguages: ['am', 'om', 'en'],
        roles: [
          'HOUSEHOLD_HEAD',
          'BENEFICIARY',
          'HEALTH_FACILITY_STAFF',
          'CBHI_OFFICER',
          'SYSTEM_ADMIN',
        ],
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
      });
    });
  });
});
