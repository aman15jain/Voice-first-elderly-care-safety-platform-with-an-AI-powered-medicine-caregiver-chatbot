import type { Role } from '@prisma/client';
import type { FamilyAccessCheck } from '../../common/access/elderScope';
import type { AuditLogger } from '../../common/audit/auditLog';
import { AppError } from '../../common/errors/AppError';
import type { CaregiverLookup } from '../reminders/missedDose.service';
import type { NotificationsService } from '../notifications/notifications.service';
import type {
  EmergencyContactRecord,
  EmergencyEventRecord,
  EmergencyRepository,
  UpdateContactInput,
} from './emergency.types';

export interface Location {
  latitude: number;
  longitude: number;
}

/**
 * Emergency SOS is deterministic, reliable backend logic — never an LLM decision (spec
 * section 15). The actual real-world call to an emergency contact happens on-device in
 * Flutter (the backend has no way to place a call to a number that isn't a registered
 * user); only linked caregivers, who ARE registered users, get an in-app notification here.
 */
export class EmergencyService {
  constructor(
    private readonly repo: EmergencyRepository,
    private readonly family: FamilyAccessCheck,
    private readonly caregiverLookup: CaregiverLookup,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditLogger,
  ) {}

  // --- Contacts ---

  listContacts(elderId: string): Promise<EmergencyContactRecord[]> {
    return this.repo.listContactsForElder(elderId);
  }

  async createContact(
    elderId: string,
    input: { name: string; phone: string; relationship?: string; priority?: number },
  ): Promise<EmergencyContactRecord> {
    const priority = input.priority ?? (await this.repo.nextContactPriority(elderId));
    return this.repo.createContact({ elderId, name: input.name, phone: input.phone, relationship: input.relationship, priority });
  }

  async getOwnedContact(elderId: string, id: string): Promise<EmergencyContactRecord> {
    const contact = await this.repo.findContactById(id);
    if (!contact || contact.elderId !== elderId) throw AppError.notFound('Emergency contact not found');
    return contact;
  }

  async updateContact(elderId: string, id: string, input: UpdateContactInput): Promise<EmergencyContactRecord> {
    await this.getOwnedContact(elderId, id);
    return this.repo.updateContact(id, input);
  }

  async deleteContact(elderId: string, id: string): Promise<void> {
    await this.getOwnedContact(elderId, id);
    await this.repo.deleteContact(id);
  }

  // --- SOS / events ---

  /** Repeated presses while one is already active/acknowledged return the existing event
   * instead of creating duplicates or spamming caregivers again. */
  async triggerSOS(elderId: string, location?: Location): Promise<EmergencyEventRecord> {
    const existing = await this.repo.findActiveEventForElder(elderId);
    if (existing) return existing;

    const event = await this.repo.createEvent({
      elderId,
      latitude: location?.latitude ?? null,
      longitude: location?.longitude ?? null,
      locationCapturedAt: location ? new Date() : null,
    });
    await this.audit.log({ actorId: elderId, action: 'EMERGENCY_SOS_TRIGGERED', targetType: 'EmergencyEvent', targetId: event.id });

    const caregiverIds = await this.caregiverLookup.listAcceptedCaregiverIds(elderId);
    for (const caregiverId of caregiverIds) {
      await this.notifications.notify({
        recipientId: caregiverId,
        type: 'EMERGENCY_SOS',
        title: 'Emergency alert',
        body: 'An emergency SOS was triggered. Please check on them right away.',
        data: { eventId: event.id, elderId },
      });
    }

    return event;
  }

  async acknowledge(caregiverId: string, eventId: string): Promise<EmergencyEventRecord> {
    const event = await this.repo.findEventById(eventId);
    if (!event) throw AppError.notFound('Emergency event not found');
    await this.family.assertCaregiverCanAccessElder(caregiverId, event.elderId);
    if (event.status !== 'ACTIVE') throw AppError.conflict(`This emergency is already ${event.status.toLowerCase()}`);

    const updated = await this.repo.updateEventStatus(eventId, { status: 'ACKNOWLEDGED', acknowledgedAt: new Date(), acknowledgedBy: caregiverId });
    await this.audit.log({ actorId: caregiverId, action: 'EMERGENCY_EVENT_ACKNOWLEDGED', targetType: 'EmergencyEvent', targetId: eventId });
    return updated;
  }

  /** The elder can cancel their own SOS (false alarm / feeling fine now); a linked caregiver can resolve it too. */
  async resolve(userId: string, role: Role, eventId: string): Promise<EmergencyEventRecord> {
    const event = await this.repo.findEventById(eventId);
    if (!event) throw AppError.notFound('Emergency event not found');
    if (event.status === 'RESOLVED') throw AppError.conflict('This emergency has already been resolved');

    if (role === 'ELDER') {
      if (event.elderId !== userId) throw AppError.forbidden();
    } else if (role === 'CAREGIVER') {
      await this.family.assertCaregiverCanAccessElder(userId, event.elderId);
    } else {
      throw AppError.forbidden();
    }

    const updated = await this.repo.updateEventStatus(eventId, { status: 'RESOLVED', resolvedAt: new Date(), resolvedBy: userId });
    await this.audit.log({ actorId: userId, action: 'EMERGENCY_EVENT_RESOLVED', targetType: 'EmergencyEvent', targetId: eventId });
    return updated;
  }

  listEvents(elderId: string, from: Date, to: Date): Promise<EmergencyEventRecord[]> {
    return this.repo.listEventsForElder(elderId, from, to);
  }
}
