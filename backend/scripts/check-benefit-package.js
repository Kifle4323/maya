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

  // Recalculate coverage premiums: 1200 + (memberCount - 1) * 120
  const covUpdate = await client.query(`
    UPDATE coverages c
    SET "premiumAmount" = (1200 + GREATEST(h."memberCount" - 1, 0) * 120)::numeric
    FROM households h
    WHERE c."householdId" = h.id
      AND h."membershipType" = 'paying'
  `);
  console.log('Updated', covUpdate.rowCount, 'coverage record(s) with recalculated premium');

  const cov = await client.query('SELECT c.id, c."premiumAmount", c."paidAmount", c.status, h."memberCount", h."membershipType" FROM coverages c JOIN households h ON c."householdId" = h.id ORDER BY c."createdAt" DESC LIMIT 10');
  console.log('Coverage records:', JSON.stringify(cov.rows, null, 2));

  await client.end();
}

main().catch(console.error);
