import { Body, Controller, Get, Post, Req, BadRequestException } from '@nestjs/common';
import { IsString, IsNotEmpty } from 'class-validator';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import {
  PasswordLoginDto,
  RefreshTokenDto,
  SetPasswordDto,
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
  @Throttle({ default: { ttl: 600_000, limit: 20 } }) // 20 attempts per 10 min per IP
  @Post('login')
  login(@Body() dto: PasswordLoginDto) {
    return this.authService.loginWithPassword(dto);
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
   *
   * Supports two auth modes:
   * 1. JWT session (authenticated) — uses @CurrentUser
   * 2. No JWT + phone in body — looks up user by phone (for web clients
   *    that may not persist the session token across navigation)
   */
  @Public()
  @Throttle({ default: { ttl: 60_000, limit: 50 } })
  @Post('set-initial-password')
  async setInitialPassword(
    @CurrentUser() user: User | null,
    @Body() dto: SetPasswordDto,
    @Req() req: any,
  ) {
    // If JWT is present and valid, use the authenticated user
    if (user) {
      return this.authService.setInitialPasswordNoInvalidate(user.id, dto.password);
    }

    // No JWT — resolve user by phone number
    if (!dto.phone) {
      throw new BadRequestException('Phone number is required when not authenticated.');
    }
    return this.authService.setInitialPasswordByPhone(dto.phone, dto.password);
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