import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * AddBeneficiaryPhoneNumber — add phoneNumber column to beneficiaries table.
 *
 * Phone numbers were previously only stored on the linked User account,
 * which meant beneficiaries without a user account (e.g. CHILD) lost their
 * phone number. This column ensures phone is always persisted on the
 * beneficiary record itself.
 */
export class AddBeneficiaryPhoneNumber1747000000000
  implements MigrationInterface
{
  name = 'AddBeneficiaryPhoneNumber1747000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "beneficiaries" ADD COLUMN IF NOT EXISTS "phoneNumber" character varying(32)`,
    );

    // Backfill: copy phone numbers from linked user accounts
    await queryRunner.query(`
      UPDATE "beneficiaries" b
      SET "phoneNumber" = u."phoneNumber"
      FROM "users" u
      WHERE b."userAccountId" = u.id
        AND u."phoneNumber" IS NOT NULL
        AND b."phoneNumber" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "beneficiaries" DROP COLUMN IF EXISTS "phoneNumber"`,
    );
  }
}
