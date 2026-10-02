import type { AuditLogger } from '../../common/audit/auditLog';
import type { NotificationsService } from '../notifications/notifications.service';
import type { DoseRepository } from './reminders.types';

export interface CaregiverLookup {
  listAcceptedCaregiverIds(elderId: string): Promise<string[]>;
}

export interface NotificationPreferencesLookup {
  getNotificationPreferences(userId: string): Promise<{ notifyOnMissedDose: boolean }>;
}

/**
 * Deterministic missed-dose detection: a dose still SCHEDULED or REMINDED after its
 * scheduled time plus a grace period is MISSED — never an LLM judgment call. Run
 * periodically by jobs/reminderSweep.ts.
 */
export class MissedDoseService {
  constructor(
    private readonly doseRepo: DoseRepository,
    private readonly family: CaregiverLookup,
    private readonly users: NotificationPreferencesLookup,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditLogger,
    private readonly graceMinutes: number,
  ) {}

  async sweep(now = new Date()): Promise<number> {
    const overdueBefore = new Date(now.getTime() - this.graceMinutes * 60_000);
    const overdue = await this.doseRepo.listOverdue(['SCHEDULED', 'REMINDED'], overdueBefore);

    for (const dose of overdue) {
      await this.doseRepo.updateStatus(dose.id, { status: 'MISSED', missedAt: now });
      await this.audit.log({
        actorId: null,
        action: 'DOSE_MISSED',
        targetType: 'MedicineDose',
        targetId: dose.id,
        metadata: { elderId: dose.elderId, scheduledFor: dose.scheduledFor.toISOString() },
      });

      const caregiverIds = await this.family.listAcceptedCaregiverIds(dose.elderId);
      for (const caregiverId of caregiverIds) {
        // Phase 10: a caregiver who muted missed-dose alerts still has full dashboard access —
        // this only skips the push-style Notification row, never the underlying data.
        const preferences = await this.users.getNotificationPreferences(caregiverId);
        if (!preferences.notifyOnMissedDose) continue;

        await this.notifications.notify({
          recipientId: caregiverId,
          type: 'MISSED_DOSE',
          title: 'A medicine dose was missed',
          body: `A scheduled dose was not confirmed within ${this.graceMinutes} minutes.`,
          data: { doseId: dose.id, elderId: dose.elderId, scheduledFor: dose.scheduledFor.toISOString() },
        });
      }
    }

    return overdue.length;
  }
}
