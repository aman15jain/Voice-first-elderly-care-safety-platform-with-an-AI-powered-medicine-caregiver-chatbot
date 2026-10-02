import type { DoseStatus, MedicineDose } from '@prisma/client';

export type DoseRecord = MedicineDose;
export type { DoseStatus };

export interface CreateDoseInput {
  scheduleId: string;
  medicineId: string;
  elderId: string;
  scheduledFor: Date;
}

/** The subset of MedicineSchedule the generator needs — kept narrow so reminders
 * doesn't depend on the medicines module's types. */
export interface ScheduleForGeneration {
  id: string;
  medicineId: string;
  elderId: string;
  timesOfDay: string[];
  daysOfWeek: number[];
  startDate: Date;
  endDate: Date | null;
}

export interface UpdateDoseStatusInput {
  status: DoseStatus;
  remindedAt?: Date;
  respondedAt?: Date;
  missedAt?: Date;
}

export interface DoseRepository {
  /** Insert-or-skip on the (scheduleId, scheduledFor) unique key: safe to call repeatedly. */
  createManySkipDuplicates(inputs: CreateDoseInput[]): Promise<number>;
  findById(id: string): Promise<DoseRecord | null>;
  updateStatus(id: string, data: UpdateDoseStatusInput): Promise<DoseRecord>;
  listForElderInRange(elderId: string, from: Date, to: Date): Promise<DoseRecord[]>;
  listOverdue(statuses: DoseStatus[], before: Date): Promise<DoseRecord[]>;
  listActiveSchedules(): Promise<ScheduleForGeneration[]>;
  /** Removes not-yet-due SCHEDULED doses for a schedule, so an edited schedule can be regenerated cleanly. */
  deleteFuturePending(scheduleId: string, after: Date): Promise<number>;
}

/** Narrow view a caller (e.g. the medicines module) needs to trigger generation without depending on the whole service. */
export interface DoseGenerator {
  generateForSchedule(schedule: ScheduleForGeneration, daysAhead?: number, now?: Date): Promise<number>;
}
