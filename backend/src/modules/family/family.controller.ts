import type { Role } from '@prisma/client';
import type { RequestHandler } from 'express';
import type { FamilyService } from './family.service';

export class FamilyController {
  constructor(private readonly service: FamilyService) {}

  invite: RequestHandler = async (req, res, next) => {
    try {
      const link = await this.service.invite(req.auth!.userId, req.auth!.role as Role, req.body.email);
      res.status(201).json({ success: true, link });
    } catch (e) {
      next(e);
    }
  };

  accept: RequestHandler = async (req, res, next) => {
    try {
      const link = await this.service.respond(req.auth!.userId, req.params.id as string, true);
      res.json({ success: true, link });
    } catch (e) {
      next(e);
    }
  };

  decline: RequestHandler = async (req, res, next) => {
    try {
      const link = await this.service.respond(req.auth!.userId, req.params.id as string, false);
      res.json({ success: true, link });
    } catch (e) {
      next(e);
    }
  };

  revoke: RequestHandler = async (req, res, next) => {
    try {
      const link = await this.service.revoke(req.auth!.userId, req.params.id as string);
      res.json({ success: true, link });
    } catch (e) {
      next(e);
    }
  };

  list: RequestHandler = async (req, res, next) => {
    try {
      const links = await this.service.list(req.auth!.userId);
      res.json({ success: true, links });
    } catch (e) {
      next(e);
    }
  };
}
