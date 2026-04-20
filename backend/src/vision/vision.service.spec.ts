import { Test, TestingModule } from '@nestjs/testing';
import { VisionService, IndigentDocumentType } from './vision.service';
import { DemoSandboxService } from '../demo/demo-sandbox.service';

// ─── helpers ────────────────────────────────────────────────────────────────

/** Minimal valid base64 PNG (1×1 transparent pixel) */
const DUMMY_B64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

/** Build a mock fetch that returns the given Vision API JSON */
function mockVisionFetch(fullText: string, confidence = 0.9) {
  return jest.fn().mockResolvedValue({
    ok: true,
    json: async () => ({
      responses: [{
        fullTextAnnotation: {
          text: fullText,
          pages: [{ confidence }],
        },
        textAnnotations: [{ description: fullText }],
      }],
    }),
    text: async () => '',
  });
}

// ─── suite ──────────────────────────────────────────────────────────────────

describe('VisionService', () => {
  let service: VisionService;

  // ── 1. DEMO MODE (no API key, DemoSandboxService active) ─────────────────

  describe('demo mode', () => {
    let demo: DemoSandboxService;

    beforeEach(async () => {
      // Ensure no real key leaks in
      delete process.env.GOOGLE_VISION_API_KEY;
      process.env.DEMO_MODE = 'true';

      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService, DemoSandboxService],
      }).compile();

      service = module.get(VisionService);
      demo = module.get(DemoSandboxService);
    });

    afterEach(() => {
      delete process.env.DEMO_MODE;
    });

    it('validateIdDocument returns isValid=true with demo flag', async () => {
      const result = await service.validateIdDocument(DUMMY_B64, '123456789012');
      expect(result.isValid).toBe(true);
      expect(result.isDemo).toBe(true);
      expect(result.detectedIdNumber).toBe('123456789012');
      expect(result.issues).toHaveLength(0);
    });

    it('validateIdDocument uses expectedIdNumber in demo response', async () => {
      const result = await service.validateIdDocument(DUMMY_B64, 'ETH-9999');
      expect(result.detectedIdNumber).toBe('ETH-9999');
    });

    it('validateIndigentDocument returns isValid=true with demo flag', async () => {
      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.isValid).toBe(true);
      expect(result.isDemo).toBe(true);
      expect(result.documentType).toBe(IndigentDocumentType.INCOME_CERTIFICATE);
      expect(result.issues).toHaveLength(0);
    });

    it('demo sandbox isActive is true', () => {
      expect(demo.isActive).toBe(true);
    });
  });

  // ── 2. LIVE MODE — extractText ────────────────────────────────────────────

  describe('extractText (live)', () => {
    beforeEach(async () => {
      process.env.GOOGLE_VISION_API_KEY = 'FAKE_KEY_FOR_TESTS';
      process.env.DEMO_MODE = 'false';

      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService],
      }).compile();

      service = module.get(VisionService);
    });

    afterEach(() => {
      delete process.env.GOOGLE_VISION_API_KEY;
      delete process.env.DEMO_MODE;
      jest.restoreAllMocks();
    });

    it('returns parsed text and words on success', async () => {
      global.fetch = mockVisionFetch('FEDERAL ETHIOPIA\nNATIONAL ID\nFAN: 123456789012', 0.95) as any;

      const result = await service.extractText(DUMMY_B64);

      expect(result.fullText).toContain('FEDERAL');
      expect(result.words).toContain('FEDERAL');
      expect(result.confidence).toBe(0.95);
    });

    it('returns empty result when Vision API returns HTTP error', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 403,
        text: async () => 'API key invalid',
      }) as any;

      const result = await service.extractText(DUMMY_B64);

      expect(result.fullText).toBe('');
      expect(result.words).toHaveLength(0);
      expect(result.confidence).toBe(0);
    });

    it('returns empty result when fetch throws (network error)', async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error('Network failure')) as any;

      const result = await service.extractText(DUMMY_B64);

      expect(result.fullText).toBe('');
      expect(result.confidence).toBe(0);
    });

    it('returns empty result when Vision API embeds an error in response', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          responses: [{ error: { message: 'Image too large' } }],
        }),
      }) as any;

      const result = await service.extractText(DUMMY_B64);
      expect(result.fullText).toBe('');
    });

    it('returns empty result when GOOGLE_VISION_API_KEY is not set', async () => {
      delete process.env.GOOGLE_VISION_API_KEY;
      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService],
      }).compile();
      const svc = module.get(VisionService);

      const fetchSpy = jest.spyOn(global, 'fetch');
      const result = await svc.extractText(DUMMY_B64);

      expect(result.fullText).toBe('');
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  // ── 3. LIVE MODE — validateIdDocument ────────────────────────────────────

  describe('validateIdDocument (live)', () => {
    beforeEach(async () => {
      process.env.GOOGLE_VISION_API_KEY = 'FAKE_KEY_FOR_TESTS';
      process.env.DEMO_MODE = 'false';

      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService],
      }).compile();

      service = module.get(VisionService);
    });

    afterEach(() => {
      delete process.env.GOOGLE_VISION_API_KEY;
      delete process.env.DEMO_MODE;
      jest.restoreAllMocks();
    });

    it('passes a valid Ethiopian National ID', async () => {
      global.fetch = mockVisionFetch(
        'FEDERAL DEMOCRATIC REPUBLIC OF ETHIOPIA\nNATIONAL ID CARD\nFAN: 123456789012\nAlemayehu Bekele\nDate of Birth: 15/03/1990',
      ) as any;

      const result = await service.validateIdDocument(DUMMY_B64, '123456789012');

      expect(result.isValid).toBe(true);
      expect(result.issues).toHaveLength(0);
      expect(result.detectedIdNumber).toBe('123456789012');
    });

    it('fails when no Ethiopian ID keywords found', async () => {
      global.fetch = mockVisionFetch('DRIVER LICENSE\nSTATE OF CALIFORNIA\nDL: D1234567') as any;

      const result = await service.validateIdDocument(DUMMY_B64);

      expect(result.isValid).toBe(false);
      expect(result.issues.some((i) => i.includes('Ethiopian National ID'))).toBe(true);
    });

    it('fails when extracted ID number does not match expected', async () => {
      global.fetch = mockVisionFetch(
        'FEDERAL ETHIOPIA NATIONAL ID\nFAN: 999999999999\nAlemayehu Bekele',
      ) as any;

      const result = await service.validateIdDocument(DUMMY_B64, '123456789012');

      expect(result.isValid).toBe(false);
      expect(result.issues.some((i) => i.includes('does not match'))).toBe(true);
    });

    it('passes when no expectedIdNumber is provided (no mismatch check)', async () => {
      global.fetch = mockVisionFetch(
        'FEDERAL ETHIOPIA NATIONAL ID\nFAN: 999999999999\nAlemayehu Bekele',
      ) as any;

      const result = await service.validateIdDocument(DUMMY_B64);
      // No expectedIdNumber → no mismatch issue
      expect(result.issues.some((i) => i.includes('does not match'))).toBe(false);
    });

    it('returns isValid=false when image has no extractable text', async () => {
      global.fetch = mockVisionFetch('') as any;

      const result = await service.validateIdDocument(DUMMY_B64);

      expect(result.isValid).toBe(false);
      expect(result.issues[0]).toContain('Could not extract text');
    });

    it('detects name from non-keyword, non-numeric line', async () => {
      global.fetch = mockVisionFetch(
        'FEDERAL ETHIOPIA NATIONAL ID\nFAN: 123456789012\nAlemayehu Bekele Tadesse',
      ) as any;

      const result = await service.validateIdDocument(DUMMY_B64);
      expect(result.detectedName).toBe('Alemayehu Bekele Tadesse');
    });
  });

  // ── 4. LIVE MODE — validateIndigentDocument ───────────────────────────────

  describe('validateIndigentDocument (live)', () => {
    beforeEach(async () => {
      process.env.GOOGLE_VISION_API_KEY = 'FAKE_KEY_FOR_TESTS';
      process.env.DEMO_MODE = 'false';

      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService],
      }).compile();

      service = module.get(VisionService);
    });

    afterEach(() => {
      delete process.env.GOOGLE_VISION_API_KEY;
      delete process.env.DEMO_MODE;
      jest.restoreAllMocks();
    });

    it('accepts a valid Income Certificate with recent date', async () => {
      const recentDate = new Date();
      recentDate.setMonth(recentDate.getMonth() - 3);
      const dateStr = `${recentDate.getDate().toString().padStart(2, '0')}/${(recentDate.getMonth() + 1).toString().padStart(2, '0')}/${recentDate.getFullYear()}`;

      global.fetch = mockVisionFetch(
        `KEBELE ADMINISTRATION OFFICE\nINCOME CERTIFICATE\nMonthly earnings below 1000 ETB\nDate: ${dateStr}`,
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);

      expect(result.isValid).toBe(true);
      expect(result.documentType).toBe(IndigentDocumentType.INCOME_CERTIFICATE);
      expect(result.isExpired).toBe(false);
      expect(result.issues).toHaveLength(0);
    });

    it('accepts a Poverty Certificate', async () => {
      const recentDate = new Date();
      recentDate.setMonth(recentDate.getMonth() - 2);
      const dateStr = `${recentDate.getDate().toString().padStart(2, '0')}/${(recentDate.getMonth() + 1).toString().padStart(2, '0')}/${recentDate.getFullYear()}`;

      global.fetch = mockVisionFetch(
        `SOCIAL WELFARE OFFICE\nPOVERTY CERTIFICATE\nThis certifies the bearer is indigent and needy\nDate: ${dateStr}`,
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.documentType).toBe(IndigentDocumentType.POVERTY_CERTIFICATE);
      expect(result.isValid).toBe(true);
    });

    it('rejects an expired Income Certificate (issued 14 months ago)', async () => {
      const oldDate = new Date();
      oldDate.setMonth(oldDate.getMonth() - 14);
      const dateStr = `${oldDate.getDate().toString().padStart(2, '0')}/${(oldDate.getMonth() + 1).toString().padStart(2, '0')}/${oldDate.getFullYear()}`;

      global.fetch = mockVisionFetch(
        `KEBELE INCOME CERTIFICATE\nMonthly salary below 1000 ETB\nDate: ${dateStr}`,
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);

      expect(result.isExpired).toBe(true);
      expect(result.isValid).toBe(false);
      expect(result.issues.some((i) => i.includes('expired'))).toBe(true);
    });

    it('warns when document is expiring within 30 days', async () => {
      const soonDate = new Date();
      soonDate.setMonth(soonDate.getMonth() - 11); // 11 months ago → expires in ~1 month
      const dateStr = `${soonDate.getDate().toString().padStart(2, '0')}/${(soonDate.getMonth() + 1).toString().padStart(2, '0')}/${soonDate.getFullYear()}`;

      global.fetch = mockVisionFetch(
        `KEBELE INCOME CERTIFICATE\nMonthly earnings below 1000 ETB\nDate: ${dateStr}`,
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.expiryWarning).toContain('expires in');
    });

    it('rejects unknown document type', async () => {
      global.fetch = mockVisionFetch('BANK STATEMENT\nAccount No: 1234\nBalance: 5000 ETB') as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);

      expect(result.isValid).toBe(false);
      expect(result.documentType).toBe(IndigentDocumentType.UNKNOWN);
      expect(result.issues.some((i) => i.includes('could not be identified'))).toBe(true);
    });

    it('rejects image with no extractable text', async () => {
      global.fetch = mockVisionFetch('') as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);

      expect(result.isValid).toBe(false);
      expect(result.issues[0]).toContain('Could not read');
    });

    it('warns when no date is detected', async () => {
      global.fetch = mockVisionFetch(
        'KEBELE INCOME CERTIFICATE\nMonthly earnings below 1000 ETB\nNo date present',
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.expiryWarning).toContain('Could not detect issue date');
    });

    it('accepts Amharic Kebele ID keywords', async () => {
      const recentDate = new Date();
      recentDate.setMonth(recentDate.getMonth() - 1);
      const dateStr = `${recentDate.getDate().toString().padStart(2, '0')}/${(recentDate.getMonth() + 1).toString().padStart(2, '0')}/${recentDate.getFullYear()}`;

      global.fetch = mockVisionFetch(
        `ቀበሌ ወረዳ RESIDENT IDENTIFICATION\nDate: ${dateStr}`,
      ) as any;

      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.documentType).toBe(IndigentDocumentType.KEBELE_ID);
    });
  });

  // ── 5. Date extraction edge cases ────────────────────────────────────────

  describe('extractDocumentDate (via validateIndigentDocument)', () => {
    beforeEach(async () => {
      process.env.GOOGLE_VISION_API_KEY = 'FAKE_KEY_FOR_TESTS';
      process.env.DEMO_MODE = 'false';

      const module: TestingModule = await Test.createTestingModule({
        providers: [VisionService],
      }).compile();

      service = module.get(VisionService);
    });

    afterEach(() => {
      delete process.env.GOOGLE_VISION_API_KEY;
      delete process.env.DEMO_MODE;
      jest.restoreAllMocks();
    });

    const cases: [string, string, string][] = [
      ['DD/MM/YYYY', 'INCOME CERTIFICATE Date: 15/06/2024', '2024-06-15'],
      ['YYYY-MM-DD', 'INCOME CERTIFICATE Date: 2024-06-15', '2024-06-15'],
      ['Month name', 'INCOME CERTIFICATE Date: June 15, 2024', '2024-06-15'],
      ['Short month', 'INCOME CERTIFICATE Date: Jun 15, 2024', '2024-06-15'],
    ];

    test.each(cases)('parses %s format → %s', async (_label, text, expectedDate) => {
      global.fetch = mockVisionFetch(`KEBELE INCOME CERTIFICATE\n${text}`) as any;
      const result = await service.validateIndigentDocument(DUMMY_B64);
      expect(result.detectedDate).toBe(expectedDate);
    });
  });
});
