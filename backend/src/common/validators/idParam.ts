import { z } from 'zod';

/** Reusable `{ params: { [name]: uuid } }` validator for `/:id`-style routes. */
export function uuidParamSchema(name = 'id') {
  return z.object({ params: z.object({ [name]: z.string().uuid(`Invalid ${name}`) }) });
}

export const dateOnly = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected a date in YYYY-MM-DD format')
  .transform((s) => new Date(`${s}T00:00:00.000Z`))
  .refine((d) => !Number.isNaN(d.getTime()), 'Invalid date');
