import type { PrismaClient } from '@prisma/client';
import type { AuthRepository, CreateUserInput, RefreshTokenRecord, UserRecord } from './auth.types';

export class PrismaAuthRepository implements AuthRepository {
  constructor(private readonly prisma: PrismaClient) {}

  findUserByEmail(email: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findUserById(id: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  /** Creates the user and their role profile atomically: never leaves a user without one. */
  createUser(input: CreateUserInput): Promise<UserRecord> {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: input.email,
          passwordHash: input.passwordHash,
          role: input.role,
          ...(input.preferredLanguage ? { preferredLanguage: input.preferredLanguage } : {}),
        },
      });
      if (input.role === 'ELDER') {
        await tx.elderProfile.create({ data: { userId: user.id, fullName: input.fullName } });
      } else if (input.role === 'CAREGIVER') {
        await tx.caregiverProfile.create({ data: { userId: user.id, fullName: input.fullName } });
      }
      return user;
    });
  }

  async createRefreshToken(input: { userId: string; tokenHash: string; expiresAt: Date }): Promise<{ id: string }> {
    return this.prisma.refreshToken.create({ data: input, select: { id: true } });
  }

  findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    return this.prisma.refreshToken.findUnique({ where: { tokenHash } });
  }

  async revokeRefreshToken(id: string): Promise<void> {
    await this.prisma.refreshToken.update({ where: { id }, data: { revokedAt: new Date() } });
  }
}
