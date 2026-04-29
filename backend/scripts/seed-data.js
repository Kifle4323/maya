const { Client } = require('pg');
const crypto = require('crypto');
require('dotenv').config();

function hashPassword(password) {
  const salt = crypto.createHash('sha256')
    .update(`${Date.now()}:${Math.random()}`)
    .digest('hex');
  const hash = crypto.pbkdf2Sync(password, salt, 120000, 64, 'sha512').toString(
    'hex',
  );
  return `${salt}:${hash}`;
}

async function seed() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || '8123',
    database: process.env.DB_NAME || 'cbhi_db',
  });

  try {
    await client.connect();
    console.log('Connected to database.');

    // 1. Create Location hierarchy (Region → Zone → Woreda → Kebele)
    const regionRes = await client.query(`
      INSERT INTO locations (name, code, level, "isActive") 
      VALUES ('Maya Region', 'REG-001', 'REGION', true) 
      ON CONFLICT (code) DO NOTHING 
      RETURNING id
    `);
    const regionId = regionRes.rows[0]?.id || (await client.query("SELECT id FROM locations WHERE code = 'REG-001'")).rows[0].id;

    const zoneRes = await client.query(`
      INSERT INTO locations (name, code, level, "parentId", "isActive") 
      VALUES ('Maya Zone', 'ZON-001', 'ZONE', $1, true) 
      ON CONFLICT (code) DO NOTHING 
      RETURNING id
    `, [regionId]);
    const zoneId = zoneRes.rows[0]?.id || (await client.query("SELECT id FROM locations WHERE code = 'ZON-001'")).rows[0].id;

    const woredaRes = await client.query(`
      INSERT INTO locations (name, code, level, "parentId", "isActive") 
      VALUES ('Maya Woreda', 'WOR-001', 'WOREDA', $1, true) 
      ON CONFLICT (code) DO NOTHING 
      RETURNING id
    `, [zoneId]);
    const woredaId = woredaRes.rows[0]?.id || (await client.query("SELECT id FROM locations WHERE code = 'WOR-001'")).rows[0].id;

    const kebeleRes = await client.query(`
      INSERT INTO locations (name, code, level, "parentId", "isActive") 
      VALUES ('Maya Kebele 01', 'KEB-001', 'KEBELE', $1, true) 
      ON CONFLICT (code) DO NOTHING 
      RETURNING id
    `, [woredaId]);
    const kebeleId = kebeleRes.rows[0]?.id || (await client.query("SELECT id FROM locations WHERE code = 'KEB-001'")).rows[0].id;

    const locationId = kebeleId;

    // 2. Create a Health Facility
    const facilityRes = await client.query(`
      INSERT INTO health_facilities (name, "facilityCode", "isAccredited", "locationId") 
      VALUES ('Maya Referral Hospital', 'FAC-001', true, $1) 
      ON CONFLICT ("facilityCode") DO NOTHING 
      RETURNING id
    `, [locationId]);
    const facilityId = facilityRes.rows[0]?.id || (await client.query("SELECT id FROM health_facilities WHERE \"facilityCode\" = 'FAC-001'")).rows[0].id;

    const passwordStr = 'CBHI@2026';
    const passwordHash = hashPassword(passwordStr);

    // 3. Create Admin User
    await client.query(`
      INSERT INTO users ("firstName", "lastName", email, "passwordHash", role, "isActive", "identityVerificationStatus") 
      VALUES ('System', 'Admin', 'admin@mayacity.gov.et', $1, 'SYSTEM_ADMIN', true, 'VERIFIED') 
      ON CONFLICT (email) DO NOTHING
    `, [passwordHash]);

    // 4. Create Facility Staff User
    const staffRes = await client.query(`
      INSERT INTO users ("firstName", "lastName", email, "passwordHash", role, "isActive", "identityVerificationStatus") 
      VALUES ('Abebe', 'Bikila', 'staff@mayahospital.et', $1, 'HEALTH_FACILITY_STAFF', true, 'VERIFIED') 
      ON CONFLICT (email) DO NOTHING 
      RETURNING id
    `, [passwordHash]);
    const staffUserId = staffRes.rows[0]?.id || (await client.query("SELECT id FROM users WHERE email = 'staff@mayahospital.et'")).rows[0].id;

    // 5. Create FacilityUser link
    await client.query(`
      INSERT INTO facility_users ("role", "isActive", "facilityId", "userId") 
      VALUES ('ADMIN', true, $1, $2) 
      ON CONFLICT DO NOTHING
    `, [facilityId, staffUserId]);

    console.log('\n--- Seed Data Created Succesfully ---');
    console.log('Admin Login:');
    console.log('  Identifier: admin@mayacity.gov.et');
    console.log('  Password:   ' + passwordStr);
    console.log('\nFacility Staff Login:');
    console.log('  Identifier: staff@mayahospital.et');
    console.log('  Password:   ' + passwordStr);
    console.log('-------------------------------------\n');

  } catch (err) {
    console.error('Error seeding data:', err);
  } finally {
    await client.end();
  }
}

seed();
