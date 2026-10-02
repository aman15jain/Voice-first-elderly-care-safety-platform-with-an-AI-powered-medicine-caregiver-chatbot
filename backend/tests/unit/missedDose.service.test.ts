import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { MissedDoseService } from '../../src/modules/reminders/missedDose.service';
import { NotificationsService } from '../../src/modules/notifications/notifications.service';
import { InMemoryNotificationsRepository } from '../fakes/inMemoryNotifications';
import { InMemoryDoseRepository } from '../fakes/inMemoryReminders';
import { RecordingAuditLogger } from '../fakes/recordingAuditLogger';

const alwaysNotify = { getNotificationPreferences: async () => ({ notifyOnMissedDose: true }) };

function makeDose(overrides: Partial<Parameters<InMemoryDoseRepository['createManySkipDuplicates']>[0][number]> = {}) {
  return {
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    elderId: 'elder-1',
    scheduledFor: new Date('2026-01-01T08:00:00.000Z'),
    ...overrides,
  };
}

function onlyDose(doses: InMemoryDoseRepository) {
  const dose = [...doses.doses.values()][0];
  if (!dose) throw new Error('expected exactly one dose');
  return dose;
}

describe('MissedDoseService', () => {
  it('marks a dose MISSED once it is past scheduledFor + grace, and notifies linked caregivers', async () => {
    const doses = new InMemoryDoseRepository();
    await doses.createManySkipDuplicates([makeDose()]);
    const dose = onlyDose(doses);

    const family = { listAcceptedCaregiverIds: async () => ['caregiver-1', 'caregiver-2'] };
    const notificationsRepo = new InMemoryNotificationsRepository();
    const notifications = new NotificationsService(notificationsRepo);
    const audit = new RecordingAuditLogger();

    const service = new MissedDoseService(doses, family, alwaysNotify, notifications, audit, 60);
    const now = new Date(dose.scheduledFor.getTime() + 61 * 60_000);
    const count = await service.sweep(now);

    expect(count).toBe(1);
    expect(doses.doses.get(dose.id)!.status).toBe('MISSED');
    expect(audit.entries.some((e) => e.action === 'DOSE_MISSED')).toBe(true);
    expect(notificationsRepo.notifications.size).toBe(2);
    expect([...notificationsRepo.notifications.values()].every((n) => n.type === 'MISSED_DOSE')).toBe(true);
  });

  it('leaves a dose alone within the grace period', async () => {
    const doses = new InMemoryDoseRepository();
    await doses.createManySkipDuplicates([makeDose()]);
    const dose = onlyDose(doses);

    const service = new MissedDoseService(
      doses,
      { listAcceptedCaregiverIds: async () => [] },
      alwaysNotify,
      new NotificationsService(new InMemoryNotificationsRepository()),
      new RecordingAuditLogger(),
      60,
    );
    const now = new Date(dose.scheduledFor.getTime() + 30 * 60_000); // within grace
    const count = await service.sweep(now);

    expect(count).toBe(0);
    expect(doses.doses.get(dose.id)!.status).toBe('SCHEDULED');
  });

  it('does not touch doses already taken or skipped', async () => {
    const doses = new InMemoryDoseRepository();
    await doses.createManySkipDuplicates([makeDose()]);
    const dose = onlyDose(doses);
    await doses.updateStatus(dose.id, { status: 'TAKEN', respondedAt: new Date() });

    const service = new MissedDoseService(
      doses,
      { listAcceptedCaregiverIds: async () => ['caregiver-1'] },
      alwaysNotify,
      new NotificationsService(new InMemoryNotificationsRepository()),
      new RecordingAuditLogger(),
      60,
    );
    const now = new Date(dose.scheduledFor.getTime() + 120 * 60_000);
    const count = await service.sweep(now);

    expect(count).toBe(0);
    expect(doses.doses.get(dose.id)!.status).toBe('TAKEN');
  });

  it('sends no notification when the elder has no linked caregivers', async () => {
    const doses = new InMemoryDoseRepository();
    await doses.createManySkipDuplicates([makeDose({ elderId: randomUUID() })]);
    const notificationsRepo = new InMemoryNotificationsRepository();

    const service = new MissedDoseService(
      doses,
      { listAcceptedCaregiverIds: async () => [] },
      alwaysNotify,
      new NotificationsService(notificationsRepo),
      new RecordingAuditLogger(),
      60,
    );
    const dose = onlyDose(doses);
    await service.sweep(new Date(dose.scheduledFor.getTime() + 120 * 60_000));

    expect(notificationsRepo.notifications.size).toBe(0);
  });

  it('skips a caregiver who has muted missed-dose alerts, but still notifies the others', async () => {
    const doses = new InMemoryDoseRepository();
    await doses.createManySkipDuplicates([makeDose()]);
    const dose = onlyDose(doses);
    const notificationsRepo = new InMemoryNotificationsRepository();

    const preferences: Record<string, boolean> = { 'caregiver-muted': false, 'caregiver-unmuted': true };
    const users = { getNotificationPreferences: async (userId: string) => ({ notifyOnMissedDose: preferences[userId] ?? true }) };

    const service = new MissedDoseService(
      doses,
      { listAcceptedCaregiverIds: async () => ['caregiver-muted', 'caregiver-unmuted'] },
      users,
      new NotificationsService(notificationsRepo),
      new RecordingAuditLogger(),
      60,
    );
    await service.sweep(new Date(dose.scheduledFor.getTime() + 120 * 60_000));

    const notified = [...notificationsRepo.notifications.values()].map((n) => n.recipientId);
    expect(notified).toEqual(['caregiver-unmuted']);
  });
});
