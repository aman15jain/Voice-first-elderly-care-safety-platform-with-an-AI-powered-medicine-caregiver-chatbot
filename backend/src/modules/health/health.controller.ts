import type { RequestHandler } from 'express';
import type { HealthService } from './health.service';

export class HealthController {
  constructor(private readonly service: HealthService) {}

  live: RequestHandler = (_req, res) => {
    res.json(this.service.liveness());
  };

  dependencies: RequestHandler = async (_req, res, next) => {
    try {
      const result = await this.service.dependencies();
      res.status(result.status === 'ok' ? 200 : 503).json(result);
    } catch (e) {
      next(e);
    }
  };
}
