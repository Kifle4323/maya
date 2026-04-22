import { createHash } from 'crypto';
import { Injectable, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DemoSandboxService } from '../demo/demo-sandbox.service';
import { VisionService } from '../vision/vision.service';
import { ClassificationService } from './classification.service';
import { ParsingService } from './parsing.service';
import { ValidationService } from './validation.service';
import { Verification } from './verification.entity';
import { VerificationResultDto, VerifyDocumentDto } from './verification.dto';

interface DecisionParams {
  nameMatch: boolean;
  nameScore: number;
  idMatch: boolean;
  expired: boolean;
  indigentValid: boolean | null;
  ocrConfidence: number;
}

interface DecisionResult {
  status: 'approved' | 'rejected' | 'manual_review';
  reasons: string[];
}

/** In-process SHA-256 cache to avoid re-calling Vision API for the same file */
const resultCache = new Map<string, { result: VerificationResultDto; expiresAt: number }>();
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

@Injectable()
export class VerificationService {
  private readonly logger = new Logger(VerificationService.name);

  constructor(
    @InjectRepository(Verification)
    private readonly verificationRepo: Repository<Verification>,
    private readonly visionService: VisionService,
    private readonly parsingService: ParsingService,
    private readonly validationService: ValidationService,
    private readonly classificationService: ClassificationService,
    @Optional() private readonly demo: DemoSandboxService,
  ) {}

  async verifyDocument(
    fileBuffer: Buffer,
    mimeType: string,
    dto: VerifyDocumentDto,
    userId?: string,
  ): Promise<VerificationResultDto> {
    // ── Demo mode shortcut ─────────────────────────────────────────────────
    if (this.demo?.isActive) {
      this.logger.debug('[DEMO] Returning mock verification result');
      const demoResult: VerificationResultDto = {
        status: 'approved',
        confidence: 0.95,
        extracted: {
          name: dto.userName,
          idNumber: dto.userIdNumber,
          expiryDate: null,
          documentType: dto.documentType === 'INDIGENT_PROOF' ? 'INCOME_CERTIFICATE' : null,
        },
        reasons: [],
        verificationId: 'demo-' + Date.now(),
        isDemo: true,
      };
      return demoResult;
    }

    // ── Cache check ────────────────────────────────────────────────────────
    const fileHash = createHash('sha256').update(fileBuffer).digest('hex');
    const cacheKey = `${fileHash}:${dto.userName}:${dto.userIdNumber}:${dto.documentType}`;
    const cached = resultCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      this.logger.debug(`Cache hit for file hash ${fileHash.substring(0, 8)}`);
      return cached.result;
    }

    // ── Step 1: Convert buffer to base64 ───────────────────────────────────
    const imageBase64 = fileBuffer.toString('base64');

    // ── Step 2: OCR extraction ─────────────────────────────────────────────
    let ocrText = '';
    let ocrConfidence = 0;

    try {
      const textResult = await this.visionService.extractText(imageBase64);
      ocrText = textResult.fullText;
      ocrConfidence = textResult.confidence;
      this.logger.debug(`OCR confidence: ${ocrConfidence}, text length: ${ocrText.length}`);
    } catch (err) {
      this.logger.warn(`Vision API failed: ${(err as Error).message} — returning manual_review`);
      return this._buildManualReviewResult(dto, userId, 'Vision API unavailable');
    }

    // ── Step 3: Parse structured fields ───────────────────────────────────
    const extractedName = this.parsingService.extractFullName(ocrText);
    const extractedId = this.parsingService.extractIdNumber(ocrText);
    const expiryDate = this.parsingService.extractExpiryDate(ocrText);

    // ── Step 4: Validate name ──────────────────────────────────────────────
    const nameMatchResult =
      extractedName
        ? this.validationService.fuzzyNameMatch(extractedName, dto.userName)
        : { match: false, score: 0 };

    // ── Step 5: Validate ID ────────────────────────────────────────────────
    const idMatch =
      extractedId !== null &&
      extractedId.replace(/\s/g, '').toUpperCase() ===
        dto.userIdNumber.replace(/\s/g, '').toUpperCase();

