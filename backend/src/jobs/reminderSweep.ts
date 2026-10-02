import { logger } from '../config/logger';
import type { DoseGenerationService } from '../modules/reminders/doseGeneration.service';
import type { MissedDoseService } from '../modules/reminders/missedDose.service';

/** Generates upcoming doses and flags overdue ones as missed. Deterministic; no LLM involved. */
export async function runReminderSweep(doseGeneration: DoseGenerationService, missedDose: MissedDoseService): Promise<void> {
  try {
    const generated = await doseGeneration.generateForAllActiveSchedules();
    const missed = await missedDose.sweep();
    if (generated || missed) logger.info({ generated, missed }, 'reminder sweep completed');
  } catch (err) {
    logger.error({ err }, 'reminder sweep failed');
  }
}

/**
 * Runs the sweep immediately and then on a fixed interval. This is a real, working
 * scheduler for a single-instance deployment — not a stand-in for one. A multi-instance
 * production deployment would move this to a proper job runner (e.g. node-cron/BullMQ)
 * so only one instance executes it; documented in docs/architecture.md.
 */
export function startReminderSweepInterval(
  doseGeneration: DoseGenerationService,
  missedDose: MissedDoseService,
  intervalMinutes: number,
): NodeJS.Timeout {
  void runReminderSweep(doseGeneration, missedDose);
  const timer = setInterval(() => void runReminderSweep(doseGeneration, missedDose), intervalMinutes * 60_000);
  timer.unref();
  return timer;
}
