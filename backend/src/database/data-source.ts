/**
 * TypeORM DataSource for CLI migrations.
 * Usage:
 *   npx typeorm migration:generate src/database/migrations/InitialSchema -d src/database/data-source.ts
 *   npx typeorm migration:run -d src/database/data-source.ts
 *   npx typeorm migration:revert -d src/database/data-source.ts
 */
import 'dotenv/config';
import { join } from 'path';
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USERNAME ?? 'postgres',
  password: process.env.DB_PASSWORD ?? 'postgres',
  database: process.env.DB_NAME ?? 'cbhi_db',
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  entities: [join(__dirname, '..', '**', '*.entity.{js,ts}')],
  migrations: [join(__dirname, 'migrations', '*.{js,ts}')],
  synchronize: false, // NEVER true in production
  logging: process.env.TYPEORM_LOGGING === 'true',
});
