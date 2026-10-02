import type { RequestHandler } from 'express';
import { AppError } from '../../common/errors/AppError';
import type { InternalContextService } from './internalContext.service';

export class InternalController {
  constructor(private readonly service: InternalContextService) {}

  medicineContext: RequestHandler = async (req, res, next) => {
    try {
      const elderId = req.params.elderId;
      if (!elderId) throw AppError.badRequest('elderId is required');
      const context = await this.service.getMedicineContext(elderId);
      res.json({ success: true, ...context });
    } catch (e) {
      next(e);
    }
  };

  caregiverInsightContext: RequestHandler = async (req, res, next) => {
    try {
      const elderId = req.params.elderId;
      if (!elderId) throw AppError.badRequest('elderId is required');
      const context = await this.service.getCaregiverInsightContext(elderId);
      res.json({ success: true, ...context });
    } catch (e) {
      next(e);
    }
  };
}
