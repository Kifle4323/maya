// FIX MJ-8: Sentry MUST be imported before any other module
import './instrument';
import 'dotenv/config';
import { join } from 'path';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { IoAdapter } from '@nestjs/platform-socket.io';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { TimeoutInterceptor } from './common/interceptors/timeout.interceptor';
import { CbhiLogger } from './common/logger/cbhi-logger.service';

function assertRequiredEnv(): void {
  const isProduction = process.env.NODE_ENV === 'production';
  if (!isProduction) return;

  // Accept either DATABASE_URL (connection string) or individual DB_* vars
  const hasDbUrl = !!process.env.DATABASE_URL;
  const dbVars = hasDbUrl ? [] : ['DB_HOST', 'DB_USERNAME', 'DB_PASSWORD', 'DB_NAME'];

  const required: string[] = ['AUTH_JWT_SECRET', 'DIGITAL_CARD_SECRET', ...dbVars];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    console.error(`[STARTUP] Missing required environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }

  if (process.env.AUTH_JWT_SECRET === 'maya-city-cbhi-secret') {
    console.error('[STARTUP] AUTH_JWT_SECRET is using the insecure default. Set a strong secret.');
    process.exit(1);
  }
  if (process.env.DIGITAL_CARD_SECRET === 'cbhi-card') {
    console.error('[STARTUP] DIGITAL_CARD_SECRET is using the insecure default. Set a strong secret.');
    process.exit(1);
  }
}

async function bootstrap() {
  assertRequiredEnv();

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: false, // Configured explicitly below
    logger: new CbhiLogger(),
  });

  // ── Security headers ──────────────────────────────────────────────────────
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }, // Allow /uploads/ images
  }));

  // ── CORS ──────────────────────────────────────────────────────────────────
  const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? 'http://localhost:3000,http://localhost:4200')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  // Wildcard patterns (e.g. "*.vercel.app") extracted separately
  const wildcardPatterns = allowedOrigins
    .filter((o) => o.startsWith('*.'))
    .map((o) => new RegExp(`^https?://${o.slice(2).replace(/\./g, '\\.')}$`));

  const exactOrigins = allowedOrigins.filter((o) => !o.startsWith('*.'));

  app.enableCors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, Postman)
      if (!origin) return callback(null, true);
      // Exact match or wildcard '*'
      if (exactOrigins.includes(origin) || exactOrigins.includes('*')) {
        return callback(null, true);
      }
      // Wildcard pattern match (e.g. *.vercel.app)
      if (wildcardPatterns.some((re) => re.test(origin))) {
        return callback(null, true);
      }
      return callback(new Error(`CORS: origin ${origin} not allowed`), false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  app.setGlobalPrefix('api/v1');
  app.useWebSocketAdapter(new IoAdapter(app));
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads/',
  });

  // ── Global filters & pipes ────────────────────────────────────────────────
  app.useGlobalFilters(new GlobalExceptionFilter());
  // FIX QW-7: Global 30-second request timeout
  app.useGlobalInterceptors(new TimeoutInterceptor(30_000));
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidUnknownValues: false,
    }),
  );

  // ── Swagger (non-production only) ────────────────────────────────────────
  if (process.env.NODE_ENV !== 'production') {
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const { DocumentBuilder, SwaggerModule } = require('@nestjs/swagger') as typeof import('@nestjs/swagger');
      const config = new DocumentBuilder()
        .setTitle('Maya City CBHI API')
        .setDescription('Community-Based Health Insurance Digital Platform API')
        .setVersion('1.0')
        .addBearerAuth()
        .addTag('auth', 'Authentication & session management')
        .addTag('cbhi', 'Member registration & household management')
        .addTag('facility', 'Health facility staff operations')
        .addTag('admin', 'CBHI officer & admin operations')
        .addTag('indigent', 'Indigent application management')
        .addTag('vision', 'Document text extraction & validation')
        .addTag('health', 'System health checks')
        .build();
      const document = SwaggerModule.createDocument(app, config);
      SwaggerModule.setup('api/docs', app, document);
      console.log('[Bootstrap] Swagger docs available at /api/docs');
    } catch {
      console.log('[Bootstrap] @nestjs/swagger not installed — skipping docs. Run: npm install @nestjs/swagger');
    }
  }

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
  console.log(`[Bootstrap] Server running on port ${port} (${process.env.NODE_ENV ?? 'development'})`);
}
void bootstrap();
