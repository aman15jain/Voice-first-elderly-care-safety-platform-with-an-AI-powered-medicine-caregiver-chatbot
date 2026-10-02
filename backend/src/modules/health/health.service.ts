import type { AiClient } from '../../services/aiClient';

export interface DependencyStatus {
  status: 'up' | 'down';
  latencyMs: number;
  error?: string;
}

export interface HealthDeps {
  pingDatabase: () => Promise<unknown>;
  ai: AiClient;
}

async function probe(fn: () => Promise<unknown>): Promise<DependencyStatus> {
  const start = Date.now();
  try {
    await fn();
    return { status: 'up', latencyMs: Date.now() - start };
  } catch (e) {
    // Short reason only; the full error is not returned to clients.
    return { status: 'down', latencyMs: Date.now() - start, error: e instanceof Error ? e.name : 'Error' };
  }
}

export class HealthService {
  constructor(private readonly deps: HealthDeps) {}

  liveness() {
    return { status: 'ok', service: 'backend', uptimeSeconds: Math.round(process.uptime()) };
  }

  async dependencies() {
    const [database, aiService] = await Promise.all([
      probe(this.deps.pingDatabase),
      probe(() => this.deps.ai.health()),
    ]);
    const allUp = database.status === 'up' && aiService.status === 'up';
    return {
      status: allUp ? 'ok' : 'degraded',
      service: 'backend',
      dependencies: { database, aiService },
    };
  }
}
