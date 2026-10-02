import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

describe('GET /health', () => {
  it('returns liveness without touching dependencies', async () => {
    const { app } = buildTestApp({
      pingDatabase: async () => {
        throw new Error('db down');
      },
    });
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.headers['x-request-id']).toBeTruthy();
  });
});

describe('GET /health/dependencies', () => {
  it('is 200 when database and AI service are up', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/health/dependencies');
    expect(res.status).toBe(200);
    expect(res.body.dependencies.database.status).toBe('up');
    expect(res.body.dependencies.aiService.status).toBe('up');
  });

  it('is 503/degraded when the AI service is down, without leaking error details', async () => {
    const { app } = buildTestApp({
      ai: {
        health: async () => {
          throw new Error('secret host 10.0.0.5');
        },
      },
    });
    const res = await request(app).get('/health/dependencies');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('degraded');
    expect(res.body.dependencies.aiService.status).toBe('down');
    expect(JSON.stringify(res.body)).not.toContain('10.0.0.5');
  });
});

describe('error handling', () => {
  it('returns a JSON 404 for unknown routes', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/nope');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });
});
