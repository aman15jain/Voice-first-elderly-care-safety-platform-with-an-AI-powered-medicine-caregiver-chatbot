import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Alex' };

async function registerAndLink(app: import('express').Express) {
  const elderRes = await request(app).post('/api/auth/register').send(elder);
  const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
  const invite = await request(app)
    .post('/api/family/links')
    .set('Authorization', `Bearer ${caregiverRes.body.accessToken}`)
    .send({ email: elder.email });
  await request(app).patch(`/api/family/links/${invite.body.link.id}/accept`).set('Authorization', `Bearer ${elderRes.body.accessToken}`).send();
  return {
    elderId: elderRes.body.user.id as string,
    elderToken: elderRes.body.accessToken as string,
    caregiverToken: caregiverRes.body.accessToken as string,
  };
}

describe('POST /api/activity/app-opened', () => {
  it('records the event once and is idempotent for the same day', async () => {
    const { app, activity } = buildTestApp();
    const { elderId, elderToken } = await registerAndLink(app);

    const first = await request(app).post('/api/activity/app-opened').set('Authorization', `Bearer ${elderToken}`).send();
    expect(first.status).toBe(204);
    const second = await request(app).post('/api/activity/app-opened').set('Authorization', `Bearer ${elderToken}`).send();
    expect(second.status).toBe(204);

    expect(activity.appOpenedEvents.filter((e) => e.elderId === elderId)).toHaveLength(1);
  });

  it('blocks a caregiver from recording an elder app-opened event', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerAndLink(app);
    const res = await request(app).post('/api/activity/app-opened').set('Authorization', `Bearer ${caregiverToken}`).send();
    expect(res.status).toBe(403);
  });
});

describe('GET /api/activity/summary', () => {
  it('defaults to a 7-day range with one row per day', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).get('/api/activity/summary').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.days).toHaveLength(7);
  });

  it('requires elderId and an accepted link for a caregiver', async () => {
    const { app } = buildTestApp();
    const { elderId, caregiverToken } = await registerAndLink(app);

    const missing = await request(app).get('/api/activity/summary').set('Authorization', `Bearer ${caregiverToken}`);
    expect(missing.status).toBe(400);

    const linked = await request(app).get(`/api/activity/summary?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(linked.status).toBe(200);
  });

  it('rejects a from without a to', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).get('/api/activity/summary?from=2026-01-01').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(400);
  });
});
