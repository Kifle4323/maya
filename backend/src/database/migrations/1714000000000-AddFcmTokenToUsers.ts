import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds fcmToken and fcmTokenUpdatedAt columns to the users table.
 * Also adds verifications table if not present (for document verification feature).
 */
export class AddFcmTokenToUsers1714000000000 implements MigrationInterface {
  name = 'AddFcmTokenToUsers1714000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Add fcmToken column if missing
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "fcmToken" VARCHAR(512),
        ADD COLUMN IF NOT EXISTS "fcmTokenUpdatedAt" TIMESTAMPTZ
    `);

    // Add WAITING_PERIOD and INACTIVE to coverage_status enum if missing
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

    // Create verifications table if not present
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS verifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "documentType" VARCHAR(80) NOT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'pending',
        confidence DECIMAL(5,4),
        "extractedData" JSONB,
        "validationErrors" JSONB,
        "userId" UUID REFERENCES users(id) ON DELETE SET NULL
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS verifications CASCADE`);
    await queryRunner.query(`
      ALTER TABLE users
        DROP COLUMN IF EXISTS "fcmToken",
        DROP COLUMN IF EXISTS "fcmTokenUpdatedAt"
    `);
  }
}
