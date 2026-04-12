import { Column, Entity, ManyToOne, JoinColumn, Index, AfterLoad } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import {
  IndigentApplicationStatus,
  IndigentEmploymentStatus,
} from '../common/enums/cbhi.enums';
import { User } from '../users/user.entity';

@Entity('indigent_applications')
export class IndigentApplication extends AuditableEntity {
  // FK relation to User — TypeORM auto-creates the userId column via @JoinColumn
  @Index()
  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL', eager: false })
  @JoinColumn({ name: 'userId' })
  user?: User | null;

  // Virtual property — populated from user relation or raw column
  userId?: string | null;

  @AfterLoad()
  setUserId() {
    if (this.user?.id) {
      this.userId = this.user.id;
    }
  }

  @Column({ type: 'int', default: 0 })
  income!: number;

  @Column({ type: 'enum', enum: IndigentEmploymentStatus })
  employmentStatus!: IndigentEmploymentStatus;

  @Column({ type: 'int', default: 1 })
  familySize!: number;

  @Column({ type: 'boolean', default: false })
  hasProperty!: boolean;

  @Column({ type: 'boolean', default: false })
  disabilityStatus!: boolean;

  @Column({ type: 'jsonb', default: [] })
  documents!: string[];

  @Column({ type: 'jsonb', nullable: true })
  documentMeta?: Array<{
    url: string;
    documentType?: string;
    detectedDate?: string;
    isExpired?: boolean;
    validationSummary?: string;
  }> | null;

  @Column({ type: 'enum', enum: IndigentApplicationStatus, default: IndigentApplicationStatus.PENDING })
  status!: IndigentApplicationStatus;

  @Column({ type: 'int', default: 0 })
  score!: number;

  @Column({ type: 'text', default: '' })
  reason!: string;

  @Column({ type: 'boolean', default: false })
  hasExpiredDocuments!: boolean;
}
