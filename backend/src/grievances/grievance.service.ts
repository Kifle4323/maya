import { Injectable, NotFoundException, ForbiddenException, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Grievance, GrievanceStatus, GrievanceType } from './grievance.entity';
import { User } from '../users/user.entity';
import { Notification } from '../notifications/notification.entity';
import { NotificationService } from '../notifications/notification.service';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { NotificationType, UserRole } from '../common/enums/cbhi.enums';

@Injectable()
export class GrievanceService {
  constructor(
    @InjectRepository(Grievance)
    private readonly grievanceRepo: Repository<Grievance>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    private readonly notificationService: NotificationService,
    @Optional() private readonly wsGateway?: NotificationsGateway,
  ) {}

  async submitGrievance(userId: string, dto: {
    type: GrievanceType;
    subject: string;
    description: string;
    referenceId?: string;
    referenceType?: string;
  }) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');

    const grievance = await this.grievanceRepo.save(
      this.grievanceRepo.create({
        type: dto.type,
        subject: dto.subject.trim(),
        description: dto.description.trim(),
        referenceId: dto.referenceId,
        referenceType: dto.referenceType,
        status: GrievanceStatus.OPEN,
        submittedBy: user,
      }),
    );

    return this.toSummary(grievance);
  }

  async getMyGrievances(userId: string) {
    const grievances = await this.grievanceRepo.find({
      where: { submittedBy: { id: userId } },
      relations: ['submittedBy', 'assignedTo'],
      order: { createdAt: 'DESC' },
    });
    return { grievances: grievances.map((g) => this.toSummary(g)) };
  }

  async getAllGrievances(adminUserId: string, status?: string) {
    await this.assertAdminAccess(adminUserId);
    const qb = this.grievanceRepo
      .createQueryBuilder('g')
      .leftJoinAndSelect('g.submittedBy', 'submittedBy')
      .leftJoinAndSelect('g.assignedTo', 'assignedTo')
      .orderBy('g.createdAt', 'DESC')
      .take(200);

    if (status) qb.where('g.status = :status', { status });

    const grievances = await qb.getMany();
    return { grievances: grievances.map((g) => this.toSummary(g)) };
  }

  async updateGrievance(adminUserId: string, grievanceId: string, dto: {
    status?: GrievanceStatus;
    resolution?: string;
    assignedToId?: string;
  }) {
    await this.assertAdminAccess(adminUserId);
    const grievance = await this.grievanceRepo.findOne({
      where: { id: grievanceId },
      relations: ['submittedBy', 'assignedTo'],
    });
    if (!grievance) throw new NotFoundException('Grievance not found.');

    if (dto.status) grievance.status = dto.status;
    if (dto.resolution) {
      grievance.resolution = dto.resolution;
      if (dto.status === GrievanceStatus.RESOLVED) {
        grievance.resolvedAt = new Date();
      }
    }
    if (dto.assignedToId) {
      const assignee = await this.userRepo.findOne({ where: { id: dto.assignedToId } });
      if (assignee) grievance.assignedTo = assignee;
    }

    await this.grievanceRepo.save(grievance);

    // B4: Notify member when grievance is resolved — FCM push + persistent notification
    if (dto.status === GrievanceStatus.RESOLVED && grievance.submittedBy) {
      try {
        await this.notificationService.createAndSend(
          grievance.submittedBy,
          NotificationType.SYSTEM_ALERT,
          'Grievance resolved',
          `Your grievance '${grievance.subject}' has been resolved: ${dto.resolution ?? 'See resolution details.'}`,
          { grievanceId: grievance.id, subject: grievance.subject },
        );
        this.wsGateway?.pushToUser(grievance.submittedBy.id, 'notification', {
          type: NotificationType.SYSTEM_ALERT,
          title: 'Grievance resolved',
          message: `Your grievance '${grievance.subject}' has been resolved.`,
        });
      } catch (err) {
        console.error(`Failed to notify grievance resolution: ${(err as Error).message}`);
      }
    }

    return this.toSummary(grievance);
  }

  private async assertAdminAccess(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user || (user.role !== UserRole.CBHI_OFFICER && user.role !== UserRole.SYSTEM_ADMIN)) {
      throw new ForbiddenException('Admin access required.');
    }
  }

  private toSummary(g: Grievance) {
    return {
      id: g.id,
      type: g.type,
      status: g.status,
      subject: g.subject,
      description: g.description,
      referenceId: g.referenceId,
      referenceType: g.referenceType,
      resolution: g.resolution,
      resolvedAt: g.resolvedAt instanceof Date
        ? g.resolvedAt.toISOString()
        : ((g.resolvedAt as unknown as string)?.toString() ?? null),
      submittedBy: g.submittedBy ? {
        id: g.submittedBy.id,
        name: [g.submittedBy.firstName, g.submittedBy.lastName].filter(Boolean).join(' '),
        phone: g.submittedBy.phoneNumber,
      } : null,
      assignedTo: g.assignedTo ? {
        id: g.assignedTo.id,
        name: [g.assignedTo.firstName, g.assignedTo.lastName].filter(Boolean).join(' '),
      } : null,
      createdAt: g.createdAt instanceof Date
        ? g.createdAt.toISOString()
        : ((g.createdAt as unknown as string)?.toString() ?? null),
    };
  }
}
