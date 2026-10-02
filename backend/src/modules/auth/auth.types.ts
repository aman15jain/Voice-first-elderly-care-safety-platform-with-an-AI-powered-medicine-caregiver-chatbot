import type { Role, User } from '@prisma/client';

/** Re-exported so callers don't need to import `@prisma/client` directly. */
export type UserRecord = User;

export interface RegisterInput {
  email: string;
  password: string;
  role: 'ELDER' | 'CAREGIVER';
  fullName: string;
  preferredLanguage?: string;
}

export interface CreateUserInput {
  email: string;
  passwordHash: string;
  role: Role;
  fullName: string;
  preferredLanguage?: string;
}

export interface RefreshTokenRecord {
  id: string;
  userId: string;
  tokenHash: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

export interface JwtConfig {
  accessSecret: string;
  /** Also the pepper mixed into hashed refresh tokens. */
  refreshPepper: string;
  accessTtlSeconds: number;
  refreshTtlDays: number;
}

export interface AuthRepository {
  findUserByEmail(email: string): Promise<UserRecord | null>;
  findUserById(id: string): Promise<UserRecord | null>;
  createUser(input: CreateUserInput): Promise<UserRecord>;
  createRefreshToken(input: { userId: string; tokenHash: string; expiresAt: Date }): Promise<{ id: string }>;
  findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenRecord | null>;
  revokeRefreshToken(id: string): Promise<void>;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: { id: string; email: string; role: Role; preferredLanguage: string };
}
