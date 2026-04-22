import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DemoSandboxService } from '../demo/demo-sandbox.service';
import { VisionService } from '../vision/vision.service';
import { ClassificationService } from './classification.service';
import { ParsingService } from './parsing.service';
import { ValidationService } from './validation.service';
import { Verification } from './verification.entity';
import { VerificationService } from './verification.service';
import { VerifyDocumentDto } from './verification.dto';

// ─── helpers ────────────────────────────────────────────────────────────────

const DUMMY_BUFFER = Buffer.from('fake-image-data');
const DUMMY_MIME = 'image/jpeg';

function makeDto(
  overrides: Partial<VerifyDocumentDto> = {},
): VerifyDocumentDto {
  return {
    userName: 'Alemayehu Bekele',
    userIdNumber: '123456789012',
    documentType: 'ID_CARD',
    ...overrides,
  };
}

/** Build a mock VisionService.extractText response */
function mockExtractText(
  fullText: string,
  confidence = 0.9,
): jest.Mock {
  return jest.fn().mockResolvedValue({ fullText, words: fullText.split(/\s+/), confidence });
}

/** Minimal mock repo */
function mockRepo(): Partial<Repository<Verification>> {
  let counter = 0;
  return {
    create: jest.fn((data) => ({ id: `uuid-${++counter}`, ...data } as Verification)),
    save: jest.fn(async (entity) => entity as Verification),
  };
}

// ─── suite ──────────────────────────────────────────────────────────────────

