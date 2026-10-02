import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import type { CaregiverDashboardController } from './caregiverDashboard.controller';

export function caregiverDashboardRoutes(controller: CaregiverDashboardController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));
  router.get('/', requireRole('CAREGIVER'), controller.getDashboard);
  return router;
}
