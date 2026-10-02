import pino from 'pino';
import { env } from './env';

export const logger = pino({
  level: env.LOG_LEVEL,
  // Never log credentials.
  redact: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.token', '*.refreshToken'],
  ...(env.NODE_ENV === 'development' ? { transport: { target: 'pino-pretty' } } : {}),
});
