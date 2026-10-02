import { Router } from 'express';
import { requireInternalApiKey } from '../../common/middleware/internalAuth';
import type { InternalController } from './internal.controller';

/** Mounted at /internal — callable only by the agentic-ai service, never by Flutter or a user token. */
export function internalRoutes(controller: InternalController, internalApiKey: string): Router {
  const router = Router();
  router.use(requireInternalApiKey(internalApiKey));

  router.get('/elders/:elderId/medicine-context', controller.medicineContext);
  router.get('/elders/:elderId/caregiver-insight-context', controller.caregiverInsightContext);

  return router;
}
