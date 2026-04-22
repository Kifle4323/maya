import { Injectable } from '@nestjs/common';

@Injectable()
export class ParsingService {
  /** Lowercase, trim, collapse whitespace */
  normalizeText(text: string): string {
    return text.toLowerCase().trim().replace(/\s+/g, ' ');
  }

  /**
   * Extract a full name: 2–5 title-case words, not all-numeric,
   * not containing known document keywords.
   */
  extractFullName(text: string): string | null {
    const SKIP_KEYWORDS = new Set([
      'federal', 'democratic', 'republic', 'ethiopia', 'national', 'id', 'card',
      'fan', 'date', 'birth', 'gender', 'region', 'zone', 'woreda', 'kebele',
      'income', 'certificate', 'poverty', 'disability', 'residence', 'identification',
      'issued', 'expiry', 'valid', 'until', 'signature', 'official', 'stamp',
      'authorized', 'director', 'office', 'male', 'female',
    ]);

    const lines = text.split(/[\n\r]+/).map((l) => l.trim()).filter(Boolean);

    for (const line of lines) {
      // Must be 2–5 words
      const words = line.split(/\s+/);
      if (words.length < 2 || words.length > 5) continue;

      // Must not be all-numeric
      if (/^\d+$/.test(line.replace(/\s/g, ''))) continue;

      // Must not contain digits (IDs, dates)
      if (/\d/.test(line)) continue;

      // Must not contain known keywords
      const lower = line.toLowerCase();
      if ([...SKIP_KEYWORDS].some((kw) => lower.includes(kw))) continue;

      // Prefer title-case lines (each word starts with uppercase)
      const isTitleCase = words.every((w) => /^[A-ZÀ-Ö]/.test(w));
      if (isTitleCase) return line;
    }

    // Fallback: any 2–5 word line without digits or keywords
    for (const line of lines) {
      const words = line.split(/\s+/);
      if (words.length < 2 || words.length > 5) continue;
      if (/\d/.test(line)) continue;
      const lower = line.toLowerCase();
      if ([...SKIP_KEYWORDS].some((kw) => lower.includes(kw))) continue;
      return line;
    }

    return null;
  }

  /**
   * Extract an ID number:
   * 1. Ethiopian 12-digit FAN: /\b\d{12}\b/
   * 2. Labeled pattern: FAN/ID/No./Number followed by alphanumeric
   */
  extractIdNumber(text: string): string | null {
    // Ethiopian 12-digit FAN (most specific — try first)
    const fanMatch = text.match(/\b(\d{12})\b/);
    if (fanMatch) return fanMatch[1];

    // Labeled pattern: FAN: ABC123, ID: 123456, No. 123456, Number: 123456
    const labeledMatch = text.match(
      /\b(?:FAN|ID|No\.?|Number)[:\s]+([A-Z0-9\-]{6,20})\b/i,
    );
    if (labeledMatch) return labeledMatch[1];

    return null;
  }

  /**
   * Extract an expiry/issue date from text.
   * Supports:
   *   - DD/MM/YYYY or DD-MM-YYYY
   *   - YYYY-MM-DD
   *   - "Month DD, YYYY" / "Mon DD, YYYY"
   *   - Preceded by expiry/valid keywords
   */
  extractExpiryDate(text: string): Date | null {
    // Expiry-labeled date
    const expiryPattern =
      /(?:expir(?:y|es?|ed?)|valid\s+until|valid\s+to)[:\s]*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/i;
    const expiryMatch = text.match(expiryPattern);
    if (expiryMatch) {
      const parsed = this._parseDateString(expiryMatch[1]);
      if (parsed) return parsed;
    }

    // ISO: YYYY-MM-DD
    const isoMatch = text.match(/\b(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})\b/);
    if (isoMatch) {
      const d = new Date(
        Number(isoMatch[1]),
        Number(isoMatch[2]) - 1,
        Number(isoMatch[3]),
      );
      if (this._isReasonableDate(d)) return d;
    }

    // DD/MM/YYYY or DD-MM-YYYY
    const dmyMatch = text.match(/\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\b/);
    if (dmyMatch) {
      const d = new Date(
        Number(dmyMatch[3]),
        Number(dmyMatch[2]) - 1,
        Number(dmyMatch[1]),
      );
      if (this._isReasonableDate(d)) return d;
    }

    // "Month DD, YYYY" or "Mon DD, YYYY"
    const monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    const shortNames = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    const monthPattern =
      /(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2}),?\s+(\d{4})/i;
    const monthMatch = text.match(monthPattern);
    if (monthMatch) {
      const m = monthMatch[1].toLowerCase();
      const monthIndex =
        monthNames.indexOf(m) !== -1
          ? monthNames.indexOf(m)
          : shortNames.indexOf(m);
      if (monthIndex !== -1) {
        const d = new Date(Number(monthMatch[3]), monthIndex, Number(monthMatch[2]));
        if (this._isReasonableDate(d)) return d;
      }
    }

    return null;
  }

  private _parseDateString(str: string): Date | null {
    const parts = str.split(/[\/\-]/);
    if (parts.length !== 3) return null;
    const [a, b, c] = parts.map(Number);
    // Determine if DD/MM/YYYY or MM/DD/YYYY — assume DD/MM/YYYY for Ethiopian docs
    const year = c > 1000 ? c : a;
    const month = c > 1000 ? b : b;
    const day = c > 1000 ? a : c;
    const d = new Date(year, month - 1, day);
    return this._isReasonableDate(d) ? d : null;
  }

  private _isReasonableDate(d: Date): boolean {
    const year = d.getFullYear();
    return !isNaN(d.getTime()) && year >= 1990 && year <= new Date().getFullYear() + 10;
  }
}
