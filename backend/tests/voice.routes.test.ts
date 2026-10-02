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

describe('POST /api/voice/process', () => {
  it('answers a medicine-info question deterministically', async () => {
    const { app, elderToken } = await (async () => {
      const { app } = buildTestApp();
      const { elderToken } = await registerAndLink(app);
      await request(app).post('/api/medicines').set('Authorization', `Bearer ${elderToken}`).send({ name: 'Metformin', dosage: '500mg' });
      return { app, elderToken };
    })();

    const res = await request(app)
      .post('/api/voice/process')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ transcript: 'what medicine do I take' });
    expect(res.status).toBe(200);
    expect(res.body.type).toBe('information');
    expect(res.body.response).toContain('Metformin');
    expect(res.body.action).toBeNull();
  });

  it('resolves "call my daughter" to the matching emergency contact as an action', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    await request(app)
      .post('/api/emergency/contacts')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ name: 'Jane', phone: '+1 555-123-4567', relationship: 'Daughter' });

    const res = await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'call my daughter' });
    expect(res.status).toBe(200);
    expect(res.body.type).toBe('action');
    expect(res.body.action).toMatchObject({ type: 'CALL_CONTACT', contactName: 'Jane', phone: '+1 555-123-4567' });
  });

  it('responds with a no-contact message when nothing matches the target', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);

    const res = await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'call my doctor' });
    expect(res.status).toBe(200);
    expect(res.body.type).toBe('information');
    expect(res.body.action).toBeNull();
  });

  it('returns a TRIGGER_SOS action (never auto-triggering the real SOS) for emergency phrases', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);

    const res = await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'help, help!' });
    expect(res.status).toBe(200);
    expect(res.body.action).toEqual({ type: 'TRIGGER_SOS' });

    const events = await request(app).get('/api/emergency/events').set('Authorization', `Bearer ${elderToken}`);
    expect(events.body.events).toHaveLength(0);
  });

  it('falls back to an unknown-intent response for unrecognized transcripts', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);

    const res = await request(app)
      .post('/api/voice/process')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ transcript: 'what is the weather today' });
    expect(res.status).toBe(200);
    expect(res.body.type).toBe('information');
    expect(res.body.action).toBeNull();
  });

  it('blocks a caregiver from processing a voice command', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerAndLink(app);
    const res = await request(app).post('/api/voice/process').set('Authorization', `Bearer ${caregiverToken}`).send({ transcript: 'help' });
    expect(res.status).toBe(403);
  });

  it('rejects an empty transcript', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: '' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/voice/interactions', () => {
  it('records every processed command and lets the elder list them', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'help' });
    await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'what is the weather' });

    const res = await request(app).get('/api/voice/interactions').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.interactions).toHaveLength(2);
    expect(res.body.interactions.map((i: { intentType: string }) => i.intentType).sort()).toEqual(['EMERGENCY_SOS', 'UNKNOWN']);
  });

  it('lets a linked caregiver view an elder\'s voice interactions, but not an unlinked one', async () => {
    const { app } = buildTestApp();
    const { elderId, elderToken, caregiverToken } = await registerAndLink(app);
    await request(app).post('/api/voice/process').set('Authorization', `Bearer ${elderToken}`).send({ transcript: 'help' });

    const allowed = await request(app).get(`/api/voice/interactions?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(allowed.status).toBe(200);
    expect(allowed.body.interactions).toHaveLength(1);

    const stranger = { email: 'stranger@example.com', password: 'correct-horse-3', role: 'CAREGIVER', fullName: 'Sam' };
    const strangerRes = await request(app).post('/api/auth/register').send(stranger);
    const blocked = await request(app)
      .get(`/api/voice/interactions?elderId=${elderId}`)
      .set('Authorization', `Bearer ${strangerRes.body.accessToken}`);
    expect(blocked.status).toBe(403);
  });
});
