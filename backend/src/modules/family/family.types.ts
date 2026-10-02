import type { FamilyLink, FamilyLinkStatus, Role } from '@prisma/client';

export type FamilyLinkRecord = FamilyLink;
export type { FamilyLinkStatus };

/** listForUser's shape: the UI needs to show who a link is with, not just their id. */
export interface FamilyLinkWithNames extends FamilyLinkRecord {
  elderName: string | null;
  elderEmail: string;
  caregiverName: string | null;
  caregiverEmail: string;
}

export interface FamilyRepository {
  findUserByEmail(email: string): Promise<{ id: string; role: Role } | null>;
  findLinkByPair(elderId: string, caregiverId: string): Promise<FamilyLinkRecord | null>;
  createLink(input: { elderId: string; caregiverId: string; invitedBy: string }): Promise<FamilyLinkRecord>;
  /** Reuses a REVOKED/DECLINED row instead of hitting the (elderId, caregiverId) unique constraint. */
  reviveLink(id: string, invitedBy: string): Promise<FamilyLinkRecord>;
  findById(id: string): Promise<FamilyLinkRecord | null>;
  updateStatus(id: string, status: FamilyLinkStatus, respondedAt?: Date): Promise<FamilyLinkRecord>;
  listForUser(userId: string): Promise<FamilyLinkWithNames[]>;
  isAcceptedLink(elderId: string, caregiverId: string): Promise<boolean>;
  /** Caregivers with an ACCEPTED link to this elder — the audience for elder-facing alerts. */
  listAcceptedCaregiverIds(elderId: string): Promise<string[]>;
}
