import { Column, Entity } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';

@Entity('verifications')
export class Verification extends AuditableEntity {
  @Column({ nullable: true })
  userId?: string;

  @Column({ length: 50 })
  documentType!: string;

  @Column({ nullable: true })
  extractedName?: string;

  @Column({ nullable: true })
  extractedId?: string;

  @Column({ type: 'date', nullable: true })
  expiryDate?: Date;

  @Column({ type: 'float', default: 0 })
  matchScore!: number;

  @Column({ type: 'float', default: 0 })
  confidenceScore!: number;

  /** 'approved' | 'rejected' | 'manual_review' */
  @Column({ length: 20 })
  status!: string;

  @Column({ type: 'text', nullable: true })
  rawText?: string;

  @Column({ nullable: true })
  fileUrl?: string;

  @Column({ type: 'jsonb', default: [] })
  reasons!: string[];

  @Column({ default: false })
  isDemo!: boolean;
}
