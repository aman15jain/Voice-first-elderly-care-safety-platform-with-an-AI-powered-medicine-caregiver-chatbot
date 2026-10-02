import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { EmergencyContactsController } from './emergencyContacts.controller';
import { createContactSchema, listContactsQuerySchema, updateContactSchema } from './emergency.validators';

export function emergencyContactsRoutes(controller: EmergencyContactsController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/', validate(listContactsQuerySchema), controller.list);
  router.post('/', requireRole('ELDER'), validate(createContactSchema), controller.create);
  router.patch('/:id', requireRole('ELDER'), validate(uuidParamSchema()), validate(updateContactSchema), controller.update);
  router.delete('/:id', requireRole('ELDER'), validate(uuidParamSchema()), controller.remove);

  return router;
}
