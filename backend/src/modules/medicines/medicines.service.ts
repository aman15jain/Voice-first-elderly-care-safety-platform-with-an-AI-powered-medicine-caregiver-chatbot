import type { AuditLogger } from '../../common/audit/auditLog';
import { AppError } from '../../common/errors/AppError';
import type { DoseGenerator, DoseRepository } from '../reminders/reminders.types';
import type {
  MedicineRecord,
  MedicineScheduleRecord,
  MedicinesRepository,
  UpdateMedicineInput,
  UpdateScheduleInput,
} from './medicines.types';

export class MedicinesService {
  constructor(
    private readonly repo: MedicinesRepository,
    private readonly doseGenerator: DoseGenerator,
    private readonly doseRepo: Pick<DoseRepository, 'deleteFuturePending'>,
    private readonly audit: AuditLogger,
    private readonly generationDaysAhead: number,
  ) {}

  async createMedicine(elderId: string, input: { name: string; dosage: string; instructions?: string }): Promise<MedicineRecord> {
    const medicine = await this.repo.createMedicine({ elderId, ...input });
    await this.audit.log({ actorId: elderId, action: 'MEDICINE_CREATED', targetType: 'Medicine', targetId: medicine.id });
    return medicine;
  }

  listMedicines(elderId: string, includeInactive: boolean): Promise<MedicineRecord[]> {
    return this.repo.listMedicinesForElder(elderId, includeInactive);
  }

  async getOwnedMedicine(elderId: string, id: string): Promise<MedicineRecord> {
    const medicine = await this.repo.findMedicineById(id);
    if (!medicine || medicine.elderId !== elderId) throw AppError.notFound('Medicine not found');
    return medicine;
  }

  async updateMedicine(elderId: string, id: string, input: UpdateMedicineInput): Promise<MedicineRecord> {
    await this.getOwnedMedicine(elderId, id);
    const updated = await this.repo.updateMedicine(id, input);
    await this.audit.log({ actorId: elderId, action: 'MEDICINE_UPDATED', targetType: 'Medicine', targetId: id });
    return updated;
  }

  async deleteMedicine(elderId: string, id: string): Promise<MedicineRecord> {
    await this.getOwnedMedicine(elderId, id);
    const updated = await this.repo.deactivateMedicine(id);
    await this.audit.log({ actorId: elderId, action: 'MEDICINE_DELETED', targetType: 'Medicine', targetId: id });
    return updated;
  }

  async createSchedule(
    elderId: string,
    input: { medicineId: string; timesOfDay: string[]; daysOfWeek: number[]; startDate: Date; endDate?: Date | null },
  ): Promise<MedicineScheduleRecord> {
    const medicine = await this.getOwnedMedicine(elderId, input.medicineId);
    if (!medicine.isActive) throw AppError.conflict('This medicine has been deleted');

    const schedule = await this.repo.createSchedule({
      medicineId: medicine.id,
      elderId,
      timesOfDay: input.timesOfDay,
      daysOfWeek: input.daysOfWeek,
      startDate: input.startDate,
      endDate: input.endDate ?? null,
    });
    await this.doseGenerator.generateForSchedule(schedule, this.generationDaysAhead);
    return schedule;
  }

  listSchedules(elderId: string, medicineId?: string): Promise<MedicineScheduleRecord[]> {
    return this.repo.listSchedulesForElder(elderId, medicineId);
  }

  async getOwnedSchedule(elderId: string, id: string): Promise<MedicineScheduleRecord> {
    const schedule = await this.repo.findScheduleById(id);
    if (!schedule || schedule.elderId !== elderId) throw AppError.notFound('Schedule not found');
    return schedule;
  }

  async updateSchedule(elderId: string, id: string, input: UpdateScheduleInput): Promise<MedicineScheduleRecord> {
    await this.getOwnedSchedule(elderId, id);
    const updated = await this.repo.updateSchedule(id, input);

    // Not-yet-due doses no longer match the new schedule — drop and regenerate them.
    // Doses already reminded/taken/skipped/missed are history and are never touched.
    await this.doseRepo.deleteFuturePending(id, new Date());
    if (updated.isActive) await this.doseGenerator.generateForSchedule(updated, this.generationDaysAhead);
    return updated;
  }
}
