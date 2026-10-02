import type { DoseRecord } from '../reminders/reminders.types';

export interface DailyAdherence {
  date: string;
  taken: number;
  totalDue: number;
  takenRate: number | null;
}

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function dateKey(date: Date): string {
  return startOfUtcDay(date).toISOString().slice(0, 10);
}

/**
 * Pure and deterministic, same pattern as `buildDailySummary` (activity module) and
 * `computeAdherenceSummary` (this module's single-range version): every day in [from, to]
 * gets a row, even an empty one, so a chart never has to guess at a gap. Never an LLM call.
 */
export function computeAdherenceTrend(doses: DoseRecord[], from: Date, to: Date): DailyAdherence[] {
  const byDay = new Map<string, { taken: number; skipped: number; missed: number }>();
  for (const dose of doses) {
    const key = dateKey(dose.scheduledFor);
    const bucket = byDay.get(key) ?? { taken: 0, skipped: 0, missed: 0 };
    if (dose.status === 'TAKEN') bucket.taken += 1;
    else if (dose.status === 'SKIPPED') bucket.skipped += 1;
    else if (dose.status === 'MISSED') bucket.missed += 1;
    byDay.set(key, bucket);
  }

  const days: DailyAdherence[] = [];
  let cursor = startOfUtcDay(from);
  const end = startOfUtcDay(to);
  while (cursor <= end) {
    const key = dateKey(cursor);
    const bucket = byDay.get(key) ?? { taken: 0, skipped: 0, missed: 0 };
    const totalDue = bucket.taken + bucket.skipped + bucket.missed;
    days.push({ date: key, taken: bucket.taken, totalDue, takenRate: totalDue > 0 ? Math.round((bucket.taken / totalDue) * 100) : null });
    cursor = new Date(cursor.getTime() + 86_400_000);
  }
  return days;
}
