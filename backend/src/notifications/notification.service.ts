import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotificationType, PreferredLanguage } from '../common/enums/cbhi.enums';
import { Notification } from './notification.entity';
import { User } from '../users/user.entity';
import { FcmService } from './fcm.service';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    private readonly fcmService: FcmService,
  ) {}

  async createAndSend(
    recipient: User,
    type: NotificationType,
    title: string,
    message: string,
    payload?: Record<string, unknown>,
  ): Promise<void> {
    // Save to DB
    await this.notificationRepository.save(
      this.notificationRepository.create({
        recipient,
        type,
        title,
        message,
        payload: payload ?? null,
        language: recipient.preferredLanguage ?? PreferredLanguage.ENGLISH,
        isRead: false,
      }),
    );

    // Send push notification if FCM token available
    const fcmToken = (recipient as User & { fcmToken?: string }).fcmToken;
    if (fcmToken) {
      await this.fcmService.sendToDevice(
        fcmToken,
        title,
        message,
        payload ? Object.fromEntries(
          Object.entries(payload).map(([k, v]) => [k, String(v)]),
        ) : undefined,
      );
    }
  }

  async getForUser(userId: string) {
    const notifications = await this.notificationRepository.find({
      where: { recipient: { id: userId } },
      order: { createdAt: 'DESC' },
      take: 50,
    });

    return notifications.map((n) => ({
      id: n.id,
      type: n.type,
      title: n.title,
      message: n.message,
      payload: n.payload,
      isRead: n.isRead,
      readAt: n.readAt?.toISOString() ?? null,
      createdAt: n.createdAt.toISOString(),
    }));
  }

  async markRead(userId: string, notificationId: string): Promise<void> {
    await this.notificationRepository.update(
      { id: notificationId, recipient: { id: userId } },
      { isRead: true, readAt: new Date() },
    );
  }
}
