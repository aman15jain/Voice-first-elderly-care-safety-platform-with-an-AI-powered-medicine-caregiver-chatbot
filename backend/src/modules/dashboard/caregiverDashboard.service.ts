import type { FamilyService } from '../family/family.service';
import type { FamilyLinkWithNames } from '../family/family.types';
import type { InternalContextService } from '../internal/internalContext.service';
import type { ElderDashboardRow } from './caregiverDashboard.types';

/**
 * The Phase 10 "one call instead of N" caregiver dashboard: reuses the exact same per-elder
 * facts the Phase 8 agentic-ai internal API already computes (`InternalContextService`), fanned
 * out across every elder this caregiver has an ACCEPTED link to — never a new authorization
 * path, never new business logic, just aggregation over data two earlier phases already produce.
 */
export class CaregiverDashboardService {
  constructor(
    private readonly family: FamilyService,
    private readonly internalContext: InternalContextService,
  ) {}

  async getDashboard(caregiverId: string): Promise<ElderDashboardRow[]> {
    const links = (await this.family.list(caregiverId)) as FamilyLinkWithNames[];
    const accepted = links.filter((link) => link.status === 'ACCEPTED' && link.caregiverId === caregiverId);

    return Promise.all(
      accepted.map(async (link) => {
        const context = await this.internalContext.getCaregiverInsightContext(link.elderId);
        return { elderId: link.elderId, elderName: link.elderName, elderEmail: link.elderEmail, ...context };
      }),
    );
  }
}
