import { Column, Entity, ManyToOne, OneToMany } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';

export enum LocationLevel {
  REGION = 'REGION',
  ZONE = 'ZONE',
  WOREDA = 'WOREDA',
  KEBELE = 'KEBELE',
}

@Entity('locations')
export class Location extends AuditableEntity {
  @Column({ length: 160 })
  name!: string;

  @Column({ type: 'varchar', length: 160, nullable: true })
  nameAmharic?: string | null;

  @Column({ length: 80, unique: true })
  code!: string;

  @Column({ type: 'enum', enum: LocationLevel })
  level!: LocationLevel;

  @Column({ default: true })
  isActive!: boolean;

  @ManyToOne(() => Location, (location) => location.children, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  parent?: Location | null;

  @OneToMany(() => Location, (location) => location.parent)
  children!: Location[];
}
