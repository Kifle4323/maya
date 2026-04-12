import { Module } from '@nestjs/common';
import { DemoModule } from '../demo/demo.module';
import { VisionService } from './vision.service';
import { VisionController } from './vision.controller';

@Module({
  imports: [DemoModule],
  providers: [VisionService],
  controllers: [VisionController],
  exports: [VisionService],
})
export class VisionModule {}
