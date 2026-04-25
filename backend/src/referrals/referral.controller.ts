import { Body, Controller, Get, Post, Query, UseGuards, UnauthorizedException } from '@nestjs/common';
import { ReferralService } from './referral.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { InjectRepository } from '@nestjs/typeorm';
import { FacilityUser } from '../facility-users/facility-user.entity';
import { Repository } from 'typeorm';

class CreateReferralDto {
  beneficiaryId!: string;
  diagnosis?: string;
  reason?: string;
}

@Controller('referrals')
@UseGuards(JwtAuthGuard)
export class ReferralController {
  constructor(
    private readonly referralService: ReferralService,
    @InjectRepository(FacilityUser)
    private readonly facilityUserRepository: Repository<FacilityUser>,
  ) {}

  @Post()
  async createReferral(
    @CurrentUser() user: User,
    @Body() dto: CreateReferralDto,
  ) {
    const facilityUser = await this.facilityUserRepository.findOne({
      where: { user: { id: user.id } },
      relations: ['facility'],
    });

    if (!facilityUser || !facilityUser.facility) {
      throw new UnauthorizedException('User is not associated with any health facility.');
    }

    return this.referralService.createReferral(
      facilityUser.facility.id,
      dto.beneficiaryId,
      dto.diagnosis,
      dto.reason,
    );
  }

  @Get('validate')
  async validateReferral(
    @Query('code') code: string,
    @Query('beneficiaryId') beneficiaryId: string,
  ) {
    return this.referralService.validateReferral(code, beneficiaryId);
  }
}
