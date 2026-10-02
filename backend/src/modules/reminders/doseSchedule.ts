import type { CreateDoseInput, ScheduleForGeneration } from './reminders.types';

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

/**
 * Pure, deterministic: given a schedule and "now", returns the dose rows due to exist for the
 * next `daysAhead` days (today inclusive). No I/O, no randomness — easy to unit test and to
 * reason about independently of the database's insert-or-skip behaviour.
 *
 * Known simplification: `timesOfDay` are treated as UTC "HH:mm", not the elder's local time.
 * Per-elder timezones would need a `timezone` field on ElderProfile — not implemented yet.
 */
export function buildDoseInputs(schedule: ScheduleForGeneration, daysAhead: number, now: Date): CreateDoseInput[] {
  const inputs: CreateDoseInput[] = [];
  const today = startOfUtcDay(now);
  const start = startOfUtcDay(schedule.startDate);
  const end = schedule.endDate ? startOfUtcDay(schedule.endDate) : null;

  for (let offset = 0; offset <= daysAhead; offset++) {
    const day = new Date(today);
    day.setUTCDate(day.getUTCDate() + offset);
    if (day < start) continue;
    if (end && day > end) continue;
    if (schedule.daysOfWeek.length > 0 && !schedule.daysOfWeek.includes(day.getUTCDay())) continue;

    for (const time of schedule.timesOfDay) {
      const [hours, minutes] = time.split(':').map(Number);
      const scheduledFor = new Date(day);
      scheduledFor.setUTCHours(hours ?? 0, minutes ?? 0, 0, 0);
      inputs.push({ scheduleId: schedule.id, medicineId: schedule.medicineId, elderId: schedule.elderId, scheduledFor });
    }
  }

  return inputs;
}
