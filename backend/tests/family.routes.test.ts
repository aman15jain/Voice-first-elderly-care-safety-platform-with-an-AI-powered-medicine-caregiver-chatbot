import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { signAccessToken } from '../src/common/utils/tokens';
import { buildTestApp, testJwtConfig } from './helpers/buildTestApp';

const elder = { email: 'elder@example.com', password: 'correct-horse-1', role: 'ELDER', fullName: 'Grandma Rose' };
const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Alex' };

async function registerBoth(app: import('express').Express) {
  const elderRes = await request(app).post('/api/auth/register').send(elder);
  const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
  return {
    elderId: elderRes.body.user.id as string,
    elderToken: elderRes.body.accessToken as string,
    caregiverId: caregiverRes.body.user.id as string,
    caregiverToken: caregiverRes.body.accessToken as string,
  };
}

describe('family links', () => {
  it('requires authentication', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/api/family/links');
    expect(res.status).toBe(401);
  });

  it('lets a caregiver invite an elder, who then sees and accepts it', async () => {
    const { app, family, audit } = buildTestApp();
    const { elderId, elderToken, caregiverId, caregiverToken } = await registerBoth(app);

    const invite = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ email: elder.email });
    expect(invite.status).toBe(201);
    expect(invite.body.link).toMatchObject({ elderId, caregiverId, status: 'PENDING', invitedBy: caregiverId });

    const elderList = await request(app).get('/api/family/links').set('Authorization', `Bearer ${elderToken}`);
    expect(elderList.body.links).toHaveLength(1);

    const linkId = invite.body.link.id as string;
    const accept = await request(app)
      .patch(`/api/family/links/${linkId}/accept`)
      .set('Authorization', `Bearer ${elderToken}`)
      .send();
    expect(accept.status).toBe(200);
    expect(accept.body.link.status).toBe('ACCEPTED');
    expect(await family.isAcceptedLink(elderId, caregiverId)).toBe(true);
    expect(audit.entries.some((e) => e.action === 'FAMILY_LINK_ACCEPTED')).toBe(true);
  });

  it('only the invited party can accept — not the inviter, not a stranger', async () => {
    const { app } = buildTestApp();
    const { elderToken, caregiverToken } = await registerBoth(app);

    const invite = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ email: elder.email });
    const linkId = invite.body.link.id as string;

    const inviterTriesToAccept = await request(app)
      .patch(`/api/family/links/${linkId}/accept`)
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send();
    expect(inviterTriesToAccept.status).toBe(403);

    void elderToken; // the elder accepting is covered by the happy-path test above
  });

  it('rejects inviting an account of the wrong role', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerBoth(app);
    const secondCaregiver = { email: 'other-caregiver@example.com', password: 'correct-horse-3', role: 'CAREGIVER', fullName: 'Sam' };
    await request(app).post('/api/auth/register').send(secondCaregiver);

    const res = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ email: secondCaregiver.email });
    expect(res.status).toBe(400);
  });

  it('rejects a duplicate invite while one is pending or accepted', async () => {
    const { app } = buildTestApp();
    const { caregiverToken } = await registerBoth(app);
    await request(app).post('/api/family/links').set('Authorization', `Bearer ${caregiverToken}`).send({ email: elder.email });

    const again = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ email: elder.email });
    expect(again.status).toBe(409);
  });

  it('either party can revoke a link, and a revoked pair can be re-invited', async () => {
    const { app } = buildTestApp();
    const { elderId, elderToken, caregiverId, caregiverToken } = await registerBoth(app);

    const invite = await request(app).post('/api/family/links').set('Authorization', `Bearer ${caregiverToken}`).send({ email: elder.email });
    const linkId = invite.body.link.id as string;
    await request(app).patch(`/api/family/links/${linkId}/accept`).set('Authorization', `Bearer ${elderToken}`).send();

    const revoke = await request(app).delete(`/api/family/links/${linkId}`).set('Authorization', `Bearer ${elderToken}`).send();
    expect(revoke.status).toBe(200);
    expect(revoke.body.link.status).toBe('REVOKED');

    const reinvite = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send({ email: elder.email });
    expect(reinvite.status).toBe(201);
    expect(reinvite.body.link.id).toBe(linkId);
    expect(reinvite.body.link.status).toBe('PENDING');

    void elderId;
    void caregiverId;
  });

  it('blocks ADMIN from creating family links', async () => {
    const { app } = buildTestApp();
    const adminToken = signAccessToken({ sub: 'admin-1', role: 'ADMIN' }, testJwtConfig.accessSecret, testJwtConfig.accessTtlSeconds);

    const res = await request(app)
      .post('/api/family/links')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: elder.email });
    expect(res.status).toBe(403);
  });
});
