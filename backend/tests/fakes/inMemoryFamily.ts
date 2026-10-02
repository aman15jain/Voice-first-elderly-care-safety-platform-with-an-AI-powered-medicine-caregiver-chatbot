import { randomUUID } from 'node:crypto';
import type { Role } from '@prisma/client';
import type { FamilyLinkRecord, FamilyLinkStatus, FamilyLinkWithNames, FamilyRepository } from '../../src/modules/family/family.types';
import type { InMemoryAuthRepository } from './inMemoryAuth';

export class InMemoryFamilyRepository implements FamilyRepository {
  readonly links = new Map<string, FamilyLinkRecord>();

  constructor(private readonly auth: InMemoryAuthRepository) {}

  async findUserByEmail(email: string): Promise<{ id: string; role: Role } | null> {
    const user = await this.auth.findUserByEmail(email);
    return user ? { id: user.id, role: user.role } : null;
  }

  async findLinkByPair(elderId: string, caregiverId: string): Promise<FamilyLinkRecord | null> {
    return [...this.links.values()].find((l) => l.elderId === elderId && l.caregiverId === caregiverId) ?? null;
  }

  async createLink(input: { elderId: string; caregiverId: string; invitedBy: string }): Promise<FamilyLinkRecord> {
    const now = new Date();
    const link: FamilyLinkRecord = {
      id: randomUUID(),
      elderId: input.elderId,
      caregiverId: input.caregiverId,
      status: 'PENDING',
      invitedBy: input.invitedBy,
      respondedAt: null,
      createdAt: now,
      updatedAt: now,
    };
    this.links.set(link.id, link);
    return link;
  }

  async reviveLink(id: string, invitedBy: string): Promise<FamilyLinkRecord> {
    const link = this.links.get(id);
    if (!link) throw new Error('link not found');
    link.status = 'PENDING';
    link.invitedBy = invitedBy;
    link.respondedAt = null;
    link.updatedAt = new Date();
    return link;
  }

  async findById(id: string): Promise<FamilyLinkRecord | null> {
    return this.links.get(id) ?? null;
  }

  async updateStatus(id: string, status: FamilyLinkStatus, respondedAt?: Date): Promise<FamilyLinkRecord> {
    const link = this.links.get(id);
    if (!link) throw new Error('link not found');
    link.status = status;
    if (respondedAt) link.respondedAt = respondedAt;
    link.updatedAt = new Date();
    return link;
  }

  async listForUser(userId: string): Promise<FamilyLinkWithNames[]> {
    return [...this.links.values()]
      .filter((l) => l.elderId === userId || l.caregiverId === userId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((l) => {
        const elder = this.auth.users.get(l.elderId);
        const caregiver = this.auth.users.get(l.caregiverId);
        return {
          ...l,
          elderName: this.auth.profiles.get(l.elderId) ?? null,
          elderEmail: elder?.email ?? '',
          caregiverName: this.auth.profiles.get(l.caregiverId) ?? null,
          caregiverEmail: caregiver?.email ?? '',
        };
      });
  }

  async isAcceptedLink(elderId: string, caregiverId: string): Promise<boolean> {
    const link = await this.findLinkByPair(elderId, caregiverId);
    return link?.status === 'ACCEPTED';
  }

  async listAcceptedCaregiverIds(elderId: string): Promise<string[]> {
    return [...this.links.values()].filter((l) => l.elderId === elderId && l.status === 'ACCEPTED').map((l) => l.caregiverId);
  }
}
