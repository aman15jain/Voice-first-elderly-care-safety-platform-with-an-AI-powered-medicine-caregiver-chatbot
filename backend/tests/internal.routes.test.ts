import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };

describe('GET /internal/elders/:elderId/medicine-context', () => {
  it('rejects a request without the internal API key', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const res = await request(app).get(`/internal/elders/${elderRes.body.user.id}/medicine-context`);
    expect(res.status).toBe(401);
  });

  it('rejects a request with the wrong internal API key', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const res = await request(app)
      .get(`/internal/elders/${elderRes.body.user.id}/medicine-context`)
      .set('x-internal-api-key', 'wrong-key');
    expect(res.status).toBe(401);
  });

  it('returns the elder\'s medicines and adherence summary for the agentic-ai service', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);
    const elderToken = elderRes.body.accessToken as string;
    await request(app).post('/api/medicines').set('Authorization', `Bearer ${elderToken}`).send({ name: 'Metformin', dosage: '500mg' });

    const res = await request(app)
      .get(`/internal/elders/${elderRes.body.user.id}/medicine-context`)
      .set('x-internal-api-key', 'test-internal-key');
    expect(res.status).toBe(200);
    expect(res.body.medicines).toEqual([{ name: 'Metformin', dosage: '500mg', instructions: null }]);
    expect(res.body.adherence).toMatchObject({ scheduled: 0, taken: 0, totalDue: 0, takenRate: null });
  });
});

describe('GET /internal/elders/:elderId/caregiver-insight-context', () => {
  it('returns adherence, activity and emergency status for the agentic-ai service', async () => {
    const { app } = buildTestApp();
    const elderRes = await request(app).post('/api/auth/register').send(elder);

    const res = await request(app)
      .get(`/internal/elders/${elderRes.body.user.id}/caregiver-insight-context`)
      .set('x-internal-api-key', 'test-internal-key');
    expect(res.status).toBe(200);
    expect(res.body.adherence).toMatchObject({ totalDue: 0 });
    expect(res.body.activity).toMatchObject({ daysInRange: 7, activeDays: 0 });
    expect(res.body.activeEmergency).toBe(false);
  });
});
