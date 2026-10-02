import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { AdherenceService } from './adherence.service';

const DEFAULT_RANGE_DAYS = 30;
const DEFAULT_TREND_DAYS = 14;

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class AdherenceController {
  constructor(
    private readonly service: AdherenceService,
    private readonly family: FamilyService,
  ) {}

  markTaken: RequestHandler = async (req, res, next) => {
    try {
      const dose = await this.service.markTaken(req.auth!.userId, req.params.doseId as string);
      res.json({ success: true, dose });
    } catch (e) {
      next(e);
    }
  };

  markSkipped: RequestHandler = async (req, res, next) => {
    try {
      const dose = await this.service.markSkipped(req.auth!.userId, req.params.doseId as string);
      res.json({ success: true, dose });
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
      const summary = await this.service.summary(elderId, from, to);
      res.json({ success: true, summary });
    } catch (e) {
      next(e);
    }
  };

  trend: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const now = new Date();
      const to = req.query.to ? new Date(`${req.query.to as string}T00:00:00.000Z`) : endOfUtcDay(now);
      const from = req.query.from
        ? new Date(`${req.query.from as string}T00:00:00.000Z`)
        : new Date(startOfUtcDay(now).getTime() - (DEFAULT_TREND_DAYS - 1) * 86_400_000);
      const days = await this.service.trend(elderId, from, to);
      res.json({ success: true, days });
    } catch (e) {
      next(e);
    }
  };
}
