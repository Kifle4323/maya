import { Injectable, Logger, Optional } from '@nestjs/common';
import { DemoSandboxService } from '../demo/demo-sandbox.service';

export interface VisionTextResult {
  fullText: string;
  words: string[];
  confidence: number;
  rawResponse?: unknown;
}

export interface IdValidationResult {
  isValid: boolean;
  extractedText: string;
  detectedName?: string;
  detectedIdNumber?: string;
  confidence: number;
  issues: string[];
  isDemo?: boolean;
}

export enum IndigentDocumentType {
  INCOME_CERTIFICATE = 'Income Certificate',
  DISABILITY_CERTIFICATE = 'Disability Certificate',
  KEBELE_ID = 'Kebele ID / Residence',
  POVERTY_CERTIFICATE = 'Poverty Certificate',
  AGRICULTURAL_CERTIFICATE = 'Agricultural Certificate',
  UNKNOWN = 'unknown',
}

export interface IndigentDocValidationResult {
  isValid: boolean;
  documentType: IndigentDocumentType | string;
  extractedText: string;
  detectedKeywords: string[];
  confidence: number;
  issues: string[];
  detectedDate?: string | null;
  isExpired?: boolean;
  expiryWarning?: string | null;
  isDemo?: boolean;
}

/** Accepted document types for indigent applications */
export const ACCEPTED_INDIGENT_DOC_TYPES = new Set<string>([
  IndigentDocumentType.INCOME_CERTIFICATE,
  IndigentDocumentType.DISABILITY_CERTIFICATE,
  IndigentDocumentType.KEBELE_ID,
  IndigentDocumentType.POVERTY_CERTIFICATE,
  IndigentDocumentType.AGRICULTURAL_CERTIFICATE,
]);

/** Document validity periods in months */
const DOC_VALIDITY_MONTHS: Record<string, number> = {
  [IndigentDocumentType.INCOME_CERTIFICATE]: 12,
  [IndigentDocumentType.DISABILITY_CERTIFICATE]: 36,
  [IndigentDocumentType.KEBELE_ID]: 24,
  [IndigentDocumentType.POVERTY_CERTIFICATE]: 12,
  [IndigentDocumentType.AGRICULTURAL_CERTIFICATE]: 12,
};

@Injectable()
export class VisionService {
  private readonly logger = new Logger(VisionService.name);
  private readonly apiKey = process.env.GOOGLE_VISION_API_KEY ?? '';
  private readonly endpoint = 'https://vision.googleapis.com/v1/images:annotate';

  constructor(
    @Optional() private readonly demo: DemoSandboxService,
  ) {}

