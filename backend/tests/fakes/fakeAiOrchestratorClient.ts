import type { AiAnswer, AiOrchestratorClient } from '../../src/modules/ai/ai.types';

/** Records what Node sent it and returns a settable canned answer — Python is never called in tests. */
export class FakeAiOrchestratorClient implements AiOrchestratorClient {
  lastElderId: string | null = null;
  lastQuery: string | null = null;
  lastLanguage: string | null = null;
  answerToReturn: AiAnswer = {
    type: 'information',
    response: 'This is a placeholder answer.',
    language: 'en',
    sources: [],
    action: null,
  };

  async askMedicineQuestion(elderId: string, query: string, language: string): Promise<AiAnswer> {
    this.lastElderId = elderId;
    this.lastQuery = query;
    this.lastLanguage = language;
    return this.answerToReturn;
  }

  async getCaregiverInsight(elderId: string, language: string): Promise<AiAnswer> {
    this.lastElderId = elderId;
    this.lastQuery = null;
    this.lastLanguage = language;
    return this.answerToReturn;
  }
}
