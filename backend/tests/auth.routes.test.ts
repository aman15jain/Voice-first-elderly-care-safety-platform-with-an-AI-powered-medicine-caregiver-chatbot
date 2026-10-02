import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };

describe('POST /api/auth/register', () => {
  it('creates an account and returns a session', async () => {
    const { app, audit } = buildTestApp();
    const res = await request(app).post('/api/auth/register').send(elder);

    expect(res.status).toBe(201);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.user).toMatchObject({ email: elder.email, role: 'ELDER' });
    expect(res.body.user.passwordHash).toBeUndefined();
    expect(audit.entries.some((e) => e.action === 'USER_REGISTERED')).toBe(true);
  });

  it('rejects a duplicate email', async () => {
    const { app } = buildTestApp();
    await request(app).post('/api/auth/register').send(elder);
    const res = await request(app).post('/api/auth/register').send(elder);
    expect(res.status).toBe(409);
  });

  it('rejects a weak password before touching the repository', async () => {
    const { app, auth } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...elder, password: 'short' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(auth.users.size).toBe(0);
  });

  it('rejects self-registration as ADMIN', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...elder, role: 'ADMIN' });
    expect(res.status).toBe(400);
  });
});

describe('POST /api/auth/login', () => {
  it('logs in with correct credentials', async () => {
    const { app } = buildTestApp();
    await request(app).post('/api/auth/register').send(elder);
    const res = await request(app).post('/api/auth/login').send({ email: elder.email, password: elder.password });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeTruthy();
  });

  it('gives the same error for a wrong password and for an unknown email', async () => {
    const { app } = buildTestApp();
    await request(app).post('/api/auth/register').send(elder);

    const wrongPassword = await request(app).post('/api/auth/login').send({ email: elder.email, password: 'nope-nope-1' });
    const unknownEmail = await request(app).post('/api/auth/login').send({ email: 'nobody@example.com', password: 'nope-nope-1' });

    expect(wrongPassword.status).toBe(401);
    expect(unknownEmail.status).toBe(401);
    expect(wrongPassword.body.error.message).toBe(unknownEmail.body.error.message);
  });

  it(
    'rate-limits repeated login attempts from the same client (brute-force protection)',
    async () => {
      const { app } = buildTestApp();
      await request(app).post('/api/auth/register').send(elder);

      let lastStatus = 0;
      for (let i = 0; i < 11; i++) {
        const res = await request(app).post('/api/auth/login').send({ email: elder.email, password: 'wrong-password-1' });
        lastStatus = res.status;
      }
      expect(lastStatus).toBe(429);
    },
    // Each attempt runs a real bcrypt comparison (intentionally slow) — 11 of them can
    // exceed vitest's default 5s per-test timeout even without unusual system load.
    20_000,
  );
});

describe('session lifecycle', () => {
  it('GET /api/users/me requires a bearer token', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/api/users/me');
    expect(res.status).toBe(401);
  });

  it('an access token authenticates GET /api/users/me', async () => {
    const { app } = buildTestApp();
    const registered = await request(app).post('/api/auth/register').send(elder);
    const res = await request(app).get('/api/users/me').set('Authorization', `Bearer ${registered.body.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.email).toBe(elder.email);
    expect(res.body.fullName).toBe(elder.fullName);
  });

  it('rotates the refresh token and invalidates the old one', async () => {
    const { app } = buildTestApp();
    const registered = await request(app).post('/api/auth/register').send(elder);
    const firstRefreshToken = registered.body.refreshToken as string;

    const refreshed = await request(app).post('/api/auth/refresh').send({ refreshToken: firstRefreshToken });
    expect(refreshed.status).toBe(200);
    expect(refreshed.body.refreshToken).not.toBe(firstRefreshToken);

    const reuse = await request(app).post('/api/auth/refresh').send({ refreshToken: firstRefreshToken });
    expect(reuse.status).toBe(401);
  });

  it('logout revokes the refresh token', async () => {
    const { app } = buildTestApp();
    const registered = await request(app).post('/api/auth/register').send(elder);
    const refreshToken = registered.body.refreshToken as string;

    const logout = await request(app).post('/api/auth/logout').send({ refreshToken });
    expect(logout.status).toBe(204);

    const afterLogout = await request(app).post('/api/auth/refresh').send({ refreshToken });
    expect(afterLogout.status).toBe(401);
  });

  it('logging out twice with the same token is not an error', async () => {
    const { app } = buildTestApp();
    const registered = await request(app).post('/api/auth/register').send(elder);
    const refreshToken = registered.body.refreshToken as string;

    await request(app).post('/api/auth/logout').send({ refreshToken });
    const second = await request(app).post('/api/auth/logout').send({ refreshToken });
    expect(second.status).toBe(204);
  });
});
