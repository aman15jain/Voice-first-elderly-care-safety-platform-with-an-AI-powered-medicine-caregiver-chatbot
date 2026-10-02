import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };

/**
 * `req.auth.role` is only ever set from a verified JWT payload (authenticate.ts) — these tests
 * confirm a client cannot bypass authorization simply by claiming a different role in the
 * request body/query, since the middleware never reads role from client-supplied input at all.
 */
describe('role manipulation from the client', () => {
  it('an elder claiming role: CAREGIVER in the body still cannot reach a caregiver-only endpoint', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const elderToken = elderRes.body.accessToken as string;

    const res = await request(app)
      .patch('/api/users/me/notification-preferences')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ notifyOnMissedDose: false, role: 'CAREGIVER' });
    expect(res.status).toBe(403);
  });

  it('an elder claiming role: CAREGIVER cannot reach the caregiver dashboard', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const elderToken = elderRes.body.accessToken as string;

    const res = await request(app).get('/api/family/dashboard?role=CAREGIVER').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(403);
  });

  it('registering with role: ADMIN in the payload is rejected outright, not silently downgraded', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'wannabe-admin@example.com', password: 'correct-horse-9', role: 'ADMIN', fullName: 'Sneaky' });
    expect(res.status).toBe(400);
  });

  it('a forged/tampered access token is rejected, not treated as a different role', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const elderToken = elderRes.body.accessToken as string;
    // Flip one character in the signature segment to simulate tampering.
    const parts = elderToken.split('.');
    const tampered = `${parts[0]}.${parts[1]}.${parts[2]!.slice(0, -1)}${parts[2]!.endsWith('A') ? 'B' : 'A'}`;

    const res = await request(app).get('/api/users/me').set('Authorization', `Bearer ${tampered}`);
    expect(res.status).toBe(401);
  });
});
