import {
  DeleteDateColumn,
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import {
  Gender,
  IdentityDocumentType,
  RelationshipToHouseholdHead,
} from '../common/enums/cbhi.enums';
import { Household } from '../households/household.entity';
import { User } from '../users/user.entity';
import { Document } from '../documents/document.entity';
import { Claim } from '../claims/claim.entity';

@Entity('beneficiaries')
export class Beneficiary extends AuditableEntity {
  /** Soft-delete: set when a beneficiary is removed so claim history is preserved */
  @DeleteDateColumn({ type: 'timestamptz', nullable: true })
  deletedAt?: Date | null;

  @Column({ length: 80, unique: true })
  memberNumber!: string;

  @Column({ length: 160 })
  fullName!: string;

  @Column({ type: 'varchar', length: 32, nullable: true, unique: true })
  nationalId?: string | null;

  @Column({ type: 'date', nullable: true })
  dateOfBirth?: Date | null;

  @Column({ type: 'int', nullable: true })
  age?: number | null;

  @Column({ type: 'enum', enum: Gender, nullable: true })
  gender?: Gender | null;

  @Column({ type: 'varchar', length: 64, nullable: true, unique: true })
  birthCertificateRef?: string | null;

  @Column({
    type: 'enum',
    enum: IdentityDocumentType,
    nullable: true,
  })
  identityType?: IdentityDocumentType | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  identityNumber?: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phoneNumber?: string | null;

  @Column({
    type: 'enum',
    enum: RelationshipToHouseholdHead,
    default: RelationshipToHouseholdHead.OTHER,
  })
  relationshipToHouseholdHead!: RelationshipToHouseholdHead;

  @Column({ default: false })
  isPrimaryHolder!: boolean;

  @Column({ default: true })
  isEligible!: boolean;

  /** Optional membership ID for cross-system reference */
  @Column({ type: 'varchar', length: 80, nullable: true })
  membershipId?: string | null;

  @ManyToOne(() => Household, (household) => household.beneficiaries, {
    onDelete: 'CASCADE',
  })
  household!: Household;

  @OneToOne(() => User, (user) => user.beneficiaryProfile, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn()
  userAccount?: User | null;

  @OneToMany(() => Document, (document) => document.beneficiary)
  documents!: Document[];

  @OneToMany(() => Claim, (claim) => claim.beneficiary)
  claims!: Claim[];
}
