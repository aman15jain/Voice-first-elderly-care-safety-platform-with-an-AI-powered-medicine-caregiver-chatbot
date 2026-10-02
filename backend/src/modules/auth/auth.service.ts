import type { AuditLogger } from '../../common/audit/auditLog';
import { AppError } from '../../common/errors/AppError';
import { hashPassword, verifyAgainstDummyHash, verifyPassword } from '../../common/utils/password';
import { generateRefreshToken, hashRefreshToken, signAccessToken } from '../../common/utils/tokens';
import type { AuthRepository, AuthSession, JwtConfig, RegisterInput, UserRecord } from './auth.types';

const DAY_MS = 86_400_000;

export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly audit: AuditLogger,
    private readonly jwtConfig: JwtConfig,
  ) {}

  async register(input: RegisterInput): Promise<AuthSession> {
    const existing = await this.repo.findUserByEmail(input.email);
    if (existing) throw AppError.conflict('An account with this email already exists');

    const passwordHash = await hashPassword(input.password);
    const user = await this.repo.createUser({
      email: input.email,
      passwordHash,
      role: input.role,
      fullName: input.fullName,
      preferredLanguage: input.preferredLanguage,
    });
    await this.audit.log({ actorId: user.id, action: 'USER_REGISTERED' });
    return this.issueSession(user);
  }

  async login(email: string, password: string): Promise<AuthSession> {
    const user = await this.repo.findUserByEmail(email);
    // Always run a bcrypt comparison, even for an unknown email, so response
    // timing doesn't reveal which emails have accounts.
    const passwordValid = user ? await verifyPassword(password, user.passwordHash) : await verifyAgainstDummyHash(password);

    if (!user || !passwordValid || !user.isActive) {
      await this.audit.log({ actorId: user?.id ?? null, action: 'USER_LOGIN_FAILED', metadata: { email } });
      throw AppError.unauthorized('Invalid email or password');
    }

    await this.audit.log({ actorId: user.id, action: 'USER_LOGGED_IN' });
    return this.issueSession(user);
  }

  async refresh(refreshToken: string): Promise<AuthSession> {
    const tokenHash = hashRefreshToken(refreshToken, this.jwtConfig.refreshPepper);
    const record = await this.repo.findRefreshTokenByHash(tokenHash);
    if (!record || record.revokedAt || record.expiresAt < new Date()) {
      throw AppError.unauthorized('Session expired, please log in again');
    }

    // Rotate immediately: this token cannot be used a second time, so a copy
    // stolen in transit is only useful until the legitimate client refreshes.
    await this.repo.revokeRefreshToken(record.id);

    const user = await this.repo.findUserById(record.userId);
    if (!user || !user.isActive) throw AppError.unauthorized('Session expired, please log in again');

    await this.audit.log({ actorId: user.id, action: 'TOKEN_REFRESHED' });
    return this.issueSession(user);
  }

  async logout(refreshToken: string): Promise<void> {
    const tokenHash = hashRefreshToken(refreshToken, this.jwtConfig.refreshPepper);
    const record = await this.repo.findRefreshTokenByHash(tokenHash);
    // Idempotent: logging out with an already-invalid token is not an error.
    if (record && !record.revokedAt) {
      await this.repo.revokeRefreshToken(record.id);
      await this.audit.log({ actorId: record.userId, action: 'USER_LOGGED_OUT' });
    }
  }

  private async issueSession(user: UserRecord): Promise<AuthSession> {
    const accessToken = signAccessToken(
      { sub: user.id, role: user.role },
      this.jwtConfig.accessSecret,
      this.jwtConfig.accessTtlSeconds,
    );
    const refreshToken = generateRefreshToken();
    const tokenHash = hashRefreshToken(refreshToken, this.jwtConfig.refreshPepper);
    const expiresAt = new Date(Date.now() + this.jwtConfig.refreshTtlDays * DAY_MS);
    await this.repo.createRefreshToken({ userId: user.id, tokenHash, expiresAt });

    return {
      accessToken,
      refreshToken,
      expiresIn: this.jwtConfig.accessTtlSeconds,
      user: { id: user.id, email: user.email, role: user.role, preferredLanguage: user.preferredLanguage },
    };
  }
}
