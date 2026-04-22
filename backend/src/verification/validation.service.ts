import { Injectable } from '@nestjs/common';

@Injectable()
export class ValidationService {
  /** Threshold from env, default 0.75 */
  private get threshold(): number {
    const val = parseFloat(process.env.VERIFICATION_NAME_MATCH_THRESHOLD ?? '0.75');
    return isNaN(val) ? 0.75 : val;
  }

  /**
   * Fuzzy name match using Levenshtein distance.
   * Normalizes both strings (lowercase, remove diacritics, collapse whitespace).
   * score = 1 - (editDistance / maxLength)
   * match = score >= threshold
   */
  fuzzyNameMatch(
    extracted: string,
    userInput: string,
  ): { match: boolean; score: number } {
    const a = this._normalize(extracted);
    const b = this._normalize(userInput);

    if (!a || !b) return { match: false, score: 0 };
    if (a === b) return { match: true, score: 1.0 };

    const dist = this._levenshtein(a, b);
    const maxLen = Math.max(a.length, b.length);
    const score = maxLen === 0 ? 1 : 1 - dist / maxLen;

    return { match: score >= this.threshold, score: Math.round(score * 1000) / 1000 };
  }

  /** Returns true if the date is in the past */
  isExpired(expiryDate: Date): boolean {
    return expiryDate < new Date();
  }

  /** Returns true if the date is within `withinDays` days from now */
  isExpiringSoon(expiryDate: Date, withinDays = 30): boolean {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() + withinDays);
    return expiryDate > new Date() && expiryDate <= cutoff;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private _normalize(str: string): string {
    return str
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // strip diacritics
      .replace(/[^a-z0-9\s]/g, '')
      .trim()
      .replace(/\s+/g, ' ');
  }

  private _levenshtein(a: string, b: string): number {
    const m = a.length;
    const n = b.length;
    const dp: number[][] = Array.from({ length: m + 1 }, (_, i) =>
      Array.from({ length: n + 1 }, (__, j) => (i === 0 ? j : j === 0 ? i : 0)),
    );

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (a[i - 1] === b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
        }
      }
    }

    return dp[m][n];
  }
}
