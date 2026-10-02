import type { PrismaClient } from '@prisma/client';
import type { ActivityRepository } from './activity.types';

export class PrismaActivityRepository implements ActivityRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async hasAppOpenedEventInRange(elderId: string, from: Date, to: Date): Promise<boolean> {
    const count = await this.prisma.activityEvent.count({
      where: { elderId, type: 'APP_OPENED', occurredAt: { gte: from, lte: to } },
    });
    return count > 0;
  }

  async createAppOpenedEvent(elderId: string, occurredAt: Date): Promise<void> {
    await this.prisma.activityEvent.create({ data: { elderId, type: 'APP_OPENED', occurredAt } });
  }

  async listMedicineInteractionDates(elderId: string, from: Date, to: Date): Promise<Date[]> {
    const doses = await this.prisma.medicineDose.findMany({
      where: { elderId, respondedAt: { gte: from, lte: to } },
      select: { respondedAt: true },
    });
    return doses.map((d) => d.respondedAt).filter((d): d is Date => d !== null);
  }

  async listGameSessionDates(elderId: string, from: Date, to: Date): Promise<Date[]> {
    const sessions = await this.prisma.gameSession.findMany({
      where: { elderId, createdAt: { gte: from, lte: to } },
      select: { createdAt: true },
    });
    return sessions.map((s) => s.createdAt);
  }
}
