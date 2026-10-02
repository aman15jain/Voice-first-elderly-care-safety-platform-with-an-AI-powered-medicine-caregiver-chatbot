import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';

export interface AccessTokenPayload {
  sub: string;
  role: string;
}

export function signAccessToken(payload: AccessTokenPayload, secret: string, ttlSeconds: number): string {
  return jwt.sign(payload, secret, { expiresIn: ttlSeconds });
}

/** Throws if the token is missing, malformed, expired or wrongly signed. */
export function verifyAccessToken(token: string, secret: string): AccessTokenPayload {
  const decoded = jwt.verify(token, secret);
  if (typeof decoded === 'string' || typeof decoded.sub !== 'string' || typeof decoded.role !== 'string') {
    throw new Error('Malformed access token payload');
  }
  return { sub: decoded.sub, role: decoded.role };
}

/** Opaque, unguessable refresh token handed to the client. Never a JWT: it carries no data. */
export function generateRefreshToken(): string {
  return randomBytes(32).toString('hex');
}

/** Only the hash is ever stored, so a database leak alone can't be used to log in. */
export function hashRefreshToken(token: string, pepper: string): string {
  return createHash('sha256').update(pepper).update(token).digest('hex');
}
