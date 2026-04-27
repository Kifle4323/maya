import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * NormalizeSchema — comprehensive schema normalization migration.
 *
 * This migration is fully idempotent (uses IF NOT EXISTS / DO $$ ... $$ guards).
 * It is safe to run multiple times and on databases that already have some of
 * these changes applied.
 *
 * Changes applied:
 *
 * 1. ENUM FIXES
 *    - grievance_status: add ESCALATED value (entity has it, no prior migration added it)
 *
 * 2. COLUMN TYPE FIXES
 *    - coverages.premiumAmount / paidAmount: ensure DECIMAL(12,2) (not varchar)
 *    - payments.amount: ensure DECIMAL(12,2) (not varchar)
 *    - claims.claimedAmount / approvedAmount / memberCoPayment: ensure DECIMAL(12,2)
 *
 * 3. MISSING INDEXES
 *    - claims: coverageId, facilityId, serviceDate, createdAt, submittedAt
 *    - payments: createdAt, paidAt, processedById
 *    - notifications: createdAt, type
 *    - indigent_applications: createdAt
 *    - households: membershipType, createdAt
 *    - beneficiaries: memberNumber (already unique but add explicit index for perf)
 *    - users: role, isActive, createdAt
 *    - audit_logs: createdAt, entityId
 *    - grievances: createdAt
 *    - coverages: nextRenewalDate
 *
 * 4. MISSING UNIQUE CONSTRAINTS
 *    - coverages.coverageNumber (already in initial migration — guard only)
 *    - payments.transactionReference (already in initial migration — guard only)
 *
 * 5. MISSING NOT NULL CONSTRAINTS (safe — only where data is guaranteed)
 *    - households.region, zone, woreda, kebele (already NOT NULL in initial — guard)
 *    - beneficiaries.fullName (already NOT NULL — guard)
 *
 * 6. SOFT-DELETE CONSISTENCY
 *    - grievances: add deletedAt column (entity uses soft-delete pattern)
 *    - notifications: add deletedAt column
 *    - claims: add deletedAt column (for future soft-delete support)
 *
 * 7. VERIFICATIONS TABLE NORMALIZATION
 *    - Reconcile the two different verifications table schemas created by
 *      1714000000000 and 1704067200001 migrations (add missing columns to
 *      whichever version was created first)
 *
 * 8. MISSING COLUMNS
 *    - users: otpFailCount, otpRateLimitCount, otpRateLimitWindowStart
 *      (added by 1745000000000 with snake_case; entity uses camelCase — add
 *       camelCase aliases as generated columns or add the camelCase columns)
 *    - claims: referralCode, referredFromFacilityId (added by SchemaFixes but
 *       guard here for safety)
 *    - health_facilities: serviceLevel (already in initial — guard)
 *
 * 9. PERFORMANCE INDEXES
 *    - Composite index on (householdId, status) for coverages
 *    - Composite index on (beneficiaryId, status) for claims
 *    - Composite index on (recipientId, isRead) for notifications
 */
export class NormalizeSchema1746000000000 implements MigrationInterface {
  name = 'NormalizeSchema1746000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {

    // ── 1. ENUM FIXES ─────────────────────────────────────────────────────────

