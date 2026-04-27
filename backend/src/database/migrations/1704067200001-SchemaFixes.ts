import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Schema fix migration — adds all columns and tables that exist in entities
 * but were missing from the initial migration, causing FUNCTION_INVOCATION_FAILED
 * on Vercel (TypeORM queries columns that don't exist in the DB).
 *
 * All statements are idempotent (IF NOT EXISTS / DO $$ ... EXCEPTION).
 */
export class SchemaFixes1704067200001 implements MigrationInterface {
  name = 'SchemaFixes1704067200001';

  public async up(queryRunner: QueryRunner): Promise<void> {

    // ── 1. Add missing enum values ────────────────────────────────────────────

    // coverage_status: add WAITING_PERIOD, INACTIVE (missing from initial migration)
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE coverage_status ADD VALUE IF NOT EXISTS 'WAITING_PERIOD';
      EXCEPTION WHEN others THEN NULL; END $$
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE coverage_status ADD VALUE IF NOT EXISTS 'INACTIVE';
      EXCEPTION WHEN others THEN NULL; END $$
    `);

    // claim_status: add ESCALATED
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE claim_status ADD VALUE IF NOT EXISTS 'ESCALATED';
      EXCEPTION WHEN others THEN NULL; END $$
    `);

    // notification_type: add PAYMENT_CONFIRMATION
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'PAYMENT_CONFIRMATION';
      EXCEPTION WHEN others THEN NULL; END $$
    `);

    // ── 2. New enum types ─────────────────────────────────────────────────────

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE membership_tier AS ENUM (
          'INDIGENT', 'LOW_INCOME', 'MIDDLE_INCOME', 'HIGH_INCOME'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE facility_level AS ENUM (
          'HEALTH_POST', 'HEALTH_CENTER', 'PRIMARY_HOSPITAL',
          'GENERAL_HOSPITAL', 'SPECIALIZED_HOSPITAL'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$
    `);

    // ── 3. users — missing columns ────────────────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "tokenVersion"          INT          NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "otpFailCount"          INT          NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "otpRateLimitCount"     INT          NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "otpRateLimitWindowStart" TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS "fcmToken"              VARCHAR(512),
        ADD COLUMN IF NOT EXISTS "fcmTokenUpdatedAt"     TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS "membershipId"          VARCHAR(80)
    `);

    // ── 4. households — missing columns ──────────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE households
        ADD COLUMN IF NOT EXISTS "indigentStatus"        VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "headEmploymentStatus"  VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "employmentStatus"      VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "membershipTier"        membership_tier
    `);

    // ── 5. coverages — missing columns ───────────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE coverages
        ADD COLUMN IF NOT EXISTS "waitingPeriodEndsAt"   DATE,
        ADD COLUMN IF NOT EXISTS "claimsEligibleFrom"    DATE,
        ADD COLUMN IF NOT EXISTS "membershipType"        membership_type,
        ADD COLUMN IF NOT EXISTS "benefitPackageId"      UUID REFERENCES benefit_packages(id) ON DELETE SET NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_coverages_benefit_package ON coverages("benefitPackageId")
    `);

    // ── 6. payments — missing columns ────────────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS "currency"          VARCHAR(3)   NOT NULL DEFAULT 'ETB',
        ADD COLUMN IF NOT EXISTS "chapaReference"    VARCHAR(120)
    `);

    // ── 7. claims — missing columns ───────────────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE claims
        ADD COLUMN IF NOT EXISTS "memberCoPayment"         DECIMAL(12,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "referralCode"            VARCHAR(32),
        ADD COLUMN IF NOT EXISTS "referredFromFacilityId"  UUID REFERENCES health_facilities(id) ON DELETE SET NULL
    `);

    // ── 8. health_facilities — missing columns ────────────────────────────────

    await queryRunner.query(`
      ALTER TABLE health_facilities
        ADD COLUMN IF NOT EXISTS "serviceLevel" VARCHAR(120)
    `);
    /* serviceLevel already exists in initial migration as VARCHAR(120) — this is a no-op safety guard */

    // ── 9. referrals table (entirely missing) ─────────────────────────────────

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS referrals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        code VARCHAR(32) NOT NULL UNIQUE,
        "beneficiaryId" UUID NOT NULL REFERENCES beneficiaries(id) ON DELETE CASCADE,
        "issuedByFacilityId" UUID NOT NULL REFERENCES health_facilities(id) ON DELETE CASCADE,
        "issuedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "expiresAt" TIMESTAMPTZ NOT NULL,
        "isUsed" BOOLEAN NOT NULL DEFAULT FALSE,
        diagnosis TEXT,
        "reasonForReferral" TEXT
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_referrals_code ON referrals(code)`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_referrals_beneficiary ON referrals("beneficiaryId")`);

    // ── 10. verifications table (used by VerificationModule) ──────────────────

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS verifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "documentType" VARCHAR(80),
        "extractedName" VARCHAR(200),
        "extractedDate" VARCHAR(40),
        "isExpired" BOOLEAN NOT NULL DEFAULT FALSE,
        "confidence" DECIMAL(5,4) NOT NULL DEFAULT 0,
        "rawText" TEXT,
        "decision" VARCHAR(32) NOT NULL DEFAULT 'manual_review',
        "issues" JSONB NOT NULL DEFAULT '[]',
        "userId" UUID REFERENCES users(id) ON DELETE SET NULL
      )
    `);

    // ── 11. Add updatedAt triggers for new tables ─────────────────────────────

    for (const table of ['referrals', 'verifications']) {
      await queryRunner.query(`
        DROP TRIGGER IF EXISTS trg_${table}_updated_at ON ${table};
        CREATE TRIGGER trg_${table}_updated_at
          BEFORE UPDATE ON ${table}
          FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
      `);
    }

    // ── 12. beneficiaries — add membershipId column ───────────────────────────

    await queryRunner.query(`
      ALTER TABLE beneficiaries
        ADD COLUMN IF NOT EXISTS "membershipId" VARCHAR(80)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS verifications CASCADE`);
    await queryRunner.query(`DROP TABLE IF EXISTS referrals CASCADE`);
    // Note: enum value removal is not supported in PostgreSQL without recreating the type
    // Column drops omitted for safety — run manually if needed
  }
}
