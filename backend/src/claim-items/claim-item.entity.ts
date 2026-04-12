import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { Claim } from '../claims/claim.entity';

@Entity('claim_items')
export class ClaimItem extends AuditableEntity {
  @Column({ length: 160 })
  serviceName!: string;

  @Column({ type: 'int', default: 1 })
  quantity!: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  unitPrice!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  totalPrice!: string;

  @Column({ type: 'varchar', length: 250, nullable: true })
  notes?: string | null;

  @ManyToOne(() => Claim, (claim) => claim.items, { onDelete: 'CASCADE' })
  claim!: Claim;
}
