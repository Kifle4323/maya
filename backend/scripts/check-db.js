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

async function main() {
  await client.connect();
  console.log('✓ Connected to database');

  // Check which tables exist
  const tables = await client.query(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name
  `);
  console.log('\nTables:', tables.rows.map(r => r.table_name).join(', '));

  // Check users columns
  const userCols = await client.query(`
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
    ORDER BY ordinal_position
  `);
  console.log('\nusers columns:', userCols.rows.map(r => r.column_name).join(', '));

  // Check coverages columns
  const covCols = await client.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'coverages'
    ORDER BY ordinal_position
  `);
  console.log('\ncoverages columns:', covCols.rows.map(r => r.column_name).join(', '));

  // Check migrations table
  const migrations = await client.query(`
    SELECT name FROM migrations ORDER BY id
  `).catch(() => ({ rows: [] }));
  console.log('\nRan migrations:', migrations.rows.map(r => r.name).join(', ') || '(none)');

  // Check enum values for coverage_status
  const enumVals = await client.query(`
    SELECT enumlabel FROM pg_enum
    JOIN pg_type ON pg_enum.enumtypid = pg_type.oid
    WHERE pg_type.typname = 'coverage_status'
    ORDER BY enumsortorder
  `);
  console.log('\ncoverage_status values:', enumVals.rows.map(r => r.enumlabel).join(', '));

  await client.end();
}

main().catch(e => {
  console.error('ERROR:', e.message);
  process.exit(1);
});
