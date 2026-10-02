import type { RequestHandler } from 'express';
import type { UsersService } from './users.service';

export class UsersController {
  constructor(private readonly service: UsersService) {}

  me: RequestHandler = async (req, res, next) => {
    try {
      // req.auth is guaranteed by the `authenticate` middleware mounted on this router.
      const profile = await this.service.me(req.auth!.userId);
      res.json({ success: true, ...profile });
    } catch (e) {
      next(e);
    }
  };

  updateNotificationPreferences: RequestHandler = async (req, res, next) => {
    try {
      const { notifyOnMissedDose } = req.body as { notifyOnMissedDose: boolean };
      const preferences = await this.service.updateNotificationPreferences(req.auth!.userId, req.auth!.role, { notifyOnMissedDose });
      res.json({ success: true, ...preferences });
    } catch (e) {
      next(e);
    }
  };
}
