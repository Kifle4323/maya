import { Column, Entity, Index, OneToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import {
  IdentityDocumentType,
  IdentityVerificationStatus,
  PreferredLanguage,
  UserRole,
} from '../common/enums/cbhi.enums';
import { Household } from '../households/household.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';

@Entity('users')
export class User extends AuditableEntity {
  @Index({ unique: true })
  @Column({ type: 'varchar', length: 32, nullable: true })
  nationalId?: string | null;

  @Column({ length: 120 })
  firstName!: string;

  @Column({ type: 'varchar', length: 120, nullable: true })
  middleName?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  lastName?: string | null;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 32, nullable: true })
  phoneNumber?: string | null;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 160, nullable: true })
  email?: string | null;

  @Column({ type: 'varchar', nullable: true, select: false })
  passwordHash?: string | null;

  @Column({ type: 'varchar', nullable: true, select: false })
  oneTimeCodeHash?: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true, select: false })
  oneTimeCodePurpose?: string | null;

  @Column({ type: 'varchar', length: 160, nullable: true, select: false })
  oneTimeCodeTarget?: string | null;

  @Column({ type: 'timestamptz', nullable: true, select: false })
  oneTimeCodeExpiresAt?: Date | null;

  @Column({
    type: 'enum',
    enum: IdentityDocumentType,
    nullable: true,
  })
  identityType?: IdentityDocumentType | null;

  @Column({ type: 'varchar', length: 64, nullable: true, unique: true })
  identityNumber?: string | null;

  @Column({
    type: 'enum',
    enum: IdentityVerificationStatus,
    default: IdentityVerificationStatus.PENDING,
  })
  identityVerificationStatus!: IdentityVerificationStatus;

  @Column({ type: 'timestamptz', nullable: true })
  identityVerifiedAt?: Date | null;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.BENEFICIARY })
  role!: UserRole;

  @Column({
    type: 'enum',
    enum: PreferredLanguage,
    default: PreferredLanguage.ENGLISH,
  })
  preferredLanguage!: PreferredLanguage;

  @Column({ default: true })
  isActive!: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  lastLoginAt?: Date | null;

  // ── Refresh token ──────────────────────────────────────────────────────────
  @Index()
  @Column({ type: 'varchar', nullable: true, select: false })
  refreshTokenHash?: string | null;

  @Column({ type: 'timestamptz', nullable: true, select: false })
  refreshTokenExpiresAt?: Date | null;

  @OneToOne(() => Household, (household) => household.headUser)
  household?: Household | null;

  @OneToOne(() => Beneficiary, (beneficiary) => beneficiary.userAccount)
  beneficiaryProfile?: Beneficiary | null;
}
