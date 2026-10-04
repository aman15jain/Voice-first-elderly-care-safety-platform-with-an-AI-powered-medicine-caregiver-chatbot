import { Router } from 'express';
import type { AuditLogger } from '../common/audit/auditLog';
import { ActivityController } from '../modules/activity/activity.controller';
import { activityRoutes } from '../modules/activity/activity.routes';
import { ActivityService } from '../modules/activity/activity.service';
import type { ActivityRepository } from '../modules/activity/activity.types';
import { AdherenceController } from '../modules/adherence/adherence.controller';
import { adherenceRoutes } from '../modules/adherence/adherence.routes';
import { AdherenceService } from '../modules/adherence/adherence.service';
import { AuthController } from '../modules/auth/auth.controller';
import { authRoutes } from '../modules/auth/auth.routes';
import { AuthService } from '../modules/auth/auth.service';
import type { AuthRepository, JwtConfig } from '../modules/auth/auth.types';
import { FamilyController } from '../modules/family/family.controller';
import { familyRoutes } from '../modules/family/family.routes';
import { FamilyService } from '../modules/family/family.service';
import type { FamilyRepository } from '../modules/family/family.types';
import { EmergencyContactsController } from '../modules/emergency/emergencyContacts.controller';
import { emergencyContactsRoutes } from '../modules/emergency/emergencyContacts.routes';
import { EmergencyEventsController } from '../modules/emergency/emergencyEvents.controller';
import { emergencyEventsRoutes } from '../modules/emergency/emergencyEvents.routes';
import { EmergencyService } from '../modules/emergency/emergency.service';
import type { EmergencyRepository } from '../modules/emergency/emergency.types';
import { GamesController } from '../modules/games/games.controller';
import { gamesRoutes } from '../modules/games/games.routes';
import { GamesService } from '../modules/games/games.service';
import type { GamesRepository } from '../modules/games/games.types';
import { HealthController } from '../modules/health/health.controller';
import { healthRoutes } from '../modules/health/health.routes';
import { HealthService, type HealthDeps } from '../modules/health/health.service';
import { MedicineSchedulesController } from '../modules/medicines/medicineSchedules.controller';
import { medicineSchedulesRoutes } from '../modules/medicines/medicineSchedules.routes';
import { MedicinesController } from '../modules/medicines/medicines.controller';
import { medicinesRoutes } from '../modules/medicines/medicines.routes';
import { MedicinesService } from '../modules/medicines/medicines.service';
import type { MedicinesRepository } from '../modules/medicines/medicines.types';
import { NotificationsController } from '../modules/notifications/notifications.controller';
import { notificationsRoutes } from '../modules/notifications/notifications.routes';
import { NotificationsService } from '../modules/notifications/notifications.service';
import type { NotificationsRepository } from '../modules/notifications/notifications.types';
import { RemindersController } from '../modules/reminders/reminders.controller';
import { remindersRoutes } from '../modules/reminders/reminders.routes';
import { RemindersService } from '../modules/reminders/reminders.service';
import type { DoseRepository } from '../modules/reminders/reminders.types';
import { UsersController } from '../modules/users/users.controller';
import { usersRoutes } from '../modules/users/users.routes';
import { UsersService } from '../modules/users/users.service';
import type { UsersRepository } from '../modules/users/users.types';
import { DoseGenerationService } from '../modules/reminders/doseGeneration.service';
import { VoiceController } from '../modules/voice/voice.controller';
import { voiceRoutes } from '../modules/voice/voice.routes';
import { VoiceService } from '../modules/voice/voice.service';
import type { VoiceRepository } from '../modules/voice/voice.types';
import { AiController } from '../modules/ai/ai.controller';
import { aiRoutes } from '../modules/ai/ai.routes';
import { AiService } from '../modules/ai/ai.service';
import type { AiOrchestratorClient } from '../modules/ai/ai.types';
import { InternalController } from '../modules/internal/internal.controller';
import { internalRoutes } from '../modules/internal/internal.routes';
import { InternalContextService } from '../modules/internal/internalContext.service';
import { CaregiverDashboardController } from '../modules/dashboard/caregiverDashboard.controller';
import { caregiverDashboardRoutes } from '../modules/dashboard/caregiverDashboard.routes';
import { CaregiverDashboardService } from '../modules/dashboard/caregiverDashboard.service';

export type { JwtConfig };

export interface ReminderConfig {
  generationDaysAhead: number;
  missedDoseGraceMinutes: number;
}

