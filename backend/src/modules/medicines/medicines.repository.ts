import type { PrismaClient } from '@prisma/client';
import type {
  CreateMedicineInput,
  CreateScheduleInput,
  MedicineRecord,
  MedicineScheduleRecord,
  MedicinesRepository,
  UpdateMedicineInput,
  UpdateScheduleInput,
} from './medicines.types';

export class PrismaMedicinesRepository implements MedicinesRepository {
  constructor(private readonly prisma: PrismaClient) {}

  createMedicine(input: CreateMedicineInput): Promise<MedicineRecord> {
    return this.prisma.medicine.create({ data: input });
  }

  findMedicineById(id: string): Promise<MedicineRecord | null> {
    return this.prisma.medicine.findUnique({ where: { id } });
  }

  listMedicinesForElder(elderId: string, includeInactive: boolean): Promise<MedicineRecord[]> {
    return this.prisma.medicine.findMany({
      where: { elderId, ...(includeInactive ? {} : { isActive: true }) },
      orderBy: { createdAt: 'desc' },
    });
  }

  updateMedicine(id: string, input: UpdateMedicineInput): Promise<MedicineRecord> {
    return this.prisma.medicine.update({ where: { id }, data: input });
  }

  deactivateMedicine(id: string): Promise<MedicineRecord> {
    return this.prisma.$transaction(async (tx) => {
      await tx.medicineSchedule.updateMany({ where: { medicineId: id }, data: { isActive: false } });
      return tx.medicine.update({ where: { id }, data: { isActive: false } });
    });
  }

  createSchedule(input: CreateScheduleInput): Promise<MedicineScheduleRecord> {
    return this.prisma.medicineSchedule.create({ data: input });
  }

  findScheduleById(id: string): Promise<MedicineScheduleRecord | null> {
    return this.prisma.medicineSchedule.findUnique({ where: { id } });
  }

  listSchedulesForElder(elderId: string, medicineId?: string): Promise<MedicineScheduleRecord[]> {
    return this.prisma.medicineSchedule.findMany({
      where: { elderId, ...(medicineId ? { medicineId } : {}) },
      orderBy: { createdAt: 'desc' },
    });
  }

  updateSchedule(id: string, input: UpdateScheduleInput): Promise<MedicineScheduleRecord> {
    return this.prisma.medicineSchedule.update({ where: { id }, data: input });
  }
}
