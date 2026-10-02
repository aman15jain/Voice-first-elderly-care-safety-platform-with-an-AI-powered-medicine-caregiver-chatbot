import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { VoiceController } from './voice.controller';
import { listInteractionsQuerySchema, processCommandSchema } from './voice.validators';

export function voiceRoutes(controller: VoiceController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.post('/process', requireRole('ELDER'), validate(processCommandSchema), controller.process);
  router.get('/interactions', validate(listInteractionsQuerySchema), controller.listInteractions);

  return router;
}
