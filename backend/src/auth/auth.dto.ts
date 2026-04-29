import {
  IsString,
  MinLength,
  Matches,
  IsOptional,
} from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  refreshToken!: string;
}

export class PasswordLoginDto {
  @IsString()
  identifier!: string;

  @IsString()
  password!: string;
}

export class SetPasswordDto {
  @IsString()
  @MinLength(6)
  password!: string;

  /** Optional: phone number for setupCode-based auth (no JWT required) */
  @IsOptional()
  @IsString()
  phone?: string;

  /** Optional: 6-digit setup code issued at registration */
  @IsOptional()
  @IsString()
  setupCode?: string;
}

export class TotpActivateDto {
  @IsString()
  @Matches(/^\d{6}$/, { message: 'Token must be a 6-digit number.' })
  token!: string;
}

export class TotpVerifyDto {
  @IsString()
  @Matches(/^\d{6}$/, { message: 'Token must be a 6-digit number.' })
  token!: string;
}
