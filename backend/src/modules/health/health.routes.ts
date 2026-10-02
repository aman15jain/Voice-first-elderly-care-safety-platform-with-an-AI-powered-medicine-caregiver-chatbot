import { Router } from 'express';
import type { HealthController } from './health.controller';

export function healthRoutes(controller: HealthController): Router {
  const router = Router();
  router.get('/', controller.live);
  router.get('/dependencies', controller.dependencies);
  return router;
}
