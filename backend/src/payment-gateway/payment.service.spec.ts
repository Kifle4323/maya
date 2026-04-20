import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { PaymentService } from './payment.service';
import { ChapaService } from './chapa.service';
import { Coverage } from '../coverages/coverage.entity';
import { Payment } from '../payments/payment.entity';
import { Household } from '../households/household.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Notification } from '../notifications/notification.entity';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { SmsService } from '../sms/sms.service';
import { CoverageStatus, PaymentMethod, PaymentStatus } from '../common/enums/cbhi.enums';
import { User } from '../users/user.entity';

// ─── mock factories ──────────────────────────────────────────────────────────

const mockRepo = () => ({
  create: jest.fn((v) => v),
  save: jest.fn(async (v) => v),
  findOne: jest.fn(),
  createQueryBuilder: jest.fn().mockReturnValue({
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue(undefined),
  }),
});

const mockChapaService = () => ({
  initiatePayment: jest.fn(),
  verifyPayment: jest.fn(),
  verifyWebhookSignature: jest.fn().mockReturnValue(true),
});

const mockWsGateway = () => ({
  pushCoverageSync: jest.fn(),
});

const mockSmsService = () => ({
  sendClaimUpdate: jest.fn().mockResolvedValue(undefined),
});

// ─── shared fixtures ─────────────────────────────────────────────────────────

const makeUser = (overrides: Partial<User> = {}): User =>
  ({
    id: 'user-1',
    firstName: 'Alemayehu',
    lastName: 'Bekele',
    phoneNumber: '+251912345678',
    email: 'test@cbhi.et',
    ...overrides,
  } as User);

const makeHousehold = (overrides = {}) => ({
  id: 'hh-1',
  householdCode: 'HH-001',
  headUser: makeUser(),
  coverageStatus: CoverageStatus.PENDING_RENEWAL,
  ...overrides,
});

const makeCoverage = (overrides = {}) => ({
  id: 'cov-1',
  coverageNumber: 'COV-001',
  status: CoverageStatus.PENDING_RENEWAL,
  household: makeHousehold(),
  ...overrides,
});

const makePendingPayment = (overrides = {}) => ({
  id: 'pay-1',
  transactionReference: 'CBHI-HH001-ABCDEF',
  amount: '720.00',
  status: PaymentStatus.PENDING,
  method: PaymentMethod.MOBILE_MONEY,
  coverage: makeCoverage(),
  ...overrides,
});

// ─── suite ───────────────────────────────────────────────────────────────────

