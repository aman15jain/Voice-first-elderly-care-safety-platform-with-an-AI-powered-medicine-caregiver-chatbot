import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { FamilyController } from './family.controller';
import { inviteSchema, linkIdParamSchema } from './family.validators';

export function familyRoutes(controller: FamilyController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/', controller.list);
  // Admins have no family graph of their own.
  router.post('/', requireRole('ELDER', 'CAREGIVER'), validate(inviteSchema), controller.invite);
  router.patch('/:id/accept', validate(linkIdParamSchema), controller.accept);
  router.patch('/:id/decline', validate(linkIdParamSchema), controller.decline);
  router.delete('/:id', validate(linkIdParamSchema), controller.revoke);

  return router;
}
