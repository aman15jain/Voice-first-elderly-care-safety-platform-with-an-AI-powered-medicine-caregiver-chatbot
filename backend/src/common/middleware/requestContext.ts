import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';
import { logger } from '../../config/logger';

/** Assigns a request ID and logs one line per request (no bodies, no auth headers). */
export const requestContext: RequestHandler = (req, res, next) => {
  const id = req.header('x-request-id') ?? randomUUID();
  res.locals.requestId = id;
  res.setHeader('x-request-id', id);
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    logger.info(
      {
        requestId: id,
        method: req.method,
        endpoint: req.originalUrl.split('?')[0],
        status: res.statusCode,
        durationMs: Number(process.hrtime.bigint() - start) / 1e6,
      },
      'request completed',
    );
  });
  next();
};
