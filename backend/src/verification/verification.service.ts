import { createHash } from 'crypto';
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

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
  ) {}

  async verifyDocument(
    fileBuffer: Buffer,
    mimeType: string,
    dto: VerifyDocumentDto,
    userId?: string,
  ): Promise<VerificationResultDto> {
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

    // ── Step 2b: ID card document validation ──────────────────────────────
    if (dto.documentType === 'ID_CARD') {
      const idValidation = this.visionService.validateIdCardText(
        { fullText: ocrText, words: ocrText.split(/[\n\r\s]+/).map(w => w.trim()).filter(w => w.length > 0), confidence: ocrConfidence },
        dto.userIdNumber,
      );
      if (!idValidation.isValid) {
        this.logger.warn(`ID card validation failed: ${idValidation.issues.join('; ')}`);
        const entity = this.verificationRepo.create({
          userId: userId ?? null,
          documentType: dto.documentType,
          status: 'rejected',
          confidence: 0,
          extractedData: { rawText: ocrText || null },
          validationErrors: idValidation.issues,
        });
        const saved = await this.verificationRepo.save(entity);
        const rejectResult: VerificationResultDto = {
          status: 'rejected',
          confidence: 0,
          extracted: { name: null, idNumber: null, expiryDate: null, documentType: null },
          reasons: idValidation.issues,
          verificationId: saved.id,
          isDemo: false,
        };
        resultCache.set(cacheKey, { result: rejectResult, expiresAt: Date.now() + CACHE_TTL_MS });
        return rejectResult;
      }
    }

    // ── Step 3: Parse structured fields ───────────────────────────────────
    const extractedName = this.parsingService.extractFullName(ocrText);
    const extractedId = this.parsingService.extractIdNumber(ocrText);
    const expiryDate = this.parsingService.extractExpiryDate(ocrText);

    // ── Step 3b: Hard check — name and ID must be found in the image ──────
    const hardRejectReasons: string[] = [];

    if (!extractedName) {
      hardRejectReasons.push('Could not find a name on the document that matches the provided name. Please upload a clear photo of your ID card.');
    } else {
      const nameResult = this.validationService.fuzzyNameMatch(extractedName, dto.userName);
      if (!nameResult.match) {
        hardRejectReasons.push(`Name on document ("${extractedName}") does not match the provided name ("${dto.userName}").`);
      }
    }

    if (!extractedId) {
      hardRejectReasons.push('Could not find an ID number on the document. Please upload a clear photo of your ID card.');
    } else {
      const normalizedExtracted = extractedId.replace(/\s/g, '').toUpperCase();
      const normalizedProvided = dto.userIdNumber.replace(/\s/g, '').toUpperCase();
      if (normalizedExtracted !== normalizedProvided) {
        hardRejectReasons.push(`ID number on document (${extractedId}) does not match the provided number (${dto.userIdNumber}).`);
      }
    }

    if (hardRejectReasons.length > 0) {
      this.logger.warn(`Hard reject: ${hardRejectReasons.join('; ')}`);
      const entity = this.verificationRepo.create({
        userId: userId ?? null,
        documentType: dto.documentType,
        status: 'rejected',
        confidence: 0,
        extractedData: { name: extractedName, idNumber: extractedId, rawText: ocrText || null },
        validationErrors: hardRejectReasons,
      });
      const saved = await this.verificationRepo.save(entity);
      const rejectResult: VerificationResultDto = {
        status: 'rejected',
        confidence: 0,
        extracted: { name: extractedName, idNumber: extractedId, expiryDate: null, documentType: null },
        reasons: hardRejectReasons,
        verificationId: saved.id,
        isDemo: false,
      };
      resultCache.set(cacheKey, { result: rejectResult, expiresAt: Date.now() + CACHE_TTL_MS });
      return rejectResult;
    }

    // ── Step 4: Validate name (already passed hard check above) ────────────
    const nameMatchResult = this.validationService.fuzzyNameMatch(extractedName!, dto.userName);

    // ── Step 5: Validate ID (already passed hard check above) ─────────────
    const idMatch = true;

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

    const roundedConfidence = Math.round(confidence * 1000) / 1000;

    // ── Step 10: Persist ───────────────────────────────────────────────────
    const extractedData: Record<string, unknown> = {
      name: extractedName,
      idNumber: extractedId,
      expiryDate: expiryDate ? expiryDate.toISOString().split('T')[0] : null,
      documentType: detectedDocumentType,
      nameMatchScore: nameMatchResult.score,
      rawText: ocrText || null,
    };

    const entity = this.verificationRepo.create({
      userId: userId ?? null,
      documentType: dto.documentType,
      status: decision.status,
      confidence: roundedConfidence,
      extractedData,
      validationErrors: decision.reasons,
    });

    const saved = await this.verificationRepo.save(entity);

    const result: VerificationResultDto = {
      status: decision.status,
      confidence: roundedConfidence,
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
    if (!nameMatch) {
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
      userId: userId ?? null,
      documentType: dto.documentType,
      status: 'manual_review',
      confidence: 0,
      extractedData: null,
      validationErrors: [reason],
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
