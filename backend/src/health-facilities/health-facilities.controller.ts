import { Controller, Get, Query } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { IsOptional, IsString } from 'class-validator';
import { Public } from '../common/decorators/public.decorator';
import { HealthFacility } from './health-facility.entity';

class SearchFacilitiesDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  woreda?: string;

  @IsOptional()
  @IsString()
  zone?: string;
}

@Controller('facilities')
export class HealthFacilitiesController {
  constructor(
    @InjectRepository(HealthFacility)
    private readonly facilityRepository: Repository<HealthFacility>,
  ) {}

  @Public()
  @Get()
  async searchFacilities(@Query() query: SearchFacilitiesDto) {
    const qb = this.facilityRepository
      .createQueryBuilder('facility')
      .where('facility.isAccredited = :isAccredited', { isAccredited: true })
      .orderBy('facility.name', 'ASC')
      .take(50);

    if (query.q) {
      qb.andWhere('LOWER(facility.name) LIKE :q', {
        q: `%${query.q.toLowerCase()}%`,
      });
    }

    if (query.woreda) {
      qb.leftJoinAndSelect('facility.location', 'location')
        .leftJoinAndSelect('location.parent', 'zone')
        .andWhere('LOWER(location.name) LIKE :woreda', {
          woreda: `%${query.woreda.toLowerCase()}%`,
        });
    }

    const facilities = await qb.getMany();

    return {
      facilities: facilities.map((f) => ({
        id: f.id,
        name: f.name,
        facilityCode: f.facilityCode ?? null,
        serviceLevel: f.serviceLevel ?? null,
        phoneNumber: f.phoneNumber ?? null,
        addressLine: f.addressLine ?? null,
        latitude: f.latitude ? Number(f.latitude) : null,
        longitude: f.longitude ? Number(f.longitude) : null,
        isAccredited: f.isAccredited,
      })),
      total: facilities.length,
    };
  }
}
