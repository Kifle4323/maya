import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { PaymentMethod, PaymentStatus } from '../common/enums/cbhi.enums';
import { Coverage } from '../coverages/coverage.entity';
import { User } from '../users/user.entity';

@Entity('payments')
export class Payment extends AuditableEntity {
  @Column({ length: 80, unique: true })
  transactionReference!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount!: string;

  @Column({ type: 'enum', enum: PaymentMethod })
  method!: PaymentMethod;

  @Column({ type: 'enum', enum: PaymentStatus, default: PaymentStatus.PENDING })
  status!: PaymentStatus;

  @Column({ type: 'varchar', length: 80, nullable: true })
  providerName?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  receiptNumber?: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  paidAt?: Date | null;

  @ManyToOne(() => Coverage, (coverage) => coverage.payments, {
    onDelete: 'CASCADE',
  })
  coverage!: Coverage;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  processedBy?: User | null;
}
