import { z } from 'zod';
import { dateOnly } from '../../common/validators/idParam';

export const processCommandSchema = z.object({
  body: z.object({
    transcript: z.string().trim().min(1, 'Transcript is required').max(500),
    language: z.string().trim().min(2).max(10).optional(),
  }),
});

export const listInteractionsQuerySchema = z
  .object({
    query: z.object({
      elderId: z.string().uuid().optional(),
      from: dateOnly.optional(),
      to: dateOnly.optional(),
    }),
  })
  .refine((v) => !v.query.from === !v.query.to, { message: 'Provide both from and to, or neither', path: ['query', 'to'] })
  .refine((v) => !v.query.from || !v.query.to || v.query.from <= v.query.to, {
    message: 'from must be on or before to',
    path: ['query', 'from'],
  })
  .refine((v) => !v.query.from || !v.query.to || v.query.to.getTime() - v.query.from.getTime() <= 90 * 86_400_000, {
    message: 'Date range cannot exceed 90 days',
    path: ['query', 'to'],
  });
