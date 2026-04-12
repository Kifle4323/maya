import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VisionModule } from '../vision/vision.module';
import { IndigentController } from './indigent.controller';
import { IndigentApplication } from './indigent.entity';
import { IndigentService } from './indigent.service';

@Module({
  imports: [TypeOrmModule.forFeature([IndigentApplication]), VisionModule],
  controllers: [IndigentController],
  providers: [IndigentService],
  exports: [IndigentService],
})
export class IndigentModule {}
