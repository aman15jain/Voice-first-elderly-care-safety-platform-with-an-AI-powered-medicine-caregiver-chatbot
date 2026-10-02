import { createApp } from '../../src/app';
import type { AppDeps, JwtConfig, ReminderConfig } from '../../src/routes';
import { InMemoryActivityRepository } from '../fakes/inMemoryActivity';
import { InMemoryAuthRepository } from '../fakes/inMemoryAuth';
import { InMemoryEmergencyRepository } from '../fakes/inMemoryEmergency';
import { InMemoryFamilyRepository } from '../fakes/inMemoryFamily';
import { InMemoryGamesRepository } from '../fakes/inMemoryGames';
import { InMemoryMedicinesRepository } from '../fakes/inMemoryMedicines';
import { InMemoryNotificationsRepository } from '../fakes/inMemoryNotifications';
import { InMemoryDoseRepository } from '../fakes/inMemoryReminders';
import { InMemoryUsersRepository } from '../fakes/inMemoryUsers';
import { InMemoryVoiceRepository } from '../fakes/inMemoryVoice';
import { FakeAiOrchestratorClient } from '../fakes/fakeAiOrchestratorClient';
import { RecordingAuditLogger } from '../fakes/recordingAuditLogger';

export const testJwtConfig: JwtConfig = {
  accessSecret: 'test-access-secret-please-ignore',
  refreshPepper: 'test-refresh-pepper-please-ignore',
  accessTtlSeconds: 900,
  refreshTtlDays: 30,
};

export const testReminderConfig: ReminderConfig = {
  generationDaysAhead: 2,
  missedDoseGraceMinutes: 60,
};

/** Builds a real Express app wired to fast, in-memory fakes instead of Postgres/the AI service. */
export function buildTestApp(overrides: Partial<AppDeps> = {}) {
  const auth = new InMemoryAuthRepository();
  const family = new InMemoryFamilyRepository(auth);
  const users = new InMemoryUsersRepository(auth);
  const medicines = new InMemoryMedicinesRepository();
  const doses = new InMemoryDoseRepository();
  const notifications = new InMemoryNotificationsRepository();
  const games = new InMemoryGamesRepository();
  const activity = new InMemoryActivityRepository();
  const emergency = new InMemoryEmergencyRepository();
  const voice = new InMemoryVoiceRepository();
  const aiOrchestrator = new FakeAiOrchestratorClient();
  const audit = new RecordingAuditLogger();

  // Mirrors the real PrismaDoseRepository.listActiveSchedules() filter: only active
  // schedules on active (not soft-deleted) medicines.
  doses.scheduleSource = () =>
    [...medicines.schedules.values()]
      .filter((s) => s.isActive && medicines.medicines.get(s.medicineId)?.isActive)
      .map((s) => ({
        id: s.id,
        medicineId: s.medicineId,
        elderId: s.elderId,
        timesOfDay: s.timesOfDay,
        daysOfWeek: s.daysOfWeek,
        startDate: s.startDate,
        endDate: s.endDate,
      }));

  const deps: AppDeps = {
    pingDatabase: async () => 1,
    ai: { health: async () => ({ status: 'ok' }) },
    authRepository: auth,
    usersRepository: users,
    familyRepository: family,
    medicinesRepository: medicines,
    doseRepository: doses,
    notificationsRepository: notifications,
    gamesRepository: games,
    activityRepository: activity,
    emergencyRepository: emergency,
    voiceRepository: voice,
    aiOrchestratorClient: aiOrchestrator,
    internalApiKey: 'test-internal-key',
    auditLogger: audit,
    jwt: testJwtConfig,
    reminderConfig: testReminderConfig,
    ...overrides,
  };

  return {
    app: createApp(deps),
    auth,
    family,
    users,
    medicines,
    doses,
    notifications,
    games,
    activity,
    emergency,
    voice,
    aiOrchestrator,
    audit,
    deps,
  };
}
