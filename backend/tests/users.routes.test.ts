import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Alex' };

describe('GET /api/users/me', () => {
  it('includes notifyOnMissedDose (default true) for a caregiver, and omits it for an elder', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);

    const elderMe = await request(app).get('/api/users/me').set('Authorization', `Bearer ${elderRes.body.accessToken}`);
    expect(elderMe.body.notifyOnMissedDose).toBeUndefined();

    const caregiverMe = await request(app).get('/api/users/me').set('Authorization', `Bearer ${caregiverRes.body.accessToken}`);
    expect(caregiverMe.body.notifyOnMissedDose).toBe(true);
  });
});

describe('PATCH /api/users/me/notification-preferences', () => {
  it('lets a caregiver mute missed-dose alerts, reflected back on GET /api/users/me', async () => {
    const { app } = buildTestApp();
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
    const token = caregiverRes.body.accessToken as string;

    const patch = await request(app)
      .patch('/api/users/me/notification-preferences')
      .set('Authorization', `Bearer ${token}`)
      .send({ notifyOnMissedDose: false });
    expect(patch.status).toBe(200);
    expect(patch.body.notifyOnMissedDose).toBe(false);

    const me = await request(app).get('/api/users/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.notifyOnMissedDose).toBe(false);
  });

  it('blocks an elder from setting notification preferences', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);

    const res = await request(app)
      .patch('/api/users/me/notification-preferences')
      .set('Authorization', `Bearer ${elderRes.body.accessToken}`)
      .send({ notifyOnMissedDose: false });
    expect(res.status).toBe(403);
  });

  it('rejects a non-boolean value', async () => {
    const { app } = buildTestApp();
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);

    const res = await request(app)
      .patch('/api/users/me/notification-preferences')
      .set('Authorization', `Bearer ${caregiverRes.body.accessToken}`)
      .send({ notifyOnMissedDose: 'nope' });
    expect(res.status).toBe(400);
  });
});
