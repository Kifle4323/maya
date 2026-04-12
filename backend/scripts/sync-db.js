require('dotenv').config();
const path = require('path');
const { DataSource } = require('typeorm');

async function main() {
  const dataSource = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || '0904',
    database: process.env.DB_NAME || 'cbhi_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    entities: [path.join(process.cwd(), 'dist', '**', '*.entity.js')],
    synchronize: false,
    logging: true,
  });

  await dataSource.initialize();
  await dataSource.synchronize();
  console.log('Database schema synchronized successfully.');
  await dataSource.destroy();
}

main().catch(async (error) => {
  console.error(error);
  process.exitCode = 1;
});
