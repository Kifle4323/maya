import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { CoverageStatus, MembershipTier, MembershipType } from '../common/enums/cbhi.enums';
import { Location } from '../locations/location.entity';
import { User } from '../users/user.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Coverage } from '../coverages/coverage.entity';

@Entity('households')
export class Household extends AuditableEntity {
  @Column({ length: 80, unique: true })
  householdCode!: string;

  @Column({ type: 'varchar', length: 120 })
  region!: string;

  @Column({ type: 'varchar', length: 120 })
  zone!: string;

  @Column({ type: 'varchar', length: 120 })
  woreda!: string;

  @Column({ type: 'varchar', length: 120 })
  kebele!: string;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phoneNumber?: string | null;

  @Column({
    type: 'enum',
    enum: MembershipType,
    nullable: true,
  })
  membershipType?: MembershipType | null;

  @Column({
    type: 'enum',
    enum: CoverageStatus,
    default: CoverageStatus.ACTIVE,
  })
  coverageStatus!: CoverageStatus;

  @Column({ type: 'int', default: 0 })
  memberCount!: number;

  /** Indigent status string (e.g. 'approved', 'pending', 'rejected') */
  @Column({ type: 'varchar', length: 80, nullable: true })
  indigentStatus?: string | null;

  /** Employment status of the household head */
  @Column({ type: 'varchar', length: 80, nullable: true })
  headEmploymentStatus?: string | null;

  /** General employment status of the household */
  @Column({ type: 'varchar', length: 80, nullable: true })
  employmentStatus?: string | null;

  /** Membership tier for premium calculation */
  @Column({ type: 'enum', enum: MembershipTier, nullable: true })
  membershipTier?: MembershipTier | null;

  @ManyToOne(() => Location, { nullable: true, onDelete: 'SET NULL' })
  location?: Location | null;

  @OneToOne(() => User, (user) => user.household, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn()
  headUser?: User | null;

  @OneToMany(() => Beneficiary, (beneficiary) => beneficiary.household)
  beneficiaries!: Beneficiary[];

  @OneToMany(() => Coverage, (coverage) => coverage.household)
  coverages!: Coverage[];
}
