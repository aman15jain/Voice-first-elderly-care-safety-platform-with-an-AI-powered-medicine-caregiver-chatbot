import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { ActivityService } from './activity.service';

const DEFAULT_RANGE_DAYS = 7;

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class ActivityController {
  constructor(
    private readonly service: ActivityService,
    private readonly family: FamilyService,
  ) {}

  recordAppOpened: RequestHandler = async (req, res, next) => {
    try {
      await this.service.recordAppOpened(req.auth!.userId);
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  };

  summary: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const now = new Date();
      const to = req.query.to ? new Date(`${req.query.to as string}T00:00:00.000Z`) : endOfUtcDay(now);
      const from = req.query.from
        ? new Date(`${req.query.from as string}T00:00:00.000Z`)
        : new Date(startOfUtcDay(now).getTime() - (DEFAULT_RANGE_DAYS - 1) * 86_400_000);
      const days = await this.service.dailySummary(elderId, from, to);
      res.json({ success: true, days });
    } catch (e) {
      next(e);
    }
  };
}
