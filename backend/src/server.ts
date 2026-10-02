import { createApp } from './app';
import { PrismaAuditLogger } from './common/audit/auditLog';
import { env } from './config/env';
import { logger } from './config/logger';
import { startReminderSweepInterval } from './jobs/reminderSweep';
import { PrismaActivityRepository } from './modules/activity/activity.repository';
import { PrismaAuthRepository } from './modules/auth/auth.repository';
import type { JwtConfig } from './modules/auth/auth.types';
import { PrismaEmergencyRepository } from './modules/emergency/emergency.repository';
import { PrismaFamilyRepository } from './modules/family/family.repository';
import { PrismaGamesRepository } from './modules/games/games.repository';
import { PrismaMedicinesRepository } from './modules/medicines/medicines.repository';
import { PrismaNotificationsRepository } from './modules/notifications/notifications.repository';
import { NotificationsService } from './modules/notifications/notifications.service';
import { DoseGenerationService } from './modules/reminders/doseGeneration.service';
import { MissedDoseService } from './modules/reminders/missedDose.service';
import { PrismaDoseRepository } from './modules/reminders/reminders.repository';
import { PrismaUsersRepository } from './modules/users/users.repository';
import { PrismaVoiceRepository } from './modules/voice/voice.repository';
import { HttpAiOrchestratorClient } from './modules/ai/ai.orchestratorClient';
import { prisma } from './prisma/client';
import { HttpAiClient } from './services/aiClient';

const jwtConfig: JwtConfig = {
  accessSecret: env.JWT_SECRET,
  refreshPepper: env.JWT_REFRESH_SECRET,
  accessTtlSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
  refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
};

const familyRepository = new PrismaFamilyRepository(prisma);
const doseRepository = new PrismaDoseRepository(prisma);
const notificationsRepository = new PrismaNotificationsRepository(prisma);
const usersRepository = new PrismaUsersRepository(prisma);
const auditLogger = new PrismaAuditLogger(prisma);

const app = createApp({
  pingDatabase: () => prisma.$queryRaw`SELECT 1`,
  ai: new HttpAiClient(),
  authRepository: new PrismaAuthRepository(prisma),
  usersRepository,
  familyRepository,
  medicinesRepository: new PrismaMedicinesRepository(prisma),
  doseRepository,
  notificationsRepository,
  gamesRepository: new PrismaGamesRepository(prisma),
  activityRepository: new PrismaActivityRepository(prisma),
  emergencyRepository: new PrismaEmergencyRepository(prisma),
  voiceRepository: new PrismaVoiceRepository(prisma),
  aiOrchestratorClient: new HttpAiOrchestratorClient(),
  internalApiKey: env.AI_SERVICE_API_KEY,
  auditLogger,
  jwt: jwtConfig,
  reminderConfig: {
    generationDaysAhead: env.DOSE_GENERATION_DAYS_AHEAD,
    missedDoseGraceMinutes: env.MISSED_DOSE_GRACE_MINUTES,
  },
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'backend listening'));
// Guards against a connection that opens but never finishes sending headers/a request
// (e.g. a slow-loris-style client) from holding a socket open indefinitely. headersTimeout
// must stay below requestTimeout per Node's own documented constraint.
server.headersTimeout = 30_000;
server.requestTimeout = 60_000;

// Real, working reminder engine: generates upcoming doses and flags overdue ones as missed.
// A multi-instance production deployment should move this to a proper job runner so only
// one instance runs it — see docs/architecture.md.
const doseGeneration = new DoseGenerationService(doseRepository, env.DOSE_GENERATION_DAYS_AHEAD);
const missedDose = new MissedDoseService(
  doseRepository,
  familyRepository,
  usersRepository,
  new NotificationsService(notificationsRepository),
  auditLogger,
  env.MISSED_DOSE_GRACE_MINUTES,
);
const reminderSweepTimer = startReminderSweepInterval(doseGeneration, missedDose, env.REMINDER_SWEEP_INTERVAL_MINUTES);

function shutdown(signal: string) {
  logger.info({ signal }, 'shutting down');
  clearInterval(reminderSweepTimer);
  server.close(() => {
    void prisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
