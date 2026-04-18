  /**
 * Vercel serverless entry point for NestJS.
 * Wraps the NestJS app as an Express handler for Vercel's serverless runtime.
 *
 * Limitations on Vercel vs a persistent server:
 *   - Bull/Redis job queues are disabled (no persistent process)
 *   - WebSockets are disabled (serverless is stateless)
 *   - File uploads go to /tmp (ephemeral — use GCS in production)
 *   - Cold starts add ~1-2s latency on first request
 *
 * All core API functionality (auth, CBHI, claims, payments, admin) works fine.
 */
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
import type { Request, Response } from 'express';

let cachedApp: NestExpressApplication | null = null;

async function createApp(): Promise<NestExpressApplication> {
  if (cachedApp) return cachedApp;

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: false,
    logger: new CbhiLogger(),
  });

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

  const allowedOrigins = (
    process.env.CORS_ALLOWED_ORIGINS ??
    'https://member-based-cbhi.vercel.app'
  )
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      // Allow exact matches
      if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
        return callback(null, true);
      }
      // Allow all Vercel preview deployments for this project
      if (origin.match(/^https:\/\/member-based-cbhi.*\.vercel\.app$/)) {
        return callback(null, true);
      }
      return callback(new Error(`CORS: origin ${origin} not allowed`), false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  app.setGlobalPrefix('api/v1');
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new TimeoutInterceptor(25_000));
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true, forbidUnknownValues: false }),
  );

  await app.init();
  cachedApp = app;
  return app;
}

// Vercel serverless handler
export default async function handler(req: Request, res: Response) {
  // Root path — return API info without going through NestJS
  if (req.url === '/' || req.url === '') {
    res.setHeader('Content-Type', 'application/json');
    res.status(200).json({
      name: 'Maya City CBHI API',
      version: '1.0.0',
      status: 'ok',
      docs: '/api/v1/health',
    });
    return;
  }

  const app = await createApp();
  const expressApp = app.getHttpAdapter().getInstance();
  return expressApp(req, res);
}
