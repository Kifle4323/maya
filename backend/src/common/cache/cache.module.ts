import { Module, Global } from '@nestjs/common';
import { CacheService } from './cache.service';

@Global() // Available everywhere without importing
@Module({
  providers: [CacheService],
  exports: [CacheService],
})
export class CacheModule {}
