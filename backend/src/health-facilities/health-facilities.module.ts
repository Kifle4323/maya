import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthFacility } from './health-facility.entity';
import { HealthFacilitiesController } from './health-facilities.controller';

@Module({
  imports: [TypeOrmModule.forFeature([HealthFacility])],
  controllers: [HealthFacilitiesController],
})
export class HealthFacilitiesModule {}