describe('PaymentService', () => {
  let service: PaymentService;
  let chapaService: ReturnType<typeof mockChapaService>;
  let coverageRepo: ReturnType<typeof mockRepo>;
  let paymentRepo: ReturnType<typeof mockRepo>;
  let householdRepo: ReturnType<typeof mockRepo>;
  let beneficiaryRepo: ReturnType<typeof mockRepo>;
  let notificationRepo: ReturnType<typeof mockRepo>;
  let wsGateway: ReturnType<typeof mockWsGateway>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentService,
        { provide: ChapaService, useFactory: mockChapaService },
        { provide: getRepositoryToken(Coverage), useFactory: mockRepo },
        { provide: getRepositoryToken(Payment), useFactory: mockRepo },
        { provide: getRepositoryToken(Household), useFactory: mockRepo },
        { provide: getRepositoryToken(Beneficiary), useFactory: mockRepo },
        { provide: getRepositoryToken(Notification), useFactory: mockRepo },
        { provide: NotificationsGateway, useFactory: mockWsGateway },
        { provide: SmsService, useFactory: mockSmsService },
      ],
    }).compile();

    service = module.get(PaymentService);
    chapaService = module.get(ChapaService);
    coverageRepo = module.get(getRepositoryToken(Coverage));
    paymentRepo = module.get(getRepositoryToken(Payment));
    householdRepo = module.get(getRepositoryToken(Household));
    beneficiaryRepo = module.get(getRepositoryToken(Beneficiary));
    notificationRepo = module.get(getRepositoryToken(Notification));
    wsGateway = module.get(NotificationsGateway);
  });

  // ── initiatePayment ───────────────────────────────────────────────────────

  describe('initiatePayment', () => {
    it('throws BadRequestException when user has no household', async () => {
      householdRepo.findOne.mockResolvedValue(null);

      await expect(service.initiatePayment(makeUser(), 720)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws BadRequestException when household has no coverage', async () => {
      householdRepo.findOne.mockResolvedValue(makeHousehold());
      coverageRepo.findOne.mockResolvedValue(null);

      await expect(service.initiatePayment(makeUser(), 720)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws BadRequestException when Chapa initiation fails', async () => {
      householdRepo.findOne.mockResolvedValue(makeHousehold());
      coverageRepo.findOne.mockResolvedValue(makeCoverage());
      (chapaService.initiatePayment as jest.Mock).mockResolvedValue({
        success: false,
        message: 'Invalid API key',
        txRef: 'CBHI-HH001-ABCDEF',
      });

      await expect(service.initiatePayment(makeUser(), 720)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('returns txRef, checkoutUrl, and amount on success', async () => {
      householdRepo.findOne.mockResolvedValue(makeHousehold());
      coverageRepo.findOne.mockResolvedValue(makeCoverage());
      (chapaService.initiatePayment as jest.Mock).mockResolvedValue({
        success: true,
        checkoutUrl: 'https://checkout.chapa.co/pay/abc123',
        txRef: 'CBHI-HH001-ABCDEF',
        message: 'Payment initiated',
      });

      const result = await service.initiatePayment(makeUser(), 720, 'CBHI premium');

      expect(result.checkoutUrl).toBe('https://checkout.chapa.co/pay/abc123');
      expect(result.amount).toBe(720);
      expect(result.currency).toBe('ETB');
      expect(result.txRef).toBeDefined();
    });

    it('saves a PENDING payment record to the database', async () => {
      householdRepo.findOne.mockResolvedValue(makeHousehold());
      coverageRepo.findOne.mockResolvedValue(makeCoverage());
      (chapaService.initiatePayment as jest.Mock).mockResolvedValue({
        success: true,
        checkoutUrl: 'https://checkout.chapa.co/pay/abc123',
        txRef: 'CBHI-HH001-ABCDEF',
        message: 'Payment initiated',
      });

      await service.initiatePayment(makeUser(), 720);

      expect(paymentRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          status: PaymentStatus.PENDING,
          method: PaymentMethod.MOBILE_MONEY,
        }),
      );
    });

    it('sets isTestMode=true when CHAPA_SECRET_KEY contains TEST', async () => {
      process.env.CHAPA_SECRET_KEY = 'CHASECK_TEST-abc123';
      householdRepo.findOne.mockResolvedValue(makeHousehold());
      coverageRepo.findOne.mockResolvedValue(makeCoverage());
      (chapaService.initiatePayment as jest.Mock).mockResolvedValue({
        success: true,
        checkoutUrl: 'https://checkout.chapa.co/pay/abc123',
        txRef: 'CBHI-HH001-ABCDEF',
        message: 'Payment initiated',
      });

      const result = await service.initiatePayment(makeUser(), 720);
      expect(result.isTestMode).toBe(true);

      delete process.env.CHAPA_SECRET_KEY;
    });
  });

  // ── verifyPayment ─────────────────────────────────────────────────────────

  describe('verifyPayment', () => {
    it('throws BadRequestException when txRef not found in DB', async () => {
      paymentRepo.findOne.mockResolvedValue(null);

      await expect(service.verifyPayment('CBHI-UNKNOWN')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('activates coverage when Chapa returns success', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);
      (chapaService.verifyPayment as jest.Mock).mockResolvedValue({
        status: 'success',
        amount: 720,
        currency: 'ETB',
        paymentMethod: 'telebirr',
        paidAt: new Date().toISOString(),
        message: 'Verified',
      });

      const result = await service.verifyPayment('CBHI-HH001-ABCDEF');

      expect(result.coverageActivated).toBe(true);
      expect(result.status).toBe('success');
      expect(coverageRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: CoverageStatus.ACTIVE }),
      );
    });

    it('marks payment as FAILED when Chapa returns failed', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);
      (chapaService.verifyPayment as jest.Mock).mockResolvedValue({
        status: 'failed',
        message: 'Payment declined',
      });

      const result = await service.verifyPayment('CBHI-HH001-ABCDEF');

      expect(result.status).toBe('failed');
      expect(paymentRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: PaymentStatus.FAILED }),
      );
    });

    it('does not re-activate already-successful payment (idempotency)', async () => {
      const payment = makePendingPayment({ status: PaymentStatus.SUCCESS });
      paymentRepo.findOne.mockResolvedValue(payment);
      (chapaService.verifyPayment as jest.Mock).mockResolvedValue({
        status: 'success',
        message: 'Already paid',
      });

      await service.verifyPayment('CBHI-HH001-ABCDEF');

      // coverageRepo.save should NOT be called again
      expect(coverageRepo.save).not.toHaveBeenCalled();
    });

    it('sets coverage endDate to exactly 1 year from activation', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);
      (chapaService.verifyPayment as jest.Mock).mockResolvedValue({
        status: 'success',
        amount: 720,
        currency: 'ETB',
        message: 'Verified',
      });

      const before = new Date();
      await service.verifyPayment('CBHI-HH001-ABCDEF');
      const after = new Date();

      const savedCoverage = (coverageRepo.save as jest.Mock).mock.calls[0][0];
      const endDate: Date = savedCoverage.endDate;

      // endDate should be ~1 year from now
      const expectedYear = before.getFullYear() + 1;
      expect(endDate.getFullYear()).toBe(expectedYear);
      expect(endDate.getMonth()).toBeGreaterThanOrEqual(before.getMonth());
    });

    it('updates all beneficiaries isEligible=true after payment', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);
      (chapaService.verifyPayment as jest.Mock).mockResolvedValue({
        status: 'success',
        amount: 720,
        currency: 'ETB',
        message: 'Verified',
      });

      await service.verifyPayment('CBHI-HH001-ABCDEF');

      const qb = beneficiaryRepo.createQueryBuilder();
      expect(qb.set).toHaveBeenCalledWith({ isEligible: true });
      expect(qb.execute).toHaveBeenCalled();
    });
  });

  // ── handleWebhook ─────────────────────────────────────────────────────────

  describe('handleWebhook', () => {
    it('silently returns when txRef not found (no crash)', async () => {
      paymentRepo.findOne.mockResolvedValue(null);
      await expect(service.handleWebhook('CBHI-UNKNOWN', 'success')).resolves.toBeUndefined();
    });

    it('activates coverage on webhook success status', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);

      await service.handleWebhook('CBHI-HH001-ABCDEF', 'success');

      expect(coverageRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: CoverageStatus.ACTIVE }),
      );
    });

    it('does not activate coverage on non-success webhook status', async () => {
      const payment = makePendingPayment();
      paymentRepo.findOne.mockResolvedValue(payment);

      await service.handleWebhook('CBHI-HH001-ABCDEF', 'failed');

      expect(coverageRepo.save).not.toHaveBeenCalled();
    });

    it('is idempotent — does not re-activate already-SUCCESS payment', async () => {
      const payment = makePendingPayment({ status: PaymentStatus.SUCCESS });
      paymentRepo.findOne.mockResolvedValue(payment);

      await service.handleWebhook('CBHI-HH001-ABCDEF', 'success');

      expect(coverageRepo.save).not.toHaveBeenCalled();
    });
  });

  // ── ChapaService (unit) ───────────────────────────────────────────────────

  describe('ChapaService.verifyWebhookSignature', () => {
    let chapa: ChapaService;

    beforeEach(async () => {
      const module: TestingModule = await Test.createTestingModule({
        providers: [ChapaService],
      }).compile();
      chapa = module.get(ChapaService);
    });

    it('returns true when CHAPA_WEBHOOK_SECRET is not set (open mode)', () => {
      delete process.env.CHAPA_WEBHOOK_SECRET;
      expect(chapa.verifyWebhookSignature('{"status":"success"}', 'any')).toBe(true);
    });

    it('returns true for a valid HMAC-SHA256 signature', () => {
      process.env.CHAPA_WEBHOOK_SECRET = 'test-secret';
      const { createHmac } = require('crypto');
      const payload = '{"status":"success","tx_ref":"CBHI-001"}';
      const sig = createHmac('sha256', 'test-secret').update(payload).digest('hex');

      expect(chapa.verifyWebhookSignature(payload, sig)).toBe(true);
      delete process.env.CHAPA_WEBHOOK_SECRET;
    });

    it('returns false for a tampered payload', () => {
      process.env.CHAPA_WEBHOOK_SECRET = 'test-secret';
      const { createHmac } = require('crypto');
      const original = '{"status":"success","tx_ref":"CBHI-001"}';
      const sig = createHmac('sha256', 'test-secret').update(original).digest('hex');

      expect(chapa.verifyWebhookSignature('{"status":"success","tx_ref":"CBHI-TAMPERED"}', sig)).toBe(false);
      delete process.env.CHAPA_WEBHOOK_SECRET;
    });
  });

  // ── ChapaService demo mode ────────────────────────────────────────────────

  describe('ChapaService demo mode', () => {
    let chapa: ChapaService;

    beforeEach(async () => {
      delete process.env.CHAPA_SECRET_KEY;
      process.env.DEMO_MODE = 'true';

      const module: TestingModule = await Test.createTestingModule({
        providers: [ChapaService],
      }).compile();
      chapa = module.get(ChapaService);
    });

    afterEach(() => {
      delete process.env.DEMO_MODE;
    });

    it('initiatePayment returns success with demo checkout URL', async () => {
      const result = await chapa.initiatePayment({
        amount: 720,
        txRef: 'CBHI-DEMO-001',
        firstName: 'Alemayehu',
        lastName: 'Bekele',
      });

      expect(result.success).toBe(true);
      expect(result.checkoutUrl).toContain('CBHI-DEMO-001');
    });

    it('verifyPayment always returns success in demo mode', async () => {
      const result = await chapa.verifyPayment('CBHI-DEMO-001');
      expect(result.status).toBe('success');
      expect(result.amount).toBe(120);
    });

    it('isConfigured is false when no secret key', () => {
      expect(chapa.isConfigured).toBe(false);
    });
  });
});
