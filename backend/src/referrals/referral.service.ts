import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Referral } from './referral.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { randomBytes } from 'crypto';

@Injectable()
export class ReferralService {
  constructor(
    @InjectRepository(Referral)
    private readonly referralRepository: Repository<Referral>,
    @InjectRepository(HealthFacility)
    private readonly facilityRepository: Repository<HealthFacility>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
  ) {}

  async createReferral(
    issuerFacilityId: string,
    beneficiaryId: string,
    diagnosis?: string,
    reason?: string,
  ) {
    const facility = await this.facilityRepository.findOneBy({ id: issuerFacilityId });
    const beneficiary = await this.beneficiaryRepository.findOneBy({ id: beneficiaryId });

    if (!facility || !beneficiary) {
      throw new NotFoundException('Facility or Beneficiary not found');
    }

    const referral = this.referralRepository.create({
      code: `REF-${randomBytes(4).toString('hex').toUpperCase()}`,
      beneficiary,
      issuedByFacility: facility,
      issuedAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days validity
      diagnosis,
      reasonForReferral: reason,
    });

    return this.referralRepository.save(referral);
  }

  async validateReferral(code: string, beneficiaryId: string) {
    const referral = await this.referralRepository.findOne({
      where: { code, beneficiary: { id: beneficiaryId } },
      relations: ['issuedByFacility'],
    });

    if (!referral) {
      throw new BadRequestException('Invalid referral code for this beneficiary.');
    }

    if (referral.isUsed) {
      throw new BadRequestException('Referral code has already been used.');
    }

    if (new Date() > referral.expiresAt) {
      throw new BadRequestException('Referral code has expired.');
    }

    return referral;
  }

  async markAsUsed(id: string) {
    await this.referralRepository.update(id, { isUsed: true });
  }
}
