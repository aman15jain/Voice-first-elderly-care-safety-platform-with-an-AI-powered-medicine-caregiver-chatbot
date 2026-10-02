import type { AiAnswer, AiOrchestratorClient } from './ai.types';

/** Thin pass-through to the Python orchestrator. Node's only job here is authorization
 * (already done by the controller via resolveElderScope) and shaping the HTTP response —
 * no AI logic lives in Node, per docs/architecture.md. */
export class AiService {
  constructor(private readonly orchestrator: AiOrchestratorClient) {}

  askMedicineQuestion(elderId: string, query: string, language: string): Promise<AiAnswer> {
    return this.orchestrator.askMedicineQuestion(elderId, query, language);
  }

  getCaregiverInsight(elderId: string, language: string): Promise<AiAnswer> {
    return this.orchestrator.getCaregiverInsight(elderId, language);
  }
}
