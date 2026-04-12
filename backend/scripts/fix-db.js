/**
 * Fix database schema issues before starting the backend.
 * Run: node scripts/fix-db.js
 */
require('dotenv').config();
const { Client } = require('pg');

async function fixDb() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_NAME || 'cbhi_db',
  });

  await client.connect();
  console.log('Connected to database');

  const fixes = [
    // Drop FK constraints that reference locations table
    `ALTER TABLE IF EXISTS health_facilities DROP CONSTRAINT IF EXISTS "FK_cae9bd7c0078e739704839b29af"`,
    `ALTER TABLE IF EXISTS households DROP CONSTRAINT IF EXISTS "FK_9916ff9f5acbf9899b9116d6335"`,
    `ALTER TABLE IF EXISTS cbhi_officers DROP CONSTRAINT IF EXISTS "FK_08d0b86bf250300d391fc26d9c3"`,
    // Drop locationId columns (will be recreated by TypeORM)
    `ALTER TABLE IF EXISTS health_facilities DROP COLUMN IF EXISTS "locationId"`,
    `ALTER TABLE IF EXISTS households DROP COLUMN IF EXISTS "locationId"`,
    `ALTER TABLE IF EXISTS cbhi_officers DROP COLUMN IF EXISTS "officeLocationId"`,
    // Drop locations table (will be recreated with correct schema)
    `DROP TABLE IF EXISTS locations CASCADE`,
    // Drop indigent_applications (will be recreated with correct schema)
    `DROP TABLE IF EXISTS indigent_applications CASCADE`,
    // Drop audit_logs if it has issues
    `DROP TABLE IF EXISTS audit_logs CASCADE`,
  ];

  for (const sql of fixes) {
    try {
      await client.query(sql);
      console.log(`✓ ${sql.substring(0, 60)}...`);
    } catch (err) {
      console.log(`  Skipped (${err.message.substring(0, 60)})`);
    }
  }

  await client.end();
  console.log('\nDatabase fixes applied. You can now start the backend.');
}

fixDb().catch(err => {
  console.error('Fix failed:', err.message);
  process.exit(1);
});
