import { join } from 'path';
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { BullMQModule } from '@nestjs/bullmq';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AdminModule } from './admin/admin.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuditModule } from './audit/audit.module';
import { AuthModule } from './auth/auth.module';
import { BenefitPackageModule } from './benefit-packages/benefit-package.module';
import { CbhiModule } from './cbhi/cbhi.module';
import { CacheModule } from './common/cache/cache.module';
import { DemoModule } from './demo/demo.module';
import { GrievanceModule } from './grievances/grievance.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { RequestLoggerMiddleware } from './common/middleware/request-logger.middleware';
import { FacilityModule } from './facility/facility.module';
import { HealthFacilitiesModule } from './health-facilities/health-facilities.module';
import { HealthModule } from './health/health.module';
import { IndigentModule } from './indigent/indigent.module';
import { IntegrationsModule } from './integrations/integrations.module';
import { JobsModule } from './jobs/jobs.module';
import { LocationsModule } from './locations/locations.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PaymentGatewayModule } from './payment-gateway/payment-gateway.module';
import { SmsModule } from './sms/sms.module';
import { StorageModule } from './storage/storage.module';
import { VisionModule } from './vision/vision.module';

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Parse a Postgres connection URL, properly decoding URL-encoded characters
 * in the password (e.g. %23 → #, %40 → @, %2C → ,).
 * TypeORM's built-in URL parser does NOT decode these, causing auth failures.
 */
function parseDbUrl(rawUrl: string) {
  const u = new URL(rawUrl);
  return {
    host: u.hostname,
    port: u.port ? Number(u.port) : 5432,
    username: decodeURIComponent(u.username),
    password: decodeURIComponent(u.password),
    database: u.pathname.replace(/^\//, ''),
    ssl:
      u.searchParams.get('sslmode') === 'require' ||
      u.searchParams.get('sslmode') === 'verify-ca',
    isPooler: Number(u.port) === 6543, // Supabase transaction pooler
  };
}

function buildTypeOrmConfig(): TypeOrmModuleOptions {
  const databaseUrl = process.env.DATABASE_URL;

  const base: Partial<TypeOrmModuleOptions> = {
    type: 'postgres',
    autoLoadEntities: true,
    entities: [join(__dirname, '**', '*.entity.{js,ts}')],
    // NEVER synchronize in production — use migrations
    // Only auto-sync in development when explicitly enabled
    synchronize:
      process.env.TYPEORM_SYNCHRONIZE === 'true' &&
      process.env.NODE_ENV !== 'production',
    logging: process.env.TYPEORM_LOGGING === 'true',
  };

  if (databaseUrl) {
    const conn = parseDbUrl(databaseUrl);
    return {
      ...base,
      type: 'postgres',
      host: conn.host,
      port: conn.port,
      username: conn.username,
      password: conn.password,
      database: conn.database,
      ssl: conn.ssl ? { rejectUnauthorized: false } : false,
      extra: {
        max: Number(process.env.DB_POOL_MAX ?? conn.isPooler ? 10 : 20),
        min: Number(process.env.DB_POOL_MIN ?? 2),
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 10_000,
        // pgBouncer transaction mode: disable prepared statements
        ...(conn.isPooler ? { statement_timeout: 30000 } : {}),
      },
    } as TypeOrmModuleOptions;
  }

  return {
    ...base,
    type: 'postgres',
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    username: process.env.DB_USERNAME ?? 'postgres',
    password: process.env.DB_PASSWORD ?? 'postgres',
    database: process.env.DB_NAME ?? 'cbhi_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    extra: {
      max: Number(process.env.DB_POOL_MAX ?? 20),
      min: Number(process.env.DB_POOL_MIN ?? 2),
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
    },
  } as TypeOrmModuleOptions;
}

// ── Module ────────────────────────────────────────────────────────────────────

const redisHost = process.env.REDIS_HOST ?? 'localhost';
const redisPort = Number(process.env.REDIS_PORT ?? 6379);
const redisPassword = process.env.REDIS_PASSWORD || undefined;
const redisEnabled = !!process.env.REDIS_HOST;

@Module({
  imports: [
    // ── Rate limiting ──────────────────────────────────────────────────────
    ThrottlerModule.forRoot([
      { name: 'default', ttl: 60_000, limit: 120 },  // 120 req/min
      { name: 'otp', ttl: 600_000, limit: 10 },       // 10 OTP/10min
    ]),

    // Bull queue — only connect to Redis if REDIS_HOST is set
    // In dev without Redis, JobsModule gracefully degrades
    BullMQModule.forRoot({
      connection: {
        host: redisHost,
        port: redisPort,
        password: redisPassword,
        lazyConnect: !redisEnabled,
        enableOfflineQueue: false,
        maxRetriesPerRequest: null,
      },
    }),

    AdminModule,
    AuditModule,
    AuthModule,
    BenefitPackageModule,
    CacheModule,
    CbhiModule,
    DemoModule,
    FacilityModule,
    GrievanceModule,
    HealthFacilitiesModule,
    HealthModule,
    IndigentModule,
    IntegrationsModule,
    JobsModule,
    LocationsModule,
    NotificationsModule,
    PaymentGatewayModule,
    SmsModule,
    StorageModule,
    VisionModule,

    TypeOrmModule.forRoot(buildTypeOrmConfig()),
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestLoggerMiddleware).forRoutes('*');
  }
}
