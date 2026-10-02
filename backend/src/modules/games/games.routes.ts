import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate';
import { requireRole } from '../../common/middleware/authorize';
import { validate } from '../../common/middleware/validate';
import type { GamesController } from './games.controller';
import { gameIdParamSchema, listGamesQuerySchema, listSessionsQuerySchema, recordSessionSchema } from './games.validators';

export function gamesRoutes(controller: GamesController, accessSecret: string): Router {
  const router = Router();
  router.use(authenticate(accessSecret));

  router.get('/', validate(listGamesQuerySchema), controller.list);
  router.get('/sessions', validate(listSessionsQuerySchema), controller.listSessions);
  router.post('/:id/session', requireRole('ELDER'), validate(gameIdParamSchema), validate(recordSessionSchema), controller.recordSession);

  return router;
}
