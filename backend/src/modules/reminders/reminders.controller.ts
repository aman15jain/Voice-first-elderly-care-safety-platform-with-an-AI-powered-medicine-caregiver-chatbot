import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { RemindersService } from './reminders.service';

export class RemindersController {
  constructor(
    private readonly service: RemindersService,
    private readonly family: FamilyService,
  ) {}

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const from = req.query.from ? new Date(`${req.query.from as string}T00:00:00.000Z`) : undefined;
      const to = req.query.to ? new Date(`${req.query.to as string}T00:00:00.000Z`) : undefined;
      const doses = await this.service.listDoses(elderId, from, to);
      res.json({ success: true, doses });
    } catch (e) {
      next(e);
    }
  };

  markReminded: RequestHandler = async (req, res, next) => {
    try {
      // Only the owning elder's own device marks a reminder as delivered.
      const dose = await this.service.markReminded(req.auth!.userId, req.params.id as string);
      res.json({ success: true, dose });
    } catch (e) {
      next(e);
    }
  };
}
