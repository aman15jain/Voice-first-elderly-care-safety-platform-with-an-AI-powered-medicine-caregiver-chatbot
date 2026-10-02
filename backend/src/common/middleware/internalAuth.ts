import type { RequestHandler } from 'express';
import { AppError } from '../errors/AppError';

/**
 * Guards routes that only the Python agentic-ai service may call — never Flutter, never a
 * user's access token. Both services are configured with the same shared secret (`AI_SERVICE_API_KEY`
 * in Node, `INTERNAL_API_KEY` in Python): Node uses it when calling out to Python, and checks it here
 * when Python calls back in, since the two processes form a single internal trust boundary.
 *
 * An empty key disables the check (local development only, mirroring the Python side's own rule).
 */
export function requireInternalApiKey(expectedKey: string): RequestHandler {
  return (req, _res, next) => {
    if (!expectedKey) {
      next();
      return;
    }
    if (req.header('x-internal-api-key') !== expectedKey) {
      next(AppError.unauthorized('Invalid internal API key'));
      return;
    }
    next();
  };
}
