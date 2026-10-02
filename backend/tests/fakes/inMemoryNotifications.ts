import { randomUUID } from 'node:crypto';
import type { CreateNotificationInput, NotificationRecord, NotificationsRepository } from '../../src/modules/notifications/notifications.types';

export class InMemoryNotificationsRepository implements NotificationsRepository {
  readonly notifications = new Map<string, NotificationRecord>();

  async create(input: CreateNotificationInput): Promise<NotificationRecord> {
    const notification: NotificationRecord = {
      id: randomUUID(),
      recipientId: input.recipientId,
      type: input.type,
      title: input.title,
      body: input.body,
      data: (input.data ?? null) as NotificationRecord['data'],
      readAt: null,
      createdAt: new Date(),
    };
    this.notifications.set(notification.id, notification);
    return notification;
  }

  async listForUser(userId: string, unreadOnly: boolean): Promise<NotificationRecord[]> {
    return [...this.notifications.values()]
      .filter((n) => n.recipientId === userId && (!unreadOnly || !n.readAt))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async findById(id: string): Promise<NotificationRecord | null> {
    return this.notifications.get(id) ?? null;
  }

  async markRead(id: string): Promise<NotificationRecord> {
    const notification = this.notifications.get(id);
    if (!notification) throw new Error('notification not found');
    notification.readAt = new Date();
    return notification;
  }
}
