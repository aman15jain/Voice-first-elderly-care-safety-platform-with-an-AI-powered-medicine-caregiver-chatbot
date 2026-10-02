import { randomUUID } from 'node:crypto';
import type {
  CreateContactInput,
  CreateEventInput,
  EmergencyContactRecord,
  EmergencyEventRecord,
  EmergencyRepository,
  UpdateContactInput,
  UpdateEventStatusInput,
} from '../../src/modules/emergency/emergency.types';

export class InMemoryEmergencyRepository implements EmergencyRepository {
  readonly contacts = new Map<string, EmergencyContactRecord>();
  readonly events = new Map<string, EmergencyEventRecord>();

  async listContactsForElder(elderId: string): Promise<EmergencyContactRecord[]> {
    return [...this.contacts.values()].filter((c) => c.elderId === elderId).sort((a, b) => a.priority - b.priority);
  }

  async findContactById(id: string): Promise<EmergencyContactRecord | null> {
    return this.contacts.get(id) ?? null;
  }

  async createContact(input: CreateContactInput): Promise<EmergencyContactRecord> {
    const now = new Date();
    const contact: EmergencyContactRecord = {
      id: randomUUID(),
      elderId: input.elderId,
      name: input.name,
      phone: input.phone,
      relationship: input.relationship ?? null,
      priority: input.priority,
      createdAt: now,
      updatedAt: now,
    };
    this.contacts.set(contact.id, contact);
    return contact;
  }

  async updateContact(id: string, input: UpdateContactInput): Promise<EmergencyContactRecord> {
    const contact = this.contacts.get(id);
    if (!contact) throw new Error('contact not found');
    Object.assign(contact, input, { updatedAt: new Date() });
    return contact;
  }

  async deleteContact(id: string): Promise<void> {
    this.contacts.delete(id);
  }

  async nextContactPriority(elderId: string): Promise<number> {
    const existing = [...this.contacts.values()].filter((c) => c.elderId === elderId);
    return existing.length === 0 ? 1 : Math.max(...existing.map((c) => c.priority)) + 1;
  }

  async findActiveEventForElder(elderId: string): Promise<EmergencyEventRecord | null> {
    return (
      [...this.events.values()]
        .filter((e) => e.elderId === elderId && (e.status === 'ACTIVE' || e.status === 'ACKNOWLEDGED'))
        .sort((a, b) => b.triggeredAt.getTime() - a.triggeredAt.getTime())[0] ?? null
    );
  }

  async createEvent(input: CreateEventInput): Promise<EmergencyEventRecord> {
    const now = new Date();
    const event: EmergencyEventRecord = {
      id: randomUUID(),
      elderId: input.elderId,
      status: 'ACTIVE',
      latitude: input.latitude,
      longitude: input.longitude,
      locationCapturedAt: input.locationCapturedAt,
      triggeredAt: now,
      acknowledgedAt: null,
      acknowledgedBy: null,
      resolvedAt: null,
      resolvedBy: null,
      createdAt: now,
    };
    this.events.set(event.id, event);
    return event;
  }

  async findEventById(id: string): Promise<EmergencyEventRecord | null> {
    return this.events.get(id) ?? null;
  }

  async updateEventStatus(id: string, input: UpdateEventStatusInput): Promise<EmergencyEventRecord> {
    const event = this.events.get(id);
    if (!event) throw new Error('event not found');
    Object.assign(event, input);
    return event;
  }

  async listEventsForElder(elderId: string, from: Date, to: Date): Promise<EmergencyEventRecord[]> {
    return [...this.events.values()]
      .filter((e) => e.elderId === elderId && e.triggeredAt >= from && e.triggeredAt <= to)
      .sort((a, b) => b.triggeredAt.getTime() - a.triggeredAt.getTime());
  }
}
