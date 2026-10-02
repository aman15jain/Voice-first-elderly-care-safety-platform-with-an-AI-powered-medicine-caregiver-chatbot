import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Alex' };

async function setup(app: import('express').Express) {
  const elderRes = await request(app).post('/api/auth/register').send(elder);
  const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
  const elderToken = elderRes.body.accessToken as string;
  const elderId = elderRes.body.user.id as string;

  const medicine = await request(app).post('/api/medicines').set('Authorization', `Bearer ${elderToken}`).send({ name: 'Metformin', dosage: '500mg' });
  const today = new Date().toISOString().slice(0, 10);
  await request(app)
    .post('/api/medicine-schedules')
    .set('Authorization', `Bearer ${elderToken}`)
    .send({ medicineId: medicine.body.medicine.id, timesOfDay: ['08:00'], startDate: today });

  const doses = await request(app).get('/api/doses').set('Authorization', `Bearer ${elderToken}`);
  const doseId = doses.body.doses[0].id as string;

  return { elderId, elderToken, caregiverToken: caregiverRes.body.accessToken as string, doseId };
}

describe('adherence', () => {
  it('marks a dose taken', async () => {
    const { app, audit } = buildTestApp();
    const { elderToken, doseId } = await setup(app);

    const res = await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(res.status).toBe(200);
    expect(res.body.dose.status).toBe('TAKEN');
    expect(audit.entries.some((e) => e.action === 'DOSE_TAKEN')).toBe(true);
  });

  it('marks a dose skipped', async () => {
    const { app } = buildTestApp();
    const { elderToken, doseId } = await setup(app);

    const res = await request(app).post(`/api/adherence/${doseId}/skipped`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(res.status).toBe(200);
    expect(res.body.dose.status).toBe('SKIPPED');
  });

  it('rejects marking an already-settled dose again', async () => {
    const { app } = buildTestApp();
    const { elderToken, doseId } = await setup(app);
    await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${elderToken}`).send();

    const again = await request(app).post(`/api/adherence/${doseId}/skipped`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(again.status).toBe(409);
  });

  it('blocks a caregiver from marking a dose', async () => {
    const { app } = buildTestApp();
    const { caregiverToken, doseId } = await setup(app);
    const res = await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${caregiverToken}`).send();
    expect(res.status).toBe(403);
  });

  it('does not let one elder mark another elder\'s dose taken or skipped, even by guessing the id', async () => {
    const { app } = buildTestApp();
    const { doseId } = await setup(app);
    const strangerElder = { email: 'stranger-elder@example.com', password: 'correct-horse-9', role: 'ELDER', fullName: 'Another Elder' };
    const strangerRes = await request(app).post('/api/auth/register').send(strangerElder);
    const strangerToken = strangerRes.body.accessToken as string;

    const taken = await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${strangerToken}`).send();
    expect(taken.status).toBe(404);

    const skipped = await request(app).post(`/api/adherence/${doseId}/skipped`).set('Authorization', `Bearer ${strangerToken}`).send();
    expect(skipped.status).toBe(404);
  });

  it('computes a summary for the default 30-day range', async () => {
    const { app } = buildTestApp();
    const { elderToken, doseId } = await setup(app);
    await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${elderToken}`).send();

    const res = await request(app).get('/api/adherence/summary').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.summary.taken).toBeGreaterThanOrEqual(1);
    expect(res.body.summary.takenRate).toBe(100);
  });

  it('lets a linked caregiver read the summary but requires elderId, and rejects an unlinked one', async () => {
    const { app } = buildTestApp();
    const { elderId, caregiverToken } = await setup(app);

    const missingElderId = await request(app).get('/api/adherence/summary').set('Authorization', `Bearer ${caregiverToken}`);
    expect(missingElderId.status).toBe(400);

    // caregiver in `setup` was never linked to the elder
    const unlinked = await request(app).get(`/api/adherence/summary?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(unlinked.status).toBe(403);
  });

  it('rejects a from without a to', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await setup(app);
    const res = await request(app).get('/api/adherence/summary?from=2026-01-01').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(400);
  });
});

describe('GET /api/adherence/trend', () => {
  it('returns one row per day for the default 14-day range, reflecting a taken dose today', async () => {
    const { app } = buildTestApp();
    const { elderToken, doseId } = await setup(app);
    await request(app).post(`/api/adherence/${doseId}/taken`).set('Authorization', `Bearer ${elderToken}`).send();

    const res = await request(app).get('/api/adherence/trend').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.days).toHaveLength(14);
    const today = res.body.days[res.body.days.length - 1];
    expect(today.taken).toBeGreaterThanOrEqual(1);
    expect(today.takenRate).toBe(100);
  });

  it('lets a linked caregiver read the trend but requires elderId, and rejects an unlinked one', async () => {
    const { app } = buildTestApp();
    const { elderId, caregiverToken } = await setup(app);

    const missingElderId = await request(app).get('/api/adherence/trend').set('Authorization', `Bearer ${caregiverToken}`);
    expect(missingElderId.status).toBe(400);

    const unlinked = await request(app).get(`/api/adherence/trend?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(unlinked.status).toBe(403);
  });
});
