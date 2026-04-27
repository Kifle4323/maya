import { Column, Entity } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';

/**
 * Persists the result of a document verification attempt.
 * Column names match the `verifications` table created by the schema-fix script.
 */
@Entity('verifications')
export class Verification extends AuditableEntity {
  /** FK to users.id — nullable because anonymous verifications are allowed */
  @Column({ type: 'varchar', nullable: true })
  userId?: string | null;

  /** 'ID_CARD' | 'INDIGENT_PROOF' */
  @Column({ type: 'varchar', length: 80 })
  documentType!: string;

  /** 'approved' | 'rejected' | 'manual_review' */
  @Column({ type: 'varchar', length: 32 })
  status!: string;

  /** Overall confidence score 0–1 */
  @Column({ type: 'decimal', precision: 5, scale: 4, default: 0 })
  confidence!: number;

  /** Structured data extracted from the document (name, idNumber, expiryDate, etc.) */
  @Column({ type: 'jsonb', nullable: true })
  extractedData?: Record<string, unknown> | null;

  /** List of validation error messages */
  @Column({ type: 'jsonb', default: [] })
  validationErrors!: string[];
}
