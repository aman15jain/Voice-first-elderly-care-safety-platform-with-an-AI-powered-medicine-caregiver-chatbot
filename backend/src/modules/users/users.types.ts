import type { Role } from '@prisma/client';

export interface FullProfile {
  id: string;
  email: string;
  role: Role;
  preferredLanguage: string;
  fullName: string | null;
  /** Only meaningful for a CAREGIVER; undefined for an ELDER/ADMIN. */
  notifyOnMissedDose?: boolean;
}

export interface NotificationPreferences {
  notifyOnMissedDose: boolean;
}

export interface UsersRepository {
  getFullProfile(userId: string): Promise<FullProfile | null>;
  /** Defaults to `{ notifyOnMissedDose: true }` for a user with no caregiver profile — callers
   * that only care about this one flag (e.g. MissedDoseService) never need to special-case role. */
  getNotificationPreferences(userId: string): Promise<NotificationPreferences>;
  /** No-op for a user with no caregiver profile (an elder has nothing to update here). */
  updateNotificationPreferences(userId: string, input: NotificationPreferences): Promise<NotificationPreferences>;
}
