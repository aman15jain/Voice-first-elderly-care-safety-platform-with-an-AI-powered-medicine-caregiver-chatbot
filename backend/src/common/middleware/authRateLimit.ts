import rateLimit from 'express-rate-limit';

/**
 * The global limiter (app.ts, 300 req/min) is a DoS guard, not brute-force protection — it still
 * leaves a meaningful password-guessing budget against one account. This is a much tighter,
 * IP-scoped budget on just login/register, matching the app's own error response shape instead
 * of express-rate-limit's default body.
 *
 * A factory, not a module-level singleton: `createApp` is called once per test (see
 * tests/helpers/buildTestApp.ts), and a shared instance would leak its request count across
 * unrelated tests in the same process.
 */
export function createAuthRateLimiter() {
  return rateLimit({
    windowMs: 15 * 60_000,
    limit: 10,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({ success: false, error: { code: 'TOO_MANY_REQUESTS', message: 'Too many attempts. Please try again later.' } });
    },
  });
}
