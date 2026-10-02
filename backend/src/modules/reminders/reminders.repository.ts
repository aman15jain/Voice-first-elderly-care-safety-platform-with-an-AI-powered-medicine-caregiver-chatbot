import type { DoseStatus, PrismaClient } from '@prisma/client';
import type {
  CreateDoseInput,
  DoseRecord,
  DoseRepository,
  ScheduleForGeneration,
  UpdateDoseStatusInput,
} from './reminders.types';

export class PrismaDoseRepository implements DoseRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async createManySkipDuplicates(inputs: CreateDoseInput[]): Promise<number> {
    if (inputs.length === 0) return 0;
    const result = await this.prisma.medicineDose.createMany({ data: inputs, skipDuplicates: true });
    return result.count;
  }

  findById(id: string): Promise<DoseRecord | null> {
    return this.prisma.medicineDose.findUnique({ where: { id } });
  }

  updateStatus(id: string, data: UpdateDoseStatusInput): Promise<DoseRecord> {
    return this.prisma.medicineDose.update({ where: { id }, data });
  }

  listForElderInRange(elderId: string, from: Date, to: Date): Promise<DoseRecord[]> {
    return this.prisma.medicineDose.findMany({
      where: { elderId, scheduledFor: { gte: from, lte: to } },
      orderBy: { scheduledFor: 'asc' },
    });
  }

  listOverdue(statuses: DoseStatus[], before: Date): Promise<DoseRecord[]> {
    return this.prisma.medicineDose.findMany({
      where: { status: { in: statuses }, scheduledFor: { lt: before } },
    });
  }

  async listActiveSchedules(): Promise<ScheduleForGeneration[]> {
    const schedules = await this.prisma.medicineSchedule.findMany({
      where: { isActive: true, medicine: { isActive: true } },
      select: { id: true, medicineId: true, elderId: true, timesOfDay: true, daysOfWeek: true, startDate: true, endDate: true },
    });
    return schedules;
  }

  async deleteFuturePending(scheduleId: string, after: Date): Promise<number> {
    const result = await this.prisma.medicineDose.deleteMany({
      where: { scheduleId, status: 'SCHEDULED', scheduledFor: { gt: after } },
    });
    return result.count;
  }
}
