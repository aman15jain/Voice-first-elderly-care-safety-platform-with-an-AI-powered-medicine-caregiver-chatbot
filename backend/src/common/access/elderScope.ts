import { AppError } from '../errors/AppError';
import type { AuthContext } from '../middleware/authenticate';

/** Narrow view of FamilyService so this helper doesn't depend on the whole family module. */
export interface FamilyAccessCheck {
  assertCaregiverCanAccessElder(caregiverId: string, elderId: string): Promise<void>;
}

/**
 * Resolves which elder's data a request may act on. This is the single enforcement
 * point for "a caregiver only sees what's explicitly shared with them" across the
 * medicines/reminders/adherence modules — every one of them calls this, none of them
 * re-implements the rule.
 *
 * - ELDER: always themself. Passing someone else's id is rejected, not silently ignored.
 * - CAREGIVER: must pass elderId and hold an ACCEPTED family link to it.
 * - ADMIN: no elder-data endpoints are open to admins yet.
 */
export async function resolveElderScope(
  auth: AuthContext,
  requestedElderId: string | undefined,
  family: FamilyAccessCheck,
): Promise<string> {
  if (auth.role === 'ELDER') {
    if (requestedElderId && requestedElderId !== auth.userId) {
      throw AppError.forbidden('You can only access your own information');
    }
    return auth.userId;
  }
  if (auth.role === 'CAREGIVER') {
    if (!requestedElderId) throw AppError.badRequest('elderId is required');
    await family.assertCaregiverCanAccessElder(auth.userId, requestedElderId);
    return requestedElderId;
  }
  throw AppError.forbidden();
}
