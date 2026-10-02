import { z } from 'zod';

export const registerSchema = z.object({
  body: z.object({
    email: z.string().trim().toLowerCase().email('Enter a valid email address'),
    // Self-registration is limited to ELDER/CAREGIVER; admins are provisioned separately.
    role: z.enum(['ELDER', 'CAREGIVER']),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .max(72)
      .regex(/[A-Za-z]/, 'Password must include a letter')
      .regex(/[0-9]/, 'Password must include a number'),
    fullName: z.string().trim().min(1, 'Full name is required').max(120),
    preferredLanguage: z.string().trim().min(2).max(10).optional(),
  }),
});

export const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().toLowerCase().email('Enter a valid email address'),
    password: z.string().min(1, 'Password is required'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(10, 'A refresh token is required'),
  }),
});
