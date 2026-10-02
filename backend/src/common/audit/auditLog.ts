import type { AuditAction, Prisma, PrismaClient } from '@prisma/client';

/** Kept as the single Prisma enum rather than duplicated here, so a new action can't be
 * added to one and forgotten in the other. */
export type AuditActionName = AuditAction;

export interface AuditEntry {
  /** null when the actor could not be identified (e.g. a login attempt for an unknown email). */
  actorId: string | null;
  action: AuditActionName;
  targetType?: string;
  targetId?: string;
  /** Never put passwords, tokens or full medical data here. */
  metadata?: Record<string, unknown>;
}

export interface AuditLogger {
  log(entry: AuditEntry): Promise<void>;
}

export class PrismaAuditLogger implements AuditLogger {
  constructor(private readonly prisma: PrismaClient) {}

  async log(entry: AuditEntry): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        actorId: entry.actorId,
        action: entry.action,
        targetType: entry.targetType,
        targetId: entry.targetId,
        metadata: entry.metadata as Prisma.InputJsonValue | undefined,
      },
    });
  }
}
