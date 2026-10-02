import { z } from 'zod';
import { dateOnly } from '../../common/validators/idParam';

const phone = z
  .string()
  .trim()
  .min(1, 'Phone number is required')
  .max(30)
  .regex(/^[0-9+\-() .]+$/, 'Enter a valid phone number');

export const createContactSchema = z.object({
  body: z.object({
    name: z.string().trim().min(1, 'Name is required').max(120),
    phone,
    relationship: z.string().trim().max(60).optional(),
    priority: z.number().int().min(0).optional(),
  }),
});

export const updateContactSchema = z.object({
  body: z
    .object({
      name: z.string().trim().min(1).max(120).optional(),
      phone: phone.optional(),
      relationship: z.string().trim().max(60).nullable().optional(),
      priority: z.number().int().min(0).optional(),
    })
    .refine((v) => Object.keys(v).length > 0, 'Provide at least one field to update'),
});

export const listContactsQuerySchema = z.object({ query: z.object({ elderId: z.string().uuid().optional() }) });

export const sosSchema = z
  .object({
    body: z.object({
      latitude: z.number().min(-90).max(90).optional(),
      longitude: z.number().min(-180).max(180).optional(),
    }),
  })
  .refine((v) => (v.body.latitude == null) === (v.body.longitude == null), {
    message: 'Provide both latitude and longitude, or neither',
    path: ['body', 'longitude'],
  });

export const listEventsQuerySchema = z
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
