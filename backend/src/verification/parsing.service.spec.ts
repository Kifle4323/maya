import { Test } from '@nestjs/testing';
import { ParsingService } from './parsing.service';

describe('ParsingService', () => {
  let service: ParsingService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [ParsingService],
    }).compile();
    service = module.get(ParsingService);
  });

  // ── extractIdNumber ────────────────────────────────────────────────────────

  describe('extractIdNumber', () => {
    it('extracts Ethiopian 12-digit FAN', () => {
      expect(service.extractIdNumber('FAN: 123456789012\nName: Test')).toBe('123456789012');
    });

    it('extracts bare 12-digit number', () => {
      expect(service.extractIdNumber('ID 987654321098 issued')).toBe('987654321098');
    });

    it('extracts labeled ID pattern', () => {
      expect(service.extractIdNumber('ID: ETH-ABC123')).toBe('ETH-ABC123');
    });

    it('extracts No. pattern', () => {
      expect(service.extractIdNumber('No. AB123456')).toBe('AB123456');
    });

    it('returns null when no ID found', () => {
      expect(service.extractIdNumber('Hello world no id here')).toBeNull();
    });

    it('prefers 12-digit FAN over labeled pattern', () => {
      expect(service.extractIdNumber('ID: SHORT\n123456789012')).toBe('123456789012');
    });
  });

  // ── extractExpiryDate ──────────────────────────────────────────────────────

  describe('extractExpiryDate', () => {
    it('parses DD/MM/YYYY format', () => {
      const d = service.extractExpiryDate('Expiry: 15/06/2027');
      expect(d).not.toBeNull();
      expect(d!.getFullYear()).toBe(2027);
      expect(d!.getMonth()).toBe(5); // June = 5
    });

    it('parses YYYY-MM-DD format', () => {
      const d = service.extractExpiryDate('Valid until 2027-06-15');
      expect(d).not.toBeNull();
      expect(d!.getFullYear()).toBe(2027);
    });

    it('parses "Month DD, YYYY" format', () => {
      const d = service.extractExpiryDate('Expires March 15, 2027');
      expect(d).not.toBeNull();
      expect(d!.getMonth()).toBe(2); // March = 2
    });

    it('parses short month format', () => {
      const d = service.extractExpiryDate('Valid to Jun 15, 2027');
      expect(d).not.toBeNull();
      expect(d!.getMonth()).toBe(5);
    });

    it('returns null when no date present', () => {
      expect(service.extractExpiryDate('No date in this text')).toBeNull();
    });
  });

  // ── extractFullName ────────────────────────────────────────────────────────

  describe('extractFullName', () => {
    it('extracts title-case name from ID text', () => {
      const text = 'FEDERAL ETHIOPIA NATIONAL ID\nFAN: 123456789012\nAlemayehu Bekele';
      expect(service.extractFullName(text)).toBe('Alemayehu Bekele');
    });

    it('extracts 3-word name', () => {
      const text = 'NATIONAL ID CARD\nFAN: 123456789012\nTigist Haile Worku';
      expect(service.extractFullName(text)).toBe('Tigist Haile Worku');
    });

    it('returns null when only keywords and numbers present', () => {
      const text = 'FEDERAL ETHIOPIA NATIONAL ID CARD\nFAN: 123456789012\n15/03/1990';
      expect(service.extractFullName(text)).toBeNull();
    });
  });

  // ── normalizeText ──────────────────────────────────────────────────────────

  describe('normalizeText', () => {
    it('lowercases and trims', () => {
      expect(service.normalizeText('  HELLO WORLD  ')).toBe('hello world');
    });

    it('collapses multiple spaces', () => {
      expect(service.normalizeText('a   b   c')).toBe('a b c');
    });
  });
});
