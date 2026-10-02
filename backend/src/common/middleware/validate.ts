import type { RequestHandler } from 'express';
import type { ZodTypeAny } from 'zod';

/**
 * Validates { body, params, query } against `schema` and replaces req.body with the
 * parsed (trimmed/coerced) result. Failures are ZodErrors, turned into 400s by errorHandler.
 */
export function validate(schema: ZodTypeAny): RequestHandler {
  return (req, _res, next) => {
    const result = schema.parse({ body: req.body, params: req.params, query: req.query });
    if (result.body !== undefined) req.body = result.body;
    next();
  };
}
