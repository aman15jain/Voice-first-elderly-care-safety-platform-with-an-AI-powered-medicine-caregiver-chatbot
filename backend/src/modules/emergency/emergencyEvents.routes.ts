import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { EmergencyEventsController } from './emergencyEvents.controller';
import { listEventsQuerySchema, sosSchema } from './emergency.validators';

export function emergencyEventsRoutes(controller: EmergencyEventsController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.post('/sos', requireRole('ELDER'), validate(sosSchema), controller.trigger);
  router.get('/events', validate(listEventsQuerySchema), controller.list);
  // Only a linked caregiver can acknowledge — it means "I've seen this and am responding".
  router.patch('/events/:id/acknowledge', requireRole('CAREGIVER'), validate(uuidParamSchema()), controller.acknowledge);
  // Either the elder themself (false alarm / feeling fine) or a linked caregiver can resolve.
  router.patch('/events/:id/resolve', requireRole('ELDER', 'CAREGIVER'), validate(uuidParamSchema()), controller.resolve);

  return router;
}
