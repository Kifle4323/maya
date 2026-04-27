/**
 * Vercel serverless entry point for NestJS.
 *
 * Limitations on Vercel vs a persistent server:
 *   - Bull/Redis job queues are disabled (no persistent process)
 *   - WebSockets are disabled (serverless is stateless)
 *   - File uploads go to /tmp (ephemeral — use GCS in production)
 *   - Cold starts add ~1-2s latency on first request
 *
 * All core API functionality (auth, CBHI, claims, payments, admin) works fine.
 */

// ── Env fallbacks — set BEFORE any imports that read process.env ──────────────
if (!process.env.DATABASE_URL && !process.env.DB_HOST) {
  process.env.DATABASE_URL =
    'postgresql://postgres.nauyjsrhykayyzqomiyx:v%21GAPf%23g%2CMaa%405r@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require';
}
if (!process.env.AUTH_JWT_SECRET) {
  process.env.AUTH_JWT_SECRET =
    'b5b35c8d9e8318f3021fc2bf320c3029d6659013a2b0b5863c9c26f92073c9bfabf7ea8320fbd49f7f1f83c6dee4af21';
}
if (!process.env.DIGITAL_CARD_SECRET) {
  process.env.DIGITAL_CARD_SECRET =
    'c2c27af2ce4cb269b3870c89a10d66f862f3d269de620231eaf7d529df44d235';
}
if (!process.env.NODE_ENV) {
  process.env.NODE_ENV = 'production';
}

import 'dotenv/config';
import '../src/instrument';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';
import { TimeoutInterceptor } from '../src/common/interceptors/timeout.interceptor';
import { CbhiLogger } from '../src/common/logger/cbhi-logger.service';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { Request, Response } from 'express';

let cachedApp: NestExpressApplication | null = null;

// ── CORS ──────────────────────────────────────────────────────────────────────

/**
 * Explicit allowlist — covers all deployed Vercel projects for this platform.
 * The *.vercel.app regex below also covers any preview deployments automatically.
 */
const EXPLICIT_ORIGINS = new Set([
  'https://member-based-cbhi.vercel.app',
  'https://members-cbhi-app.vercel.app',
  'https://cbhi-admin.vercel.app',
  'https://cbhi-facility.vercel.app',
  'http://localhost:3000',
  'http://localhost:4200',
  'http://localhost:8080',
  'http://10.0.2.2:3000',
]);

/**
 * Returns true if the given origin should receive CORS headers.
 *
 * Allowed if:
 *  1. No origin header (mobile apps, curl, server-to-server) → always allow
 *  2. Exact match in EXPLICIT_ORIGINS or CORS_ALLOWED_ORIGINS env var
 *  3. Any *.vercel.app subdomain (covers all preview + production deployments)
 *  4. localhost on any port
 */
function isOriginAllowed(origin: string | undefined): boolean {
  if (!origin) return true;

  // Explicit allowlist (fastest check)
  if (EXPLICIT_ORIGINS.has(origin)) return true;

  // Env var overrides (set in Vercel dashboard)
  const envOrigins = process.env.CORS_ALLOWED_ORIGINS;
  if (envOrigins) {
    const list = envOrigins.split(',').map((o) => o.trim()).filter(Boolean);
    if (list.includes('*')) return true;
    if (list.includes(origin)) return true;
  }

  // Any *.vercel.app deployment (preview URLs, custom project names, etc.)
  // Pattern: https://<anything-without-dots>.vercel.app
  if (/^https:\/\/[a-zA-Z0-9][a-zA-Z0-9-]*\.vercel\.app$/.test(origin)) return true;

  // localhost on any port
  if (/^http:\/\/localhost(:\d+)?$/.test(origin)) return true;

  return false;
}

/**
 * Apply CORS headers to a response.
 * Always called — even on error responses — so the browser can read the body.
 */
function applyCorsHeaders(res: Response, origin: string | undefined): void {
  const allowed = isOriginAllowed(origin);
  // Always set Vary so CDN/proxies don't cache the wrong origin
  res.setHeader('Vary', 'Origin');
  if (allowed && origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (allowed) {
    // No origin header (mobile/server) — no ACAO header needed
  }
}

// ── App factory ───────────────────────────────────────────────────────────────

async function createApp(): Promise<NestExpressApplication> {
  if (cachedApp) return cachedApp;

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: false,
    logger: new CbhiLogger(),
  });

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

  app.enableCors({
    origin: (origin, callback) => {
      if (isOriginAllowed(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: origin ${origin} not allowed`), false);
      }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
    preflightContinue: false,
    optionsSuccessStatus: 204,
  });

  app.setGlobalPrefix('api/v1');
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new TimeoutInterceptor(25_000));
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true, forbidUnknownValues: false }),
  );

  // Swagger docs
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
  SwaggerModule.setup('api/v1/docs', app, document, {
    customSiteTitle: 'Maya City CBHI API Docs',
    swaggerOptions: { persistAuthorization: true },
  });

  await app.init();
  cachedApp = app;
  return app;
}

// ── Vercel handler ────────────────────────────────────────────────────────────

export default async function handler(req: Request, res: Response) {
  const origin = req.headers['origin'] as string | undefined;

  // ── OPTIONS preflight — handle before NestJS boots (eliminates cold-start latency)
  if (req.method === 'OPTIONS') {
    if (isOriginAllowed(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin ?? '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      res.setHeader('Access-Control-Max-Age', '86400');
      res.setHeader('Vary', 'Origin');
      res.status(204).end();
    } else {
      res.status(403).json({ message: `CORS: origin ${origin} not allowed` });
    }
    return;
  }

  // ── Root path — lightweight health response, no NestJS boot needed
  if (req.url === '/' || req.url === '') {
    applyCorsHeaders(res, origin);
    res.setHeader('Content-Type', 'application/json');
    res.status(200).json({
      name: 'Maya City CBHI API',
      version: '1.0.0',
      status: 'ok',
      docs: '/api/v1/docs',
    });
    return;
  }

  // ── All other requests — boot NestJS and delegate
  try {
    const app = await createApp();
    const expressApp = app.getHttpAdapter().getInstance();
    return expressApp(req, res);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    console.error('[Vercel] Handler error:', message);

    // ALWAYS apply CORS headers on error so the browser can read the response body
    applyCorsHeaders(res, origin);
    res.setHeader('Content-Type', 'application/json');
    res.status(503).json({
      statusCode: 503,
      message: 'Service temporarily unavailable. Please try again in a moment.',
      error: process.env.NODE_ENV !== 'production' ? message : undefined,
    });

    // Reset cached app so the next request retries initialization
    // (Vercel invocations are isolated — this only matters within the same warm instance)
    cachedApp = null;
  }
}
