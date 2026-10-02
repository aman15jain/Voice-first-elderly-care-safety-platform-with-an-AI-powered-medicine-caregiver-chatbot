import type { RequestHandler } from 'express';
import type { CaregiverDashboardService } from './caregiverDashboard.service';

export class CaregiverDashboardController {
  constructor(private readonly service: CaregiverDashboardService) {}

  getDashboard: RequestHandler = async (req, res, next) => {
    try {
      const elders = await this.service.getDashboard(req.auth!.userId);
      res.json({ success: true, elders });
    } catch (e) {
      next(e);
    }
  };
}
