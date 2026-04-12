import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditAction, AuditLog } from './audit-log.entity';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(
    @InjectRepository(AuditLog)
    private readonly auditRepository: Repository<AuditLog>,
  ) {}

  async log(input: {
    userId?: string;
    userEmail?: string;
    userRole?: string;
    action: AuditAction;
    entityType: string;
    entityId?: string;
    oldValue?: Record<string, unknown>;
    newValue?: Record<string, unknown>;
    ipAddress?: string;
    userAgent?: string;
  }): Promise<void> {
    try {
      await this.auditRepository.save(
        this.auditRepository.create({
          userId: input.userId,
          userEmail: input.userEmail,
          userRole: input.userRole,
          action: input.action,
          entityType: input.entityType,
          entityId: input.entityId,
          oldValue: input.oldValue ?? null,
          newValue: input.newValue ?? null,
          ipAddress: input.ipAddress,
          userAgent: input.userAgent,
        }),
      );
    } catch (error) {
      // Never let audit logging break the main flow
      this.logger.error(`Audit log failed: ${(error as Error).message}`);
    }
  }

  async getLogsForEntity(entityType: string, entityId: string) {
    return this.auditRepository.find({
      where: { entityType, entityId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async getLogsForUser(userId: string) {
    return this.auditRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }
}
