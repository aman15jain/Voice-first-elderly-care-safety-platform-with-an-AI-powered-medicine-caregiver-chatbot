import { env } from '../config/env';

export interface AiHealth {
  status: string;
  service?: string;
  version?: string;
}

export interface AiClient {
  health(): Promise<AiHealth>;
}

/** HTTP client for the Python agentic-ai service. Node -> Python only; never exposed to Flutter. */
export class HttpAiClient implements AiClient {
  constructor(
    private readonly baseUrl = env.AI_SERVICE_URL,
    private readonly timeoutMs = env.AI_SERVICE_TIMEOUT_MS,
    private readonly apiKey = env.AI_SERVICE_API_KEY,
  ) {}

  private async request<T>(path: string): Promise<T> {
    const res = await fetch(new URL(path, this.baseUrl), {
      headers: this.apiKey ? { 'x-internal-api-key': this.apiKey } : {},
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!res.ok) throw new Error(`AI service responded ${res.status}`);
    return (await res.json()) as T;
  }

  health(): Promise<AiHealth> {
    return this.request<AiHealth>('/health');
  }
}
