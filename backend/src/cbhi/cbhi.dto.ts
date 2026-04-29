import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import {
  Gender,
  IdentityDocumentType,
  IndigentEmploymentStatus,
  MembershipTier,
  MembershipType,
  PaymentMethod,
  PreferredLanguage,
  RelationshipToHouseholdHead,
} from '../common/enums/cbhi.enums';

export class AddressDto {
  @IsString()
  region!: string;

  @IsString()
  zone!: string;

  @IsOptional()
  @IsString()
  woreda?: string;

  @IsOptional()
  @IsString()
  kebele?: string;
}

export class InlineAttachmentDto {
  @IsString()
  fileName!: string;

  @IsString()
  mimeType!: string;

  @IsString()
  contentBase64!: string;

  @IsOptional()
  @IsString()
  localPath?: string;
}

export class RegistrationStepOneDto {
  @IsString()
  firstName!: string;

  @IsOptional()
  @IsString()
  middleName?: string;

  @IsString()
  lastName!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  age?: number;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsEnum(Gender)
  gender!: Gender;

  @IsDateString()
  dateOfBirth!: string;

  @IsOptional()
  @IsString()
  birthCertificateRef?: string;

  @IsOptional()
  @IsString()
  birthCertificatePath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  birthCertificateUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  idDocumentPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  idDocumentUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  beneficiaryPhotoPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  beneficiaryPhotoUpload?: InlineAttachmentDto;

  @ValidateNested()
  @Type(() => AddressDto)
  address!: AddressDto;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  householdSize!: number;

  @IsOptional()
  @IsEnum(PreferredLanguage)
  preferredLanguage?: PreferredLanguage;
}

export class EligibilitySignalsDto {
  @IsEnum(IndigentEmploymentStatus)
  employmentStatus!: IndigentEmploymentStatus;
}

export class RegistrationStepTwoDto {
  @IsUUID()
  registrationId!: string;

  @IsEnum(IdentityDocumentType)
  identityType!: IdentityDocumentType;

  @IsString()
  identityNumber!: string;

  @IsEnum(MembershipType)
  membershipType!: MembershipType;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  premiumAmount?: number;

  @ValidateNested()
  @Type(() => EligibilitySignalsDto)
  eligibilitySignals!: EligibilitySignalsDto;

  /** Required for INDIGENT: at least one kebele / income / poverty proof document */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => InlineAttachmentDto)
  indigentProofUploads?: InlineAttachmentDto[];

  @IsOptional()
  @IsEnum(MembershipTier)
  membershipTier?: MembershipTier;
}

export class CreateFamilyMemberDto {
  @IsString()
  firstName!: string;

  @IsOptional()
  @IsString()
  middleName?: string;

  @IsString()
  lastName!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  age?: number;

  @IsEnum(Gender)
  gender!: Gender;

  @IsDateString()
  dateOfBirth!: string;

  @IsEnum(RelationshipToHouseholdHead)
  relationshipToHouseholdHead!: RelationshipToHouseholdHead;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @ValidateIf((value: CreateFamilyMemberDto) => !!value.identityNumber)
  @IsEnum(IdentityDocumentType)
  identityType?: IdentityDocumentType;

  @IsOptional()
  @ValidateIf((value: CreateFamilyMemberDto) => !!value.identityType)
  @IsString()
  identityNumber?: string;

  @IsOptional()
  @IsString()
  birthCertificateRef?: string;

  @IsOptional()
  @IsString()
  beneficiaryPhotoPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  beneficiaryPhotoUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  birthCertificatePath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  birthCertificateUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  idDocumentPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  idDocumentUpload?: InlineAttachmentDto;
}

export class UpdateFamilyMemberDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  middleName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  age?: number;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsEnum(RelationshipToHouseholdHead)
  relationshipToHouseholdHead?: RelationshipToHouseholdHead;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @IsEnum(IdentityDocumentType)
  identityType?: IdentityDocumentType;

  @IsOptional()
  @IsString()
  identityNumber?: string;

  @IsOptional()
  @IsString()
  birthCertificateRef?: string;

  @IsOptional()
  @IsString()
  beneficiaryPhotoPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  beneficiaryPhotoUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  birthCertificatePath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  birthCertificateUpload?: InlineAttachmentDto;

  @IsOptional()
  @IsString()
  idDocumentPath?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineAttachmentDto)
  idDocumentUpload?: InlineAttachmentDto;
}

export class RenewCoverageDto {
  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount?: number;

  @IsOptional()
  @IsString()
  providerName?: string;

  @IsOptional()
  @IsString()
  receiptNumber?: string;

  @IsOptional()
  @IsEnum(MembershipTier)
  membershipTier?: MembershipTier;
}
