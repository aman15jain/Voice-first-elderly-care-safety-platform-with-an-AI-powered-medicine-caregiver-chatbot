import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { MedicinesController } from './medicines.controller';
import { createMedicineSchema, listMedicinesQuerySchema, updateMedicineSchema } from './medicines.validators';

export function medicinesRoutes(controller: MedicinesController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/', validate(listMedicinesQuerySchema), controller.list);
  router.post('/', requireRole('ELDER'), validate(createMedicineSchema), controller.create);
  router.patch('/:id', requireRole('ELDER'), validate(uuidParamSchema()), validate(updateMedicineSchema), controller.update);
  router.delete('/:id', requireRole('ELDER'), validate(uuidParamSchema()), controller.remove);

  return router;
}
