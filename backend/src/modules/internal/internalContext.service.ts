import type { ActivityService } from '../activity/activity.service';
import { computeAdherenceSummary, type AdherenceSummary } from '../adherence/adherence.summary';
import type { DoseRepository } from '../reminders/reminders.types';
import type { EmergencyRepository } from '../emergency/emergency.types';
import type { MedicinesRepository } from '../medicines/medicines.types';
import { daysAgoRange } from '../../common/utils/dateRange';

export interface MedicineContext {
  medicines: Array<{ name: string; dosage: string; instructions: string | null }>;
  adherence: AdherenceSummary;
}

export interface CaregiverInsightContext {
  adherence: AdherenceSummary;
  activity: { daysInRange: number; activeDays: number; medicineInteractionDays: number; gameSessionDays: number };
  activeEmergency: boolean;
}

const ADHERENCE_WINDOW_DAYS = 30;
const ACTIVITY_WINDOW_DAYS = 7;

/**
 * The only thing the Python agentic-ai service is allowed to read for a given elder — plain,
 * already-authorized, already-computed facts. Node resolved and authorized the caller (elder or
 * linked caregiver) *before* ever calling Python, so this module does no authorization of its own;
 * it exists purely so Python never needs database credentials (docs/ai-architecture.md rule 4).
 */
export class InternalContextService {
  constructor(
    private readonly medicinesRepo: MedicinesRepository,
    private readonly doseRepo: DoseRepository,
    private readonly activityService: ActivityService,
    private readonly emergencyRepo: EmergencyRepository,
  ) {}

  async getMedicineContext(elderId: string): Promise<MedicineContext> {
    const [medicines, { from, to }] = [await this.medicinesRepo.listMedicinesForElder(elderId, false), daysAgoRange(ADHERENCE_WINDOW_DAYS)];
    const doses = await this.doseRepo.listForElderInRange(elderId, from, to);
    return {
      medicines: medicines.map((m) => ({ name: m.name, dosage: m.dosage, instructions: m.instructions ?? null })),
      adherence: computeAdherenceSummary(doses, from, to),
    };
  }

  async getCaregiverInsightContext(elderId: string): Promise<CaregiverInsightContext> {
    const { from, to } = daysAgoRange(ADHERENCE_WINDOW_DAYS);
    const activityRange = daysAgoRange(ACTIVITY_WINDOW_DAYS);
    const [doses, dailyActivity, activeEvent] = await Promise.all([
      this.doseRepo.listForElderInRange(elderId, from, to),
      this.activityService.dailySummary(elderId, activityRange.from, activityRange.to),
      this.emergencyRepo.findActiveEventForElder(elderId),
    ]);
    return {
      adherence: computeAdherenceSummary(doses, from, to),
      activity: {
        daysInRange: dailyActivity.length,
        activeDays: dailyActivity.filter((d) => d.active).length,
        medicineInteractionDays: dailyActivity.filter((d) => d.medicineInteractions > 0).length,
        gameSessionDays: dailyActivity.filter((d) => d.gameSessions > 0).length,
      },
      activeEmergency: activeEvent !== null,
    };
  }
}
