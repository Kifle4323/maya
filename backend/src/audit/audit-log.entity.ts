import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export enum AuditAction {
  CREATE = 'CREATE',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE',
  LOGIN = 'LOGIN',
  LOGOUT = 'LOGOUT',
  PAYMENT = 'PAYMENT',
  CLAIM_SUBMIT = 'CLAIM_SUBMIT',
  CLAIM_REVIEW = 'CLAIM_REVIEW',
  INDIGENT_APPLY = 'INDIGENT_APPLY',
  INDIGENT_REVIEW = 'INDIGENT_REVIEW',
  COVERAGE_RENEW = 'COVERAGE_RENEW',
  MEMBER_ADD = 'MEMBER_ADD',
  MEMBER_REMOVE = 'MEMBER_REMOVE',
  SETTINGS_UPDATE = 'SETTINGS_UPDATE',
}

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'varchar', length: 36, nullable: true })
  userId?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  userEmail?: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  userRole?: string | null;

  @Column({ type: 'enum', enum: AuditAction })
  action!: AuditAction;

  @Index()
  @Column({ type: 'varchar', length: 80 })
  entityType!: string;

  @Column({ type: 'varchar', length: 36, nullable: true })
  entityId?: string | null;

  @Column({ type: 'jsonb', nullable: true })
  oldValue?: Record<string, unknown> | null;

  @Column({ type: 'jsonb', nullable: true })
  newValue?: Record<string, unknown> | null;

  @Column({ type: 'varchar', length: 45, nullable: true })
  ipAddress?: string | null;

  @Column({ type: 'varchar', length: 250, nullable: true })
  userAgent?: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
