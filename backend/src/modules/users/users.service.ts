import type { Role } from '@prisma/client';
import { AppError } from '../../common/errors/AppError';
import type { FullProfile, NotificationPreferences, UsersRepository } from './users.types';

export class UsersService {
  constructor(private readonly repo: UsersRepository) {}

  async me(userId: string): Promise<FullProfile> {
    const profile = await this.repo.getFullProfile(userId);
    if (!profile) throw AppError.notFound('User not found');
    return profile;
  }

  /** Caregiver-only: an elder has no notification preferences to set. */
  async updateNotificationPreferences(userId: string, role: Role, input: NotificationPreferences): Promise<NotificationPreferences> {
    if (role !== 'CAREGIVER') throw AppError.forbidden('Only caregiver accounts have notification preferences');
    return this.repo.updateNotificationPreferences(userId, input);
  }
}
