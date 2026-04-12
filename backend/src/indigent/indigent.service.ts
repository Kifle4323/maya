import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  IndigentApplicationStatus,
  IndigentEmploymentStatus,
} from '../common/enums/cbhi.enums';
import { IndigentApplication } from './indigent.entity';
import {
  CreateIndigentApplicationDto,
  IndigentDecisionDto,
  OverrideIndigentApplicationDto,
} from './indigent.dto';

@Injectable()
export class IndigentService {
  constructor(
    @InjectRepository(IndigentApplication)
    private readonly indigentRepository: Repository<IndigentApplication>,
  ) {}

  evaluateIndigentApplication(
    data: CreateIndigentApplicationDto,
  ): IndigentDecisionDto {
    let score = 0;
    const matchedReasons: string[] = [];

    const incomeThreshold = Number(process.env.INDIGENT_INCOME_THRESHOLD ?? 1000);
    if (data.income < incomeThreshold) {
      score += 40;
      matchedReasons.push('low income');
    }

    if (data.employmentStatus === IndigentEmploymentStatus.UNEMPLOYED) {
      score += 30;
      matchedReasons.push('unemployed');
    } else if (data.employmentStatus === IndigentEmploymentStatus.DAILY_LABORER) {
      score += 25;
      matchedReasons.push('daily laborer');
    } else if (data.employmentStatus === IndigentEmploymentStatus.FARMER) {
      score += 20;
      matchedReasons.push('smallholder farmer');
    } else if (data.employmentStatus === IndigentEmploymentStatus.HOMEMAKER) {
      score += 18;
      matchedReasons.push('homemaker');
    }

    const familySizeThreshold = Number(process.env.INDIGENT_FAMILY_SIZE_THRESHOLD ?? 5);
    if (data.familySize >= familySizeThreshold) {
      score += 20;
      matchedReasons.push('high family size');
    } else if (data.familySize >= 4) {
      score += 10;
      matchedReasons.push('mid-size household');
    }

    if (!data.hasProperty) {
      score += 10;
      matchedReasons.push('no property');
    }

    if (data.disabilityStatus) {
      score += 10;
      matchedReasons.push('disability');
    }

    const approvalThreshold = Number(process.env.INDIGENT_APPROVAL_THRESHOLD ?? 70);
    const status =
      score >= approvalThreshold
        ? IndigentApplicationStatus.APPROVED
        : IndigentApplicationStatus.REJECTED;

    const reason =
      status === IndigentApplicationStatus.APPROVED
        ? `Approved: ${matchedReasons.join(', ')}`
        : 'Does not meet indigent criteria';

    return { score, status, reason };
  }

  async applyApplication(data: CreateIndigentApplicationDto) {
    const hasExpiredDocuments = data.documentMeta?.some((doc) => doc.isExpired === true) ?? false;

    if (hasExpiredDocuments) {
      const expiredDocs = data.documentMeta
        ?.filter((doc) => doc.isExpired)
        .map((doc) => doc.documentType ?? 'Unknown document')
        .join(', ');
      throw new BadRequestException(
        `Application rejected: expired document(s) detected (${expiredDocs}). ` +
        'Please obtain updated certificates from your kebele before applying.',
      );
    }

    const decision = this.evaluateIndigentApplication(data);
    const application = this.indigentRepository.create({
      income: data.income,
      employmentStatus: data.employmentStatus,
      familySize: data.familySize,
      hasProperty: data.hasProperty,
      disabilityStatus: data.disabilityStatus,
      documents: data.documents,
      documentMeta: data.documentMeta ?? null,
      hasExpiredDocuments,
      ...decision,
    });

    return this.indigentRepository.save(application);
  }

  async getApplicationById(id: string) {
    const application = await this.indigentRepository.findOne({
      where: { id },
      relations: ['user'],
    });

    if (!application) {
      throw new NotFoundException(`Indigent application ${id} not found`);
    }

    return application;
  }

  async getApplicationsByUserId(userId: string) {
    return this.indigentRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async overrideApplication(id: string, dto: OverrideIndigentApplicationDto) {
    const application = await this.getApplicationById(id);
    application.status = dto.status;
    application.reason =
      dto.reason ?? `Manually overridden to ${dto.status.toLowerCase()}`;
    return this.indigentRepository.save(application);
  }
}
