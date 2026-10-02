import { buildDailySummary, type DailyActivity } from './activitySummary';
import type { ActivityRepository } from './activity.types';

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class ActivityService {
  constructor(private readonly repo: ActivityRepository) {}

  /** Idempotent per day: opening the app five times today still records one event. */
  async recordAppOpened(elderId: string): Promise<void> {
    const now = new Date();
    const alreadyToday = await this.repo.hasAppOpenedEventInRange(elderId, startOfUtcDay(now), endOfUtcDay(now));
    if (!alreadyToday) await this.repo.createAppOpenedEvent(elderId, now);
  }

  async dailySummary(elderId: string, from: Date, to: Date): Promise<DailyActivity[]> {
    const [medicineDates, gameDates] = await Promise.all([
      this.repo.listMedicineInteractionDates(elderId, from, to),
      this.repo.listGameSessionDates(elderId, from, to),
    ]);
    return buildDailySummary(from, to, medicineDates, gameDates);
  }
}
