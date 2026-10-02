import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ORIGINS: z.string().default(''),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters'),
  // Doubles as the pepper mixed into hashed refresh tokens (see common/utils/tokens.ts).
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be at least 16 characters'),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  AI_SERVICE_URL: z.string().url().default('http://localhost:8000'),
  AI_SERVICE_TIMEOUT_MS: z.coerce.number().int().positive().default(5000),
  AI_SERVICE_API_KEY: z.string().default(''),

  // --- Reminder engine (Phase 3) ---
  // How far ahead dose rows are generated from active schedules.
  DOSE_GENERATION_DAYS_AHEAD: z.coerce.number().int().min(1).max(14).default(2),
  // Grace period after a scheduled time before an unconfirmed dose is marked MISSED.
  MISSED_DOSE_GRACE_MINUTES: z.coerce.number().int().positive().default(60),
  // How often the background sweep (generate + missed-dose check) runs. Disabled in tests.
  REMINDER_SWEEP_INTERVAL_MINUTES: z.coerce.number().int().positive().default(15),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  // Log only field names/messages, never values (may contain secrets).
  console.error('Invalid environment configuration:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = {
  ...parsed.data,
  corsOrigins: parsed.data.CORS_ORIGINS.split(',')
    .map((s) => s.trim())
    .filter(Boolean),
};
export type Env = typeof env;
