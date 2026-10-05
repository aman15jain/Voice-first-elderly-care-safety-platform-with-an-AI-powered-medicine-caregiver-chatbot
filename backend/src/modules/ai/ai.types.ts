/** The AI response contract (spec section 26) — shared by voice (Phase 7, deterministic) and this
 *  module (Phase 8, agent-produced). `action` is always null here: Phase 8's agents are read-only
 *  and informational, never allowed to trigger a real-world action (docs/ai-architecture.md rule 3). */
export interface AiAnswer {
  type: 'information' | 'action';
  response: string;
  language: string;
  sources: string[];
  action: null;
}

export interface AiOrchestratorClient {
  askMedicineQuestion(elderId: string, query: string, language: string): Promise<AiAnswer>;
  getCaregiverInsight(elderId: string, language: string): Promise<AiAnswer>;
  /** Live, general-knowledge answer (no personal data). Used by the voice fallback. */
  askGeneralQuestion(elderId: string, query: string, language: string): Promise<AiAnswer>;
}
