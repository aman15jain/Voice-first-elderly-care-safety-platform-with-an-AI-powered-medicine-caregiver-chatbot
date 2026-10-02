import type { RequestHandler } from 'express';
import { AppError } from '../errors/AppError';
import type { AppRole } from './authenticate';

/** Must run after `authenticate`. Rejects roles not in the allow-list. */
export function requireRole(...roles: AppRole[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.auth) {
      next(AppError.unauthorized());
      return;
    }
    if (!roles.includes(req.auth.role)) {
      next(AppError.forbidden());
      return;
    }
    next();
  };
}