    // ── Step 6: Expiry check ───────────────────────────────────────────────
    const expired = expiryDate ? this.validationService.isExpired(expiryDate) : false;

    // ── Step 7: Indigent classification (if applicable) ───────────────────
    let indigentValid: boolean | null = null;
    let detectedDocumentType: string | null = null;

    if (dto.documentType === 'INDIGENT_PROOF') {
      const classification = this.classificationService.classifyIndigentDocument(ocrText);
      detectedDocumentType = classification.documentType;
      indigentValid =
        classification.documentType !== 'UNKNOWN' && classification.confidence > 0.1;
    }

    // ── Step 8: Decision engine ────────────────────────────────────────────
    const decision = this.makeDecision({
      nameMatch: nameMatchResult.match,
      nameScore: nameMatchResult.score,
      idMatch,
      expired,
      indigentValid,
      ocrConfidence,
    });

    // ── Step 9: Confidence score ───────────────────────────────────────────
    const idMatchScore = idMatch ? 1 : 0;
    const freshnessScore = expiryDate && !expired ? 1 : expiryDate && expired ? 0 : 0.5;
    const confidence =
      ocrConfidence * 0.3 +
      nameMatchResult.score * 0.4 +
      idMatchScore * 0.2 +
      freshnessScore * 0.1;

    // ── Step 10: Persist ───────────────────────────────────────────────────
    const entity = this.verificationRepo.create({
      userId,
      documentType: dto.documentType,
      extractedName: extractedName ?? undefined,
      extractedId: extractedId ?? undefined,
      expiryDate: expiryDate ?? undefined,
      matchScore: nameMatchResult.score,
      confidenceScore: Math.round(confidence * 1000) / 1000,
      status: decision.status,
      rawText: ocrText || undefined,
      reasons: decision.reasons,
      isDemo: false,
    });

    const saved = await this.verificationRepo.save(entity);

    const result: VerificationResultDto = {
      status: decision.status,
      confidence: Math.round(confidence * 1000) / 1000,
      extracted: {
        name: extractedName,
        idNumber: extractedId,
        expiryDate: expiryDate ? expiryDate.toISOString().split('T')[0] : null,
        documentType: detectedDocumentType,
      },
      reasons: decision.reasons,
      verificationId: saved.id,
      isDemo: false,
    };

    // Cache the result
    resultCache.set(cacheKey, { result, expiresAt: Date.now() + CACHE_TTL_MS });

    return result;
  }

  makeDecision(params: DecisionParams): DecisionResult {
    const { nameMatch, nameScore, idMatch, expired, indigentValid, ocrConfidence } = params;
    const reasons: string[] = [];

    // Low image quality → manual review immediately
    if (ocrConfidence < 0.4) {
      return { status: 'manual_review', reasons: ['Low image quality'] };
    }

    // Name mismatch (hard reject)
    if (!nameMatch && nameScore < 0.5) {
      reasons.push('Name mismatch');
    }

    // ID mismatch
    if (!idMatch) {
      reasons.push('ID number mismatch');
    }

    // Expired document
    if (expired) {
      reasons.push('Document expired');
    }

    // Invalid indigent document
    if (indigentValid === false) {
      reasons.push('Invalid indigent document');
    }

    if (reasons.length > 0) {
      return { status: 'rejected', reasons };
    }

    // Borderline name match → manual review
    if (nameScore >= 0.75 && nameScore < 0.9) {
      return { status: 'manual_review', reasons: ['Name requires manual review'] };
    }

    return { status: 'approved', reasons: [] };
  }

  private async _buildManualReviewResult(
    dto: VerifyDocumentDto,
    userId: string | undefined,
    reason: string,
  ): Promise<VerificationResultDto> {
    const entity = this.verificationRepo.create({
      userId,
      documentType: dto.documentType,
      matchScore: 0,
      confidenceScore: 0,
      status: 'manual_review',
      reasons: [reason],
      isDemo: false,
    });
    const saved = await this.verificationRepo.save(entity);

    return {
      status: 'manual_review',
      confidence: 0,
      extracted: { name: null, idNumber: null, expiryDate: null, documentType: null },
      reasons: [reason],
      verificationId: saved.id,
      isDemo: false,
    };
  }
}
