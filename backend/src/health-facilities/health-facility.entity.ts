import { Column, Entity, ManyToOne, OneToMany } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { Location } from '../locations/location.entity';
import { FacilityService } from '../facility-services/facility-service.entity';
import { FacilityUser } from '../facility-users/facility-user.entity';
import { Claim } from '../claims/claim.entity';

@Entity('health_facilities')
export class HealthFacility extends AuditableEntity {
  @Column({ length: 160 })
  name!: string;

  @Column({ type: 'varchar', length: 80, nullable: true, unique: true })
  facilityCode?: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  licenseNumber?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  serviceLevel?: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phoneNumber?: string | null;

  @Column({ type: 'varchar', length: 160, nullable: true })
  email?: string | null;

  @Column({ type: 'varchar', length: 250, nullable: true })
  addressLine?: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 6, nullable: true })
  latitude?: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 6, nullable: true })
  longitude?: string | null;

  @Column({ default: true })
  isAccredited!: boolean;

  @ManyToOne(() => Location, { nullable: true, onDelete: 'SET NULL' })
  location?: Location | null;

  @OneToMany(() => FacilityService, (service) => service.facility)
  services!: FacilityService[];

  @OneToMany(() => FacilityUser, (facilityUser) => facilityUser.facility)
  facilityUsers!: FacilityUser[];

  @OneToMany(() => Claim, (claim) => claim.facility)
  claims!: Claim[];
}
