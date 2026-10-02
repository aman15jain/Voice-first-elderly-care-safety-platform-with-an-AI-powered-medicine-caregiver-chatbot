import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-1', role: 'CAREGIVER', fullName: 'Alex' };

function elder(n: number) {
  return { email: `elder${n}@example.com`, password: 'correct-horse-2', role: 'ELDER', fullName: `Grandma ${n}` };
}

async function linkElderToCaregiver(app: import('express').Express, elderToken: string, elderEmail: string, caregiverToken: string) {
  const invite = await request(app).post('/api/family/links').set('Authorization', `Bearer ${caregiverToken}`).send({ email: elderEmail });
  await request(app).patch(`/api/family/links/${invite.body.link.id}/accept`).set('Authorization', `Bearer ${elderToken}`).send();
}

describe('GET /api/family/dashboard', () => {
  it('returns one row per ACCEPTED-linked elder, with adherence/activity/emergency facts, and nothing for an unlinked elder', async () => {
    const { app } = buildTestApp();
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
    const caregiverToken = caregiverRes.body.accessToken as string;

    const elder1 = elder(1);
    const elder1Res = await request(app).post('/api/auth/register').send(elder1);
    await linkElderToCaregiver(app, elder1Res.body.accessToken, elder1.email, caregiverToken);

    const elder2 = elder(2);
    const elder2Res = await request(app).post('/api/auth/register').send(elder2);
    await linkElderToCaregiver(app, elder2Res.body.accessToken, elder2.email, caregiverToken);

    // A third elder exists but was never linked — must not show up on this caregiver's dashboard.
    await request(app).post('/api/auth/register').send(elder(3));

    const res = await request(app).get('/api/family/dashboard').set('Authorization', `Bearer ${caregiverToken}`);
    expect(res.status).toBe(200);
    expect(res.body.elders).toHaveLength(2);

    const ids = res.body.elders.map((e: { elderId: string }) => e.elderId).sort();
    expect(ids).toEqual([elder1Res.body.user.id, elder2Res.body.user.id].sort());

    for (const row of res.body.elders) {
      expect(row).toHaveProperty('elderName');
      expect(row).toHaveProperty('elderEmail');
      expect(row).toHaveProperty('adherence');
      expect(row).toHaveProperty('activity');
      expect(row).toHaveProperty('activeEmergency', false);
    }
  });

  it('returns an empty list for a caregiver with no accepted links', async () => {
    const { app } = buildTestApp();
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);

    const res = await request(app).get('/api/family/dashboard').set('Authorization', `Bearer ${caregiverRes.body.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.elders).toEqual([]);
  });

  it('blocks an elder from calling the caregiver dashboard', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder(1));

    const res = await request(app).get('/api/family/dashboard').set('Authorization', `Bearer ${elderRes.body.accessToken}`);
    expect(res.status).toBe(403);
  });
});
