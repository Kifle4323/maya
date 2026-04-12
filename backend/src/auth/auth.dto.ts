import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MinLength,
  ValidateIf,
} from 'class-validator';

export const otpPurposes = ['login', 'password_reset'] as const;
export type OtpPurpose = (typeof otpPurposes)[number];

export class RefreshTokenDto {
  @IsString()
  refreshToken!: string;
}

export class SendOtpDto {
  @ValidateIf((value: SendOtpDto) => !value.email)
  @IsString()
  phoneNumber?: string;

  @ValidateIf((value: SendOtpDto) => !value.phoneNumber)
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsIn(otpPurposes)
  purpose?: OtpPurpose;
}

export class RequestFamilyOtpDto {
  @IsString()
  phoneNumber!: string;

  @IsOptional()
  @IsString()
  membershipId?: string;

  @ValidateIf((value: RequestFamilyOtpDto) => !value.membershipId)
  @IsString()
  householdCode?: string;

  @ValidateIf((value: RequestFamilyOtpDto) => !value.membershipId)
  @IsString()
  fullName?: string;
}

export class FamilyPasswordLoginDto {
  @IsString()
  phoneNumber!: string;

  @IsOptional()
  @IsString()
  membershipId?: string;

  @ValidateIf((value: FamilyPasswordLoginDto) => !value.membershipId)
  @IsString()
  householdCode?: string;

  @ValidateIf((value: FamilyPasswordLoginDto) => !value.membershipId)
  @IsString()
  fullName?: string;

  @IsString()
  password!: string;
}

export class VerifyOtpDto {
  @ValidateIf((value: VerifyOtpDto) => !value.email)
  @IsString()
  phoneNumber?: string;

  @ValidateIf((value: VerifyOtpDto) => !value.phoneNumber)
  @IsEmail()
  email?: string;

  @IsString()
  @Matches(/^\d{4,6}$/)
  code!: string;
}

export class PasswordLoginDto {
  @IsString()
  identifier!: string;

  @IsString()
  password!: string;
}

export class ForgotPasswordDto {
  @IsString()
  identifier!: string;
}

export class ResetPasswordDto {
  @IsString()
  identifier!: string;

  @IsString()
  @Matches(/^\d{4,6}$/)
  code!: string;

  @IsString()
  @MinLength(6)
  newPassword!: string;
}
