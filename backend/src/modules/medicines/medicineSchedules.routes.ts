import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import { uuidParamSchema } from '../../common/validators/idParam';
import type { MedicineSchedulesController } from './medicineSchedules.controller';
import { createScheduleSchema, listSchedulesQuerySchema, updateScheduleSchema } from './medicines.validators';

export function medicineSchedulesRoutes(controller: MedicineSchedulesController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/', validate(listSchedulesQuerySchema), controller.list);
  router.post('/', requireRole('ELDER'), validate(createScheduleSchema), controller.create);
  router.patch('/:id', requireRole('ELDER'), validate(uuidParamSchema()), validate(updateScheduleSchema), controller.update);

  return router;
}
