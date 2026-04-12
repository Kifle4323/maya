import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createHmac, createHash, pbkdf2Sync, randomBytes, timingSafeEqual } from 'crypto';
import { Repository } from 'typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { UserRole } from '../common/enums/cbhi.enums';
import { PreferredLanguage } from '../common/enums/cbhi.enums';
import { SmsService } from '../sms/sms.service';
import { User } from '../users/user.entity';
import {
  FamilyPasswordLoginDto,
  ForgotPasswordDto,
  OtpPurpose,
  PasswordLoginDto,
  RefreshTokenDto,
  RequestFamilyOtpDto,
  ResetPasswordDto,
  SendOtpDto,
  VerifyOtpDto,
} from './auth.dto';

type AuthTokenPayload = {
  sub: string;
  role: string;
  phoneNumber?: string | null;
  email?: string | null;
  exp: number;
};

// Refresh token TTL: 30 days
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService {
  private readonly accessTokenTtlSeconds = Number(
    process.env.AUTH_ACCESS_TOKEN_TTL_SECONDS ?? 60 * 60 * 24, // 24h default
  );

  private readonly jwtSecret =
    process.env.AUTH_JWT_SECRET ?? 'maya-city-cbhi-secret';

  private readonly isProduction = process.env.NODE_ENV === 'production';

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
    private readonly smsService: SmsService,
  ) {}

  normalizePhoneNumber(value?: string | null) {
    const digits = value?.replace(/\D/g, '') ?? '';
    if (!digits) {
      return undefined;
    }

    if (digits.startsWith('251') && digits.length === 12) {
      return `+${digits}`;
    }

    if (digits.startsWith('09') && digits.length === 10) {
      return `+251${digits.substring(1)}`;
    }

    if (digits.startsWith('9') && digits.length === 9) {
      return `+251${digits}`;
    }

    throw new BadRequestException(
      'Phone number must be a valid Ethiopian mobile number.',
    );
  }

  normalizeEmail(value?: string | null) {
    const email = value?.trim().toLowerCase();
    return email ? email : undefined;
  }

  async sendOtp(dto: SendOtpDto) {
    const purpose = dto.purpose ?? 'login';
    const target = this.resolveTarget(dto.phoneNumber, dto.email);
    const user = await this.findUserByTarget(target, { includeSecrets: true });

    if (!user) {
      throw new NotFoundException(
        purpose === 'login'
          ? 'No member account was found for that phone or email. Start registration to create one.'
          : 'No member account was found for that phone or email.',
      );
    }

    const code = this.generateOtp();
    user.oneTimeCodeHash = this.hashValue(`${purpose}:${code}`);
    user.oneTimeCodePurpose = purpose;
    user.oneTimeCodeTarget = target;
    user.oneTimeCodeExpiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await this.userRepository.save(user);

    // Send OTP via SMS (non-email targets) or log in dev
    const isEmail = target.includes('@');
    if (!isEmail) {
      await this.smsService.sendOtp(target, code);
    }
    // TODO: integrate email OTP delivery (SendGrid / Gmail SMTP)

    return {
      channel: isEmail ? 'email' : 'sms',
      target: this.maskTarget(target),
      expiresInSeconds: 300,
      // Only expose debugCode in non-production environments
      ...(this.isProduction ? {} : { debugCode: code }),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const target = this.resolveTarget(dto.phoneNumber, dto.email);
    const user = await this.findUserByTarget(target, { includeSecrets: true });
    if (!user) {
      throw new NotFoundException('Account not found.');
    }

    this.assertOtp(user, dto.code, 'login', target);
    this.clearOtp(user);
    user.lastLoginAt = new Date();
    await this.userRepository.save(user);

    return this.issueSession(user);
  }

  async requestFamilyMemberOtp(dto: RequestFamilyOtpDto) {
    const { phoneNumber } = await this.resolveFamilyMemberAccess({
      phoneNumber: dto.phoneNumber,
      membershipId: dto.membershipId,
      householdCode: dto.householdCode,
      fullName: dto.fullName,
      includeSecrets: false,
    });

    return this.sendOtp({
      phoneNumber,
      purpose: 'login',
    });
  }

  async loginFamilyMemberWithPassword(dto: FamilyPasswordLoginDto) {
    const { beneficiary, linkedUser } = await this.resolveFamilyMemberAccess({
      phoneNumber: dto.phoneNumber,
      membershipId: dto.membershipId,
      householdCode: dto.householdCode,
      fullName: dto.fullName,
      includeSecrets: true,
    });

    if (!linkedUser.passwordHash) {
      throw new UnauthorizedException(
        `Password login is not set up for ${beneficiary.fullName}. Use OTP or reset the password first.`,
      );
    }

    if (!this.verifyPassword(dto.password, linkedUser.passwordHash)) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    linkedUser.lastLoginAt = new Date();
    await this.userRepository.save(linkedUser);
    return this.issueSession(linkedUser);
  }

  async loginWithPassword(dto: PasswordLoginDto) {
    const identifier = this.normalizeIdentifier(dto.identifier);
    const user = await this.findUserByTarget(identifier, {
      includeSecrets: true,
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException(
        'Email or password login is not available for this account.',
      );
    }

    if (!this.verifyPassword(dto.password, user.passwordHash)) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    user.lastLoginAt = new Date();
    await this.userRepository.save(user);
    return this.issueSession(user);
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    return this.sendOtp({
      email: dto.identifier.includes('@') ? dto.identifier : undefined,
      phoneNumber: dto.identifier.includes('@') ? undefined : dto.identifier,
      purpose: 'password_reset',
    });
  }

  async resetPassword(dto: ResetPasswordDto) {
    const identifier = this.normalizeIdentifier(dto.identifier);
    const user = await this.findUserByTarget(identifier, {
      includeSecrets: true,
    });

    if (!user) {
      throw new NotFoundException('Account not found.');
    }

    this.assertOtp(user, dto.code, 'password_reset', identifier);
    user.passwordHash = this.hashPassword(dto.newPassword);
    this.clearOtp(user);
    await this.userRepository.save(user);

    return {
      message: 'Password updated successfully.',
    };
  }

  async getCurrentUser(authorization?: string) {
    const user = await this.requireUserFromAuthorization(authorization);
    return this.buildUserProfile(user);
  }

  buildUserProfilePublic(user: User) {
    return this.buildUserProfile(user);
  }

  async requireUserFromAuthorization(authorization?: string) {
    const token = authorization?.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      throw new UnauthorizedException('Missing bearer token.');
    }

    const payload = this.verifyAccessToken(token);
    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
      relations: [
        'household',
        'beneficiaryProfile',
        'beneficiaryProfile.household',
      ],
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Your session is no longer active.');
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
    const accessToken = this.signAccessToken({
      sub: user.id,
      role: user.role,
      phoneNumber: user.phoneNumber,
      email: user.email,
      exp: Math.floor(Date.now() / 1000) + this.accessTokenTtlSeconds,
    });

    // Issue refresh token
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
    // Hash the incoming token first, then look up by hash directly
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

  hashPassword(password: string) {
    const salt = createHash('sha256')
      .update(`${Date.now()}:${Math.random()}`)
      .digest('hex');
    const hash = pbkdf2Sync(password, salt, 120000, 64, 'sha512').toString(
      'hex',
    );
    return `${salt}:${hash}`;
  }

  private async loadUserForSession(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: [
        'household',
        'beneficiaryProfile',
        'beneficiaryProfile.household',
      ],
    });

    if (!user) {
      throw new NotFoundException(`User ${userId} not found.`);
    }

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

  private assertOtp(
    user: User,
    code: string,
    purpose: OtpPurpose,
    target: string,
  ) {
    if (
      !user.oneTimeCodeHash ||
      !user.oneTimeCodePurpose ||
      !user.oneTimeCodeTarget ||
      !user.oneTimeCodeExpiresAt
    ) {
      throw new UnauthorizedException('No verification code is active.');
    }

    if (user.oneTimeCodePurpose !== purpose) {
      throw new UnauthorizedException(
        'The verification code purpose is invalid.',
      );
    }

    if (user.oneTimeCodeTarget !== target) {
      throw new UnauthorizedException(
        'The verification code target does not match.',
      );
    }

    if (user.oneTimeCodeExpiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('The verification code has expired.');
    }

    const expected = this.hashValue(`${purpose}:${code}`);
    if (!this.safeEqual(expected, user.oneTimeCodeHash)) {
      throw new UnauthorizedException('The verification code is invalid.');
    }
  }

  private clearOtp(user: User) {
    user.oneTimeCodeHash = null;
    user.oneTimeCodePurpose = null;
    user.oneTimeCodeTarget = null;
    user.oneTimeCodeExpiresAt = null;
  }

  private verifyPassword(password: string, stored: string) {
    const [salt, expectedHash] = stored.split(':');
    if (!salt || !expectedHash) {
      return false;
    }

    const hash = pbkdf2Sync(password, salt, 120000, 64, 'sha512').toString(
      'hex',
    );
    return this.safeEqual(hash, expectedHash);
  }

  private resolveTarget(phoneNumber?: string, email?: string) {
    const normalizedPhone = this.normalizePhoneNumber(phoneNumber);
    if (normalizedPhone) {
      return normalizedPhone;
    }

    const normalizedEmail = this.normalizeEmail(email);
    if (normalizedEmail) {
      return normalizedEmail;
    }

    throw new BadRequestException('Provide a valid phone number or email.');
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
      builder.addSelect([
        'user.passwordHash',
        'user.oneTimeCodeHash',
        'user.oneTimeCodePurpose',
        'user.oneTimeCodeTarget',
        'user.oneTimeCodeExpiresAt',
      ]);
    }

    builder.leftJoinAndSelect('user.household', 'household');
    builder.leftJoinAndSelect('user.beneficiaryProfile', 'beneficiaryProfile');
    builder.leftJoinAndSelect(
      'beneficiaryProfile.household',
      'beneficiaryHousehold',
    );
    builder.where(
      isEmail ? 'LOWER(user.email) = :target' : 'user.phoneNumber = :target',
      { target: isEmail ? target.toLowerCase() : target },
    );

    return builder.getOne();
  }

  private generateOtp() {
    return `${Math.floor(100000 + Math.random() * 900000)}`;
  }

  private maskTarget(target: string) {
    if (target.includes('@')) {
      const [name, domain] = target.split('@');
      return `${name.slice(0, 2)}***@${domain}`;
    }

    return `${target.substring(0, 4)}****${target.substring(target.length - 2)}`;
  }

  private hashValue(input: string) {
    return createHash('sha256').update(input).digest('hex');
  }

  private async findBeneficiaryForFamilyAccess(input: {
    membershipId?: string;
    householdCode?: string;
    fullName?: string;
    phoneNumber: string;
    includeSecrets?: boolean;
  }) {
    const builder = this.beneficiaryRepository
      .createQueryBuilder('beneficiary')
      .leftJoinAndSelect('beneficiary.household', 'household')
      .leftJoinAndSelect('beneficiary.userAccount', 'userAccount')
      .where('userAccount.phoneNumber = :phoneNumber', {
        phoneNumber: input.phoneNumber,
      })
      .andWhere('userAccount.isActive = :isActive', { isActive: true })
      .andWhere('beneficiary.isPrimaryHolder = :isPrimaryHolder', {
        isPrimaryHolder: false,
      });

    if (input.includeSecrets) {
      builder.addSelect(['userAccount.passwordHash']);
    }

    const membershipId = input.membershipId?.trim();
    if (membershipId) {
      builder.andWhere('beneficiary.memberNumber = :membershipId', {
        membershipId,
      });
    } else {
      const householdCode = input.householdCode?.trim();
      const fullName = this.normalizeFullName(input.fullName);
      if (!householdCode || !fullName) {
        throw new BadRequestException(
          'Provide a membership ID or the household code and full name.',
        );
      }

      builder
        .andWhere('household.householdCode = :householdCode', {
          householdCode,
        })
        .andWhere('LOWER(TRIM(beneficiary.fullName)) = :fullName', {
          fullName,
        });
    }

    const beneficiary = await builder.getOne();
    if (!beneficiary) {
      throw new NotFoundException(
        'No family member matched the provided access details.',
      );
    }

    this.assertBeneficiaryCanLogin(beneficiary);
    return beneficiary;
  }

  private async resolveFamilyMemberAccess(input: {
    phoneNumber: string;
    membershipId?: string;
    householdCode?: string;
    fullName?: string;
    includeSecrets?: boolean;
  }) {
    const phoneNumber = this.normalizePhoneNumber(input.phoneNumber);
    if (!phoneNumber) {
      throw new BadRequestException(
        'A valid Ethiopian phone number is required.',
      );
    }

    const beneficiary = await this.findBeneficiaryForFamilyAccess({
      membershipId: input.membershipId,
      householdCode: input.householdCode,
      fullName: input.fullName,
      phoneNumber,
      includeSecrets: input.includeSecrets,
    });

    const linkedUser = beneficiary.userAccount;
    if (!linkedUser || linkedUser.role !== UserRole.BENEFICIARY) {
      throw new BadRequestException(
        'Independent access is not enabled for this family member yet.',
      );
    }

    if (!linkedUser.isActive || linkedUser.phoneNumber !== phoneNumber) {
      throw new UnauthorizedException(
        'The provided phone number does not match the family member profile.',
      );
    }

    return { beneficiary, linkedUser, phoneNumber };
  }

  private assertBeneficiaryCanLogin(beneficiary: Beneficiary) {
    if (beneficiary.isPrimaryHolder) {
      throw new UnauthorizedException(
        'Household heads should sign in through the primary household login.',
      );
    }

    if (beneficiary.relationshipToHouseholdHead === 'CHILD') {
      throw new UnauthorizedException(
        'Children must access services through the household head account.',
      );
    }

    if (
      !beneficiary.dateOfBirth ||
      this.calculateAge(beneficiary.dateOfBirth) < 18
    ) {
      throw new UnauthorizedException(
        'Independent access is only available for adult beneficiaries.',
      );
    }
  }

  private calculateAge(dateOfBirth: Date) {
    const today = new Date();
    let age = today.getFullYear() - dateOfBirth.getFullYear();
    const monthDelta = today.getMonth() - dateOfBirth.getMonth();
    if (
      monthDelta < 0 ||
      (monthDelta === 0 && today.getDate() < dateOfBirth.getDate())
    ) {
      age -= 1;
    }
    return age;
  }

  private normalizeFullName(value?: string | null) {
    return value?.trim().replace(/\s+/g, ' ').toLowerCase();
  }

  private safeEqual(left: string, right: string) {
    const leftBuffer = Buffer.from(left);
    const rightBuffer = Buffer.from(right);
    if (leftBuffer.length !== rightBuffer.length) {
      return false;
    }
    return timingSafeEqual(leftBuffer, rightBuffer);
  }

  private signAccessToken(payload: AuthTokenPayload) {
    const header = this.base64UrlEncode({ alg: 'HS256', typ: 'JWT' });
    const body = this.base64UrlEncode(payload);
    const signature = createHmac('sha256', this.jwtSecret)
      .update(`${header}.${body}`)
      .digest('base64url');
    return `${header}.${body}.${signature}`;
  }

  private verifyAccessToken(token: string) {
    const [header, body, signature] = token.split('.');
    if (!header || !body || !signature) {
      throw new UnauthorizedException('Malformed access token.');
    }

    const expectedSignature = createHmac('sha256', this.jwtSecret)
      .update(`${header}.${body}`)
      .digest('base64url');

    if (!this.safeEqual(signature, expectedSignature)) {
      throw new UnauthorizedException('Invalid token signature.');
    }

    const payload = JSON.parse(
      Buffer.from(body, 'base64url').toString('utf8'),
    ) as AuthTokenPayload;

    if (!payload.sub || !payload.exp || payload.exp < Date.now() / 1000) {
      throw new UnauthorizedException('Access token expired.');
    }

    return payload;
  }

  private base64UrlEncode(value: Record<string, unknown>) {
    return Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
  }
}
