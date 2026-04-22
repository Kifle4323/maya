import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DemoModule } from '../demo/demo.module';
import { VisionModule } from '../vision/vision.module';
import { ClassificationService } from './classification.service';
import { ParsingService } from './parsing.service';
import { ValidationService } from './validation.service';
import { VerificationController } from './verification.controller';
import { Verification } from './verification.entity';
import { VerificationService } from './verification.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Verification]),
    VisionModule,
    DemoModule,
  ],
  controllers: [VerificationController],
  providers: [
    VerificationService,
    ParsingService,
    ValidationService,
    ClassificationService,
  ],
  exports: [VerificationService],
})
export class VerificationModule {}
