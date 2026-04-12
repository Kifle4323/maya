import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { InlineAttachmentDto } from '../cbhi/cbhi.dto';

export class VerifyEligibilityQueryDto {
  @IsOptional()
  @IsString()
  membershipId?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ValidateIf(
    (value: VerifyEligibilityQueryDto) =>
      !value.membershipId && !value.phoneNumber,
  )
  @IsString()
  householdCode?: string;

  @ValidateIf(
    (value: VerifyEligibilityQueryDto) =>
      !value.membershipId && !value.phoneNumber,
  )
  @IsString()
  fullName?: string;
}

export class FacilityClaimItemDto {
  @IsString()
  serviceName!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(1)
  quantity!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  unitPrice!: number;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class SubmitServiceClaimDto {
  @IsOptional()
  @IsString()
  membershipId?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ValidateIf(
    (value: SubmitServiceClaimDto) => !value.membershipId && !value.phoneNumber,
  )
  @IsString()
  householdCode?: string;

  @ValidateIf(
    (value: SubmitServiceClaimDto) => !value.membershipId && !value.phoneNumber,
  )
  @IsString()
  fullName?: string;

  @IsDateString()
  serviceDate!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => FacilityClaimItemDto)
  items!: FacilityClaimItemDto[];

  @IsOptional()
  @IsString()
  supportingDocumentPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  supportingDocumentUpload?: InlineAttachmentDto;
}
