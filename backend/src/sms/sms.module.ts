import { Module } from '@nestjs/common';
import { DemoModule } from '../demo/demo.module';
import { SmsService } from './sms.service';

@Module({
  imports: [DemoModule],
  providers: [SmsService],
  exports: [SmsService],
})
export class SmsModule {}