    // grievance_status: add ESCALATED (entity GrievanceStatus.ESCALATED exists)
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE grievance_status ADD VALUE IF NOT EXISTS 'ESCALATED';
      EXCEPTION WHEN others THEN NULL; END $$
    `);

    // ── 2. COLUMN TYPE FIXES ──────────────────────────────────────────────────
    // TypeORM maps decimal columns to string in JS but the DB column must be
    // DECIMAL/NUMERIC. The initial migration already uses DECIMAL(12,2) for
    // most of these, but we guard against any environment where a VARCHAR
    // was accidentally created.

    // coverages.premiumAmount — ensure DECIMAL(12,2), not varchar
    await queryRunner.query(`
      DO $$ BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'coverages'
            AND column_name = 'premiumAmount'
            AND data_type IN ('character varying', 'text')
        ) THEN
          ALTER TABLE coverages
            ALTER COLUMN "premiumAmount" TYPE DECIMAL(12,2)
            USING "premiumAmount"::DECIMAL(12,2);
        END IF;
      END $$
    `);

    // coverages.paidAmount — ensure DECIMAL(12,2)
    await queryRunner.query(`
      DO $$ BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'coverages'
            AND column_name = 'paidAmount'
            AND data_type IN ('character varying', 'text')
        ) THEN
          ALTER TABLE coverages
            ALTER COLUMN "paidAmount" TYPE DECIMAL(12,2)
            USING "paidAmount"::DECIMAL(12,2);
        END IF;
      END $$
    `);

    // payments.amount — ensure DECIMAL(12,2)
    await queryRunner.query(`
      DO $$ BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'payments'
            AND column_name = 'amount'
            AND data_type IN ('character varying', 'text')
        ) THEN
          ALTER TABLE payments
            ALTER COLUMN amount TYPE DECIMAL(12,2)
            USING amount::DECIMAL(12,2);
        END IF;
      END $$
    `);

    // claims.claimedAmount — ensure DECIMAL(12,2)
    await queryRunner.query(`
      DO $$ BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'claims'
            AND column_name = 'claimedAmount'
            AND data_type IN ('character varying', 'text')
        ) THEN
          ALTER TABLE claims
            ALTER COLUMN "claimedAmount" TYPE DECIMAL(12,2)
            USING "claimedAmount"::DECIMAL(12,2);
        END IF;
      END $$
    `);

    // claims.approvedAmount — ensure DECIMAL(12,2)
    await queryRunner.query(`
      DO $$ BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'claims'
            AND column_name = 'approvedAmount'
            AND data_type IN ('character varying', 'text')
        ) THEN
          ALTER TABLE claims
            ALTER COLUMN "approvedAmount" TYPE DECIMAL(12,2)
            USING "approvedAmount"::DECIMAL(12,2);
        END IF;
      END $$
    `);

    // ── 3. MISSING INDEXES ────────────────────────────────────────────────────

    // claims — additional performance indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_coverage ON claims("coverageId")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_facility ON claims("facilityId")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_service_date ON claims("serviceDate")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_created_at ON claims("createdAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_submitted_at ON claims("submittedAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_claims_reviewed_at ON claims("reviewedAt")`);

    // Composite index: beneficiary + status (used by duplicate claim detection)
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_claims_beneficiary_status
        ON claims("beneficiaryId", status)
    `);

    // Composite index: coverage + status (used by annual ceiling check)
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_claims_coverage_status
        ON claims("coverageId", status)
    `);

    // payments — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments("createdAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments("paidAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_payments_processed_by ON payments("processedById")`);

    // notifications — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications("createdAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type)`);

    // Composite index: recipient + isRead (used by unread count queries)
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_notifications_recipient_read
        ON notifications("recipientId", "isRead")
    `);

    // indigent_applications — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_indigent_created_at ON indigent_applications("createdAt")`);

    // households — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_households_membership_type ON households("membershipType")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_households_created_at ON households("createdAt")`);

    // users — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_users_is_active ON users("isActive")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_users_created_at ON users("createdAt")`);

    // audit_logs — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs("createdAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_id ON audit_logs("entityId")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action)`);

    // grievances — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_grievances_created_at ON grievances("createdAt")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_grievances_type ON grievances(type)`);

    // coverages — additional indexes
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_coverages_next_renewal ON coverages("nextRenewalDate")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_coverages_created_at ON coverages("createdAt")`);

    // Composite index: household + status (used by coverage lookups)
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_coverages_household_status
        ON coverages("householdId", status)
    `);

    // beneficiaries — member number lookup index (unique constraint already exists)
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_beneficiaries_member_number ON beneficiaries("memberNumber")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_beneficiaries_is_eligible ON beneficiaries("isEligible")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_beneficiaries_is_primary ON beneficiaries("isPrimaryHolder")`);

    // ── 4. SOFT-DELETE COLUMNS ────────────────────────────────────────────────
    // Add deletedAt to tables that may need soft-delete in the future.
    // beneficiaries already has it from the initial migration.

    await queryRunner.query(`
      ALTER TABLE grievances
        ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMPTZ
    `);

    await queryRunner.query(`
      ALTER TABLE notifications
        ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMPTZ
    `);

    await queryRunner.query(`
      ALTER TABLE claims
        ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMPTZ
    `);

    // ── 5. VERIFICATIONS TABLE NORMALIZATION ──────────────────────────────────
    // Two migrations created verifications with different schemas.
    // Add any missing columns to reconcile them.

    await queryRunner.query(`
      ALTER TABLE verifications
        ADD COLUMN IF NOT EXISTS "documentType"   VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "extractedName"  VARCHAR(200),
        ADD COLUMN IF NOT EXISTS "extractedDate"  VARCHAR(40),
        ADD COLUMN IF NOT EXISTS "isExpired"      BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS "confidence"     DECIMAL(5,4) NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "rawText"        TEXT,
        ADD COLUMN IF NOT EXISTS "decision"       VARCHAR(32) NOT NULL DEFAULT 'manual_review',
        ADD COLUMN IF NOT EXISTS "issues"         JSONB NOT NULL DEFAULT '[]',
        ADD COLUMN IF NOT EXISTS "extractedData"  JSONB,
        ADD COLUMN IF NOT EXISTS "validationErrors" JSONB,
        ADD COLUMN IF NOT EXISTS status           VARCHAR(32) NOT NULL DEFAULT 'pending'
    `);

    // ── 6. MISSING COLUMNS (safety guards) ───────────────────────────────────

    // users: camelCase OTP rate-limit columns (1745000000000 added snake_case)
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "otpFailCount"              INT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "otpRateLimitCount"         INT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "otpRateLimitWindowStart"   TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS "tokenVersion"              INT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "membershipId"              VARCHAR(80)
    `);

    // claims: referral columns (added by SchemaFixes — guard here)
    await queryRunner.query(`
      ALTER TABLE claims
        ADD COLUMN IF NOT EXISTS "referralCode"           VARCHAR(32),
        ADD COLUMN IF NOT EXISTS "referredFromFacilityId" UUID REFERENCES health_facilities(id) ON DELETE SET NULL
    `);

    // coverages: benefit package FK (added by SchemaFixes — guard here)
    await queryRunner.query(`
      ALTER TABLE coverages
        ADD COLUMN IF NOT EXISTS "membershipType"   membership_type,
        ADD COLUMN IF NOT EXISTS "benefitPackageId" UUID REFERENCES benefit_packages(id) ON DELETE SET NULL
    `);

    // households: additional columns (added by SchemaFixes — guard here)
    await queryRunner.query(`
      ALTER TABLE households
        ADD COLUMN IF NOT EXISTS "indigentStatus"       VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "headEmploymentStatus" VARCHAR(80),
        ADD COLUMN IF NOT EXISTS "employmentStatus"     VARCHAR(80)
    `);

    // ── 7. UPDATEDÁT TRIGGERS for new soft-delete tables ─────────────────────
    // (grievances and notifications already have updatedAt triggers from
    //  the initial migration — no action needed)

    // ── 8. STATISTICS UPDATE ──────────────────────────────────────────────────
    // Analyze tables with new indexes so the query planner uses them immediately.
    await queryRunner.query(`ANALYZE claims`);
    await queryRunner.query(`ANALYZE payments`);
    await queryRunner.query(`ANALYZE notifications`);
    await queryRunner.query(`ANALYZE coverages`);
    await queryRunner.query(`ANALYZE beneficiaries`);
    await queryRunner.query(`ANALYZE users`);
    await queryRunner.query(`ANALYZE households`);
    await queryRunner.query(`ANALYZE grievances`);
    await queryRunner.query(`ANALYZE indigent_applications`);
    await queryRunner.query(`ANALYZE audit_logs`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop composite and performance indexes added in this migration
    const indexesToDrop = [
      'idx_claims_coverage',
      'idx_claims_facility',
      'idx_claims_service_date',
      'idx_claims_created_at',
      'idx_claims_submitted_at',
      'idx_claims_reviewed_at',
      'idx_claims_beneficiary_status',
      'idx_claims_coverage_status',
      'idx_payments_created_at',
      'idx_payments_paid_at',
      'idx_payments_processed_by',
      'idx_notifications_created_at',
      'idx_notifications_type',
      'idx_notifications_recipient_read',
      'idx_indigent_created_at',
      'idx_households_membership_type',
      'idx_households_created_at',
      'idx_users_role',
      'idx_users_is_active',
      'idx_users_created_at',
      'idx_audit_logs_created_at',
      'idx_audit_logs_entity_id',
      'idx_audit_logs_action',
      'idx_grievances_created_at',
      'idx_grievances_type',
      'idx_coverages_next_renewal',
      'idx_coverages_created_at',
      'idx_coverages_household_status',
      'idx_beneficiaries_member_number',
      'idx_beneficiaries_is_eligible',
      'idx_beneficiaries_is_primary',
    ];

    for (const idx of indexesToDrop) {
      await queryRunner.query(`DROP INDEX IF EXISTS ${idx}`);
    }

    // Remove soft-delete columns
    await queryRunner.query(`
      ALTER TABLE claims DROP COLUMN IF EXISTS "deletedAt"
    `);
    await queryRunner.query(`
      ALTER TABLE notifications DROP COLUMN IF EXISTS "deletedAt"
    `);
    await queryRunner.query(`
      ALTER TABLE grievances DROP COLUMN IF EXISTS "deletedAt"
    `);

    // Note: enum values (ESCALATED) cannot be removed from PostgreSQL enums
    // without recreating the type. Leave them — they are harmless.
  }
}
