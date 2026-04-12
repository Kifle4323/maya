import { Column, Entity, JoinColumn, ManyToOne, OneToOne } from 'typeorm';
import { AuditableEntity } from '../common/entities/auditable.entity';
import { FacilityUserRole } from '../common/enums/cbhi.enums';
import { HealthFacility } from '../health-facilities/health-facility.entity';
import { User } from '../users/user.entity';

@Entity('facility_users')
export class FacilityUser extends AuditableEntity {
  @Column({
    type: 'enum',
    enum: FacilityUserRole,
    default: FacilityUserRole.REGISTRAR,
  })
  role!: FacilityUserRole;

  @Column({ default: true })
  isActive!: boolean;

  @ManyToOne(() => HealthFacility, (facility) => facility.facilityUsers, {
    onDelete: 'CASCADE',
  })
  facility!: HealthFacility;

  @OneToOne(() => User, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn()
  user!: User;
}
