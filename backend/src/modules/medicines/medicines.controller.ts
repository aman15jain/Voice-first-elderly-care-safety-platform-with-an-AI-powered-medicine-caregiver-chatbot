import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { MedicinesService } from './medicines.service';

export class MedicinesController {
  constructor(
    private readonly service: MedicinesService,
    private readonly family: FamilyService,
  ) {}

  // Mutations are elder-only and always act on the caller's own data (enforced by requireRole('ELDER')
  // in medicines.routes.ts), so there's no elder id to resolve here.

  create: RequestHandler = async (req, res, next) => {
    try {
      const medicine = await this.service.createMedicine(req.auth!.userId, req.body);
      res.status(201).json({ success: true, medicine });
    } catch (e) {
      next(e);
    }
  };

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const medicines = await this.service.listMedicines(elderId, req.query.includeInactive === 'true');
      res.json({ success: true, medicines });
    } catch (e) {
      next(e);
    }
  };

  update: RequestHandler = async (req, res, next) => {
    try {
      const medicine = await this.service.updateMedicine(req.auth!.userId, req.params.id as string, req.body);
      res.json({ success: true, medicine });
    } catch (e) {
      next(e);
    }
  };

  remove: RequestHandler = async (req, res, next) => {
    try {
      const medicine = await this.service.deleteMedicine(req.auth!.userId, req.params.id as string);
      res.json({ success: true, medicine });
    } catch (e) {
      next(e);
    }
  };
}
