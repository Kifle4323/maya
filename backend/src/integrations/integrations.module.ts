import { Module } from '@nestjs/common';
import { FaydaService } from './fayda.service';
import { OpenImisService } from './openimis.service';

@Module({
  providers: [FaydaService, OpenImisService],
  exports: [FaydaService, OpenImisService],
})
export class IntegrationsModule {}