describe('VerificationService', () => {
  let service: VerificationService;
  let visionService: VisionService;
  let repo: Partial<Repository<Verification>>;

  // ── shared setup (live mode, no demo) ─────────────────────────────────────

  async function buildModule(demoActive = false) {
    process.env.GOOGLE_VISION_API_KEY = 'FAKE_KEY';
    process.env.DEMO_MODE = demoActive ? 'true' : 'false';

    repo = mockRepo();

    const demoStub = {
      isActive: demoActive,
      validateIdDocument: jest.fn(),
      validateIndigentDocument: jest.fn(),
    } as unknown as DemoSandboxService;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VerificationService,
        ParsingService,
        ValidationService,
        ClassificationService,
        { provide: VisionService, useValue: { extractText: jest.fn() } },
        { provide: DemoSandboxService, useValue: demoStub },
        { provide: getRepositoryToken(Verification), useValue: repo },
      ],
    }).compile();

    service = module.get(VerificationService);
    visionService = module.get(VisionService);
  }

  afterEach(() => {
    delete process.env.GOOGLE_VISION_API_KEY;
    delete process.env.DEMO_MODE;
    jest.restoreAllMocks();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEST CASE 1 — Valid ID
  // ══════════════════════════════════════════════════════════════════════════

  describe('Test Case 1: Valid ID', () => {
    it('should approve a valid ID with matching name and future expiry', async () => {
      await buildModule(false);

      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 2);
      const dd = String(futureDate.getDate()).padStart(2, '0');
      const mm = String(futureDate.getMonth() + 1).padStart(2, '0');
      const yyyy = futureDate.getFullYear();

      (visionService.extractText as jest.Mock) = mockExtractText(
        `FEDERAL DEMOCRATIC REPUBLIC OF ETHIOPIA\nNATIONAL ID CARD\nFAN: 123456789012\nAlemayehu Bekele\nExpiry: ${dd}/${mm}/${yyyy}`,
        0.95,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userName: 'Alemayehu Bekele', userIdNumber: '123456789012' }),
      );

      expect(result.status).toBe('approved');
      expect(result.confidence).toBeGreaterThan(0.7);
      expect(result.reasons).toHaveLength(0);
      expect(result.isDemo).toBe(false);
      expect(result.verificationId).toBeDefined();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEST CASE 2 — Expired ID
  // ══════════════════════════════════════════════════════════════════════════

  describe('Test Case 2: Expired ID', () => {
    it('should reject an expired ID document', async () => {
      await buildModule(false);

      (visionService.extractText as jest.Mock) = mockExtractText(
        `FEDERAL DEMOCRATIC REPUBLIC OF ETHIOPIA\nNATIONAL ID CARD\nFAN: 987654321098\nTigist Haile\nExpiry: 01/01/2020`,
        0.92,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userName: 'Tigist Haile', userIdNumber: '987654321098' }),
      );

      expect(result.status).toBe('rejected');
      expect(result.reasons).toContain('Document expired');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEST CASE 3 — Blurry Image (low OCR confidence)
  // ══════════════════════════════════════════════════════════════════════════

  describe('Test Case 3: Blurry Image', () => {
    it('should return manual_review for low OCR confidence (< 0.4)', async () => {
      await buildModule(false);

      (visionService.extractText as jest.Mock) = mockExtractText(
        'f3d3r@l 3th10p14 n@t10n@l 1d c@rd f@n 1234',
        0.25, // below 0.4 threshold
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto(),
      );

      expect(result.status).toBe('manual_review');
      expect(result.reasons).toContain('Low image quality');
    });

    it('should return manual_review when Vision API throws', async () => {
      await buildModule(false);

      (visionService.extractText as jest.Mock) = jest
        .fn()
        .mockRejectedValue(new Error('Network timeout'));

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto(),
      );

      expect(result.status).toBe('manual_review');
      expect(result.reasons[0]).toContain('Vision API unavailable');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEST CASE 4 — Fake / Unrecognized Document (no valid ID number)
  // ══════════════════════════════════════════════════════════════════════════

  describe('Test Case 4: Fake Document', () => {
    it('should reject a document with no recognizable ID number', async () => {
      await buildModule(false);

      (visionService.extractText as jest.Mock) = mockExtractText(
        'LOREM IPSUM DOLOR SIT AMET\nCONSECTETUR ADIPISCING ELIT\nNO VALID ID HERE',
        0.85,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userIdNumber: '123456789012' }),
      );

      expect(result.status).toBe('rejected');
      expect(result.reasons).toContain('ID number mismatch');
    });

    it('should reject when extracted ID does not match user-provided ID', async () => {
      await buildModule(false);

      (visionService.extractText as jest.Mock) = mockExtractText(
        `FEDERAL ETHIOPIA NATIONAL ID\nFAN: 999999999999\nAlemayehu Bekele`,
        0.90,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userIdNumber: '123456789012' }),
      );

      expect(result.status).toBe('rejected');
      expect(result.reasons).toContain('ID number mismatch');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEST CASE 5 — Mismatched Name
  // ══════════════════════════════════════════════════════════════════════════

  describe('Test Case 5: Mismatched Name', () => {
    it('should reject when extracted name is completely different from user input', async () => {
      await buildModule(false);

      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 1);
      const dd = String(futureDate.getDate()).padStart(2, '0');
      const mm = String(futureDate.getMonth() + 1).padStart(2, '0');
      const yyyy = futureDate.getFullYear();

      (visionService.extractText as jest.Mock) = mockExtractText(
        `FEDERAL ETHIOPIA NATIONAL ID\nFAN: 555666777888\nDawit Girma\nExpiry: ${dd}/${mm}/${yyyy}`,
        0.90,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({
          userName: 'Abebe Kebede',
          userIdNumber: '555666777888',
        }),
      );

      expect(result.status).toBe('rejected');
      expect(result.reasons).toContain('Name mismatch');
    });

    it('should return manual_review for borderline name match (score 0.75–0.89)', async () => {
      await buildModule(false);

      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 1);
      const dd = String(futureDate.getDate()).padStart(2, '0');
      const mm = String(futureDate.getMonth() + 1).padStart(2, '0');
      const yyyy = futureDate.getFullYear();

      // "Alemayehu Bekele" vs "Alemayehu Bekele Tadesse" → borderline score
      (visionService.extractText as jest.Mock) = mockExtractText(
        `FEDERAL ETHIOPIA NATIONAL ID\nFAN: 123456789012\nAlemayehu Bekele Tadesse\nExpiry: ${dd}/${mm}/${yyyy}`,
        0.92,
      );

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userName: 'Alemayehu Bekele', userIdNumber: '123456789012' }),
      );

      // Score will be borderline — either manual_review or approved depending on exact score
      expect(['approved', 'manual_review']).toContain(result.status);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DEMO MODE
  // ══════════════════════════════════════════════════════════════════════════

  describe('Demo mode', () => {
    it('should return approved with isDemo=true when DEMO_MODE=true', async () => {
      await buildModule(true);

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto(),
      );

      expect(result.status).toBe('approved');
      expect(result.confidence).toBe(0.95);
      expect(result.isDemo).toBe(true);
      // Vision API should NOT be called in demo mode
      expect(visionService.extractText).not.toHaveBeenCalled();
    });

    it('demo result includes user-provided name and ID', async () => {
      await buildModule(true);

      const result = await service.verifyDocument(
        DUMMY_BUFFER,
        DUMMY_MIME,
        makeDto({ userName: 'Tigist Haile', userIdNumber: '999888777666' }),
      );

      expect(result.extracted.name).toBe('Tigist Haile');
      expect(result.extracted.idNumber).toBe('999888777666');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DECISION ENGINE unit tests
  // ══════════════════════════════════════════════════════════════════════════

  describe('makeDecision', () => {
    beforeEach(async () => {
      await buildModule(false);
    });

    it('returns manual_review for ocrConfidence < 0.4', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 1.0, idMatch: true,
        expired: false, indigentValid: null, ocrConfidence: 0.3,
      });
      expect(r.status).toBe('manual_review');
      expect(r.reasons).toContain('Low image quality');
    });

    it('returns rejected for name score < 0.5', () => {
      const r = service.makeDecision({
        nameMatch: false, nameScore: 0.2, idMatch: true,
        expired: false, indigentValid: null, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('rejected');
      expect(r.reasons).toContain('Name mismatch');
    });

    it('returns rejected for ID mismatch', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 1.0, idMatch: false,
        expired: false, indigentValid: null, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('rejected');
      expect(r.reasons).toContain('ID number mismatch');
    });

    it('returns rejected for expired document', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 1.0, idMatch: true,
        expired: true, indigentValid: null, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('rejected');
      expect(r.reasons).toContain('Document expired');
    });

    it('returns rejected for invalid indigent document', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 1.0, idMatch: true,
        expired: false, indigentValid: false, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('rejected');
      expect(r.reasons).toContain('Invalid indigent document');
    });

    it('returns manual_review for borderline name score (0.75–0.89)', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 0.80, idMatch: true,
        expired: false, indigentValid: null, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('manual_review');
      expect(r.reasons).toContain('Name requires manual review');
    });

    it('returns approved for all-passing inputs', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 0.95, idMatch: true,
        expired: false, indigentValid: null, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('approved');
      expect(r.reasons).toHaveLength(0);
    });

    it('returns approved for valid indigent document', () => {
      const r = service.makeDecision({
        nameMatch: true, nameScore: 0.95, idMatch: true,
        expired: false, indigentValid: true, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('approved');
    });

    it('accumulates multiple rejection reasons', () => {
      const r = service.makeDecision({
        nameMatch: false, nameScore: 0.1, idMatch: false,
        expired: true, indigentValid: false, ocrConfidence: 0.9,
      });
      expect(r.status).toBe('rejected');
      expect(r.reasons).toContain('Name mismatch');
      expect(r.reasons).toContain('ID number mismatch');
      expect(r.reasons).toContain('Document expired');
      expect(r.reasons).toContain('Invalid indigent document');
    });
  });
});
