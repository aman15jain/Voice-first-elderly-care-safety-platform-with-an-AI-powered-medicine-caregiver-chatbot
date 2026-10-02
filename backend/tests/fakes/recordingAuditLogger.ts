import type { AuditEntry, AuditLogger } from '../../src/common/audit/auditLog';

export class RecordingAuditLogger implements AuditLogger {
  readonly entries: AuditEntry[] = [];

  async log(entry: AuditEntry): Promise<void> {
    this.entries.push(entry);
  }
}
