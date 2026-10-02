import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { GamesService } from './games.service';

const DEFAULT_RANGE_DAYS = 30;

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class GamesController {
  constructor(
    private readonly service: GamesService,
    private readonly family: FamilyService,
  ) {}

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const games = await this.service.listGames(elderId);
      res.json({ success: true, games });
    } catch (e) {
      next(e);
    }
  };

  recordSession: RequestHandler = async (req, res, next) => {
    try {
      // Only the elder plays for themself — a caregiver can watch, never record a session.
      const session = await this.service.recordSession(req.auth!.userId, req.params.id as string, req.body);
      res.status(201).json({ success: true, session });
    } catch (e) {
      next(e);
    }
  };

  listSessions: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const now = new Date();
      const to = req.query.to ? new Date(`${req.query.to as string}T00:00:00.000Z`) : endOfUtcDay(now);
      const from = req.query.from
        ? new Date(`${req.query.from as string}T00:00:00.000Z`)
        : new Date(startOfUtcDay(now).getTime() - (DEFAULT_RANGE_DAYS - 1) * 86_400_000);
      const sessions = await this.service.listSessions(elderId, from, to, req.query.gameId as string | undefined);
      res.json({ success: true, sessions });
    } catch (e) {
      next(e);
    }
  };
}
