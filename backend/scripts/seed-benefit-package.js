/**
 * Seeds the full CBHI Standard Benefit Package into the database.
 * Run: node scripts/seed-benefit-package.js
 *
 * Safe to run multiple times — skips if a package named
 * "CBHI Standard Benefit Package" already exists.
 */
require('dotenv').config();
const { Client } = require('pg');

const PACKAGE = {
  name: 'CBHI Standard Benefit Package',
  description:
    'Comprehensive benefit package covering outpatient, inpatient, maternal/child health, and diagnostics per the Ethiopian national health package.',
  premiumPerMember: 120.0,
  annualCeiling: 10000.0,
};

const ITEMS = [
  // ── Outpatient Services (OPD) ──────────────────────────────────────────
  {
    serviceName: 'Medical Consultation',
    serviceCode: 'OPD-001',
    category: 'Outpatient (OPD)',
    maxClaimAmount: 150,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'General and specialist consultations for acute and chronic illnesses.',
  },
  {
    serviceName: 'Specialist Consultation',
    serviceCode: 'OPD-002',
    category: 'Outpatient (OPD)',
    maxClaimAmount: 300,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Referral-based specialist consultations.',
  },
  {
    serviceName: 'Essential Medicines',
    serviceCode: 'OPD-003',
    category: 'Outpatient (OPD)',
    maxClaimAmount: 200,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Prescribed drugs listed under the national essential health package.',
  },
  {
    serviceName: 'Minor Procedure',
    serviceCode: 'OPD-004',
    category: 'Outpatient (OPD)',
    maxClaimAmount: 500,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Basic surgical and medical procedures not requiring overnight stay.',
  },

  // ── Inpatient Services (IPD) ───────────────────────────────────────────
  {
    serviceName: 'Hospitalization (per day)',
    serviceCode: 'IPD-001',
    category: 'Inpatient (IPD)',
    maxClaimAmount: 800,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Ward bed stays and nursing care.',
  },
  {
    serviceName: 'Major Surgery',
    serviceCode: 'IPD-002',
    category: 'Inpatient (IPD)',
    maxClaimAmount: 5000,
    coPaymentPercent: 0,
    maxClaimsPerYear: 2,
    notes: 'Essential major surgical interventions.',
  },
  {
    serviceName: 'Minor Surgery',
    serviceCode: 'IPD-003',
    category: 'Inpatient (IPD)',
    maxClaimAmount: 1500,
    coPaymentPercent: 0,
    maxClaimsPerYear: 4,
    notes: 'Minor surgical interventions requiring admission.',
  },
  {
    serviceName: 'Intensive Care (ICU, per day)',
    serviceCode: 'IPD-004',
    category: 'Inpatient (IPD)',
    maxClaimAmount: 2000,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Intensive care and specialized inpatient monitoring.',
  },

  // ── Maternal, Neonatal & Child Health (MNCH) ───────────────────────────
  {
    serviceName: 'Antenatal Care (ANC)',
    serviceCode: 'MNCH-001',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 200,
    coPaymentPercent: 0,
    maxClaimsPerYear: 8,
    notes: 'Antenatal care visits per pregnancy.',
  },
  {
    serviceName: 'Normal Delivery',
    serviceCode: 'MNCH-002',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 1000,
    coPaymentPercent: 0,
    maxClaimsPerYear: 1,
    notes: 'Skilled delivery at health facility.',
  },
  {
    serviceName: 'Caesarean Section (C-Section)',
    serviceCode: 'MNCH-003',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 4000,
    coPaymentPercent: 0,
    maxClaimsPerYear: 1,
    notes: 'Emergency and elective C-sections.',
  },
  {
    serviceName: 'Postnatal Care (PNC)',
    serviceCode: 'MNCH-004',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 200,
    coPaymentPercent: 0,
    maxClaimsPerYear: 3,
    notes: 'Postnatal care visits.',
  },
  {
    serviceName: 'IMNCI / Child Illness Treatment',
    serviceCode: 'MNCH-005',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 300,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Integrated Management of Neonatal and Childhood Illnesses — pneumonia, diarrhea, malnutrition.',
  },
  {
    serviceName: 'Immunization',
    serviceCode: 'MNCH-006',
    category: 'Maternal & Child Health (MNCH)',
    maxClaimAmount: 100,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Routine childhood immunization per national schedule.',
  },

  // ── Diagnostic & Laboratory ────────────────────────────────────────────
  {
    serviceName: 'Blood Chemistry (Hgb, Glucose)',
    serviceCode: 'LAB-001',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 120,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Hemoglobin, blood glucose, and basic blood chemistry.',
  },
  {
    serviceName: 'Microbiology (Stool, Urine)',
    serviceCode: 'LAB-002',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 100,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Stool and urine microscopy and culture.',
  },
  {
    serviceName: 'HIV Screening',
    serviceCode: 'LAB-003',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 80,
    coPaymentPercent: 0,
    maxClaimsPerYear: 2,
    notes: 'HIV rapid diagnostic test.',
  },
  {
    serviceName: 'Malaria Test (RDT/Smear)',
    serviceCode: 'LAB-004',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 60,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Malaria rapid diagnostic test or blood smear.',
  },
  {
    serviceName: 'TB Sputum Test',
    serviceCode: 'LAB-005',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 80,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Tuberculosis sputum smear microscopy.',
  },
  {
    serviceName: 'X-Ray',
    serviceCode: 'LAB-006',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 300,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Plain radiography (chest, limbs, abdomen).',
  },
  {
    serviceName: 'Ultrasound',
    serviceCode: 'LAB-007',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 500,
    coPaymentPercent: 0,
    maxClaimsPerYear: 0,
    notes: 'Abdominal, obstetric, and pelvic ultrasound.',
  },
  {
    serviceName: 'CT Scan',
    serviceCode: 'LAB-008',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 2500,
    coPaymentPercent: 0,
    maxClaimsPerYear: 2,
    notes: 'Computed tomography — where specialized facilities permit.',
  },
  {
    serviceName: 'MRI',
    serviceCode: 'LAB-009',
    category: 'Diagnostics & Laboratory',
    maxClaimAmount: 4000,
    coPaymentPercent: 0,
    maxClaimsPerYear: 1,
    notes: 'Magnetic resonance imaging — where specialized facilities permit.',
  },
];

