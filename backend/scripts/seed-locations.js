/**
 * Seed Ethiopian administrative locations (Regions → Zones → Woredas → Kebeles)
 * Run: node scripts/seed-locations.js
 *
 * Seeds the core regions and a sample of zones/woredas for Maya City (Oromia).
 * Extend this file with full national data from EHIA/CSA datasets.
 */
require('dotenv').config();
const { DataSource } = require('typeorm');
const path = require('path');

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'cbhi_db',
  entities: [path.join(__dirname, '../dist/**/*.entity.js')],
  synchronize: false,
});

const REGIONS = [
  { name: 'Oromia', nameAmharic: 'ኦሮሚያ', code: 'OR' },
  { name: 'Amhara', nameAmharic: 'አማራ', code: 'AM' },
  { name: 'Tigray', nameAmharic: 'ትግራይ', code: 'TI' },
  { name: 'SNNPR', nameAmharic: 'ደቡብ ብሔሮች', code: 'SN' },
  { name: 'Somali', nameAmharic: 'ሶማሌ', code: 'SO' },
  { name: 'Afar', nameAmharic: 'አፋር', code: 'AF' },
  { name: 'Benishangul-Gumuz', nameAmharic: 'ቤኒሻንጉል-ጉሙዝ', code: 'BG' },
  { name: 'Gambela', nameAmharic: 'ጋምቤላ', code: 'GA' },
  { name: 'Harari', nameAmharic: 'ሐረሪ', code: 'HA' },
  { name: 'Dire Dawa', nameAmharic: 'ድሬ ዳዋ', code: 'DD' },
  { name: 'Addis Ababa', nameAmharic: 'አዲስ አበባ', code: 'AA' },
  { name: 'Sidama', nameAmharic: 'ሲዳማ', code: 'SI' },
  { name: 'South West Ethiopia', nameAmharic: 'ደቡብ ምዕራብ ኢትዮጵያ', code: 'SW' },
];

// Sample zones for Oromia (East Hararghe — where Maya City is)
const OROMIA_ZONES = [
  { name: 'East Hararghe', nameAmharic: 'ምስራቅ ሐረርጌ', code: 'OR-EH' },
  { name: 'West Hararghe', nameAmharic: 'ምዕራብ ሐረርጌ', code: 'OR-WH' },
  { name: 'Arsi', nameAmharic: 'አርሲ', code: 'OR-AR' },
  { name: 'Bale', nameAmharic: 'ባሌ', code: 'OR-BA' },
  { name: 'Borena', nameAmharic: 'ቦረና', code: 'OR-BO' },
  { name: 'Guji', nameAmharic: 'ጉጂ', code: 'OR-GU' },
  { name: 'Jimma', nameAmharic: 'ጅማ', code: 'OR-JI' },
  { name: 'West Shewa', nameAmharic: 'ምዕራብ ሸዋ', code: 'OR-WS' },
  { name: 'North Shewa', nameAmharic: 'ሰሜን ሸዋ', code: 'OR-NS' },
  { name: 'East Shewa', nameAmharic: 'ምስራቅ ሸዋ', code: 'OR-ES' },
];

// Sample woredas for East Hararghe
const EAST_HARARGHE_WOREDAS = [
  { name: 'Maya City', nameAmharic: 'ማያ ከተማ', code: 'OR-EH-MC' },
  { name: 'Harar', nameAmharic: 'ሐረር', code: 'OR-EH-HA' },
  { name: 'Dire Dawa Rural', nameAmharic: 'ድሬ ዳዋ ገጠር', code: 'OR-EH-DD' },
  { name: 'Babile', nameAmharic: 'ባቢሌ', code: 'OR-EH-BB' },
  { name: 'Gursum', nameAmharic: 'ጉርሱም', code: 'OR-EH-GU' },
  { name: 'Jarso', nameAmharic: 'ጃርሶ', code: 'OR-EH-JA' },
  { name: 'Kombolcha', nameAmharic: 'ቆምቦልቻ', code: 'OR-EH-KO' },
  { name: 'Chinaksen', nameAmharic: 'ቺናክሰን', code: 'OR-EH-CH' },
];

// Sample kebeles for Maya City
const MAYA_CITY_KEBELES = [
  { name: 'Kebele 01', nameAmharic: 'ቀበሌ 01', code: 'OR-EH-MC-01' },
  { name: 'Kebele 02', nameAmharic: 'ቀበሌ 02', code: 'OR-EH-MC-02' },
  { name: 'Kebele 03', nameAmharic: 'ቀበሌ 03', code: 'OR-EH-MC-03' },
  { name: 'Kebele 04', nameAmharic: 'ቀበሌ 04', code: 'OR-EH-MC-04' },
  { name: 'Kebele 05', nameAmharic: 'ቀበሌ 05', code: 'OR-EH-MC-05' },
  { name: 'Kebele 06', nameAmharic: 'ቀበሌ 06', code: 'OR-EH-MC-06' },
  { name: 'Kebele 07', nameAmharic: 'ቀበሌ 07', code: 'OR-EH-MC-07' },
  { name: 'Kebele 08', nameAmharic: 'ቀበሌ 08', code: 'OR-EH-MC-08' },
];

async function seed() {
  await AppDataSource.initialize();
  const repo = AppDataSource.getRepository('locations');

  console.log('Seeding locations...');

  // Seed regions
  const regionEntities = {};
  for (const region of REGIONS) {
    let existing = await repo.findOne({ where: { code: region.code } });
    if (!existing) {
      existing = await repo.save(repo.create({
        name: region.name,
        nameAmharic: region.nameAmharic,
        code: region.code,
        level: 'REGION',
        isActive: true,
      }));
      console.log(`  Created region: ${region.name}`);
    }
    regionEntities[region.code] = existing;
  }

  // Seed Oromia zones
  const oromia = regionEntities['OR'];
  const zoneEntities = {};
  for (const zone of OROMIA_ZONES) {
    let existing = await repo.findOne({ where: { code: zone.code } });
    if (!existing) {
      existing = await repo.save(repo.create({
        name: zone.name,
        nameAmharic: zone.nameAmharic,
        code: zone.code,
        level: 'ZONE',
        parent: oromia,
        isActive: true,
      }));
      console.log(`  Created zone: ${zone.name}`);
    }
    zoneEntities[zone.code] = existing;
  }

  // Seed East Hararghe woredas
  const eastHararghe = zoneEntities['OR-EH'];
  const woredaEntities = {};
  for (const woreda of EAST_HARARGHE_WOREDAS) {
    let existing = await repo.findOne({ where: { code: woreda.code } });
    if (!existing) {
      existing = await repo.save(repo.create({
        name: woreda.name,
        nameAmharic: woreda.nameAmharic,
        code: woreda.code,
        level: 'WOREDA',
        parent: eastHararghe,
        isActive: true,
      }));
      console.log(`  Created woreda: ${woreda.name}`);
    }
    woredaEntities[woreda.code] = existing;
  }

  // Seed Maya City kebeles
  const mayaCity = woredaEntities['OR-EH-MC'];
  for (const kebele of MAYA_CITY_KEBELES) {
    const existing = await repo.findOne({ where: { code: kebele.code } });
    if (!existing) {
      await repo.save(repo.create({
        name: kebele.name,
        nameAmharic: kebele.nameAmharic,
        code: kebele.code,
        level: 'KEBELE',
        parent: mayaCity,
        isActive: true,
      }));
      console.log(`  Created kebele: ${kebele.name}`);
    }
  }

  console.log('Location seeding complete!');
  await AppDataSource.destroy();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
