import { Controller, Get } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Public } from '../common/decorators/public.decorator';

@Controller('health')
export class HealthController {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  @Public()
  @Get()
  async check() {
    const dbOk = await this.checkDatabase();
    const status = dbOk ? 'ok' : 'degraded';

    return {
      status,
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
      version: process.env.npm_package_version ?? '1.0.0',
      environment: process.env.NODE_ENV ?? 'development',
      checks: {
        database: dbOk ? 'ok' : 'error',
        sms: process.env.AT_API_KEY ? 'configured' : 'not_configured',
        vision: process.env.GOOGLE_VISION_API_KEY ? 'configured' : 'not_configured',
        storage: process.env.GCS_BUCKET ? 'gcs' : 'local',
        fcm: process.env.FCM_PROJECT_ID ? 'configured' : 'not_configured',
      },
    };
  }

  private async checkDatabase(): Promise<boolean> {
    try {
      await this.dataSource.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }
}
