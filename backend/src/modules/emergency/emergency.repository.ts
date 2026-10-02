import type { PrismaClient } from '@prisma/client';
import type {
  CreateContactInput,
  CreateEventInput,
  EmergencyContactRecord,
  EmergencyEventRecord,
  EmergencyRepository,
  UpdateContactInput,
  UpdateEventStatusInput,
} from './emergency.types';

export class PrismaEmergencyRepository implements EmergencyRepository {
  constructor(private readonly prisma: PrismaClient) {}

  listContactsForElder(elderId: string): Promise<EmergencyContactRecord[]> {
    return this.prisma.emergencyContact.findMany({ where: { elderId }, orderBy: { priority: 'asc' } });
  }

  findContactById(id: string): Promise<EmergencyContactRecord | null> {
    return this.prisma.emergencyContact.findUnique({ where: { id } });
  }

  createContact(input: CreateContactInput): Promise<EmergencyContactRecord> {
    return this.prisma.emergencyContact.create({ data: input });
  }

  updateContact(id: string, input: UpdateContactInput): Promise<EmergencyContactRecord> {
    return this.prisma.emergencyContact.update({ where: { id }, data: input });
  }

  async deleteContact(id: string): Promise<void> {
    await this.prisma.emergencyContact.delete({ where: { id } });
  }

  async nextContactPriority(elderId: string): Promise<number> {
    const result = await this.prisma.emergencyContact.aggregate({ where: { elderId }, _max: { priority: true } });
    return (result._max.priority ?? 0) + 1;
  }

  findActiveEventForElder(elderId: string): Promise<EmergencyEventRecord | null> {
    return this.prisma.emergencyEvent.findFirst({
      where: { elderId, status: { in: ['ACTIVE', 'ACKNOWLEDGED'] } },
      orderBy: { triggeredAt: 'desc' },
    });
  }

  createEvent(input: CreateEventInput): Promise<EmergencyEventRecord> {
    return this.prisma.emergencyEvent.create({ data: input });
  }

  findEventById(id: string): Promise<EmergencyEventRecord | null> {
    return this.prisma.emergencyEvent.findUnique({ where: { id } });
  }

  updateEventStatus(id: string, input: UpdateEventStatusInput): Promise<EmergencyEventRecord> {
    return this.prisma.emergencyEvent.update({ where: { id }, data: input });
  }

  listEventsForElder(elderId: string, from: Date, to: Date): Promise<EmergencyEventRecord[]> {
    return this.prisma.emergencyEvent.findMany({
      where: { elderId, triggeredAt: { gte: from, lte: to } },
      orderBy: { triggeredAt: 'desc' },
    });
  }
}
