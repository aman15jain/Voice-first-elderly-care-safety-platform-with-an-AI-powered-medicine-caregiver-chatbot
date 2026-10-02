import { z } from 'zod';

export const notificationPreferencesSchema = z.object({
  body: z.object({
    notifyOnMissedDose: z.boolean(),
  }),
});
