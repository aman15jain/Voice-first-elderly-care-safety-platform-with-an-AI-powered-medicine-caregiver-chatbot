import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const otherElder = { email: 'other-elder@example.com', password: 'correct-horse-2', role: 'ELDER', fullName: 'Grandpa Joe' };

async function setup(app: import('express').Express) {
  const elderRes = await request(app).post('/api/auth/register').send(elder);
  const otherRes = await request(app).post('/api/auth/register').send(otherElder);
  const elderToken = elderRes.body.accessToken as string;

  const medicine = await request(app).post('/api/medicines').set('Authorization', `Bearer ${elderToken}`).send({ name: 'Metformin', dosage: '500mg' });
  const today = new Date().toISOString().slice(0, 10);
  await request(app)
    .post('/api/medicine-schedules')
    .set('Authorization', `Bearer ${elderToken}`)
    .send({ medicineId: medicine.body.medicine.id, timesOfDay: ['08:00', '20:00'], startDate: today });

  return { elderToken, otherElderToken: otherRes.body.accessToken as string };
}

describe('GET /api/doses', () => {
  it("defaults to today's doses", async () => {
    const { app } = buildTestApp();
    const { elderToken } = await setup(app);
    const res = await request(app).get('/api/doses').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.doses.length).toBe(2); // 08:00 and 20:00 today
  });

  it("does not let one elder see another elder's doses", async () => {
    const { app } = buildTestApp();
    const { otherElderToken } = await setup(app);
    const res = await request(app).get('/api/doses').set('Authorization', `Bearer ${otherElderToken}`);
    expect(res.body.doses).toHaveLength(0);
  });

  it('rejects a range over 90 days', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await setup(app);
    const res = await request(app).get('/api/doses?from=2026-01-01&to=2026-06-01').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(400);
  });
});

describe('POST /api/doses/:id/reminded', () => {
  it('marks a scheduled dose as reminded, and rejects doing it twice', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await setup(app);
    const doses = await request(app).get('/api/doses').set('Authorization', `Bearer ${elderToken}`);
    const doseId = doses.body.doses[0].id as string;

    const first = await request(app).post(`/api/doses/${doseId}/reminded`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(first.status).toBe(200);
    expect(first.body.dose.status).toBe('REMINDED');
    expect(first.body.dose.remindedAt).toBeTruthy();

    const second = await request(app).post(`/api/doses/${doseId}/reminded`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(second.status).toBe(409);
  });

  it("does not let one elder mark another elder's dose as reminded", async () => {
    const { app } = buildTestApp();
    const { elderToken, otherElderToken } = await setup(app);
    const doses = await request(app).get('/api/doses').set('Authorization', `Bearer ${elderToken}`);
    const doseId = doses.body.doses[0].id as string;

    const res = await request(app).post(`/api/doses/${doseId}/reminded`).set('Authorization', `Bearer ${otherElderToken}`).send();
    expect(res.status).toBe(404);
  });
});