  async extractText(imageBase64: string): Promise<VisionTextResult> {
    if (!this.apiKey) {
      this.logger.warn('GOOGLE_VISION_API_KEY not set — skipping text extraction');
      return { fullText: '', words: [], confidence: 0 };
    }

    try {
      const body = {
        requests: [{
          image: { content: imageBase64 },
          features: [
            { type: 'TEXT_DETECTION', maxResults: 1 },
            { type: 'DOCUMENT_TEXT_DETECTION', maxResults: 1 },
          ],
          imageContext: { languageHints: ['am', 'en'] },
        }],
      };

      const response = await fetch(`${this.endpoint}?key=${this.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`Vision API error [${response.status}]: ${text}`);
        return { fullText: '', words: [], confidence: 0 };
      }

      const result = await response.json() as {
        responses?: Array<{
          fullTextAnnotation?: { text: string; pages?: Array<{ confidence?: number }> };
          textAnnotations?: Array<{ description: string }>;
          error?: { message: string };
        }>;
      };

      const resp = result.responses?.[0];
      if (resp?.error) {
        this.logger.error(`Vision API response error: ${resp.error.message}`);
        return { fullText: '', words: [], confidence: 0 };
      }

      const fullText = resp?.fullTextAnnotation?.text ?? resp?.textAnnotations?.[0]?.description ?? '';
      const confidence = resp?.fullTextAnnotation?.pages?.[0]?.confidence ?? 0.5;
      const words = fullText.split(/[\n\r\s]+/).map((w) => w.trim()).filter((w) => w.length > 0);

      return { fullText, words, confidence, rawResponse: result };
    } catch (error) {
      this.logger.error(`Vision API exception: ${(error as Error).message}`);
      return { fullText: '', words: [], confidence: 0 };
    }
  }

  async validateIdDocument(imageBase64: string, expectedIdNumber?: string): Promise<IdValidationResult> {
    if (this.demo?.isActive || !this.apiKey) {
      return this.demo?.validateIdDocument(imageBase64, expectedIdNumber) ?? {
        isValid: true,
        extractedText: 'DEMO: Ethiopian National ID',
        detectedIdNumber: expectedIdNumber ?? '123456789012',
        confidence: 0.95,
        issues: [],
        isDemo: true,
      };
    }

    const textResult = await this.extractText(imageBase64);
    const issues: string[] = [];

    if (!textResult.fullText) {
      return {
        isValid: false,
        extractedText: '',
        confidence: 0,
        issues: ['Could not extract text from the document image. Please upload a clearer photo.'],
      };
    }

    const text = textResult.fullText.toUpperCase();
    const idKeywords = ['FEDERAL', 'ETHIOPIA', 'NATIONAL', 'ID', 'FAYDA', 'FAN', 'ፌደራል', 'ኢትዮጵያ'];
    const foundKeywords = idKeywords.filter((kw) => text.includes(kw));

    if (foundKeywords.length === 0) {
      issues.push('Document does not appear to be an Ethiopian National ID. Please upload the correct document.');
    }

    const fanMatch = text.match(/\b\d{12}\b/) ?? text.match(/FAN[:\s]*([A-Z0-9]{8,15})/i);
    const detectedIdNumber = fanMatch?.[1] ?? fanMatch?.[0];

    if (expectedIdNumber && detectedIdNumber) {
      const normalizedExpected = expectedIdNumber.replace(/\s/g, '').toUpperCase();
      const normalizedDetected = detectedIdNumber.replace(/\s/g, '').toUpperCase();
      if (!normalizedDetected.includes(normalizedExpected) && !normalizedExpected.includes(normalizedDetected)) {
        issues.push(`ID number on document (${detectedIdNumber}) does not match the provided number (${expectedIdNumber}).`);
      }
    }

    const lines = textResult.fullText.split('\n').map((l) => l.trim()).filter(Boolean);
    const nameLine = lines.find((line) =>
      line.length > 3 && line.length < 60 && !/\d{4,}/.test(line) &&
      !idKeywords.some((kw) => line.toUpperCase().includes(kw)),
    );

    return {
      isValid: issues.length === 0,
      extractedText: textResult.fullText,
      detectedName: nameLine,
      detectedIdNumber,
      confidence: textResult.confidence,
      issues,
    };
  }

  /**
   * Validate indigent supporting documents with:
   * - Document type detection and enforcement
   * - Document expiry detection (extracts issue date, checks validity period)
   */
  async validateIndigentDocument(imageBase64: string): Promise<IndigentDocValidationResult> {
    if (this.demo?.isActive || !this.apiKey) {
      return this.demo?.validateIndigentDocument(imageBase64) ?? {
        isValid: true,
        documentType: IndigentDocumentType.INCOME_CERTIFICATE,
        extractedText: 'DEMO: Kebele Income Certificate\nDate: 15/01/2024',
        detectedKeywords: ['INCOME', 'CERTIFICATE', 'KEBELE'],
        confidence: 0.92,
        issues: [],
        detectedDate: new Date().toISOString().split('T')[0],
        isExpired: false,
        isDemo: true,
      };
    }

    const textResult = await this.extractText(imageBase64);
    const issues: string[] = [];

    if (!textResult.fullText) {
      return {
        isValid: false,
        documentType: IndigentDocumentType.UNKNOWN,
        extractedText: '',
        detectedKeywords: [],
        confidence: 0,
        issues: ['Could not read the document. Please upload a clearer image or PDF scan.'],
      };
    }

    const text = textResult.fullText.toUpperCase();

    // ── Step 1: Detect document type ─────────────────────────────────────────
    const documentTypeKeywords: Record<string, string[]> = {
      [IndigentDocumentType.INCOME_CERTIFICATE]: ['INCOME', 'SALARY', 'EARNINGS', 'ደሞዝ', 'ገቢ', 'CERTIFICATE', 'MONTHLY'],
      [IndigentDocumentType.DISABILITY_CERTIFICATE]: ['DISABILITY', 'DISABLED', 'IMPAIRMENT', 'አካል ጉዳት', 'MEDICAL', 'HOSPITAL', 'REHABILITATION'],
      [IndigentDocumentType.KEBELE_ID]: ['KEBELE', 'WOREDA', 'RESIDENCE', 'ቀበሌ', 'ወረዳ', 'RESIDENT', 'IDENTIFICATION'],
      [IndigentDocumentType.POVERTY_CERTIFICATE]: ['POVERTY', 'INDIGENT', 'POOR', 'ድሃ', 'SOCIAL', 'WELFARE', 'NEEDY'],
      [IndigentDocumentType.AGRICULTURAL_CERTIFICATE]: ['FARMER', 'AGRICULTURE', 'LAND', 'CROP', 'ገበሬ', 'ግብርና', 'SMALLHOLDER'],
    };

    let detectedType: string = IndigentDocumentType.UNKNOWN;
    let maxKeywords: string[] = [];

    for (const [docType, keywords] of Object.entries(documentTypeKeywords)) {
      const found = keywords.filter((kw) => text.includes(kw));
      if (found.length > maxKeywords.length) {
        maxKeywords = found;
        detectedType = docType;
      }
    }

    // ── Step 2: Enforce accepted document types ───────────────────────────────
    if (detectedType === IndigentDocumentType.UNKNOWN || maxKeywords.length === 0) {
      issues.push(
        'Document type could not be identified. Accepted documents: ' +
        'Income Certificate, Disability Certificate, Kebele ID, Poverty Certificate, or Agricultural Certificate.',
      );
    } else if (!ACCEPTED_INDIGENT_DOC_TYPES.has(detectedType)) {
      issues.push(`Document type "${detectedType}" is not accepted for indigent applications.`);
    }

    // ── Step 3: Extract issue date and check expiry ───────────────────────────
    const detectedDate = this.extractDocumentDate(textResult.fullText);
    let isExpired = false;
    let expiryWarning: string | null = null;

    if (detectedDate) {
      const validityMonths = DOC_VALIDITY_MONTHS[detectedType] ?? 12;
      const issueDate = new Date(detectedDate);
      const expiryDate = new Date(issueDate);
      expiryDate.setMonth(expiryDate.getMonth() + validityMonths);
      const now = new Date();

      if (expiryDate < now) {
        isExpired = true;
        const monthsExpired = Math.floor((now.getTime() - expiryDate.getTime()) / (1000 * 60 * 60 * 24 * 30));
        issues.push(
          `This document expired ${monthsExpired} month(s) ago (issued: ${detectedDate}, ` +
          `valid for ${validityMonths} months). Please obtain a new certificate from your kebele.`,
        );
      } else {
        const daysUntilExpiry = Math.floor((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
        if (daysUntilExpiry < 30) {
          expiryWarning = `Document expires in ${daysUntilExpiry} days. Consider renewing soon.`;
        }
      }
    } else {
      expiryWarning = 'Could not detect issue date. Please ensure the document is current (issued within the last year).';
    }

    // ── Step 4: Minimum text content check ───────────────────────────────────
    if (textResult.words.length < 5) {
      issues.push('Document appears to have insufficient text content. Please ensure the image is clear and complete.');
    }

    return {
      isValid: issues.length === 0,
      documentType: detectedType,
      extractedText: textResult.fullText,
      detectedKeywords: maxKeywords,
      confidence: textResult.confidence,
      issues,
      detectedDate,
      isExpired,
      expiryWarning,
    };
  }

  /**
   * Extract a date from document text.
   * Handles Ethiopian Ge'ez calendar and Gregorian formats.
   */
  private extractDocumentDate(text: string): string | null {
    // Gregorian: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
    const gregorianPatterns = [
      /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/,
      /(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/,
      /(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})/i,
      /(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{4})/i,
    ];

    for (const pattern of gregorianPatterns) {
      const match = text.match(pattern);
      if (match) {
        try {
          let year: number, month: number, day: number;
          if (/^\d{4}/.test(match[0])) {
            year = Number(match[1]); month = Number(match[2]); day = Number(match[3]);
          } else if (/[A-Za-z]/.test(match[1])) {
            const monthNames = ['january','february','march','april','may','june','july','august','september','october','november','december'];
            const shortNames = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
            const m = match[1].toLowerCase();
            month = monthNames.indexOf(m) + 1 || shortNames.indexOf(m) + 1;
            day = Number(match[2]); year = Number(match[3]);
          } else {
            day = Number(match[1]); month = Number(match[2]); year = Number(match[3]);
          }
          if (year > 1990 && year <= new Date().getFullYear() + 1 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          }
        } catch { continue; }
      }
    }

    // Ethiopian Ge'ez calendar months
    const ethMonths = ['Meskerem','Tikimt','Hidar','Tahsas','Tir','Yekatit','Megabit','Miazia','Ginbot','Sene','Hamle','Nehase','Pagume'];
    const ethPattern = new RegExp(`(${ethMonths.join('|')})\\s+(\\d{1,2}),?\\s+(\\d{4})`, 'i');
    const ethMatch = text.match(ethPattern);
    if (ethMatch) {
      const monthIndex = ethMonths.findIndex((m) => m.toLowerCase() === ethMatch[1].toLowerCase());
      const ethYear = Number(ethMatch[3]);
      if (monthIndex >= 0 && ethYear > 2000) {
        const gregYear = ethYear + 7; // Ethiopian year is ~7 years behind Gregorian
        return `${gregYear}-${String(monthIndex + 1).padStart(2, '0')}-${String(Number(ethMatch[2])).padStart(2, '0')}`;
      }
    }

    return null;
  }
}