export interface AppDeps extends HealthDeps {
  authRepository: AuthRepository;
  usersRepository: UsersRepository;
  familyRepository: FamilyRepository;
  medicinesRepository: MedicinesRepository;
  doseRepository: DoseRepository;
  notificationsRepository: NotificationsRepository;
  gamesRepository: GamesRepository;
  activityRepository: ActivityRepository;
  emergencyRepository: EmergencyRepository;
  voiceRepository: VoiceRepository;
  auditLogger: AuditLogger;
  jwt: JwtConfig;
  reminderConfig: ReminderConfig;
  aiOrchestratorClient: AiOrchestratorClient;
  /** Shared secret the agentic-ai service presents on /internal/* calls — see common/middleware/internalAuth.ts. */
  internalApiKey: string;
}

/** Mounts /health and every /api/* module router. */
export function buildRoutes(deps: AppDeps): Router {
  const router = Router();

  router.use('/health', healthRoutes(new HealthController(new HealthService(deps))));

  const authService = new AuthService(deps.authRepository, deps.auditLogger, deps.jwt);
  const usersService = new UsersService(deps.usersRepository);
  const familyService = new FamilyService(deps.familyRepository, deps.auditLogger);
  const notificationsService = new NotificationsService(deps.notificationsRepository);
  const doseGenerator = new DoseGenerationService(deps.doseRepository, deps.reminderConfig.generationDaysAhead);
  const medicinesService = new MedicinesService(
    deps.medicinesRepository,
    doseGenerator,
    deps.doseRepository,
    deps.auditLogger,
    deps.reminderConfig.generationDaysAhead,
  );
  const remindersService = new RemindersService(deps.doseRepository);
  const adherenceService = new AdherenceService(deps.doseRepository, deps.auditLogger);
  const gamesService = new GamesService(deps.gamesRepository);
  const activityService = new ActivityService(deps.activityRepository);
  const emergencyService = new EmergencyService(
    deps.emergencyRepository,
    familyService,
    deps.familyRepository,
    notificationsService,
    deps.auditLogger,
  );
  const voiceService = new VoiceService(
    deps.voiceRepository,
    deps.doseRepository,
    deps.medicinesRepository,
    activityService,
    deps.emergencyRepository,
    deps.aiOrchestratorClient,
  );
  const aiService = new AiService(deps.aiOrchestratorClient);
  const internalContextService = new InternalContextService(
    deps.medicinesRepository,
    deps.doseRepository,
    activityService,
    deps.emergencyRepository,
  );
  const caregiverDashboardService = new CaregiverDashboardService(familyService, internalContextService);

  router.use('/api/auth', authRoutes(new AuthController(authService)));
  router.use('/api/users', usersRoutes(new UsersController(usersService), deps.jwt.accessSecret));
  router.use('/api/family/links', familyRoutes(new FamilyController(familyService), deps.jwt.accessSecret));
  router.use('/api/medicines', medicinesRoutes(new MedicinesController(medicinesService, familyService), deps.jwt.accessSecret));
  router.use(
    '/api/medicine-schedules',
    medicineSchedulesRoutes(new MedicineSchedulesController(medicinesService, familyService), deps.jwt.accessSecret),
  );
  router.use('/api/doses', remindersRoutes(new RemindersController(remindersService, familyService), deps.jwt.accessSecret));
  router.use('/api/adherence', adherenceRoutes(new AdherenceController(adherenceService, familyService), deps.jwt.accessSecret));
  router.use('/api/notifications', notificationsRoutes(new NotificationsController(notificationsService), deps.jwt.accessSecret));
  router.use('/api/games', gamesRoutes(new GamesController(gamesService, familyService), deps.jwt.accessSecret));
  router.use('/api/activity', activityRoutes(new ActivityController(activityService, familyService), deps.jwt.accessSecret));
  router.use(
    '/api/emergency/contacts',
    emergencyContactsRoutes(new EmergencyContactsController(emergencyService, familyService), deps.jwt.accessSecret),
  );
  router.use('/api/emergency', emergencyEventsRoutes(new EmergencyEventsController(emergencyService, familyService), deps.jwt.accessSecret));
  router.use('/api/voice', voiceRoutes(new VoiceController(voiceService, familyService), deps.jwt.accessSecret));
  router.use('/api/ai', aiRoutes(new AiController(aiService, familyService), deps.jwt.accessSecret));
  router.use('/internal', internalRoutes(new InternalController(internalContextService), deps.internalApiKey));
  router.use(
    '/api/family/dashboard',
    caregiverDashboardRoutes(new CaregiverDashboardController(caregiverDashboardService), deps.jwt.accessSecret),
  );

  return router;
}
