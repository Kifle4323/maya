import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import {
  NotificationType,
  PreferredLanguage,
} from '../common/enums/cbhi.enums';
import { User } from '../users/user.entity';

@Entity('notifications')
export class Notification extends AuditableEntity {
  @Column({ type: 'enum', enum: NotificationType })
  type!: NotificationType;

  @Column({ length: 160 })
  title!: string;

  @Column({ type: 'text' })
  message!: string;

  @Column({ type: 'jsonb', nullable: true })
  payload?: Record<string, unknown> | null;

  @Column({ type: 'timestamptz', nullable: true })
  readAt?: Date | null;

  @Column({ default: false })
  isRead!: boolean;

  @Column({
    type: 'enum',
    enum: PreferredLanguage,
    default: PreferredLanguage.ENGLISH,
  })
  language!: PreferredLanguage;

  @ManyToOne(() => User, { nullable: true, onDelete: 'CASCADE' })
  recipient?: User | null;
}
