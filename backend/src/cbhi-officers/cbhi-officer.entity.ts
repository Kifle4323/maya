import { Column, Entity, JoinColumn, ManyToOne, OneToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { User } from '../users/user.entity';
import { Location } from '../locations/location.entity';

@Entity('cbhi_officers')
export class CBHIOfficer extends AuditableEntity {
  @Column({ length: 160 })
  officeName!: string;

  @Column({ type: 'varchar', length: 80, nullable: true })
  officeLevel?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  positionTitle?: string | null;

  @Column({ default: true })
  canApproveClaims!: boolean;

  @Column({ default: true })
  canManageSettings!: boolean;

  @ManyToOne(() => Location, { nullable: true, onDelete: 'SET NULL' })
  officeLocation?: Location | null;

  @OneToOne(() => User, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn()
  user!: User;
}
