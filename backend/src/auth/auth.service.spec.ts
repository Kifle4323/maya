import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { SmsService } from '../sms/sms.service';
import { User } from '../users/user.entity';
import { AuthService } from './auth.service';

const mockUserRepo = {
  findOne: jest.fn(),
  save: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    addSelect: jest.fn().mockReturnThis(),
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
    getMany: jest.fn().mockResolvedValue([]),
  })),
};

const mockBeneficiaryRepo = {
  findOne: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
  })),
};

const mockSmsService = {
  sendOtp: jest.fn().mockResolvedValue(undefined),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: mockUserRepo },
        { provide: getRepositoryToken(Beneficiary), useValue: mockBeneficiaryRepo },
        { provide: SmsService, useValue: mockSmsService },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    jest.clearAllMocks();
  });

  describe('normalizePhoneNumber', () => {
    it('normalizes +251 format', () => {
      expect(service.normalizePhoneNumber('+251912345678')).toBe('+251912345678');
    });

    it('normalizes 09 format', () => {
      expect(service.normalizePhoneNumber('0912345678')).toBe('+251912345678');
    });

    it('normalizes 9 format', () => {
      expect(service.normalizePhoneNumber('912345678')).toBe('+251912345678');
    });

    it('throws for invalid number', () => {
      expect(() => service.normalizePhoneNumber('12345')).toThrow(BadRequestException);
    });

    it('returns undefined for empty input', () => {
      expect(service.normalizePhoneNumber('')).toBeUndefined();
    });
  });

  describe('normalizeEmail', () => {
    it('lowercases and trims email', () => {
      expect(service.normalizeEmail('  Test@Example.COM  ')).toBe('test@example.com');
    });

    it('returns undefined for empty string', () => {
      expect(service.normalizeEmail('')).toBeUndefined();
    });
  });

  describe('hashPassword / verifyPassword', () => {
    it('hashes and verifies a password correctly', () => {
      const password = 'SecurePass123!';
      const hash = service.hashPassword(password);
      expect(hash).toContain(':');
      // Access private method via type cast for testing
      const verify = (service as unknown as { verifyPassword: (p: string, h: string) => boolean }).verifyPassword;
      expect(verify.call(service, password, hash)).toBe(true);
      expect(verify.call(service, 'WrongPass', hash)).toBe(false);
    });
  });

  describe('sendOtp', () => {
    it('throws NotFoundException when user not found', async () => {
      const qb = {
        addSelect: jest.fn().mockReturnThis(),
        leftJoinAndSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
        getMany: jest.fn().mockResolvedValue([]),
      };
      mockUserRepo.createQueryBuilder.mockReturnValue(qb);

      await expect(
        service.sendOtp({ phoneNumber: '0912345678', purpose: 'login' }),
      ).rejects.toThrow('No member account was found');
    });

    it('sends OTP and calls SmsService for phone targets', async () => {
      const mockUser = {
        id: 'user-1',
        phoneNumber: '+251912345678',
        oneTimeCodeHash: null,
        oneTimeCodePurpose: null,
        oneTimeCodeTarget: null,
        oneTimeCodeExpiresAt: null,
      };
      const qb = {
        addSelect: jest.fn().mockReturnThis(),
        leftJoinAndSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(mockUser),
        getMany: jest.fn().mockResolvedValue([]),
      };
      mockUserRepo.createQueryBuilder.mockReturnValue(qb);
      mockUserRepo.save.mockResolvedValue(mockUser);

      const result = await service.sendOtp({
        phoneNumber: '0912345678',
        purpose: 'login',
      });

      expect(result.channel).toBe('sms');
      expect(result.target).toContain('****');
      expect(mockSmsService.sendOtp).toHaveBeenCalledWith(
        '+251912345678',
        expect.any(String),
      );
    });
  });
});
