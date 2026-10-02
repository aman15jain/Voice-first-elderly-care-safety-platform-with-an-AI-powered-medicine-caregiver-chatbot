import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { MedicinesService } from './medicines.service';

export class MedicineSchedulesController {
  constructor(
    private readonly service: MedicinesService,
    private readonly family: FamilyService,
  ) {}

  create: RequestHandler = async (req, res, next) => {
    try {
      const schedule = await this.service.createSchedule(req.auth!.userId, req.body);
      res.status(201).json({ success: true, schedule });
    } catch (e) {
      next(e);
    }
  };

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const schedules = await this.service.listSchedules(elderId, req.query.medicineId as string | undefined);
      res.json({ success: true, schedules });
    } catch (e) {
      next(e);
    }
  };

  update: RequestHandler = async (req, res, next) => {
    try {
      const schedule = await this.service.updateSchedule(req.auth!.userId, req.params.id as string, req.body);
      res.json({ success: true, schedule });
    } catch (e) {
      next(e);
    }
  };
}
