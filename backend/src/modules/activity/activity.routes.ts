import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { ActivityController } from './activity.controller';
import { summaryQuerySchema } from './activity.validators';

export function activityRoutes(controller: ActivityController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/summary', validate(summaryQuerySchema), controller.summary);
  router.post('/app-opened', requireRole('ELDER'), controller.recordAppOpened);

  return router;
}
