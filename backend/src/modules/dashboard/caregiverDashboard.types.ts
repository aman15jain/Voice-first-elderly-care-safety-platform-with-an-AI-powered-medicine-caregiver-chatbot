import type { CaregiverInsightContext } from '../internal/internalContext.service';

export interface ElderDashboardRow extends CaregiverInsightContext {
  elderId: string;
  elderName: string | null;
  elderEmail: string;
}
