import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { UsersController } from './users.controller';
import { notificationPreferencesSchema } from './users.validators';

export function usersRoutes(controller: UsersController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));
  router.get('/me', controller.me);
  router.patch(
    '/me/notification-preferences',
    requireRole('CAREGIVER'),
    validate(notificationPreferencesSchema),
    controller.updateNotificationPreferences,
  );
  return router;
}
