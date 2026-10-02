import type { RequestHandler } from 'express';
import { AppError } from '../errors/AppError';
import { verifyAccessToken } from '../utils/tokens';

export type AppRole = 'ELDER' | 'CAREGIVER' | 'ADMIN';

export interface AuthContext {
  userId: string;
  role: AppRole;
}

declare module 'express-serve-static-core' {
  interface Request {
    /** Set by `authenticate`. Only ever derived from a verified access token, never from client input. */
    auth?: AuthContext;
  }
}

/** Requires a valid `Authorization: Bearer <accessToken>` header. */
export function authenticate(accessSecret: string): RequestHandler {
  return (req, _res, next) => {
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) {
      next(AppError.unauthorized());
      return;
    }
    try {
      const payload = verifyAccessToken(header.slice('Bearer '.length), accessSecret);
      req.auth = { userId: payload.sub, role: payload.role as AppRole };
      next();
    } catch {
      next(AppError.unauthorized('Invalid or expired session'));
    }
  };
}
