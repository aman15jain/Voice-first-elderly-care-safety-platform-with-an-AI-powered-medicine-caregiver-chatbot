import { Router } from 'express';
import { createAuthRateLimiter } from '../../common/middleware/authRateLimit';
import { validate } from '../../common/middleware/validate';
import type { AuthController } from './auth.controller';
import { loginSchema, refreshSchema, registerSchema } from './auth.validators';

export function authRoutes(controller: AuthController): Router {
  const router = Router();
  // Stricter than the global limiter (app.ts) — specifically to bound password-guessing
  // attempts, which the global DoS-oriented limiter doesn't meaningfully constrain.
  const authRateLimiter = createAuthRateLimiter();
  router.post('/register', authRateLimiter, validate(registerSchema), controller.register);
  router.post('/login', authRateLimiter, validate(loginSchema), controller.login);
  router.post('/refresh', validate(refreshSchema), controller.refresh);
  router.post('/logout', validate(refreshSchema), controller.logout);
  return router;
}
