import type { FamilyLinkStatus, PrismaClient, Role } from '@prisma/client';
import type { FamilyLinkRecord, FamilyLinkWithNames, FamilyRepository } from './family.types';

export class PrismaFamilyRepository implements FamilyRepository {
  constructor(private readonly prisma: PrismaClient) {}

  findUserByEmail(email: string): Promise<{ id: string; role: Role } | null> {
    return this.prisma.user.findUnique({ where: { email }, select: { id: true, role: true } });
  }

  findLinkByPair(elderId: string, caregiverId: string): Promise<FamilyLinkRecord | null> {
    return this.prisma.familyLink.findUnique({ where: { elderId_caregiverId: { elderId, caregiverId } } });
  }

  createLink(input: { elderId: string; caregiverId: string; invitedBy: string }): Promise<FamilyLinkRecord> {
    return this.prisma.familyLink.create({ data: input });
  }

  reviveLink(id: string, invitedBy: string): Promise<FamilyLinkRecord> {
    return this.prisma.familyLink.update({ where: { id }, data: { status: 'PENDING', invitedBy, respondedAt: null } });
  }

  findById(id: string): Promise<FamilyLinkRecord | null> {
    return this.prisma.familyLink.findUnique({ where: { id } });
  }

  updateStatus(id: string, status: FamilyLinkStatus, respondedAt?: Date): Promise<FamilyLinkRecord> {
    return this.prisma.familyLink.update({ where: { id }, data: { status, ...(respondedAt ? { respondedAt } : {}) } });
  }

  async listForUser(userId: string): Promise<FamilyLinkWithNames[]> {
    const links = await this.prisma.familyLink.findMany({
      where: { OR: [{ elderId: userId }, { caregiverId: userId }] },
      orderBy: { createdAt: 'desc' },
      include: {
        elder: { select: { email: true, elderProfile: { select: { fullName: true } } } },
        caregiver: { select: { email: true, caregiverProfile: { select: { fullName: true } } } },
      },
    });
    return links.map(({ elder, caregiver, ...link }) => ({
      ...link,
      elderName: elder.elderProfile?.fullName ?? null,
      elderEmail: elder.email,
      caregiverName: caregiver.caregiverProfile?.fullName ?? null,
      caregiverEmail: caregiver.email,
    }));
  }

  async isAcceptedLink(elderId: string, caregiverId: string): Promise<boolean> {
    const link = await this.findLinkByPair(elderId, caregiverId);
    return link?.status === 'ACCEPTED';
  }

  async listAcceptedCaregiverIds(elderId: string): Promise<string[]> {
    const links = await this.prisma.familyLink.findMany({
      where: { elderId, status: 'ACCEPTED' },
      select: { caregiverId: true },
    });
    return links.map((l) => l.caregiverId);
  }
}
