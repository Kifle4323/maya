import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';

@Entity('referrals')
export class Referral extends AuditableEntity {
  @Column({ length: 32, unique: true })
  code!: string;

  @ManyToOne(() => Beneficiary, { nullable: false, onDelete: 'CASCADE' })
  beneficiary!: Beneficiary;

  @ManyToOne(() => HealthFacility, { nullable: false, onDelete: 'CASCADE' })
  issuedByFacility!: HealthFacility;

  @Column({ type: 'timestamptz' })
  issuedAt!: Date;

  @Column({ type: 'timestamptz' })
  expiresAt!: Date;

  @Column({ default: false })
  isUsed!: boolean;

  @Column({ type: 'text', nullable: true })
  diagnosis?: string | null;

  @Column({ type: 'text', nullable: true })
  reasonForReferral?: string | null;
}
