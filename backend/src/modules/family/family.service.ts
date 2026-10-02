import type { Role } from '@prisma/client';
import type { AuditLogger } from '../../common/audit/auditLog';
import { AppError } from '../../common/errors/AppError';
import type { FamilyLinkRecord, FamilyRepository } from './family.types';

export class FamilyService {
  constructor(
    private readonly repo: FamilyRepository,
    private readonly audit: AuditLogger,
  ) {}

  /** Either an elder or a caregiver may start the link; the other party must accept it. */
  async invite(requesterId: string, requesterRole: Role, targetEmail: string): Promise<FamilyLinkRecord> {
    const target = await this.repo.findUserByEmail(targetEmail);
    if (!target) throw AppError.notFound('No account found with that email');
    if (target.id === requesterId) throw AppError.badRequest('You cannot link to your own account');

    let elderId: string;
    let caregiverId: string;
    if (requesterRole === 'ELDER') {
      if (target.role !== 'CAREGIVER') throw AppError.badRequest('That email does not belong to a caregiver account');
      elderId = requesterId;
      caregiverId = target.id;
    } else {
      if (target.role !== 'ELDER') throw AppError.badRequest('That email does not belong to an elder account');
      elderId = target.id;
      caregiverId = requesterId;
    }

    const existing = await this.repo.findLinkByPair(elderId, caregiverId);
    let link: FamilyLinkRecord;
    if (!existing) {
      link = await this.repo.createLink({ elderId, caregiverId, invitedBy: requesterId });
    } else if (existing.status === 'ACCEPTED' || existing.status === 'PENDING') {
      throw AppError.conflict('A family link already exists with that person');
    } else {
      link = await this.repo.reviveLink(existing.id, requesterId);
    }

    await this.audit.log({ actorId: requesterId, action: 'FAMILY_LINK_INVITED', targetType: 'FamilyLink', targetId: link.id });
    return link;
  }

  async respond(userId: string, linkId: string, accept: boolean): Promise<FamilyLinkRecord> {
    const link = await this.repo.findById(linkId);
    if (!link) throw AppError.notFound('Family link not found');

    const invitedParty = link.invitedBy === link.elderId ? link.caregiverId : link.elderId;
    if (invitedParty !== userId) throw AppError.forbidden('Only the invited person can respond to this link');
    if (link.status !== 'PENDING') throw AppError.conflict('This invite has already been responded to');

    const updated = await this.repo.updateStatus(linkId, accept ? 'ACCEPTED' : 'DECLINED', new Date());
    await this.audit.log({
      actorId: userId,
      action: accept ? 'FAMILY_LINK_ACCEPTED' : 'FAMILY_LINK_DECLINED',
      targetType: 'FamilyLink',
      targetId: linkId,
    });
    return updated;
  }

  async revoke(userId: string, linkId: string): Promise<FamilyLinkRecord> {
    const link = await this.repo.findById(linkId);
    if (!link) throw AppError.notFound('Family link not found');
    if (link.elderId !== userId && link.caregiverId !== userId) throw AppError.forbidden();
    if (link.status === 'REVOKED') return link;

    const updated = await this.repo.updateStatus(linkId, 'REVOKED');
    await this.audit.log({ actorId: userId, action: 'FAMILY_LINK_REVOKED', targetType: 'FamilyLink', targetId: linkId });
    return updated;
  }

  list(userId: string): Promise<FamilyLinkRecord[]> {
    return this.repo.listForUser(userId);
  }

  /**
   * Reusable guard for later modules (medicines, activity, emergency, ...): throws unless
   * this caregiver has an ACCEPTED link to this elder. This is the single enforcement point
   * for "a caregiver only sees what's explicitly shared with them" — call it, don't reimplement it.
   */
  async assertCaregiverCanAccessElder(caregiverId: string, elderId: string): Promise<void> {
    const ok = await this.repo.isAcceptedLink(elderId, caregiverId);
    if (!ok) throw AppError.forbidden("You do not have access to this elder's information");
  }
}
