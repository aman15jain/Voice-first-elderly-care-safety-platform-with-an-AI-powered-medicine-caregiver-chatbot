import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './helpers/buildTestApp';

const caregiver = { email: 'caregiver@example.com', password: 'correct-horse-1', role: 'CAREGIVER', fullName: 'Alex' };
const stranger = { email: 'stranger@example.com', password: 'correct-horse-2', role: 'CAREGIVER', fullName: 'Sam' };

describe('notifications', () => {
  it('lists and marks a notification read, and a stranger cannot mark someone else’s read', async () => {
    const { app, notifications } = buildTestApp();
    const caregiverRes = await request(app).post('/api/auth/register').send(caregiver);
    const strangerRes = await request(app).post('/api/auth/register').send(stranger);
    const caregiverToken = caregiverRes.body.accessToken as string;
    const strangerToken = strangerRes.body.accessToken as string;
    const caregiverId = caregiverRes.body.user.id as string;

    // Seeded directly, the way MissedDoseService would create one via NotificationsService.
    const notification = await notifications.create({
      recipientId: caregiverId,
      type: 'MISSED_DOSE',
      title: 'A medicine dose was missed',
      body: 'A scheduled dose was not confirmed in time.',
      data: { doseId: 'dose-1' },
    });

    const list = await request(app).get('/api/notifications').set('Authorization', `Bearer ${caregiverToken}`);
    expect(list.status).toBe(200);
    expect(list.body.notifications).toHaveLength(1);
    expect(list.body.notifications[0].readAt).toBeNull();

    const strangerTriesToRead = await request(app)
      .patch(`/api/notifications/${notification.id}/read`)
      .set('Authorization', `Bearer ${strangerToken}`)
      .send();
    expect(strangerTriesToRead.status).toBe(403);

    const markRead = await request(app)
      .patch(`/api/notifications/${notification.id}/read`)
      .set('Authorization', `Bearer ${caregiverToken}`)
      .send();
    expect(markRead.status).toBe(200);
    expect(markRead.body.notification.readAt).toBeTruthy();

    const unreadOnly = await request(app).get('/api/notifications?unreadOnly=true').set('Authorization', `Bearer ${caregiverToken}`);
    expect(unreadOnly.body.notifications).toHaveLength(0);
  });
});
