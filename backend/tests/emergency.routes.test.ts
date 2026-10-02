import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Alex' };
const stranger = { email: 'stranger@example.com', password: 'correct-horse-3', role: 'CAREGIVER', fullName: 'Sam' };

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

describe('emergency contacts', () => {
  it('lets an elder create, list and update their own contact; blocks a caregiver from creating one', async () => {
    const { app } = buildTestApp();
    const { elderToken, caregiverToken } = await registerAndLink(app);

    const create = await request(app)
      .post('/api/emergency/contacts')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Daughter Jane', phone: '+1 555-123-4567', relationship: 'Daughter' });
    expect(create.status).toBe(201);
    expect(create.body.contact.priority).toBe(1);

    const list = await request(app).get('/api/emergency/contacts').set('Authorization', `Bearer ${elderToken}`);
    expect(list.body.contacts).toHaveLength(1);

    const blocked = await request(app)
      .post('/api/emergency/contacts')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ name: 'X', phone: '123' });
    expect(blocked.status).toBe(403);
  });

  it('rejects a malformed phone number', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app)
      .post('/api/emergency/contacts')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Bad', phone: 'call-me-maybe!!' });
    expect(res.status).toBe(400);
  });

  it("does not let one elder edit another elder's contact", async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const otherElder = { email: 'other@example.com', password: 'correct-horse-4', role: 'ELDER', fullName: 'Grandpa Joe' };
    const otherRes = await request(app).post('/api/auth/register').send(otherElder);

    const create = await request(app)
      .post('/api/emergency/contacts')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Daughter Jane', phone: '5551234567' });

    const res = await request(app)
      .patch(`/api/emergency/contacts/${create.body.contact.id}`)
      .set('Authorization', `Bearer ${otherRes.body.accessToken}`)
      .send({ name: 'Hijacked' });
    expect(res.status).toBe(404);

    const deleted = await request(app)
      .delete(`/api/emergency/contacts/${create.body.contact.id}`)
      .set('Authorization', `Bearer ${otherRes.body.accessToken}`);
    expect(deleted.status).toBe(404);

    // Still there — the other elder's delete attempt must not have actually removed it.
    const stillThere = await request(app).get('/api/emergency/contacts').set('Authorization', `Bearer ${elderToken}`);
    expect(stillThere.body.contacts).toHaveLength(1);
  });
});

describe('POST /api/emergency/sos', () => {
  it('creates an event, notifies linked caregivers, and is idempotent while active', async () => {
    const { app, audit } = buildTestApp();
    const { elderToken, caregiverToken } = await registerAndLink(app);

    const first = await request(app)
      .post('/api/emergency/sos')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ latitude: 12.34, longitude: 56.78 });
    expect(first.status).toBe(201);
    expect(first.body.event.status).toBe('ACTIVE');
    expect(first.body.event.latitude).toBe(12.34);
    expect(audit.entries.some((e) => e.action === 'EMERGENCY_SOS_TRIGGERED')).toBe(true);

    const cgNotifs = await request(app).get('/api/notifications').set('Authorization', `Bearer ${caregiverToken}`);
    expect(cgNotifs.body.notifications.some((n: { type: string }) => n.type === 'EMERGENCY_SOS')).toBe(true);

    // Pressing SOS again while one is already active must not create a second event.
    const second = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    expect(second.status).toBe(201);
    expect(second.body.event.id).toBe(first.body.event.id);

    const events = await request(app).get('/api/emergency/events').set('Authorization', `Bearer ${elderToken}`);
    expect(events.body.events).toHaveLength(1);
  });

  it('blocks a caregiver from triggering an SOS', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerAndLink(app);
    const res = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${caregiverToken}`).send({});
    expect(res.status).toBe(403);
  });

  it('rejects latitude without longitude', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({ latitude: 12.34 });
    expect(res.status).toBe(400);
  });
});

describe('acknowledge / resolve', () => {
  it('lets a linked caregiver acknowledge, then either party resolve', async () => {
    const { app } = buildTestApp();
    const { elderToken, caregiverToken } = await registerAndLink(app);
    const sos = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    const eventId = sos.body.event.id as string;

    const ack = await request(app).patch(`/api/emergency/events/${eventId}/acknowledge`).set('Authorization', `Bearer ${caregiverToken}`).send();
    expect(ack.status).toBe(200);
    expect(ack.body.event.status).toBe('ACKNOWLEDGED');

    const resolve = await request(app).patch(`/api/emergency/events/${eventId}/resolve`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(resolve.status).toBe(200);
    expect(resolve.body.event.status).toBe('RESOLVED');
  });

  it('an elder cannot acknowledge their own event (caregiver-only)', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const sos = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    const res = await request(app)
      .patch(`/api/emergency/events/${sos.body.event.id}/acknowledge`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send();
    expect(res.status).toBe(403);
  });

  it('an unlinked caregiver cannot acknowledge or resolve', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const strangerRes = await request(app).post('/api/auth/register').send(stranger);
    const sos = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});

    const res = await request(app)
      .patch(`/api/emergency/events/${sos.body.event.id}/acknowledge`)
      .set('Authorization', `Bearer ${strangerRes.body.accessToken}`)
      .send();
    expect(res.status).toBe(403);
  });

  it('rejects acknowledging an already-acknowledged event, and resolving a resolved one', async () => {
    const { app } = buildTestApp();
    const { elderToken, caregiverToken } = await registerAndLink(app);
    const sos = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    const eventId = sos.body.event.id as string;

    await request(app).patch(`/api/emergency/events/${eventId}/acknowledge`).set('Authorization', `Bearer ${caregiverToken}`).send();
    const again = await request(app).patch(`/api/emergency/events/${eventId}/acknowledge`).set('Authorization', `Bearer ${caregiverToken}`).send();
    expect(again.status).toBe(409);

    await request(app).patch(`/api/emergency/events/${eventId}/resolve`).set('Authorization', `Bearer ${elderToken}`).send();
    const resolveAgain = await request(app).patch(`/api/emergency/events/${eventId}/resolve`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(resolveAgain.status).toBe(409);
  });

  it('a new SOS can be triggered again after the previous one is resolved', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const first = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    await request(app).patch(`/api/emergency/events/${first.body.event.id}/resolve`).set('Authorization', `Bearer ${elderToken}`).send();

    const second = await request(app).post('/api/emergency/sos').set('Authorization', `Bearer ${elderToken}`).send({});
    expect(second.body.event.id).not.toBe(first.body.event.id);

    const events = await request(app).get('/api/emergency/events').set('Authorization', `Bearer ${elderToken}`);
    expect(events.body.events).toHaveLength(2);
  });
});
