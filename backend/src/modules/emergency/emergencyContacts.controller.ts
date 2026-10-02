import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { EmergencyService } from './emergency.service';

export class EmergencyContactsController {
  constructor(
    private readonly service: EmergencyService,
    private readonly family: FamilyService,
  ) {}

  list: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const contacts = await this.service.listContacts(elderId);
      res.json({ success: true, contacts });
    } catch (e) {
      next(e);
    }
  };

  create: RequestHandler = async (req, res, next) => {
    try {
      const contact = await this.service.createContact(req.auth!.userId, req.body);
      res.status(201).json({ success: true, contact });
    } catch (e) {
      next(e);
    }
  };

  update: RequestHandler = async (req, res, next) => {
    try {
      const contact = await this.service.updateContact(req.auth!.userId, req.params.id as string, req.body);
      res.json({ success: true, contact });
    } catch (e) {
      next(e);
    }
  };

  remove: RequestHandler = async (req, res, next) => {
    try {
      await this.service.deleteContact(req.auth!.userId, req.params.id as string);
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  };
}
