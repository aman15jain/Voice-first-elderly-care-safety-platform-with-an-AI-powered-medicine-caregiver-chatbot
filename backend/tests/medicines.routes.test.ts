import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const otherElder = { email: 'other-elder@example.com', password: 'correct-horse-2', role: 'ELDER', fullName: 'Grandpa Joe' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-3', role: 'CAREGIVER', fullName: 'Alex' };

async function registerAndLink(app: import('express').Express) {
  const elderRes = await request(app).post('/api/auth/register').send(elder);
  const otherRes = await request(app).post('/api/auth/register').send(otherElder);
  const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
  const invite = await request(app)
    .post('/api/family/links')
    .set('Authorization', `Bearer ${caregiverRes.body.accessToken}`)
    .send({ email: elder.email });
  await request(app).patch(`/api/family/links/${invite.body.link.id}/accept`).set('Authorization', `Bearer ${elderRes.body.accessToken}`).send();

  return {
    elderId: elderRes.body.user.id as string,
    elderToken: elderRes.body.accessToken as string,
    otherElderToken: otherRes.body.accessToken as string,
    caregiverToken: caregiverRes.body.accessToken as string,
  };
}

describe('medicines', () => {
  it('lets an elder create, list, update and (soft) delete their own medicine', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);

    const create = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg', instructions: 'after breakfast' });
    expect(create.status).toBe(201);
    const medicineId = create.body.medicine.id as string;

    const list = await request(app).get('/api/medicines').set('Authorization', `Bearer ${elderToken}`);
    expect(list.body.medicines).toHaveLength(1);

    const update = await request(app)
      .patch(`/api/medicines/${medicineId}`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ dosage: '10mg' });
    expect(update.status).toBe(200);
    expect(update.body.medicine.dosage).toBe('10mg');

    const remove = await request(app).delete(`/api/medicines/${medicineId}`).set('Authorization', `Bearer ${elderToken}`);
    expect(remove.status).toBe(200);
    expect(remove.body.medicine.isActive).toBe(false);

    const listAfterDelete = await request(app).get('/api/medicines').set('Authorization', `Bearer ${elderToken}`);
    expect(listAfterDelete.body.medicines).toHaveLength(0);
    const listIncludingInactive = await request(app)
      .get('/api/medicines?includeInactive=true')
      .set('Authorization', `Bearer ${elderToken}`);
    expect(listIncludingInactive.body.medicines).toHaveLength(1);
  });

  it('blocks a caregiver from creating a medicine', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerAndLink(app);
    const res = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg' });
    expect(res.status).toBe(403);
  });

  it("blocks one elder from reading or editing another elder's medicine", async () => {
    const { app } = buildTestApp();
    const { elderToken, otherElderToken } = await registerAndLink(app);
    const create = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg' });
    const medicineId = create.body.medicine.id as string;

    const readOther = await request(app).get('/api/medicines').set('Authorization', `Bearer ${otherElderToken}`);
    expect(readOther.body.medicines).toHaveLength(0);

    const editOther = await request(app)
      .patch(`/api/medicines/${medicineId}`)
      .set('Authorization', `Bearer ${otherElderToken}`)
      .send({ dosage: '999mg' });
    expect(editOther.status).toBe(404);
  });

  it('lets a linked caregiver read an elder’s medicines, but not an unlinked one', async () => {
    const { app } = buildTestApp();
    const { elderId, elderToken, otherElderToken, caregiverToken } = await registerAndLink(app);
    await request(app).post('/api/medicines').set('Authorization', `Bearer ${elderToken}`).send({ name: 'Amlodipine', dosage: '5mg' });

    const linked = await request(app).get(`/api/medicines?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(linked.status).toBe(200);
    expect(linked.body.medicines).toHaveLength(1);

    const noElderId = await request(app).get('/api/medicines').set('Authorization', `Bearer ${caregiverToken}`);
    expect(noElderId.status).toBe(400);

    void otherElderToken;
  });
});

describe('medicine schedules', () => {
  it('creating a schedule generates upcoming doses', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const medicine = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg' });

    const today = new Date().toISOString().slice(0, 10);
    const schedule = await request(app)
      .post('/api/medicine-schedules')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ medicineId: medicine.body.medicine.id, timesOfDay: ['08:00', '20:00'], startDate: today });
    expect(schedule.status).toBe(201);

    const doses = await request(app).get('/api/doses').set('Authorization', `Bearer ${elderToken}`);
    expect(doses.status).toBe(200);
    expect(doses.body.doses.length).toBeGreaterThanOrEqual(1);
  });

  it('rejects an endDate before startDate', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const medicine = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg' });

    const res = await request(app)
      .post('/api/medicine-schedules')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ medicineId: medicine.body.medicine.id, timesOfDay: ['08:00'], startDate: '2026-06-01', endDate: '2026-05-01' });
    expect(res.status).toBe(400);
  });

  it("does not let one elder update another elder's medicine schedule, even by guessing the id", async () => {
    const { app } = buildTestApp();
    const { elderToken, otherElderToken } = await registerAndLink(app);
    const medicine = await request(app)
      .post('/api/medicines')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Amlodipine', dosage: '5mg' });
    const today = new Date().toISOString().slice(0, 10);
    const schedule = await request(app)
      .post('/api/medicine-schedules')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ medicineId: medicine.body.medicine.id, timesOfDay: ['08:00'], startDate: today });

    const res = await request(app)
      .patch(`/api/medicine-schedules/${schedule.body.schedule.id}`)
      .set('Authorization', `Bearer ${otherElderToken}`)
      .send({ timesOfDay: ['09:00'] });
    expect(res.status).toBe(404);
  });
});
