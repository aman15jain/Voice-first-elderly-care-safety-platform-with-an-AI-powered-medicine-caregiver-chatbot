import { describe, expect, it } from 'vitest';
import { computeAdherenceTrend } from '../../src/modules/adherence/adherence.trend';
import type { DoseRecord } from '../../src/modules/reminders/reminders.types';

function dose(overrides: Partial<DoseRecord>): DoseRecord {
  return {
    id: 'dose-1',
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    elderId: 'elder-1',
    scheduledFor: new Date('2026-01-01T08:00:00.000Z'),
    status: 'TAKEN',
    remindedAt: null,
    respondedAt: null,
    missedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  } as DoseRecord;
}

describe('computeAdherenceTrend', () => {
  it('produces one row per day in range, even empty ones', () => {
    const from = new Date('2026-01-01T00:00:00.000Z');
    const to = new Date('2026-01-03T00:00:00.000Z');
    const days = computeAdherenceTrend([], from, to);
    expect(days.map((d) => d.date)).toEqual(['2026-01-01', '2026-01-02', '2026-01-03']);
    expect(days.every((d) => d.totalDue === 0 && d.takenRate === null)).toBe(true);
  });

  it('buckets doses by their scheduled day and computes a rate per day', () => {
    const from = new Date('2026-01-01T00:00:00.000Z');
    const to = new Date('2026-01-02T00:00:00.000Z');
    const doses = [
      dose({ id: '1', scheduledFor: new Date('2026-01-01T08:00:00.000Z'), status: 'TAKEN' }),
      dose({ id: '2', scheduledFor: new Date('2026-01-01T20:00:00.000Z'), status: 'MISSED' }),
      dose({ id: '3', scheduledFor: new Date('2026-01-02T08:00:00.000Z'), status: 'SKIPPED' }),
    ];
    const days = computeAdherenceTrend(doses, from, to);

    expect(days[0]).toEqual({ date: '2026-01-01', taken: 1, totalDue: 2, takenRate: 50 });
    expect(days[1]).toEqual({ date: '2026-01-02', taken: 0, totalDue: 1, takenRate: 0 });
  });

  it('ignores SCHEDULED/REMINDED doses — only settled outcomes count toward totalDue', () => {
    const from = new Date('2026-01-01T00:00:00.000Z');
    const to = new Date('2026-01-01T00:00:00.000Z');
    const doses = [dose({ status: 'SCHEDULED' }), dose({ id: '2', status: 'REMINDED' })];
    const days = computeAdherenceTrend(doses, from, to);
    expect(days[0]).toEqual({ date: '2026-01-01', taken: 0, totalDue: 0, takenRate: null });
  });
});
