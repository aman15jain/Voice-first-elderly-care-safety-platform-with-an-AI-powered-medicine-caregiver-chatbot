function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function dateKey(date: Date): string {
  return startOfUtcDay(date).toISOString().slice(0, 10);
}

export interface DailyActivity {
  date: string;
  medicineInteractions: number;
  gameSessions: number;
  /** True if anything meaningful happened that day — the one signal the UI leads with. */
  active: boolean;
}

function countByDay(dates: Date[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const date of dates) {
    const key = dateKey(date);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

/**
 * Pure and deterministic: every day in [from, to] gets a row, even ones with nothing in
 * them, so the UI can render a full week/month without gaps. No LLM involved — this is
 * arithmetic over timestamps already recorded for their own purposes (dose responses,
 * game sessions).
 */
export function buildDailySummary(from: Date, to: Date, medicineInteractionDates: Date[], gameSessionDates: Date[]): DailyActivity[] {
  const medicineCounts = countByDay(medicineInteractionDates);
  const gameCounts = countByDay(gameSessionDates);

  const days: DailyActivity[] = [];
  let cursor = startOfUtcDay(from);
  const end = startOfUtcDay(to);
  while (cursor <= end) {
    const key = dateKey(cursor);
    const medicineInteractions = medicineCounts.get(key) ?? 0;
    const gameSessions = gameCounts.get(key) ?? 0;
    days.push({ date: key, medicineInteractions, gameSessions, active: medicineInteractions > 0 || gameSessions > 0 });
    cursor = new Date(cursor.getTime() + 86_400_000);
  }
  return days;
}
