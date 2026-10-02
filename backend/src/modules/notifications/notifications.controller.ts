import type { RequestHandler } from 'express';
import type { NotificationsService } from './notifications.service';

export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  list: RequestHandler = async (req, res, next) => {
    try {
      const notifications = await this.service.list(req.auth!.userId, req.query.unreadOnly === 'true');
      res.json({ success: true, notifications });
    } catch (e) {
      next(e);
    }
  };

  markRead: RequestHandler = async (req, res, next) => {
    try {
      const notification = await this.service.markRead(req.auth!.userId, req.params.id as string);
      res.json({ success: true, notification });
    } catch (e) {
      next(e);
    }
  };
}
