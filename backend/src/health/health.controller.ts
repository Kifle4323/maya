import { Controller, Get } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Public } from '../common/decorators/public.decorator';
import { CacheService } from '../common/cache/cache.service';

@Public()
@Controller('health')
export class HealthController {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly cacheService: CacheService,
  ) {}

  @Public()
  @Get()
  async check() {
    const dbOk = await this.checkDatabase();
    const cacheOk = await this.checkCache();
    const status = dbOk ? 'ok' : 'degraded';

    return {
      status,
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
      version: process.env.npm_package_version ?? '1.0.0',
      environment: process.env.NODE_ENV ?? 'development',
      checks: {
        database: dbOk ? 'ok' : 'error',
        cache: cacheOk ? (process.env.REDIS_HOST ? 'redis' : 'in-memory') : 'error',
        sms: process.env.AT_API_KEY ? 'configured' : 'not_configured',
        vision: process.env.GOOGLE_VISION_API_KEY ? 'configured' : 'not_configured',
        storage: process.env.GCS_BUCKET ? 'gcs' : 'local',
        fcm: process.env.FCM_PROJECT_ID ? 'configured' : 'not_configured',
        chapa: process.env.CHAPA_SECRET_KEY ? 'configured' : 'demo_mode',
      },
    };
  }

  private async checkDatabase(): Promise<boolean> {
    try {
      // 5-second timeout — Vercel serverless cold starts can be slow
      await Promise.race([
        this.dataSource.query('SELECT 1'),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('DB timeout')), 5000),
        ),
      ]);
      return true;
    } catch {
      return false;
    }
  }

  private async checkCache(): Promise<boolean> {
    try {
      await this.cacheService.set('__health_check__', 1, 5000);
      const val = await this.cacheService.get<number>('__health_check__');
      return val === 1;
    } catch {
      return false;
    }
  }
}
