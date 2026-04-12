import { Controller, Get, Query } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Public } from '../common/decorators/public.decorator';
import { Location, LocationLevel } from './location.entity';

@Controller('locations')
export class LocationsController {
  constructor(
    @InjectRepository(Location)
    private readonly locationRepository: Repository<Location>,
  ) {}

  @Public()
  @Get('regions')
  async getRegions() {
    return this.locationRepository.find({
      where: { level: LocationLevel.REGION, isActive: true },
      order: { name: 'ASC' },
      select: ['id', 'name', 'nameAmharic', 'code'],
    });
  }

  @Public()
  @Get('zones')
  async getZones(@Query('regionCode') regionCode?: string) {
    const qb = this.locationRepository
      .createQueryBuilder('loc')
      .where('loc.level = :level', { level: LocationLevel.ZONE })
      .andWhere('loc.isActive = true')
      .orderBy('loc.name', 'ASC')
      .select(['loc.id', 'loc.name', 'loc.nameAmharic', 'loc.code']);

    if (regionCode) {
      qb.innerJoin('loc.parent', 'parent').andWhere('parent.code = :regionCode', { regionCode });
    }

    return qb.getMany();
  }

  @Public()
  @Get('woredas')
  async getWoredas(@Query('zoneCode') zoneCode?: string) {
    const qb = this.locationRepository
      .createQueryBuilder('loc')
      .where('loc.level = :level', { level: LocationLevel.WOREDA })
      .andWhere('loc.isActive = true')
      .orderBy('loc.name', 'ASC')
      .select(['loc.id', 'loc.name', 'loc.nameAmharic', 'loc.code']);

    if (zoneCode) {
      qb.innerJoin('loc.parent', 'parent').andWhere('parent.code = :zoneCode', { zoneCode });
    }

    return qb.getMany();
  }

  @Public()
  @Get('kebeles')
  async getKebeles(@Query('woredaCode') woredaCode?: string) {
    const qb = this.locationRepository
      .createQueryBuilder('loc')
      .where('loc.level = :level', { level: LocationLevel.KEBELE })
      .andWhere('loc.isActive = true')
      .orderBy('loc.name', 'ASC')
      .select(['loc.id', 'loc.name', 'loc.nameAmharic', 'loc.code']);

    if (woredaCode) {
      qb.innerJoin('loc.parent', 'parent').andWhere('parent.code = :woredaCode', { woredaCode });
    }

    return qb.getMany();
  }
}
