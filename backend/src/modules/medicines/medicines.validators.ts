import { z } from 'zod';
import { dateOnly } from '../../common/validators/idParam';

export const createMedicineSchema = z.object({
  body: z.object({
    name: z.string().trim().min(1, 'Name is required').max(160),
    dosage: z.string().trim().min(1, 'Dosage is required').max(60),
    instructions: z.string().trim().max(500).optional(),
  }),
});

export const updateMedicineSchema = z.object({
  body: z
    .object({
      name: z.string().trim().min(1).max(160).optional(),
      dosage: z.string().trim().min(1).max(60).optional(),
      instructions: z.string().trim().max(500).nullable().optional(),
    })
    .refine((v) => Object.keys(v).length > 0, 'Provide at least one field to update'),
});

export const listMedicinesQuerySchema = z.object({
  query: z.object({ includeInactive: z.enum(['true', 'false']).optional() }),
});

const timeOfDay = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected 24-hour time as HH:mm');
const dayOfWeek = z.number().int().min(0).max(6);

export const createScheduleSchema = z
  .object({
    body: z.object({
      medicineId: z.string().uuid(),
      timesOfDay: z.array(timeOfDay).min(1, 'At least one time is required').max(6),
      daysOfWeek: z.array(dayOfWeek).max(7).default([]),
      startDate: dateOnly,
      endDate: dateOnly.optional(),
    }),
  })
  .refine((v) => !v.body.endDate || v.body.endDate >= v.body.startDate, {
    message: 'endDate must be on or after startDate',
    path: ['body', 'endDate'],
  });

export const updateScheduleSchema = z.object({
  body: z
    .object({
      timesOfDay: z.array(timeOfDay).min(1).max(6).optional(),
      daysOfWeek: z.array(dayOfWeek).max(7).optional(),
      endDate: dateOnly.nullable().optional(),
      isActive: z.boolean().optional(),
    })
    .refine((v) => Object.keys(v).length > 0, 'Provide at least one field to update'),
});

export const listSchedulesQuerySchema = z.object({
  query: z.object({ medicineId: z.string().uuid().optional() }),
});
