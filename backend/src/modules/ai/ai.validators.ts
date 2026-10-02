import { z } from 'zod';

export const askSchema = z.object({
  body: z.object({
    query: z.string().trim().min(1, 'Please ask a question').max(500),
    language: z.string().trim().min(2).max(10).optional(),
  }),
});

export const caregiverInsightQuerySchema = z.object({
  query: z.object({
    elderId: z.string().uuid().optional(),
    language: z.string().trim().min(2).max(10).optional(),
  }),
});
