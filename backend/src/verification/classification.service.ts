import { Injectable } from '@nestjs/common';
import { ParsingService } from './parsing.service';

export interface ClassificationResult {
  documentType: string;
  confidence: number;
  keywords: string[];
  hasOfficialStamp: boolean;
  issuingAuthority: string | null;
  isRecent: boolean;
}

const KEYWORD_SETS: Record<string, string[]> = {
  INCOME_CERTIFICATE: [
    'income certificate',
    'monthly earnings',
    'salary below',
    'ገቢ ምስክር',
    'income',
    'earnings',
    'salary',
    'monthly',
  ],
  POVERTY_CERTIFICATE: [
    'poverty certificate',
    'indigent',
    'needy',
    'ድሃ',
    'ድህነት',
    'poverty',
    'poor',
    'welfare',
  ],
  KEBELE_ID: [
    'kebele',
    'ቀበሌ',
    'residence',
    'ወረዳ',
    'resident identification',
    'woreda',
    'resident',
  ],
  DISABILITY_CERTIFICATE: [
    'disability',
    'disabled',
    'አካል ጉዳተኛ',
    'impairment',
    'rehabilitation',
  ],
};

const OFFICIAL_STAMP_KEYWORDS = [
  'official stamp',
  'authorized',
  'signed by',
  'director',
  'head of office',
  'ፊርማ',
  'signature',
  'seal',
];

const AUTHORITY_PATTERNS = [
  /kebele\s+(?:administration\s+)?office/i,
  /woreda\s+(?:administration\s+)?office/i,
  /social\s+welfare\s+office/i,
  /health\s+(?:center|office)/i,
  /ቀበሌ\s+አስተዳደር/,
];

@Injectable()
export class ClassificationService {
  constructor(private readonly parsingService: ParsingService) {}

  classifyIndigentDocument(text: string): ClassificationResult {
    const lower = text.toLowerCase();

    // Score each document type by keyword hits
    let bestType = 'UNKNOWN';
    let bestKeywords: string[] = [];
    let bestScore = 0;

    for (const [docType, keywords] of Object.entries(KEYWORD_SETS)) {
      const found = keywords.filter((kw) => lower.includes(kw.toLowerCase()));
      // Weight multi-word phrases higher
      const score = found.reduce((acc, kw) => acc + (kw.includes(' ') ? 2 : 1), 0);
      if (score > bestScore) {
        bestScore = score;
        bestType = docType;
        bestKeywords = found;
      }
    }

    // Confidence: normalize by max possible score for that type
    const maxPossible = (KEYWORD_SETS[bestType] ?? []).reduce(
      (acc, kw) => acc + (kw.includes(' ') ? 2 : 1),
      0,
    );
    const confidence =
      bestScore === 0 || maxPossible === 0
        ? 0
        : Math.min(bestScore / maxPossible, 1);

    // Official stamp detection
    const hasOfficialStamp = OFFICIAL_STAMP_KEYWORDS.some((kw) =>
      lower.includes(kw.toLowerCase()),
    );

    // Issuing authority extraction
    let issuingAuthority: string | null = null;
    for (const pattern of AUTHORITY_PATTERNS) {
      const match = text.match(pattern);
      if (match) {
        issuingAuthority = match[0];
        break;
      }
    }

    // isRecent: check if a date in the text is within the last 12 months
    const detectedDate = this.parsingService.extractExpiryDate(text);
    let isRecent = false;
    if (detectedDate) {
      const twelveMonthsAgo = new Date();
      twelveMonthsAgo.setMonth(twelveMonthsAgo.getMonth() - 12);
      isRecent = detectedDate >= twelveMonthsAgo && detectedDate <= new Date();
    }

    return {
      documentType: bestType,
      confidence,
      keywords: bestKeywords,
      hasOfficialStamp,
      issuingAuthority,
      isRecent,
    };
  }
}
