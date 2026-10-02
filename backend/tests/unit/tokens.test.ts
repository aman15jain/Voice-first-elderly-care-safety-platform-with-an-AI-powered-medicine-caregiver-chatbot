import { describe, expect, it } from 'vitest';
import { generateRefreshToken, hashRefreshToken, signAccessToken, verifyAccessToken } from '../../src/common/utils/tokens';

describe('access tokens', () => {
  it('round-trips the payload', () => {
    const token = signAccessToken({ sub: 'user-1', role: 'ELDER' }, 'secret', 900);
    expect(verifyAccessToken(token, 'secret')).toEqual({ sub: 'user-1', role: 'ELDER' });
  });

  it('rejects a token signed with a different secret', () => {
    const token = signAccessToken({ sub: 'user-1', role: 'ELDER' }, 'secret-a', 900);
    expect(() => verifyAccessToken(token, 'secret-b')).toThrow();
  });

  it('rejects an expired token', () => {
    const token = signAccessToken({ sub: 'user-1', role: 'ELDER' }, 'secret', -1);
    expect(() => verifyAccessToken(token, 'secret')).toThrow();
  });
});

describe('refresh tokens', () => {
  it('generates unique, high-entropy opaque tokens', () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toBe(b);
    expect(a).toHaveLength(64);
  });

  it('hashing is deterministic per pepper and differs across peppers', () => {
    const token = generateRefreshToken();
    expect(hashRefreshToken(token, 'pepper-a')).toBe(hashRefreshToken(token, 'pepper-a'));
    expect(hashRefreshToken(token, 'pepper-a')).not.toBe(hashRefreshToken(token, 'pepper-b'));
  });
});
