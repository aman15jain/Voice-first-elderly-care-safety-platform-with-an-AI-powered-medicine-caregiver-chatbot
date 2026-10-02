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

describe('GET /api/games', () => {
  it('lists the four built-in games with a suggested difficulty of 1 for a new elder', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);

    const res = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.games).toHaveLength(4);
    expect(res.body.games.every((g: { suggestedDifficulty: number }) => g.suggestedDifficulty === 1)).toBe(true);
  });

  it('requires elderId for a caregiver, and requires an accepted link', async () => {
    const { app } = buildTestApp();
    const { elderId, caregiverToken } = await registerAndLink(app);

    const missing = await request(app).get('/api/games').set('Authorization', `Bearer ${caregiverToken}`);
    expect(missing.status).toBe(400);

    const linked = await request(app).get(`/api/games?elderId=${elderId}`).set('Authorization', `Bearer ${caregiverToken}`);
    expect(linked.status).toBe(200);
  });
});

describe('POST /api/games/:id/session', () => {
  it('records a session and blocks a caregiver from recording one', async () => {
    const { app } = buildTestApp();
    const { elderToken, caregiverToken } = await registerAndLink(app);
    const games = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    const gameId = games.body.games[0].id as string;

    const res = await request(app)
      .post(`/api/games/${gameId}/session`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ difficulty: 1, score: 100, mistakes: 0, durationSeconds: 45, completed: true });
    expect(res.status).toBe(201);
    expect(res.body.session).toMatchObject({ gameId, difficulty: 1, score: 100, completed: true });

    const blocked = await request(app)
      .post(`/api/games/${gameId}/session`)
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ difficulty: 1, score: 100, mistakes: 0, durationSeconds: 45, completed: true });
    expect(blocked.status).toBe(403);
  });

  it('rejects an out-of-range difficulty', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const games = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    const gameId = games.body.games[0].id as string;

    const res = await request(app)
      .post(`/api/games/${gameId}/session`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ difficulty: 4, score: 100, mistakes: 0, durationSeconds: 45, completed: true });
    expect(res.status).toBe(400);
  });

  it('404s for an unknown game', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const res = await request(app)
      .post('/api/games/00000000-0000-0000-0000-000000000000/session')
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ difficulty: 1, score: 0, mistakes: 0, durationSeconds: 10, completed: false });
    expect(res.status).toBe(404);
  });

  it('suggests a higher difficulty after two strong sessions at the current level', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const games = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    const gameId = games.body.games[0].id as string;

    for (let i = 0; i < 2; i++) {
      await request(app)
        .post(`/api/games/${gameId}/session`)
        .set('Authorization', `Bearer ${elderToken}`)
        .send({ difficulty: 1, score: 100, mistakes: 0, durationSeconds: 30, completed: true });
    }

    const after = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    const game = after.body.games.find((g: { id: string }) => g.id === gameId);
    expect(game.suggestedDifficulty).toBe(2);
  });
});

describe('GET /api/games/sessions', () => {
  it('lists recorded sessions and validates the date range', async () => {
    const { app } = buildTestApp();
    const { elderToken } = await registerAndLink(app);
    const games = await request(app).get('/api/games').set('Authorization', `Bearer ${elderToken}`);
    const gameId = games.body.games[0].id as string;
    await request(app)
      .post(`/api/games/${gameId}/session`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send({ difficulty: 1, score: 50, mistakes: 1, durationSeconds: 20, completed: true });

    const res = await request(app).get('/api/games/sessions').set('Authorization', `Bearer ${elderToken}`);
    expect(res.status).toBe(200);
    expect(res.body.sessions).toHaveLength(1);

    const badRange = await request(app).get('/api/games/sessions?from=2026-01-01&to=2026-06-01').set('Authorization', `Bearer ${elderToken}`);
    expect(badRange.status).toBe(400);
  });
});
