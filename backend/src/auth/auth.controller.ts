import { Body, Controller, Get, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsString, IsNotEmpty } from 'class-validator';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import {
  FamilyPasswordLoginDto,
  ForgotPasswordDto,
  PasswordLoginDto,
  RefreshTokenDto,
  RequestFamilyOtpDto,
  ResetPasswordDto,
  SendOtpDto,
  SetPasswordDto,
  VerifyOtpDto,
} from './auth.dto';
import { AuthService } from './auth.service';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

class RegisterFcmTokenDto {
  @IsString()
  @IsNotEmpty()
  fcmToken!: string;
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  @Public()
  @Throttle({ otp: { limit: 5, ttl: 600_000 } })
  @Post('send-otp')
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  @Public()
  @Throttle({ otp: { limit: 5, ttl: 600_000 } })
  @Post('family/request-otp')
  requestFamilyOtp(@Body() dto: RequestFamilyOtpDto) {
    return this.authService.requestFamilyMemberOtp(dto);
  }

  @Public()
  @Post('family/login')
  familyLogin(@Body() dto: FamilyPasswordLoginDto) {
    return this.authService.loginFamilyMemberWithPassword(dto);
  }

  @Public()
  @Throttle({ otp: { limit: 10, ttl: 600_000 } })
  @Post('verify-otp')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: PasswordLoginDto) {
    return this.authService.loginWithPassword(dto);
  }

  @Public()
  @Throttle({ otp: { limit: 3, ttl: 600_000 } })
  @Post('forgot-password')
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto);
  }

  @Public()
  @Post('reset-password')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Public()
  @Post('refresh')
  refreshToken(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshSession(dto);
  }

  @Get('me')
  getCurrentUser(@CurrentUser() user: User) {
    return this.authService.buildUserProfilePublic(user);
  }

  @Post('logout')
  async logout(@CurrentUser() user: User) {
    await this.authService.revokeRefreshToken(user.id);
    return { message: 'Logged out successfully.' };
  }

  @Post('set-password')
  async setPassword(
    @CurrentUser() user: User,
    @Body() dto: SetPasswordDto,
  ) {
    return this.authService.setPassword(user.id, dto.password);
  }

  /**
   * First-time password setup — sets the password WITHOUT invalidating the
   * current session (tokenVersion is not incremented). Use this when the user
   * is setting a password for the first time after registration so they are
   * not logged out immediately after completing setup.
   */
  @Post('set-initial-password')
  async setInitialPassword(
    @CurrentUser() user: User,
    @Body() dto: SetPasswordDto,
  ) {
    return this.authService.setInitialPasswordNoInvalidate(user.id, dto.password);
  }

  /**
   * GDPR / data privacy: anonymise and deactivate the account.
   * The user's PII is replaced with anonymised placeholders.
   * Household, claims, and payment records are preserved for audit.
   */
  @Post('delete-account')
  async deleteAccount(@CurrentUser() user: User) {
    return this.authService.anonymiseAccount(user.id);
  }

  /** Register or update the FCM push token for the current user */
  @Post('fcm-token')
  async registerFcmToken(
    @CurrentUser() user: User,
    @Body() dto: RegisterFcmTokenDto,
  ) {
    await this.userRepository.update(user.id, {
      fcmToken: dto.fcmToken,
      fcmTokenUpdatedAt: new Date(),
    });
    return { message: 'FCM token registered.' };
  }

  /** Remove FCM token on logout (stop receiving push notifications) */
  @Post('fcm-token/remove')
  async removeFcmToken(@CurrentUser() user: User) {
    await this.userRepository.update(user.id, {
      fcmToken: null,
      fcmTokenUpdatedAt: new Date(),
    });
    return { message: 'FCM token removed.' };
  }
}