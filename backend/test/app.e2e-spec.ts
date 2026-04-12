import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppController } from '../src/app.controller';
import { AppService } from '../src/app.service';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('/api (GET)', () => {
    return request(app.getHttpServer())
      .get('/api')
      .expect(200)
      .expect({
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
