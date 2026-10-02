import { AppError } from '../../common/errors/AppError';
import type { CreateNotificationInput, NotificationRecord, NotificationsRepository } from './notifications.types';

/**
 * In-app notifications only. There is no push/SMS provider wired up — that would need a
 * real FCM/APNs/Twilio account, which this project doesn't have. This is the genuine,
 * working default (poll GET /api/notifications), not a placeholder for one.
 */
export class NotificationsService {
  constructor(private readonly repo: NotificationsRepository) {}

  notify(input: CreateNotificationInput): Promise<NotificationRecord> {
    return this.repo.create(input);
  }

  list(userId: string, unreadOnly: boolean): Promise<NotificationRecord[]> {
    return this.repo.listForUser(userId, unreadOnly);
  }

  async markRead(userId: string, id: string): Promise<NotificationRecord> {
    const notification = await this.repo.findById(id);
    if (!notification) throw AppError.notFound('Notification not found');
    if (notification.recipientId !== userId) throw AppError.forbidden();
    if (notification.readAt) return notification;
    return this.repo.markRead(id);
  }
}
