import { z } from 'zod';
import { dateOnly } from '../../common/validators/idParam';
import { MAX_DIFFICULTY, MIN_DIFFICULTY } from './gameDifficulty';

export const listGamesQuerySchema = z.object({ query: z.object({ elderId: z.string().uuid().optional() }) });

export const gameIdParamSchema = z.object({ params: z.object({ id: z.string().uuid('Invalid game id') }) });

export const recordSessionSchema = z.object({
  body: z.object({
    difficulty: z.number().int().min(MIN_DIFFICULTY).max(MAX_DIFFICULTY),
    score: z.number().int().min(0).max(10_000),
    mistakes: z.number().int().min(0).max(1000),
    // A session capped at one hour — long enough for any real round, short enough to reject garbage.
    durationSeconds: z.number().int().min(1).max(3600),
    completed: z.boolean(),
  }),
});

export const listSessionsQuerySchema = z
  .object({
    query: z.object({
      elderId: z.string().uuid().optional(),
      gameId: z.string().uuid().optional(),
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
