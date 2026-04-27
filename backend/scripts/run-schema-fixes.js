/**
 * Applies all missing schema changes directly via pg client.
 * Run: node scripts/run-schema-fixes.js
 */
require('dotenv').config();
const { Client } = require('pg');

const client = new Client({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: { rejectUnauthorized: false },
});

const fixes = [
  // ── 1. Enum additions ──────────────────────────────────────────────────────
  {
    name: 'coverage_status: add WAITING_PERIOD',
    sql: `ALTER TYPE coverage_status ADD VALUE IF NOT EXISTS 'WAITING_PERIOD'`,
  },
  {
    name: 'coverage_status: add INACTIVE',
    sql: `ALTER TYPE coverage_status ADD VALUE IF NOT EXISTS 'INACTIVE'`,
  },
  {
    name: 'claim_status: add ESCALATED',
    sql: `ALTER TYPE claim_status ADD VALUE IF NOT EXISTS 'ESCALATED'`,
  },
  {
    name: 'notification_type: add PAYMENT_CONFIRMATION',
    sql: `ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'PAYMENT_CONFIRMATION'`,
  },

  // ── 2. New enum types ──────────────────────────────────────────────────────
  {
    name: 'create membership_tier enum',
    sql: `DO $$ BEGIN CREATE TYPE membership_tier AS ENUM ('INDIGENT','LOW_INCOME','MIDDLE_INCOME','HIGH_INCOME'); EXCEPTION WHEN duplicate_object THEN NULL; END $$`,
  },
  {
    name: 'create facility_level enum',
    sql: `DO $$ BEGIN CREATE TYPE facility_level AS ENUM ('HEALTH_POST','HEALTH_CENTER','PRIMARY_HOSPITAL','GENERAL_HOSPITAL','SPECIALIZED_HOSPITAL'); EXCEPTION WHEN duplicate_object THEN NULL; END $$`,
  },

  // ── 3. users — missing columns ─────────────────────────────────────────────
  { name: 'users: tokenVersion',          sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS "tokenVersion" INT NOT NULL DEFAULT 0` },
  { name: 'users: otpFailCount',          sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS "otpFailCount" INT NOT NULL DEFAULT 0` },
  { name: 'users: otpRateLimitCount',     sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS "otpRateLimitCount" INT NOT NULL DEFAULT 0` },
  { name: 'users: otpRateLimitWindowStart', sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS "otpRateLimitWindowStart" TIMESTAMPTZ` },
  { name: 'users: membershipId',          sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS "membershipId" VARCHAR(80)` },

  // ── 4. households — missing columns ───────────────────────────────────────
  { name: 'households: indigentStatus',       sql: `ALTER TABLE households ADD COLUMN IF NOT EXISTS "indigentStatus" VARCHAR(80)` },
  { name: 'households: headEmploymentStatus', sql: `ALTER TABLE households ADD COLUMN IF NOT EXISTS "headEmploymentStatus" VARCHAR(80)` },
  { name: 'households: employmentStatus',     sql: `ALTER TABLE households ADD COLUMN IF NOT EXISTS "employmentStatus" VARCHAR(80)` },
  { name: 'households: membershipTier',       sql: `ALTER TABLE households ADD COLUMN IF NOT EXISTS "membershipTier" membership_tier` },

  // ── 5. coverages — missing columns ────────────────────────────────────────
  { name: 'coverages: waitingPeriodEndsAt', sql: `ALTER TABLE coverages ADD COLUMN IF NOT EXISTS "waitingPeriodEndsAt" DATE` },
  { name: 'coverages: claimsEligibleFrom',  sql: `ALTER TABLE coverages ADD COLUMN IF NOT EXISTS "claimsEligibleFrom" DATE` },
  { name: 'coverages: membershipType',      sql: `ALTER TABLE coverages ADD COLUMN IF NOT EXISTS "membershipType" membership_type` },
  { name: 'coverages: benefitPackageId FK', sql: `ALTER TABLE coverages ADD COLUMN IF NOT EXISTS "benefitPackageId" UUID REFERENCES benefit_packages(id) ON DELETE SET NULL` },
  { name: 'coverages: benefitPackageId index', sql: `CREATE INDEX IF NOT EXISTS idx_coverages_benefit_package ON coverages("benefitPackageId")` },

  // ── 6. payments — missing columns ─────────────────────────────────────────
  { name: 'payments: currency',        sql: `ALTER TABLE payments ADD COLUMN IF NOT EXISTS "currency" VARCHAR(3) NOT NULL DEFAULT 'ETB'` },
  { name: 'payments: chapaReference',  sql: `ALTER TABLE payments ADD COLUMN IF NOT EXISTS "chapaReference" VARCHAR(120)` },

  // ── 7. claims — missing columns ───────────────────────────────────────────
  { name: 'claims: memberCoPayment',        sql: `ALTER TABLE claims ADD COLUMN IF NOT EXISTS "memberCoPayment" DECIMAL(12,2) DEFAULT 0` },
  { name: 'claims: referralCode',           sql: `ALTER TABLE claims ADD COLUMN IF NOT EXISTS "referralCode" VARCHAR(32)` },
  { name: 'claims: referredFromFacilityId', sql: `ALTER TABLE claims ADD COLUMN IF NOT EXISTS "referredFromFacilityId" UUID REFERENCES health_facilities(id) ON DELETE SET NULL` },

  // ── 8. beneficiaries — missing columns ────────────────────────────────────
  { name: 'beneficiaries: membershipId', sql: `ALTER TABLE beneficiaries ADD COLUMN IF NOT EXISTS "membershipId" VARCHAR(80)` },

  // ── 9. referrals table ────────────────────────────────────────────────────
  {
    name: 'create referrals table',
    sql: `
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
    `,
  },
  { name: 'referrals: code index',        sql: `CREATE INDEX IF NOT EXISTS idx_referrals_code ON referrals(code)` },
  { name: 'referrals: beneficiary index', sql: `CREATE INDEX IF NOT EXISTS idx_referrals_beneficiary ON referrals("beneficiaryId")` },

  // ── 10. updatedAt trigger for referrals ───────────────────────────────────
  {
    name: 'referrals: updatedAt trigger',
    sql: `
      DROP TRIGGER IF EXISTS trg_referrals_updated_at ON referrals;
      CREATE TRIGGER trg_referrals_updated_at
        BEFORE UPDATE ON referrals
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
    `,
  },

  // ── 11. Record this migration ──────────────────────────────────────────────
  {
    name: 'record migration in typeorm_migrations',
    sql: `
      INSERT INTO typeorm_migrations(timestamp, name)
      VALUES (1704067200001, 'SchemaFixes1704067200001')
      ON CONFLICT DO NOTHING
    `,
  },
];

async function main() {
  await client.connect();
  console.log('✓ Connected to database\n');

  let passed = 0;
  let failed = 0;

  for (const fix of fixes) {
    try {
      await client.query(fix.sql);
      console.log(`  ✓ ${fix.name}`);
      passed++;
    } catch (e) {
      console.error(`  ✗ ${fix.name}: ${e.message}`);
      failed++;
    }
  }

  console.log(`\n${passed} passed, ${failed} failed`);

  // Verify key columns now exist
  console.log('\n── Verification ──────────────────────────────────────────────');
  const checks = [
    { table: 'users', col: 'tokenVersion' },
    { table: 'coverages', col: 'claimsEligibleFrom' },
    { table: 'coverages', col: 'benefitPackageId' },
    { table: 'payments', col: 'currency' },
    { table: 'claims', col: 'memberCoPayment' },
  ];

  for (const { table, col } of checks) {
    const r = await client.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name=$1 AND column_name=$2`,
      [table, col]
    );
    const exists = r.rows.length > 0;
    console.log(`  ${exists ? '✓' : '✗'} ${table}.${col}`);
  }

  const refTable = await client.query(
    `SELECT table_name FROM information_schema.tables WHERE table_name='referrals'`
  );
  console.log(`  ${refTable.rows.length > 0 ? '✓' : '✗'} referrals table`);

  await client.end();
  if (failed > 0) process.exit(1);
}

main().catch(e => {
  console.error('FATAL:', e.message);
  process.exit(1);
});
