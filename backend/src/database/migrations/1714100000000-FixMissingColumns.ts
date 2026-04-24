import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Fixes missing columns and enum values that caused HTTP 500 on:
 *   - GET /api/v1/admin/reports/summary
 *   - GET /api/v1/admin/claims
 *
 * Root cause: TypeORM entities declared columns/enum values that were never
 * added to the initial schema migration, so every SELECT against those tables
 * failed with "column does not exist" or "invalid input value for enum".
 *
 * Changes:
 *   claims      — add "memberCoPayment" column
 *   claim_status — add ESCALATED enum value
 *   payments    — add "currency" and "chapaReference" columns
 *   coverages   — add "waitingPeriodEndsAt" and "claimsEligibleFrom" columns
 *   notification_type — add PAYMENT_CONFIRMATION enum value
 *
 * All statements are idempotent (IF NOT EXISTS / IF NOT EXISTS guard).
 */
export class FixMissingColumns1714100000000 implements MigrationInterface {
  name = 'FixMissingColumns1714100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── claims: add memberCoPayment ─────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE claims
        ADD COLUMN IF NOT EXISTS "memberCoPayment" DECIMAL(12,2) DEFAULT 0.00
    `);

    // ── claim_status enum: add ESCALATED ────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE claim_status ADD VALUE IF NOT EXISTS 'ESCALATED';
      EXCEPTION WHEN others THEN NULL; END $$
    `);

    // ── payments: add currency and chapaReference ───────────────────────────
    await queryRunner.query(`
      ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS "currency" VARCHAR(3) NOT NULL DEFAULT 'ETB',
        ADD COLUMN IF NOT EXISTS "chapaReference" VARCHAR(120)
    `);

    // ── coverages: add waitingPeriodEndsAt and claimsEligibleFrom ───────────
    await queryRunner.query(`
      ALTER TABLE coverages
        ADD COLUMN IF NOT EXISTS "waitingPeriodEndsAt" DATE,
        ADD COLUMN IF NOT EXISTS "claimsEligibleFrom" DATE
    `);

    // ── notification_type enum: add PAYMENT_CONFIRMATION ────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'PAYMENT_CONFIRMATION';
      EXCEPTION WHEN others THEN NULL; END $$
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Remove added columns (enum values cannot be removed in Postgres without
    // recreating the type, so we leave them — they are harmless).
    await queryRunner.query(`
      ALTER TABLE coverages
        DROP COLUMN IF EXISTS "claimsEligibleFrom",
        DROP COLUMN IF EXISTS "waitingPeriodEndsAt"
    `);

    await queryRunner.query(`
      ALTER TABLE payments
        DROP COLUMN IF EXISTS "chapaReference",
        DROP COLUMN IF EXISTS "currency"
    `);

    await queryRunner.query(`
      ALTER TABLE claims
        DROP COLUMN IF EXISTS "memberCoPayment"
    `);
  }
}