async function seed() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'cbhi_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });

  try {
    await client.connect();
    console.log('[seed] Connected to database.');

    // Check if package already exists
    const existing = await client.query(
      `SELECT id FROM benefit_packages WHERE name = $1 LIMIT 1`,
      [PACKAGE.name],
    );

    if (existing.rows.length > 0) {
      console.log(`[seed] Package "${PACKAGE.name}" already exists — skipping.`);
      console.log(`[seed] Package ID: ${existing.rows[0].id}`);
      return;
    }

    // Insert package
    const pkgRes = await client.query(
      `INSERT INTO benefit_packages (name, description, "premiumPerMember", "annualCeiling", "isActive")
       VALUES ($1, $2, $3, $4, true) RETURNING id`,
      [PACKAGE.name, PACKAGE.description, PACKAGE.premiumPerMember, PACKAGE.annualCeiling],
    );
    const packageId = pkgRes.rows[0].id;
    console.log(`[seed] Created package: ${PACKAGE.name} (${packageId})`);

    // Insert items
    for (const item of ITEMS) {
      await client.query(
        `INSERT INTO benefit_items
           ("serviceName", "serviceCode", category, "maxClaimAmount",
            "coPaymentPercent", "maxClaimsPerYear", "isCovered", notes, "packageId")
         VALUES ($1, $2, $3, $4, $5, $6, true, $7, $8)`,
        [
          item.serviceName,
          item.serviceCode,
          item.category,
          item.maxClaimAmount,
          item.coPaymentPercent,
          item.maxClaimsPerYear,
          item.notes,
          packageId,
        ],
      );
      console.log(`  + ${item.serviceCode}  ${item.serviceName}`);
    }

    console.log(`\n[seed] Done — ${ITEMS.length} benefit items seeded.`);
  } catch (err) {
    console.error('[seed] Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

seed();

