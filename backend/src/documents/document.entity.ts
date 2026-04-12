import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { DocumentType } from '../common/enums/cbhi.enums';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { Claim } from '../claims/claim.entity';

@Entity('documents')
export class Document extends AuditableEntity {
  @Column({ type: 'enum', enum: DocumentType, default: DocumentType.OTHER })
  type!: DocumentType;

  @Column({ length: 180 })
  fileName!: string;

  @Column({ length: 500 })
  fileUrl!: string;

  @Column({ type: 'varchar', length: 120, nullable: true })
  mimeType?: string | null;

  @Column({ default: false })
  isVerified!: boolean;

  @ManyToOne(() => Beneficiary, (beneficiary) => beneficiary.documents, {
    nullable: true,
    onDelete: 'CASCADE',
  })
  beneficiary?: Beneficiary | null;

  @ManyToOne(() => Claim, (claim) => claim.documents, {
    nullable: true,
    onDelete: 'CASCADE',
  })
  claim?: Claim | null;
}
