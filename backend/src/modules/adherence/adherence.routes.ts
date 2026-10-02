import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { AdherenceController } from './adherence.controller';
import { doseIdParamSchema, summaryQuerySchema } from './adherence.validators';

export function adherenceRoutes(controller: AdherenceController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/summary', validate(summaryQuerySchema), controller.summary);
  router.get('/trend', validate(summaryQuerySchema), controller.trend);
  // Only the elder confirms their own doses — not even a linked caregiver can do this for them.
  router.post('/:doseId/taken', requireRole('ELDER'), validate(doseIdParamSchema), controller.markTaken);
  router.post('/:doseId/skipped', requireRole('ELDER'), validate(doseIdParamSchema), controller.markSkipped);

  return router;
}
