import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, pbkdf2Sync, randomBytes, timingSafeEqual } from 'crypto';
import { Repository } from 'typeorm';
import { PreferredLanguage } from '../common/enums/cbhi.enums';
import { User } from '../users/user.entity';
import {
  PasswordLoginDto,
  RefreshTokenDto,
} from './auth.dto';
import { TotpService } from './totp.service';

type AuthTokenPayload = {
  sub: string;
  role: string;
  phoneNumber?: string | null;
  email?: string | null;
  tokenVersion?: number;
  totpPending?: boolean;
};

// Refresh token TTL: 30 days
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService {
  private readonly accessTokenTtlSeconds = Number(
    process.env.AUTH_ACCESS_TOKEN_TTL_SECONDS ?? 60 * 60 * 24, // 24h default
  );

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  normalizePhoneNumber(value?: string | null) {
    const digits = value?.replace(/\D/g, '') ?? '';
    if (!digits) return undefined;

    if (digits.startsWith('251') && digits.length === 12) return `+${digits}`;
    if (digits.startsWith('09') && digits.length === 10) return `+251${digits.substring(1)}`;
    if (digits.startsWith('9') && digits.length === 9) return `+251${digits}`;

    throw new BadRequestException(
      'Phone number must be a valid Ethiopian mobile number.',
    );
  }

  normalizeEmail(value?: string | null) {
    const email = value?.trim().toLowerCase();
    return email ? email : undefined;
  }

  async loginWithPassword(dto: PasswordLoginDto) {
    const identifier = this.normalizeIdentifier(dto.identifier);
    const user = await this.findUserByTarget(identifier, { includeSecrets: true });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    if (!this.verifyPassword(dto.password, user.passwordHash)) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    // If TOTP is enabled (admin accounts), issue a short-lived pending token
    if (user.totpEnabled) {
      const pendingToken = this.jwtService.sign(
        { sub: user.id, role: user.role, totpPending: true } satisfies AuthTokenPayload,
        { expiresIn: '5m' },
      );
      return { requiresTotpVerification: true, pendingToken };
    }

    user.lastLoginAt = new Date();
    await this.userRepository.save(user);
    return this.issueSession(user);
  }

  buildUserProfilePublic(user: User) {
    return this.buildUserProfile(user);
  }

  async requireUserFromAuthorization(authorization?: string) {
    const token = authorization?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Missing bearer token.');

    const isProduction = process.env.NODE_ENV === 'production';
    const publicKey = process.env.AUTH_JWT_PUBLIC_KEY;

    let payload: AuthTokenPayload;
    try {
      if (isProduction && publicKey) {
        payload = this.jwtService.verify<AuthTokenPayload>(token, {
          algorithms: ['RS256'],
          publicKey: publicKey.replace(/\\n/g, '\n'),
        });
      } else {
        payload = this.jwtService.verify<AuthTokenPayload>(token);
      }
    } catch {
      throw new UnauthorizedException('Invalid or expired access token.');
    }

    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
      relations: ['household', 'beneficiaryProfile', 'beneficiaryProfile.household'],
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Your session is no longer active.');
    }

    const payloadVersion = payload.tokenVersion ?? 0;
    const userVersion = user.tokenVersion ?? 0;
    if (payloadVersion !== userVersion) {
      throw new UnauthorizedException('Session invalidated. Please sign in again.');
    }

    return user;
  }

  async issueSession(userOrId: User | string) {
    const user =
      typeof userOrId === 'string'
        ? await this.loadUserForSession(userOrId)
        : await this.loadUserForSession(userOrId.id);

    const expiresAt = new Date(
      Date.now() + this.accessTokenTtlSeconds * 1000,
    ).toISOString();

    const payload: AuthTokenPayload = {
      sub: user.id,
      role: user.role,
      phoneNumber: user.phoneNumber,
      email: user.email,
      tokenVersion: user.tokenVersion ?? 0,
    };
    const accessToken = this.jwtService.sign(payload, {
      expiresIn: `${this.accessTokenTtlSeconds}s`,
    });

    const rawRefreshToken = randomBytes(48).toString('hex');
    const userWithSecrets = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.refreshTokenHash', 'user.refreshTokenExpiresAt'])
      .where('user.id = :id', { id: user.id })
      .getOne();

    if (userWithSecrets) {
      userWithSecrets.refreshTokenHash = this.hashValue(rawRefreshToken);
      userWithSecrets.refreshTokenExpiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
      await this.userRepository.save(userWithSecrets);
    }

    return {
      accessToken,
      refreshToken: rawRefreshToken,
      tokenType: 'Bearer',
      expiresAt,
      refreshTokenExpiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS).toISOString(),
      user: this.buildUserProfile(user),
    };
  }

  async refreshSession(dto: RefreshTokenDto) {
    const tokenHash = this.hashValue(dto.refreshToken);

    const userWithSecrets = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.refreshTokenHash', 'user.refreshTokenExpiresAt'])
      .leftJoinAndSelect('user.household', 'household')
      .leftJoinAndSelect('user.beneficiaryProfile', 'beneficiaryProfile')
      .leftJoinAndSelect('beneficiaryProfile.household', 'beneficiaryHousehold')
      .where('user.isActive = :isActive', { isActive: true })
      .andWhere('user.refreshTokenHash = :tokenHash', { tokenHash })
      .getOne();

    if (!userWithSecrets) {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    if (
      !userWithSecrets.refreshTokenExpiresAt ||
      userWithSecrets.refreshTokenExpiresAt.getTime() < Date.now()
    ) {
      throw new UnauthorizedException('Refresh token has expired. Please sign in again.');
    }

    return this.issueSession(userWithSecrets.id);
  }

  async revokeRefreshToken(userId: string) {
    const user = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.refreshTokenHash', 'user.refreshTokenExpiresAt'])
      .where('user.id = :id', { id: userId })
      .getOne();

    if (user) {
      user.refreshTokenHash = null;
      user.refreshTokenExpiresAt = null;
      await this.userRepository.save(user);
    }
  }

  async setInitialPasswordNoInvalidate(userId: string, password: string) {
    if (!password || password.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters.');
    }
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');
    user.passwordHash = this.hashPassword(password);
    await this.userRepository.save(user);
    return { message: 'Password set successfully.' };
  }

  async setInitialPasswordByPhone(phone: string, password: string) {
    if (!password || password.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters.');
    }
    const normalized = this.normalizePhoneNumber(phone);
    const user = await this.userRepository.findOne({
      where: { phoneNumber: normalized ?? phone },
    });
    if (!user) throw new NotFoundException('User not found.');
    if (user.passwordHash) {
      throw new BadRequestException('Password already set. Use change-password instead.');
    }
    user.passwordHash = this.hashPassword(password);
    await this.userRepository.save(user);
    return { message: 'Password set successfully.' };
  }

  async setPassword(userId: string, password: string) {
    if (!password || password.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters.');
    }
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');
    user.passwordHash = this.hashPassword(password);
    user.tokenVersion = (user.tokenVersion ?? 0) + 1;
    await this.userRepository.save(user);
    return { message: 'Password set successfully.' };
  }

  /**
   * GDPR / data privacy: anonymise PII and deactivate the account.
   */
  async anonymiseAccount(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');

    user.firstName = 'Deleted';
    user.middleName = null;
    user.lastName = 'User';
    user.phoneNumber = null;
    user.email = null;
    user.nationalId = null;
    user.identityNumber = null;
    user.passwordHash = null;
    user.refreshTokenHash = null;
    user.totpSecret = null;
    user.totpEnabled = false;
    user.isActive = false;
    await this.userRepository.save(user);
    await this.revokeRefreshToken(userId);

    return { message: 'Account data anonymised and deactivated.' };
  }

  // ── TOTP 2FA (admin accounts only) ────────────────────────────────────────

  async setupTotp(userId: string, totpService: TotpService) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');

    const secret = totpService.generateSecret();
    const accountName = user.email ?? user.phoneNumber ?? user.id;
    const qrUri = totpService.generateQrUri(secret, accountName);

    const userWithSecrets = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.totpSecret'])
      .where('user.id = :id', { id: userId })
      .getOne();

    if (userWithSecrets) {
      userWithSecrets.totpSecret = secret;
      await this.userRepository.save(userWithSecrets);
    }

    return { secret, qrUri };
  }

  async activateTotp(userId: string, token: string, totpService: TotpService) {
    const userWithSecrets = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.totpSecret'])
      .where('user.id = :id', { id: userId })
      .getOne();

    if (!userWithSecrets) throw new NotFoundException('User not found.');
    if (!userWithSecrets.totpSecret) {
      throw new BadRequestException('TOTP setup has not been initiated. Call /auth/totp/setup first.');
    }

    const valid = totpService.verifyToken(userWithSecrets.totpSecret, token);
    if (!valid) {
      throw new UnauthorizedException('Invalid TOTP token. Please check your authenticator app.');
    }

    userWithSecrets.totpEnabled = true;
    await this.userRepository.save(userWithSecrets);

    return { message: 'Two-factor authentication has been activated.' };
  }

  async verifyTotpLogin(pendingToken: string, token: string, totpService: TotpService) {
    let payload: AuthTokenPayload;
    try {
      payload = this.jwtService.verify<AuthTokenPayload>(pendingToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired pending token. Please sign in again.');
    }

    if (!payload.totpPending) {
      throw new UnauthorizedException('This token is not a TOTP pending token.');
    }

    const userWithSecrets = await this.userRepository
      .createQueryBuilder('user')
      .addSelect(['user.totpSecret'])
      .leftJoinAndSelect('user.household', 'household')
      .leftJoinAndSelect('user.beneficiaryProfile', 'beneficiaryProfile')
      .leftJoinAndSelect('beneficiaryProfile.household', 'beneficiaryHousehold')
      .where('user.id = :id', { id: payload.sub })
      .getOne();

    if (!userWithSecrets || !userWithSecrets.isActive) {
      throw new UnauthorizedException('Account not found or inactive.');
    }

    if (!userWithSecrets.totpSecret || !userWithSecrets.totpEnabled) {
      throw new BadRequestException('TOTP is not enabled for this account.');
    }

    const valid = totpService.verifyToken(userWithSecrets.totpSecret, token);
    if (!valid) {
      throw new UnauthorizedException('Invalid TOTP token. Please check your authenticator app and try again.');
    }

    userWithSecrets.lastLoginAt = new Date();
    await this.userRepository.save(userWithSecrets);

    return this.issueSession(userWithSecrets.id);
  }

  hashPassword(password: string) {
    const salt = createHash('sha256')
      .update(`${Date.now()}:${Math.random()}`)
      .digest('hex');
    const hash = pbkdf2Sync(password, salt, 120000, 64, 'sha512').toString('hex');
    return `${salt}:${hash}`;
  }

  private async loadUserForSession(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['household', 'beneficiaryProfile', 'beneficiaryProfile.household'],
    });
    if (!user) throw new NotFoundException(`User ${userId} not found.`);
    return user;
  }

  private buildUserProfile(user: User) {
    const displayName = [user.firstName, user.middleName, user.lastName]
      .filter(Boolean)
      .join(' ')
      .trim();
    const householdCode =
      user.household?.householdCode ??
      user.beneficiaryProfile?.household?.householdCode ??
      null;

    return {
      id: user.id,
      displayName: displayName || 'Member',
      firstName: user.firstName,
      middleName: user.middleName,
      lastName: user.lastName,
      phoneNumber: user.phoneNumber,
      email: user.email,
      role: user.role,
      preferredLanguage: user.preferredLanguage ?? PreferredLanguage.ENGLISH,
      householdCode,
      beneficiaryId: user.beneficiaryProfile?.id ?? null,
      membershipId: user.beneficiaryProfile?.memberNumber ?? null,
      lastLoginAt: user.lastLoginAt?.toISOString() ?? null,
    };
  }

  private verifyPassword(password: string, stored: string) {
    const [salt, expectedHash] = stored.split(':');
    if (!salt || !expectedHash) return false;
    const hash = pbkdf2Sync(password, salt, 120000, 64, 'sha512').toString('hex');
    return this.safeEqual(hash, expectedHash);
  }

  private normalizeIdentifier(identifier: string) {
    return identifier.includes('@')
      ? (this.normalizeEmail(identifier) ?? identifier.trim().toLowerCase())
      : (this.normalizePhoneNumber(identifier) ?? identifier.trim());
  }

  private async findUserByTarget(
    target: string,
    options: { includeSecrets?: boolean } = {},
  ) {
    const isEmail = target.includes('@');
    const builder = this.userRepository.createQueryBuilder('user');
    if (options.includeSecrets) {
      builder.addSelect(['user.passwordHash']);
    }
    builder.leftJoinAndSelect('user.household', 'household');
    builder.leftJoinAndSelect('user.beneficiaryProfile', 'beneficiaryProfile');
    builder.leftJoinAndSelect('beneficiaryProfile.household', 'beneficiaryHousehold');
    builder.where(
      isEmail ? 'LOWER(user.email) = :target' : 'user.phoneNumber = :target',
      { target: isEmail ? target.toLowerCase() : target },
    );
    return builder.getOne();
  }

  private hashValue(input: string) {
    return createHash('sha256').update(input).digest('hex');
  }

  private safeEqual(left: string, right: string) {
    const leftBuffer = Buffer.from(left);
    const rightBuffer = Buffer.from(right);
    if (leftBuffer.length !== rightBuffer.length) return false;
    return timingSafeEqual(leftBuffer, rightBuffer);
  }
}
