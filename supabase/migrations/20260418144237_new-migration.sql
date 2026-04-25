-- ============================================================
-- CBHI — Missing Tables Migration
-- Adds: referrals, passkey_credentials, verifications
-- These entities exist in TypeORM but were missing from the
-- initial Supabase migration.
-- ============================================================

-- ── TABLE: referrals ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referrals (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "createdAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  code                  VARCHAR(32) NOT NULL UNIQUE,
  "issuedAt"            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "expiresAt"           TIMESTAMPTZ NOT NULL,
  "isUsed"              BOOLEAN NOT NULL DEFAULT FALSE,
  diagnosis             TEXT,
  "reasonForReferral"   TEXT,
  "beneficiaryId"       UUID NOT NULL REFERENCES beneficiaries(id) ON DELETE CASCADE,
  "issuedByFacilityId"  UUID NOT NULL REFERENCES health_facilities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_referrals_code ON referrals(code);
CREATE INDEX IF NOT EXISTS idx_referrals_beneficiary ON referrals("beneficiaryId");
CREATE INDEX IF NOT EXISTS idx_referrals_facility ON referrals("issuedByFacilityId");
CREATE INDEX IF NOT EXISTS idx_referrals_is_used ON referrals("isUsed");

-- ── TABLE: passkey_credentials ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS passkey_credentials (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "createdAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "credentialId"    VARCHAR(512) NOT NULL,
  "publicKey"       TEXT NOT NULL,
  "signCount"       BIGINT NOT NULL DEFAULT 0,
  "rpId"            VARCHAR(255) NOT NULL,
  "deviceName"      VARCHAR(255),
  "lastUsedAt"      TIMESTAMPTZ,
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_passkey_cred_user ON passkey_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_passkey_cred_id ON passkey_credentials("credentialId");

-- ── TABLE: verifications ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS verifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "createdAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "userId"            VARCHAR(36),
  "documentType"      VARCHAR(50) NOT NULL,
  "extractedName"     VARCHAR(255),
  "extractedId"       VARCHAR(255),
  "expiryDate"        DATE,
  "matchScore"        FLOAT NOT NULL DEFAULT 0,
  "confidenceScore"   FLOAT NOT NULL DEFAULT 0,
  status              VARCHAR(20) NOT NULL,
  "rawText"           TEXT,
  "fileUrl"           VARCHAR(500),
  reasons             JSONB NOT NULL DEFAULT '[]',
  "isDemo"            BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_verifications_user ON verifications("userId");
CREATE INDEX IF NOT EXISTS idx_verifications_status ON verifications(status);

-- ── Apply updatedAt triggers ─────────────────────────────────────────────────
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['referrals', 'passkey_credentials', 'verifications']
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%s_updated_at
       BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()',
      t, t
    );
  END LOOP;
END;
$$;
