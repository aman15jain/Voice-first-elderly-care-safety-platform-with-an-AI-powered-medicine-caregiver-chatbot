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

describe('POST /api/ai/ask', () => {
  it('forwards the elder\'s own id and query to the orchestrator and returns its answer', async () => {
    const { app, aiOrchestrator } = buildTestApp();
    const { elderToken, elderId } = await registerAndLink(app);
    aiOrchestrator.answerToReturn = {
      type: 'information',
      response: 'You take Metformin 500mg once a day.',
      language: 'en',
      sources: ['medicines'],
      action: null,
    };

    const res = await request(app).post('/api/ai/ask').set('Authorization', `Bearer ${elderToken}`).send({ query: 'what medicine do I take' });
    expect(res.status).toBe(200);
    expect(res.body.response).toBe('You take Metformin 500mg once a day.');
    expect(res.body.sources).toEqual(['medicines']);
    expect(res.body.action).toBeNull();
    expect(aiOrchestrator.lastElderId).toBe(elderId);
    expect(aiOrchestrator.lastQuery).toBe('what medicine do I take');
    expect(aiOrchestrator.lastLanguage).toBe('en');
  });

  it('blocks a caregiver from asking the medicine assistant', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerAndLink(app);
    const res = await request(app).post('/api/ai/ask').set('Authorization', `Bearer ${caregiverToken}`).send({ query: 'hello' });
    expect(res.status).toBe(403);
  });

  it('rejects an empty query', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).post('/api/ai/ask').set('Authorization', `Bearer ${elderToken}`).send({ query: '' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/ai/caregiver-insight', () => {
  it('lets a linked caregiver fetch an insight summary for their elder', async () => {
    const { app, aiOrchestrator } = buildTestApp();
    const { elderId, caregiverToken } = await registerAndLink(app);
    aiOrchestrator.answerToReturn = {
      type: 'information',
      response: 'Adherence has been good this month.',
      language: 'en',
      sources: ['adherence_summary'],
      action: null,
    };

    const res = await request(app).get(`/api/ai/caregiver-insight?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(res.status).toBe(200);
    expect(res.body.response).toBe('Adherence has been good this month.');
    expect(aiOrchestrator.lastElderId).toBe(elderId);
  });

  it('blocks a caregiver without an accepted link', async () => {
    const { app } = buildTestApp();
    const { elderId } = await registerAndLink(app);
    const stranger = { email: 'stranger@example.com', password: 'correct-horse-3', role: 'CAREGIVER', fullName: 'Sam' };
    const strangerRes = await request(app).post('/api/auth/register').send(stranger);

    const res = await request(app).get(`/api/ai/caregiver-insight?elderId=${elderId}`).set('Authorization', `Bearer ${strangerRes.body.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('lets an elder fetch their own insight without passing elderId', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app).get('/api/ai/caregiver-insight').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
  });
});
