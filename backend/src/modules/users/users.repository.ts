import type { PrismaClient } from '@prisma/client';
import type { FullProfile, NotificationPreferences, UsersRepository } from './users.types';

export class PrismaUsersRepository implements UsersRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async getFullProfile(userId: string): Promise<FullProfile | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { elderProfile: true, caregiverProfile: true },
    });
    if (!user) return null;
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      preferredLanguage: user.preferredLanguage,
      fullName: user.elderProfile?.fullName ?? user.caregiverProfile?.fullName ?? null,
      notifyOnMissedDose: user.caregiverProfile?.notifyOnMissedDose,
    };
  }

  async getNotificationPreferences(userId: string): Promise<NotificationPreferences> {
    const profile = await this.prisma.caregiverProfile.findUnique({ where: { userId }, select: { notifyOnMissedDose: true } });
    return { notifyOnMissedDose: profile?.notifyOnMissedDose ?? true };
  }

  async updateNotificationPreferences(userId: string, input: NotificationPreferences): Promise<NotificationPreferences> {
    const profile = await this.prisma.caregiverProfile.findUnique({ where: { userId }, select: { id: true } });
    if (!profile) return { notifyOnMissedDose: true };
    const updated = await this.prisma.caregiverProfile.update({
      where: { userId },
      data: { notifyOnMissedDose: input.notifyOnMissedDose },
      select: { notifyOnMissedDose: true },
    });
    return { notifyOnMissedDose: updated.notifyOnMissedDose };
  }
}
