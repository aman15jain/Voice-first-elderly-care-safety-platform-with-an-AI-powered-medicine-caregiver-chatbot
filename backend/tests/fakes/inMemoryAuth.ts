import { randomUUID } from 'node:crypto';
import type { AuthRepository, CreateUserInput, RefreshTokenRecord, UserRecord } from '../../src/modules/auth/auth.types';

/** In-memory stand-in for PrismaAuthRepository, shaped identically so services can't tell the difference. */
export class InMemoryAuthRepository implements AuthRepository {
  readonly users = new Map<string, UserRecord>();
  readonly profiles = new Map<string, string>(); // userId -> fullName, mirrors ElderProfile/CaregiverProfile
  readonly refreshTokens = new Map<string, RefreshTokenRecord>();

  async findUserByEmail(email: string): Promise<UserRecord | null> {
    return [...this.users.values()].find((u) => u.email === email) ?? null;
  }

  async findUserById(id: string): Promise<UserRecord | null> {
    return this.users.get(id) ?? null;
  }

  async createUser(input: CreateUserInput): Promise<UserRecord> {
    const now = new Date();
    const user: UserRecord = {
      id: randomUUID(),
      email: input.email,
      passwordHash: input.passwordHash,
      role: input.role,
      preferredLanguage: input.preferredLanguage ?? 'en',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    this.users.set(user.id, user);
    this.profiles.set(user.id, input.fullName);
    return user;
  }

  async createRefreshToken(input: { userId: string; tokenHash: string; expiresAt: Date }): Promise<{ id: string }> {
    const id = randomUUID();
    this.refreshTokens.set(id, { id, userId: input.userId, tokenHash: input.tokenHash, expiresAt: input.expiresAt, revokedAt: null });
    return { id };
  }

  async findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    return [...this.refreshTokens.values()].find((t) => t.tokenHash === tokenHash) ?? null;
  }

  async revokeRefreshToken(id: string): Promise<void> {
    const token = this.refreshTokens.get(id);
    if (token) token.revokedAt = new Date();
  }
}
