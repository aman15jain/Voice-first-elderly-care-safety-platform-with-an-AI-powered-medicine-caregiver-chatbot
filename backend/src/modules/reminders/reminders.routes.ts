import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { RemindersController } from './reminders.controller';
import { listDosesQuerySchema } from './reminders.validators';

export function remindersRoutes(controller: RemindersController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));
  router.get('/', validate(listDosesQuerySchema), controller.list);
  router.post('/:id/reminded', validate(uuidParamSchema()), controller.markReminded);
  return router;
}
