import {
  IsDateString,
  IsEnum,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { ClaimStatus, IndigentApplicationStatus } from '../common/enums/cbhi.enums';

export class ReviewClaimDto {
  @IsEnum(ClaimStatus)
  status!: ClaimStatus;

  @IsOptional()
  @IsNumber()
  approvedAmount?: number;

  @IsOptional()
  @IsString()
  decisionNote?: string;
}

export class ReviewIndigentApplicationDto {
  @IsEnum(IndigentApplicationStatus)
  status!: IndigentApplicationStatus;

  @IsOptional()
  @IsString()
  reason?: string;
}

export class UpdateSystemSettingDto {
  @IsOptional()
  @IsString()
  label?: string;

  @IsOptional()
  @IsString()
  description?: string;

  value!: Record<string, unknown>;

  @IsOptional()
  isSensitive?: boolean;
}

export class ReportsQueryDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;
}

export class ExportQueryDto {
  @IsOptional()
  @IsIn(['households', 'claims', 'payments', 'indigent'])
  type?: 'households' | 'claims' | 'payments' | 'indigent';

  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;
}
