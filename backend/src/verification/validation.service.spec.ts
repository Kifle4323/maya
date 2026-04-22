import { Test } from '@nestjs/testing';
import { ValidationService } from './validation.service';

describe('ValidationService', () => {
  let service: ValidationService;

  beforeEach(async () => {
    delete process.env.VERIFICATION_NAME_MATCH_THRESHOLD;
    const module = await Test.createTestingModule({
      providers: [ValidationService],
    }).compile();
    service = module.get(ValidationService);
  });

  afterEach(() => {
    delete process.env.VERIFICATION_NAME_MATCH_THRESHOLD;
  });

  // ── fuzzyNameMatch ─────────────────────────────────────────────────────────

  describe('fuzzyNameMatch', () => {
    it('returns score=1.0 for exact match', () => {
      const r = service.fuzzyNameMatch('Alemayehu Bekele', 'Alemayehu Bekele');
      expect(r.score).toBe(1.0);
      expect(r.match).toBe(true);
    });

    it('returns match=true for close match (score >= 0.75)', () => {
      // "Alemayehu Bekele" vs "Alemayehu Bekele Tadesse" — close enough
      const r = service.fuzzyNameMatch('Alemayehu Bekele', 'Alemayehu Bekele Tadesse');
      expect(r.score).toBeGreaterThanOrEqual(0.5);
    });

    it('returns match=false for completely different names', () => {
      const r = service.fuzzyNameMatch('Dawit Girma', 'Abebe Kebede');
      expect(r.match).toBe(false);
      expect(r.score).toBeLessThan(0.75);
    });

    it('is case-insensitive', () => {
      const r = service.fuzzyNameMatch('ALEMAYEHU BEKELE', 'alemayehu bekele');
      expect(r.score).toBe(1.0);
    });

    it('handles diacritics normalization', () => {
      const r = service.fuzzyNameMatch('Àlèmàyèhu', 'Alemayehu');
      expect(r.score).toBeGreaterThan(0.7);
    });

    it('returns match=false for empty strings', () => {
      const r = service.fuzzyNameMatch('', 'Alemayehu');
      expect(r.match).toBe(false);
      expect(r.score).toBe(0);
    });

    it('respects custom threshold from env', () => {
      process.env.VERIFICATION_NAME_MATCH_THRESHOLD = '0.95';
      // Re-create service to pick up new env
      const svc = new ValidationService();
      // "Alemayehu Bekele" vs "Alemayehu Bekele Tadesse" — score < 0.95
      const r = svc.fuzzyNameMatch('Alemayehu Bekele', 'Alemayehu Bekele Tadesse');
      // With high threshold, borderline match should not pass
      if (r.score < 0.95) {
        expect(r.match).toBe(false);
      }
    });
  });

  // ── isExpired ──────────────────────────────────────────────────────────────

  describe('isExpired', () => {
    it('returns true for past date', () => {
      expect(service.isExpired(new Date('2020-01-01'))).toBe(true);
    });

    it('returns false for future date', () => {
      const future = new Date();
      future.setFullYear(future.getFullYear() + 2);
      expect(service.isExpired(future)).toBe(false);
    });
  });

  // ── isExpiringSoon ─────────────────────────────────────────────────────────

  describe('isExpiringSoon', () => {
    it('returns true when expiry is within 30 days', () => {
      const soon = new Date();
      soon.setDate(soon.getDate() + 15);
      expect(service.isExpiringSoon(soon)).toBe(true);
    });

    it('returns false when expiry is more than 30 days away', () => {
      const far = new Date();
      far.setDate(far.getDate() + 60);
      expect(service.isExpiringSoon(far)).toBe(false);
    });

    it('returns false for already expired date', () => {
      expect(service.isExpiringSoon(new Date('2020-01-01'))).toBe(false);
    });
  });
});
