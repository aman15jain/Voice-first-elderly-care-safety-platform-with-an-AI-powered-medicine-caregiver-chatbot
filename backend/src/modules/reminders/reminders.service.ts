import { AppError } from '../../common/errors/AppError';
import type { DoseRecord, DoseRepository } from './reminders.types';

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class RemindersService {
  constructor(private readonly repo: DoseRepository) {}

  /** No `from`/`to` given -> today (UTC). */
  listDoses(elderId: string, from?: Date, to?: Date): Promise<DoseRecord[]> {
    const now = new Date();
    return this.repo.listForElderInRange(elderId, from ?? startOfUtcDay(now), to ? endOfUtcDay(to) : endOfUtcDay(now));
  }

  async markReminded(elderId: string, doseId: string): Promise<DoseRecord> {
    const dose = await this.repo.findById(doseId);
    if (!dose || dose.elderId !== elderId) throw AppError.notFound('Dose not found');
    if (dose.status !== 'SCHEDULED') throw AppError.conflict(`This dose is already ${dose.status.toLowerCase()}`);
    return this.repo.updateStatus(doseId, { status: 'REMINDED', remindedAt: new Date() });
  }
}
