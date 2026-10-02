import compression from 'compression';
import cors from 'cors';
import express, { type Express } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { env } from './config/env';
import { errorHandler, notFoundHandler } from './common/middleware/errorHandler';
import { requestContext } from './common/middleware/requestContext';
import { buildRoutes, type AppDeps } from './routes';

export function createApp(deps: AppDeps): Express {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);

  app.use(requestContext);
  app.use(helmet());
  app.use(cors({ origin: env.corsOrigins.length ? env.corsOrigins : false }));
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(rateLimit({ windowMs: 60_000, limit: 300, standardHeaders: true, legacyHeaders: false }));

  app.use(buildRoutes(deps));

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
