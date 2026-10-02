import type { Notification, NotificationType } from '@prisma/client';

export type NotificationRecord = Notification;

export interface CreateNotificationInput {
  recipientId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

export interface NotificationsRepository {
  create(input: CreateNotificationInput): Promise<NotificationRecord>;
  listForUser(userId: string, unreadOnly: boolean): Promise<NotificationRecord[]>;
  findById(id: string): Promise<NotificationRecord | null>;
  markRead(id: string): Promise<NotificationRecord>;
}
