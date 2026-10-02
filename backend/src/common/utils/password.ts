import bcrypt from 'bcryptjs';

const SALT_ROUNDS = 12;

// A precomputed hash of a value nobody will ever type, used to keep login's
// timing the same whether or not the email exists (avoids user enumeration).
const DUMMY_HASH = bcrypt.hashSync('no-account-has-this-password', SALT_ROUNDS);

export function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, SALT_ROUNDS);
}

export function verifyPassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

export function verifyAgainstDummyHash(plain: string): Promise<boolean> {
  return bcrypt.compare(plain, DUMMY_HASH);
}
