import { describe, expect, it } from 'vitest';
import { computeAdherenceSummary } from '../../src/modules/adherence/adherence.summary';
import type { DoseRecord } from '../../src/modules/reminders/reminders.types';

function dose(status: DoseRecord['status']): DoseRecord {
  return {
    id: `dose-${status}-${Math.random()}`,
    scheduleId: 's1',
    medicineId: 'm1',
    elderId: 'e1',
    scheduledFor: new Date('2026-01-01T08:00:00.000Z'),
    status,
    remindedAt: null,
    respondedAt: null,
    missedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

const from = new Date('2026-01-01T00:00:00.000Z');
const to = new Date('2026-01-07T23:59:59.999Z');

describe('computeAdherenceSummary', () => {
  it('counts by status and computes a taken rate over settled doses only', () => {
    const doses = [dose('TAKEN'), dose('TAKEN'), dose('SKIPPED'), dose('MISSED'), dose('SCHEDULED'), dose('REMINDED')];
    const summary = computeAdherenceSummary(doses, from, to);
    expect(summary).toMatchObject({ taken: 2, skipped: 1, missed: 1, scheduled: 1, reminded: 1, totalDue: 4, takenRate: 50 });
  });

  it('returns null takenRate when nothing is settled yet', () => {
    const summary = computeAdherenceSummary([dose('SCHEDULED'), dose('REMINDED')], from, to);
    expect(summary.totalDue).toBe(0);
    expect(summary.takenRate).toBeNull();
  });

  it('handles an empty list', () => {
    const summary = computeAdherenceSummary([], from, to);
    expect(summary).toMatchObject({ scheduled: 0, reminded: 0, taken: 0, skipped: 0, missed: 0, totalDue: 0, takenRate: null });
  });
});
