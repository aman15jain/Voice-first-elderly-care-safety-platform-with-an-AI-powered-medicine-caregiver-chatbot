import type { EmergencyContact, EmergencyEvent, EmergencyEventStatus } from '@prisma/client';

export type EmergencyContactRecord = EmergencyContact;
export type EmergencyEventRecord = EmergencyEvent;
export type { EmergencyEventStatus };

export interface CreateContactInput {
  elderId: string;
  name: string;
  phone: string;
  relationship?: string;
  priority: number;
}

export interface UpdateContactInput {
  name?: string;
  phone?: string;
  relationship?: string | null;
  priority?: number;
}

export interface CreateEventInput {
  elderId: string;
  latitude: number | null;
  longitude: number | null;
  locationCapturedAt: Date | null;
}

export interface UpdateEventStatusInput {
  status: EmergencyEventStatus;
  acknowledgedAt?: Date;
  acknowledgedBy?: string;
  resolvedAt?: Date;
  resolvedBy?: string;
}

export interface EmergencyRepository {
  listContactsForElder(elderId: string): Promise<EmergencyContactRecord[]>;
  findContactById(id: string): Promise<EmergencyContactRecord | null>;
  createContact(input: CreateContactInput): Promise<EmergencyContactRecord>;
  updateContact(id: string, input: UpdateContactInput): Promise<EmergencyContactRecord>;
  deleteContact(id: string): Promise<void>;
  nextContactPriority(elderId: string): Promise<number>;

  /** ACTIVE or ACKNOWLEDGED — used to make repeated SOS presses idempotent. */
  findActiveEventForElder(elderId: string): Promise<EmergencyEventRecord | null>;
  createEvent(input: CreateEventInput): Promise<EmergencyEventRecord>;
  findEventById(id: string): Promise<EmergencyEventRecord | null>;
  updateEventStatus(id: string, input: UpdateEventStatusInput): Promise<EmergencyEventRecord>;
  listEventsForElder(elderId: string, from: Date, to: Date): Promise<EmergencyEventRecord[]>;
}
