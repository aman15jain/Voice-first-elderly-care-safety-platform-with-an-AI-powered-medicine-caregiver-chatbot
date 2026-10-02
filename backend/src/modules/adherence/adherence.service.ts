import type { AuditLogger } from '../../common/audit/auditLog';
import { AppError } from '../../common/errors/AppError';
import type { DoseRecord, DoseRepository } from '../reminders/reminders.types';
import { computeAdherenceSummary, type AdherenceSummary } from './adherence.summary';
import { computeAdherenceTrend, type DailyAdherence } from './adherence.trend';

const RESPONDABLE_STATUSES = new Set(['SCHEDULED', 'REMINDED', 'MISSED']);

export class AdherenceService {
  constructor(
    private readonly doseRepo: DoseRepository,
    private readonly audit: AuditLogger,
  ) {}

  markTaken(elderId: string, doseId: string): Promise<DoseRecord> {
    return this.respond(elderId, doseId, 'TAKEN');
  }

  markSkipped(elderId: string, doseId: string): Promise<DoseRecord> {
    return this.respond(elderId, doseId, 'SKIPPED');
  }

  private async respond(elderId: string, doseId: string, status: 'TAKEN' | 'SKIPPED'): Promise<DoseRecord> {
    const dose = await this.doseRepo.findById(doseId);
    if (!dose || dose.elderId !== elderId) throw AppError.notFound('Dose not found');
    if (!RESPONDABLE_STATUSES.has(dose.status)) {
      throw AppError.conflict(`This dose is already marked ${dose.status.toLowerCase()}`);
    }

    const updated = await this.doseRepo.updateStatus(doseId, { status, respondedAt: new Date() });
    await this.audit.log({
      actorId: elderId,
      action: status === 'TAKEN' ? 'DOSE_TAKEN' : 'DOSE_SKIPPED',
      targetType: 'MedicineDose',
      targetId: doseId,
    });
    return updated;
  }

  async summary(elderId: string, from: Date, to: Date): Promise<AdherenceSummary> {
    const doses = await this.doseRepo.listForElderInRange(elderId, from, to);
    return computeAdherenceSummary(doses, from, to);
  }

  async trend(elderId: string, from: Date, to: Date): Promise<DailyAdherence[]> {
    const doses = await this.doseRepo.listForElderInRange(elderId, from, to);
    return computeAdherenceTrend(doses, from, to);
  }
}
