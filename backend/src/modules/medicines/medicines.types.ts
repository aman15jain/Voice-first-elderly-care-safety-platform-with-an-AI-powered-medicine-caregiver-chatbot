import type { Medicine, MedicineSchedule } from '@prisma/client';

export type MedicineRecord = Medicine;
export type MedicineScheduleRecord = MedicineSchedule;

export interface CreateMedicineInput {
  elderId: string;
  name: string;
  dosage: string;
  instructions?: string;
}

export interface UpdateMedicineInput {
  name?: string;
  dosage?: string;
  instructions?: string | null;
}

export interface CreateScheduleInput {
  medicineId: string;
  elderId: string;
  timesOfDay: string[];
  daysOfWeek: number[];
  startDate: Date;
  endDate?: Date | null;
}

export interface UpdateScheduleInput {
  timesOfDay?: string[];
  daysOfWeek?: number[];
  endDate?: Date | null;
  isActive?: boolean;
}

export interface MedicinesRepository {
  createMedicine(input: CreateMedicineInput): Promise<MedicineRecord>;
  findMedicineById(id: string): Promise<MedicineRecord | null>;
  listMedicinesForElder(elderId: string, includeInactive: boolean): Promise<MedicineRecord[]>;
  updateMedicine(id: string, input: UpdateMedicineInput): Promise<MedicineRecord>;
  /** Soft delete: deactivates the medicine and all of its schedules in one transaction. */
  deactivateMedicine(id: string): Promise<MedicineRecord>;

  createSchedule(input: CreateScheduleInput): Promise<MedicineScheduleRecord>;
  findScheduleById(id: string): Promise<MedicineScheduleRecord | null>;
  listSchedulesForElder(elderId: string, medicineId?: string): Promise<MedicineScheduleRecord[]>;
  updateSchedule(id: string, input: UpdateScheduleInput): Promise<MedicineScheduleRecord>;
}
