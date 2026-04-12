import { Column, Entity, Index } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';

@Entity('system_settings')
export class SystemSetting extends AuditableEntity {
  @Index({ unique: true })
  @Column({ type: 'varchar', length: 120 })
  key!: string;

  @Column({ type: 'varchar', length: 160 })
  label!: string;

  @Column({ type: 'text', nullable: true })
  description?: string | null;

  @Column({ type: 'jsonb', default: {} })
  value!: Record<string, unknown>;

  @Column({ default: false })
  isSensitive!: boolean;
}
