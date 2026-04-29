import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { User } from '../users/user.entity';
import { VisionService, ACCEPTED_INDIGENT_DOC_TYPES, IndigentDocumentType } from '../vision/vision.service';
import { CreateIndigentApplicationDto } from './indigent.dto';
import { IndigentService } from './indigent.service';

class ValidateIndigentDocDto {
  @IsString()
  imageBase64!: string;
}

@Controller('indigent')
export class IndigentController {
  constructor(
    private readonly indigentService: IndigentService,
    private readonly visionService: VisionService,
  ) {}

  /**
   * Submit an indigent application.
   * Documents are validated server-side before scoring.
   */
  @Public()
  @Post('apply')
  apply(@Body() dto: CreateIndigentApplicationDto) {
    return this.indigentService.applyApplication(dto);
  }

  /**
   * Get application status by ID.
   */
  @Get(':id')
  getStatus(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.indigentService.getApplicationById(id);
  }

  /**
   * Get all applications for the authenticated user.
   */
  @Get('my/applications')
  getMyApplications(@CurrentUser() user: User) {
    return this.indigentService.getApplicationsByUserId(user.id);
  }

  /**
   * Pre-validate an indigent supporting document before submission.
   * Returns:
   *   - documentType: detected type (Income Certificate, Disability Certificate, etc.)
   *   - isValid: whether the document is accepted
   *   - detectedDate: extracted issue date
   *   - isExpired: whether the document has expired
   *   - expiryWarning: warning if expiring soon
   *   - issues: list of problems found
   *
   * @Public — no auth required (used during registration flow)
   */
  @Public()
  @Post('validate-document')
  async validateDocument(@Body() dto: ValidateIndigentDocDto) {
    const result = await this.visionService.validateIndigentDocument(dto.imageBase64);
    return {
      ...result,
      acceptedDocumentTypes: [...ACCEPTED_INDIGENT_DOC_TYPES],
      validityPeriods: {
        [IndigentDocumentType.INCOME_CERTIFICATE]: '12 months',
        [IndigentDocumentType.DISABILITY_CERTIFICATE]: '36 months',
        [IndigentDocumentType.KEBELE_ID]: '24 months',
        [IndigentDocumentType.POVERTY_CERTIFICATE]: '12 months',
        [IndigentDocumentType.AGRICULTURAL_CERTIFICATE]: '12 months',
      },
    };
  }

  /**
   * Get accepted document types and their validity periods.
   * @Public — shown to users before they upload documents.
   */
  @Public()
  @Get('document-requirements')
  getDocumentRequirements() {
    return {
      acceptedTypes: [
        {
          type: IndigentDocumentType.INCOME_CERTIFICATE,
          description: 'Certificate from kebele confirming monthly income below threshold',
          validityMonths: 12,
          amharic: 'የገቢ ማረጋገጫ ደብዳቤ',
        },
        {
          type: IndigentDocumentType.DISABILITY_CERTIFICATE,
          description: 'Medical certificate confirming physical or mental disability',
          validityMonths: 36,
          amharic: 'የአካል ጉዳት ማረጋገጫ',
        },
        {
          type: IndigentDocumentType.KEBELE_ID,
          description: 'Kebele identification card or residence certificate',
          validityMonths: 24,
          amharic: 'የቀበሌ መታወቂያ',
        },
        {
          type: IndigentDocumentType.POVERTY_CERTIFICATE,
          description: 'Certificate from social welfare office confirming poverty status',
          validityMonths: 12,
          amharic: 'የድህነት ማረጋገጫ',
        },
        {
          type: IndigentDocumentType.AGRICULTURAL_CERTIFICATE,
          description: 'Certificate confirming smallholder farmer status',
          validityMonths: 12,
          amharic: 'የገበሬ ማረጋገጫ',
        },
      ],
      notes: [
        'Documents must be issued within their validity period',
        'Expired documents will be rejected automatically',
        'Documents must be from an official kebele or government office',
        'Upload clear, well-lit photos — blurry images cannot be validated',
      ],
    };
  }
}
