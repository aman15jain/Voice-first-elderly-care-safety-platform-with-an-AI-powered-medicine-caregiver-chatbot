import type { FullProfile, NotificationPreferences, UsersRepository } from '../../src/modules/users/users.types';
import type { InMemoryAuthRepository } from './inMemoryAuth';

export class InMemoryUsersRepository implements UsersRepository {
  readonly notificationPreferences = new Map<string, NotificationPreferences>();

  constructor(private readonly auth: InMemoryAuthRepository) {}

  async getFullProfile(userId: string): Promise<FullProfile | null> {
    const user = this.auth.users.get(userId);
    if (!user) return null;
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      preferredLanguage: user.preferredLanguage,
      fullName: this.auth.profiles.get(userId) ?? null,
      notifyOnMissedDose: user.role === 'CAREGIVER' ? this.getPreferencesSync(userId).notifyOnMissedDose : undefined,
    };
  }

  async getNotificationPreferences(userId: string): Promise<NotificationPreferences> {
    return this.getPreferencesSync(userId);
  }

  async updateNotificationPreferences(userId: string, input: NotificationPreferences): Promise<NotificationPreferences> {
    this.notificationPreferences.set(userId, input);
    return input;
  }

  private getPreferencesSync(userId: string): NotificationPreferences {
    return this.notificationPreferences.get(userId) ?? { notifyOnMissedDose: true };
  }
}
