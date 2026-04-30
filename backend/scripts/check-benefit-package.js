const { Client } = require('pg');

async function main() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || '8123',
    database: process.env.DB_NAME || 'cbhi_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });

  await client.connect();

  // Update premiumPerMember to 1200 for active packages
  const upd = await client.query('UPDATE benefit_packages SET "premiumPerMember" = \'1200\' WHERE "isActive" = true');
  console.log('Updated', upd.rowCount, 'benefit package(s) to premiumPerMember=1200');

  const res = await client.query('SELECT id, name, "premiumPerMember", "annualCeiling", "isActive" FROM benefit_packages');
  console.log('Benefit Packages:', JSON.stringify(res.rows, null, 2));

  const cov = await client.query('SELECT id, "premiumAmount", "paidAmount", status FROM coverage ORDER BY "createdAt" DESC LIMIT 5');
  console.log('Coverage records:', JSON.stringify(cov.rows, null, 2));

  await client.end();
}

main().catch(console.error);
