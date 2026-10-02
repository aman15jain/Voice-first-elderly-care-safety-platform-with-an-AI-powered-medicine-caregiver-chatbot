import { describe, expect, it } from 'vitest';
import { buildDailySummary } from '../../src/modules/activity/activitySummary';

const from = new Date('2026-01-01T00:00:00.000Z');
const to = new Date('2026-01-03T00:00:00.000Z');

describe('buildDailySummary', () => {
  it('returns one row per day in range, even with no activity', () => {
    const days = buildDailySummary(from, to, [], []);
    expect(days.map((d) => d.date)).toEqual(['2026-01-01', '2026-01-02', '2026-01-03']);
    expect(days.every((d) => !d.active)).toBe(true);
  });

  it('counts interactions per day and marks the day active', () => {
    const days = buildDailySummary(
      from,
      to,
      [new Date('2026-01-01T08:00:00.000Z'), new Date('2026-01-01T20:00:00.000Z')],
      [new Date('2026-01-02T10:00:00.000Z')],
    );
    expect(days[0]).toMatchObject({ date: '2026-01-01', medicineInteractions: 2, gameSessions: 0, active: true });
    expect(days[1]).toMatchObject({ date: '2026-01-02', medicineInteractions: 0, gameSessions: 1, active: true });
    expect(days[2]).toMatchObject({ date: '2026-01-03', medicineInteractions: 0, gameSessions: 0, active: false });
  });

  it('is a pure function: identical inputs produce identical output', () => {
    const dates = [new Date('2026-01-02T10:00:00.000Z')];
    expect(buildDailySummary(from, to, dates, [])).toEqual(buildDailySummary(from, to, dates, []));
  });
});
