import { Column, Entity, ManyToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { HealthFacility } from '../health-facilities/health-facility.entity';

@Entity('facility_services')
export class FacilityService extends AuditableEntity {
  @Column({ length: 120 })
  serviceName!: string;

  @Column({ type: 'varchar', length: 80, nullable: true })
  serviceCode?: string | null;

  @Column({ type: 'varchar', length: 250, nullable: true })
  description?: string | null;

  @Column({ default: true })
  isActive!: boolean;

  @ManyToOne(() => HealthFacility, (facility) => facility.services, {
    onDelete: 'CASCADE',
  })
  facility!: HealthFacility;
}
