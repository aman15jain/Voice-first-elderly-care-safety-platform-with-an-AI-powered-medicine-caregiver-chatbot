import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { AiController } from './ai.controller';
import { askSchema, caregiverInsightQuerySchema } from './ai.validators';

export function aiRoutes(controller: AiController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.post('/ask', requireRole('ELDER'), validate(askSchema), controller.askMedicineQuestion);
  router.get('/caregiver-insight', validate(caregiverInsightQuerySchema), controller.getCaregiverInsight);

  return router;
}
