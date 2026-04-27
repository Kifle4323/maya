import { Column, Entity, ManyToOne, OneToMany } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { CoverageStatus, MembershipType } from '../common/enums/cbhi.enums';
import { BenefitPackage } from '../benefit-packages/benefit-package.entity';
import { Household } from '../households/household.entity';
import { Payment } from '../payments/payment.entity';

@Entity('coverages')
export class Coverage extends AuditableEntity {
  @Column({ length: 80, unique: true })
  coverageNumber!: string;

  @Column({ type: 'date' })
  startDate!: Date;

  @Column({ type: 'date' })
  endDate!: Date;

  @Column({
    type: 'enum',
    enum: CoverageStatus,
    default: CoverageStatus.ACTIVE,
  })
  status!: CoverageStatus;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  premiumAmount!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  paidAmount!: string;

  @Column({ type: 'date', nullable: true })
  nextRenewalDate?: Date | null;

  @Column({ type: 'date', nullable: true })
  waitingPeriodEndsAt?: Date | null;

  @Column({ type: 'date', nullable: true })
  claimsEligibleFrom?: Date | null;

  @Column({ type: 'enum', enum: MembershipType, nullable: true })
  membershipType?: MembershipType | null;

  @ManyToOne(() => Household, (household) => household.coverages, {
    onDelete: 'CASCADE',
  })
  household!: Household;

  @ManyToOne(() => BenefitPackage, { nullable: true, eager: false })
  benefitPackage?: BenefitPackage | null;

  @OneToMany(() => Payment, (payment) => payment.coverage)
  payments!: Payment[];
}
