import { randomUUID } from 'node:crypto';
import type {
  CreateMedicineInput,
  CreateScheduleInput,
  MedicineRecord,
  MedicinesRepository,
  MedicineScheduleRecord,
  UpdateMedicineInput,
  UpdateScheduleInput,
} from '../../src/modules/medicines/medicines.types';

export class InMemoryMedicinesRepository implements MedicinesRepository {
  readonly medicines = new Map<string, MedicineRecord>();
  readonly schedules = new Map<string, MedicineScheduleRecord>();

  async createMedicine(input: CreateMedicineInput): Promise<MedicineRecord> {
    const now = new Date();
    const medicine: MedicineRecord = {
      id: randomUUID(),
      elderId: input.elderId,
      name: input.name,
      dosage: input.dosage,
      instructions: input.instructions ?? null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    this.medicines.set(medicine.id, medicine);
    return medicine;
  }

  async findMedicineById(id: string): Promise<MedicineRecord | null> {
    return this.medicines.get(id) ?? null;
  }

  async listMedicinesForElder(elderId: string, includeInactive: boolean): Promise<MedicineRecord[]> {
    return [...this.medicines.values()]
      .filter((m) => m.elderId === elderId && (includeInactive || m.isActive))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async updateMedicine(id: string, input: UpdateMedicineInput): Promise<MedicineRecord> {
    const medicine = this.medicines.get(id);
    if (!medicine) throw new Error('medicine not found');
    Object.assign(medicine, input, { updatedAt: new Date() });
    return medicine;
  }

  async deactivateMedicine(id: string): Promise<MedicineRecord> {
    const medicine = this.medicines.get(id);
    if (!medicine) throw new Error('medicine not found');
    medicine.isActive = false;
    medicine.updatedAt = new Date();
    for (const schedule of this.schedules.values()) {
      if (schedule.medicineId === id) {
        schedule.isActive = false;
        schedule.updatedAt = new Date();
      }
    }
    return medicine;
  }

  async createSchedule(input: CreateScheduleInput): Promise<MedicineScheduleRecord> {
    const now = new Date();
    const schedule: MedicineScheduleRecord = {
      id: randomUUID(),
      medicineId: input.medicineId,
      elderId: input.elderId,
      timesOfDay: input.timesOfDay,
      daysOfWeek: input.daysOfWeek,
      startDate: input.startDate,
      endDate: input.endDate ?? null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    this.schedules.set(schedule.id, schedule);
    return schedule;
  }

  async findScheduleById(id: string): Promise<MedicineScheduleRecord | null> {
    return this.schedules.get(id) ?? null;
  }

  async listSchedulesForElder(elderId: string, medicineId?: string): Promise<MedicineScheduleRecord[]> {
    return [...this.schedules.values()]
      .filter((s) => s.elderId === elderId && (!medicineId || s.medicineId === medicineId))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async updateSchedule(id: string, input: UpdateScheduleInput): Promise<MedicineScheduleRecord> {
    const schedule = this.schedules.get(id);
    if (!schedule) throw new Error('schedule not found');
    Object.assign(schedule, input, { updatedAt: new Date() });
    return schedule;
  }
}
