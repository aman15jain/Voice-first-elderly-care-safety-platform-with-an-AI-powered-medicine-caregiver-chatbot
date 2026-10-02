import { describe, expect, it } from 'vitest';
import { buildDoseInputs } from '../../src/modules/reminders/doseSchedule';
import type { ScheduleForGeneration } from '../../src/modules/reminders/reminders.types';

const baseSchedule: ScheduleForGeneration = {
  id: 'schedule-1',
  medicineId: 'medicine-1',
  elderId: 'elder-1',
  timesOfDay: ['08:00', '20:00'],
  daysOfWeek: [],
  startDate: new Date('2026-01-01T00:00:00.000Z'),
  endDate: null,
};

const now = new Date('2026-01-10T12:00:00.000Z'); // a Saturday

describe('buildDoseInputs', () => {
  it('generates one dose per time of day, for today through daysAhead', () => {
    const inputs = buildDoseInputs(baseSchedule, 1, now);
    expect(inputs).toHaveLength(4); // 2 times x 2 days (today + 1)
    expect(inputs.map((i) => i.scheduledFor.toISOString())).toEqual([
      '2026-01-10T08:00:00.000Z',
      '2026-01-10T20:00:00.000Z',
      '2026-01-11T08:00:00.000Z',
      '2026-01-11T20:00:00.000Z',
    ]);
  });

  it('never generates before startDate', () => {
    const schedule = { ...baseSchedule, startDate: new Date('2026-01-11T00:00:00.000Z') };
    const inputs = buildDoseInputs(schedule, 2, now);
    expect(inputs.every((i) => i.scheduledFor >= schedule.startDate)).toBe(true);
    expect(inputs).toHaveLength(4); // only Jan 11 and Jan 12
  });

  it('never generates after endDate', () => {
    const schedule = { ...baseSchedule, endDate: new Date('2026-01-10T00:00:00.000Z') };
    const inputs = buildDoseInputs(schedule, 3, now);
    expect(inputs).toHaveLength(2); // only today, both times
  });

  it('respects daysOfWeek', () => {
    // 2026-01-10 is a Saturday (6); only generate on Sundays (0).
    const schedule = { ...baseSchedule, daysOfWeek: [0] };
    const inputs = buildDoseInputs(schedule, 7, now);
    expect(inputs.every((i) => i.scheduledFor.getUTCDay() === 0)).toBe(true);
    expect(inputs.length).toBeGreaterThan(0);
  });

  it('is a pure function: identical inputs produce identical output', () => {
    const a = buildDoseInputs(baseSchedule, 2, now);
    const b = buildDoseInputs(baseSchedule, 2, now);
    expect(a).toEqual(b);
  });
});
