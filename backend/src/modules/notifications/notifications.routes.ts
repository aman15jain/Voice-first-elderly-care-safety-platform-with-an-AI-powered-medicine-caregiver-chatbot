import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { NotificationsController } from './notifications.controller';

export function notificationsRoutes(controller: NotificationsController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));
  router.get('/', controller.list);
  router.patch('/:id/read', validate(uuidParamSchema()), controller.markRead);
  return router;
}
