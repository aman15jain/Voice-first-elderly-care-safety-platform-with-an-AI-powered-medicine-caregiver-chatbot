import { z } from 'zod';

export const inviteSchema = z.object({
  body: z.object({
    email: z.string().trim().toLowerCase().email('Enter a valid email address'),
  }),
});

export const linkIdParamSchema = z.object({
  params: z.object({
    id: z.string().uuid('Invalid family link id'),
  }),
});
