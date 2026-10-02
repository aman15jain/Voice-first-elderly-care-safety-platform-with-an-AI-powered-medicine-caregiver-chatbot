import { env } from '../../config/env';
import { AppError } from '../../common/errors/AppError';
import type { AiAnswer, AiOrchestratorClient } from './ai.types';

interface AgentHttpResponse {
  success: boolean;
  type: 'information' | 'action';
  response: string;
  language: string;
  sources: string[];
  action: null;
}

/** Node -> Python only; never called from Flutter. Mirrors `HttpAiClient` (services/aiClient.ts). */
export class HttpAiOrchestratorClient implements AiOrchestratorClient {
  constructor(
    private readonly baseUrl = env.AI_SERVICE_URL,
    private readonly timeoutMs = env.AI_SERVICE_TIMEOUT_MS,
    private readonly apiKey = env.AI_SERVICE_API_KEY,
  ) {}

  private async respond(body: Record<string, unknown>): Promise<AiAnswer> {
    let res: Response;
    try {
      res = await fetch(new URL('/agents/respond', this.baseUrl), {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...(this.apiKey ? { 'x-internal-api-key': this.apiKey } : {}) },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch {
      throw AppError.serviceUnavailable('The AI assistant is unavailable right now. Please try again shortly.');
    }
    if (!res.ok) throw AppError.serviceUnavailable('The AI assistant is unavailable right now. Please try again shortly.');
    const data = (await res.json()) as AgentHttpResponse;
    return { type: data.type, response: data.response, language: data.language, sources: data.sources, action: null };
  }

  askMedicineQuestion(elderId: string, query: string, language: string): Promise<AiAnswer> {
    return this.respond({ elder_id: elderId, mode: 'medicine_query', query, language });
  }

  getCaregiverInsight(elderId: string, language: string): Promise<AiAnswer> {
    return this.respond({ elder_id: elderId, mode: 'caregiver_insight', language });
  }
}
