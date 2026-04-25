import { Column, Entity, ManyToOne, OneToMany } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { ClaimStatus } from '../common/enums/cbhi.enums';
import { Household } from '../households/household.entity';
import { Coverage } from '../coverages/coverage.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { User } from '../users/user.entity';
import { ClaimItem } from '../claim-items/claim-item.entity';
import { Document } from '../documents/document.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';

@Entity('claims')
export class Claim extends AuditableEntity {
  @Column({ length: 80, unique: true })
  claimNumber!: string;

  @Column({ type: 'enum', enum: ClaimStatus, default: ClaimStatus.DRAFT })
  status!: ClaimStatus;

  @Column({ type: 'date' })
  serviceDate!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  submittedAt?: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  reviewedAt?: Date | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  claimedAmount!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  approvedAmount!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: '0.00', nullable: true })
  memberCoPayment?: string | null;

  @Column({ type: 'text', nullable: true })
  decisionNote?: string | null;

  @ManyToOne(() => Household, { nullable: true, onDelete: 'SET NULL' })
  household?: Household | null;

  @ManyToOne(() => Coverage, { nullable: true, onDelete: 'SET NULL' })
  coverage?: Coverage | null;

  @ManyToOne(() => Beneficiary, { nullable: true, onDelete: 'SET NULL' })
  beneficiary?: Beneficiary | null;

  @ManyToOne(() => HealthFacility, (facility) => facility.claims, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  facility?: HealthFacility | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  submittedBy?: User | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  reviewedBy?: User | null;

  @OneToMany(() => ClaimItem, (item) => item.claim, { cascade: true })
  items!: ClaimItem[];

  @Column({ type: 'varchar', length: 32, nullable: true })
  referralCode?: string | null;

  @ManyToOne(() => HealthFacility, { nullable: true, onDelete: 'SET NULL' })
  referredFromFacility?: HealthFacility | null;

  @OneToMany(() => Document, (document) => document.claim)
  documents!: Document[];
}
