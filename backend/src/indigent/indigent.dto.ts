import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  IndigentApplicationStatus,
  IndigentEmploymentStatus,
} from '../common/enums/cbhi.enums';

/**
 * Metadata for each uploaded indigent document.
 * Stores document type, URL, detected date, and expiry status.
 */
export class IndigentDocumentMetaDto {
  @IsString()
  url!: string;

  @IsOptional()
  @IsString()
  documentType?: string;

  @IsOptional()
  @IsString()
  detectedDate?: string;

  @IsOptional()
  isExpired?: boolean;

  @IsOptional()
  @IsString()
  validationSummary?: string;
}

export class CreateIndigentApplicationDto {
  @IsString()
  userId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  income!: number;

  @IsEnum(IndigentEmploymentStatus)
  employmentStatus!: IndigentEmploymentStatus;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  familySize!: number;

  @IsBoolean()
  hasProperty!: boolean;

  @IsBoolean()
  disabilityStatus!: boolean;

  /**
   * Document URLs — stored as plain strings (not validated as URLs
   * to support local file paths in offline mode).
   * Each entry can be a URL or a local path.
   */
  @IsArray()
  @IsString({ each: true })
  documents!: string[];

  /**
   * Optional rich document metadata from Vision API validation.
   * Stored alongside the application for admin review.
   */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => IndigentDocumentMetaDto)
  documentMeta?: IndigentDocumentMetaDto[];
}

export class OverrideIndigentApplicationDto {
  @IsEnum(IndigentApplicationStatus)
  status!: IndigentApplicationStatus;

  @IsOptional()
  @IsString()
  reason?: string;
}

export class IndigentDecisionDto {
  score!: number;
  status!: IndigentApplicationStatus;
  reason!: string;
}
