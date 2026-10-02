import { randomUUID } from 'node:crypto';
import type {
  CreateDoseInput,
  DoseRecord,
  DoseRepository,
  DoseStatus,
  ScheduleForGeneration,
  UpdateDoseStatusInput,
} from '../../src/modules/reminders/reminders.types';

export class InMemoryDoseRepository implements DoseRepository {
  readonly doses = new Map<string, DoseRecord>();
  /** Populated by InMemoryMedicinesRepository so listActiveSchedules() can see them. */
  scheduleSource: (() => ScheduleForGeneration[]) | null = null;

  private key(scheduleId: string, scheduledFor: Date) {
    return `${scheduleId}:${scheduledFor.getTime()}`;
  }

  async createManySkipDuplicates(inputs: CreateDoseInput[]): Promise<number> {
    let created = 0;
    const existingKeys = new Set([...this.doses.values()].map((d) => this.key(d.scheduleId, d.scheduledFor)));
    for (const input of inputs) {
      const k = this.key(input.scheduleId, input.scheduledFor);
      if (existingKeys.has(k)) continue;
      const now = new Date();
      const dose: DoseRecord = {
        id: randomUUID(),
        scheduleId: input.scheduleId,
        medicineId: input.medicineId,
        elderId: input.elderId,
        scheduledFor: input.scheduledFor,
        status: 'SCHEDULED',
        remindedAt: null,
        respondedAt: null,
        missedAt: null,
        createdAt: now,
        updatedAt: now,
      };
      this.doses.set(dose.id, dose);
      existingKeys.add(k);
      created += 1;
    }
    return created;
  }

  async findById(id: string): Promise<DoseRecord | null> {
    return this.doses.get(id) ?? null;
  }

  async updateStatus(id: string, data: UpdateDoseStatusInput): Promise<DoseRecord> {
    const dose = this.doses.get(id);
    if (!dose) throw new Error('dose not found');
    Object.assign(dose, data, { updatedAt: new Date() });
    return dose;
  }

  async listForElderInRange(elderId: string, from: Date, to: Date): Promise<DoseRecord[]> {
    return [...this.doses.values()]
      .filter((d) => d.elderId === elderId && d.scheduledFor >= from && d.scheduledFor <= to)
      .sort((a, b) => a.scheduledFor.getTime() - b.scheduledFor.getTime());
  }

  async listOverdue(statuses: DoseStatus[], before: Date): Promise<DoseRecord[]> {
    return [...this.doses.values()].filter((d) => statuses.includes(d.status) && d.scheduledFor < before);
  }

  async listActiveSchedules(): Promise<ScheduleForGeneration[]> {
    return this.scheduleSource?.() ?? [];
  }

  async deleteFuturePending(scheduleId: string, after: Date): Promise<number> {
    let count = 0;
    for (const [id, dose] of this.doses) {
      if (dose.scheduleId === scheduleId && dose.status === 'SCHEDULED' && dose.scheduledFor > after) {
        this.doses.delete(id);
        count += 1;
      }
    }
    return count;
  }
}
