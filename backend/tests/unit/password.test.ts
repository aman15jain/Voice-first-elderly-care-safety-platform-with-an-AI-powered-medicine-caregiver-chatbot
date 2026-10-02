import { describe, expect, it } from 'vitest';
import { hashPassword, verifyAgainstDummyHash, verifyPassword } from '../../src/common/utils/password';

describe('password hashing', () => {
  it('hashes are salted and never equal to the plain password', async () => {
    const hash = await hashPassword('correct horse battery staple');
    expect(hash).not.toBe('correct horse battery staple');
    expect(hash.startsWith('$2')).toBe(true);
  });

  it('verifyPassword accepts the right password and rejects a wrong one', async () => {
    const hash = await hashPassword('correct horse battery staple');
    await expect(verifyPassword('correct horse battery staple', hash)).resolves.toBe(true);
    await expect(verifyPassword('wrong password', hash)).resolves.toBe(false);
  });

  it('the dummy hash never validates against any real password', async () => {
    await expect(verifyAgainstDummyHash('correct horse battery staple')).resolves.toBe(false);
  });
});
