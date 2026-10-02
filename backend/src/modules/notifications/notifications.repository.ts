import type { Prisma, PrismaClient } from '@prisma/client';
import type { CreateNotificationInput, NotificationRecord, NotificationsRepository } from './notifications.types';

export class PrismaNotificationsRepository implements NotificationsRepository {
  constructor(private readonly prisma: PrismaClient) {}

  create(input: CreateNotificationInput): Promise<NotificationRecord> {
    return this.prisma.notification.create({
      data: {
        recipientId: input.recipientId,
        type: input.type,
        title: input.title,
        body: input.body,
        data: input.data as Prisma.InputJsonValue | undefined,
      },
    });
  }

  listForUser(userId: string, unreadOnly: boolean): Promise<NotificationRecord[]> {
    return this.prisma.notification.findMany({
      where: { recipientId: userId, ...(unreadOnly ? { readAt: null } : {}) },
      orderBy: { createdAt: 'desc' },
    });
  }

  findById(id: string): Promise<NotificationRecord | null> {
    return this.prisma.notification.findUnique({ where: { id } });
  }

  markRead(id: string): Promise<NotificationRecord> {
    return this.prisma.notification.update({ where: { id }, data: { readAt: new Date() } });
  }
}
