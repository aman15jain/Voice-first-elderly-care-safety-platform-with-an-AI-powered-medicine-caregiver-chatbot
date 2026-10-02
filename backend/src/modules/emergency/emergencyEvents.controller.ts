import type { Role } from '@prisma/client';
import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { EmergencyService } from './emergency.service';

const DEFAULT_RANGE_DAYS = 30;

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

export class EmergencyEventsController {
  constructor(
    private readonly service: EmergencyService,
    private readonly family: FamilyService,
  ) {}

  /** Returns the event plus the elder's own contact list, so Flutter can immediately offer
   * "Call <top contact>" without a second round trip. */
  trigger: RequestHandler = async (req, res, next) => {
    try {
      const elderId = req.auth!.userId;
      const { latitude, longitude } = req.body as { latitude?: number; longitude?: number };
      const location = latitude != null && longitude != null ? { latitude, longitude } : undefined;
      const event = await this.service.triggerSOS(elderId, location);
      const contacts = await this.service.listContacts(elderId);
      res.status(201).json({ success: true, event, contacts });
    } catch (e) {
      next(e);
    }
  };

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const now = new Date();
      const to = req.query.to ? new Date(`${req.query.to as string}T00:00:00.000Z`) : endOfUtcDay(now);
      const from = req.query.from
        ? new Date(`${req.query.from as string}T00:00:00.000Z`)
        : new Date(startOfUtcDay(now).getTime() - (DEFAULT_RANGE_DAYS - 1) * 86_400_000);
      const events = await this.service.listEvents(elderId, from, to);
      res.json({ success: true, events });
    } catch (e) {
      next(e);
    }
  };

  acknowledge: RequestHandler = async (req, res, next) => {
    try {
      const event = await this.service.acknowledge(req.auth!.userId, req.params.id as string);
      res.json({ success: true, event });
    } catch (e) {
      next(e);
    }
  };

  resolve: RequestHandler = async (req, res, next) => {
    try {
      const event = await this.service.resolve(req.auth!.userId, req.auth!.role as Role, req.params.id as string);
      res.json({ success: true, event });
    } catch (e) {
      next(e);
    }
  };
}
