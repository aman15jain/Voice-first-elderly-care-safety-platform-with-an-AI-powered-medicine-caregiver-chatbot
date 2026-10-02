import type { DoseRecord } from '../reminders/reminders.types';

export interface AdherenceSummary {
  from: string;
  to: string;
  scheduled: number;
  reminded: number;
  taken: number;
  skipped: number;
  missed: number;
  /** Doses whose outcome is settled: taken + skipped + missed. Still-pending SCHEDULED/REMINDED doses are excluded. */
  totalDue: number;
  /** taken / totalDue as a whole-number percentage, or null when nothing was due yet. */
  takenRate: number | null;
}

/** Pure and deterministic — never an LLM judgment. Callers pass the doses already scoped to one elder and range. */
export function computeAdherenceSummary(doses: DoseRecord[], from: Date, to: Date): AdherenceSummary {
  const counts = { SCHEDULED: 0, REMINDED: 0, TAKEN: 0, SKIPPED: 0, MISSED: 0 };
  for (const dose of doses) counts[dose.status] += 1;

  const totalDue = counts.TAKEN + counts.SKIPPED + counts.MISSED;
  return {
    from: from.toISOString().slice(0, 10),
    to: to.toISOString().slice(0, 10),
    scheduled: counts.SCHEDULED,
    reminded: counts.REMINDED,
    taken: counts.TAKEN,
    skipped: counts.SKIPPED,
    missed: counts.MISSED,
    totalDue,
    takenRate: totalDue > 0 ? Math.round((counts.TAKEN / totalDue) * 100) : null,
  };
}
