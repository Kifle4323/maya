import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
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
import { VisionService } from '../vision/vision.service';

@Injectable()
export class IndigentService {
  constructor(
    @InjectRepository(IndigentApplication)
    private readonly indigentRepository: Repository<IndigentApplication>,
    private readonly visionService: VisionService,
  ) {}

  private readonly logger = new Logger(IndigentService.name);

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

    const visionResults = [];
    if (data.documents?.length) {
       // If documents are passed as base64, validate them. 
       // Note: Currently documents are expected to be URLs or Base64 depending on the source.
       // We only validate if they look like base64.
       for (const doc of data.documents) {
         if (doc.length > 500) { // likely base64
           try {
             const res = await this.visionService.validateIndigentDocument(doc);
             visionResults.push(res);
           } catch (e) {
             this.logger.error(`Vision validation failed: ${e.message}`);
           }
         }
       }
    }

    const decision = this.evaluateIndigentApplication(data);

    // Two-way proof gating
    if (visionResults.length > 0) {
      const validResults = visionResults.filter(r => r.isValid && r.confidence >= 0.85);
      if (validResults.length > 0) {
        decision.status = IndigentApplicationStatus.APPROVED;
        decision.reason += ` | Vision verified: ${validResults[0].documentType}`;
      } else {
        decision.status = IndigentApplicationStatus.PENDING;
        decision.reason += ` | Vision validation pending: ${visionResults[0]?.issues?.[0] ?? 'low confidence'}`;
      }
    }
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
