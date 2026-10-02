import { randomUUID } from 'node:crypto';
import type { GameType } from '@prisma/client';
import type {
  CreateSessionInput,
  GameRecord,
  GamesRepository,
  GameSessionRecord,
  SessionOutcome,
} from '../../src/modules/games/games.types';

const CATALOG: { type: GameType; name: string; description: string }[] = [
  { type: 'MEMORY_MATCH', name: 'Memory Match', description: 'Find the matching pairs of cards.' },
  { type: 'PATTERN_RECOGNITION', name: 'Pattern Recognition', description: "Spot what comes next in the pattern." },
  { type: 'ATTENTION_EXERCISE', name: 'Attention Exercise', description: 'Find the one that is different.' },
  { type: 'SEQUENCE_RECALL', name: 'Sequence Recall', description: 'Repeat the sequence back in order.' },
];

export class InMemoryGamesRepository implements GamesRepository {
  readonly games = new Map<string, GameRecord>();
  readonly sessions: GameSessionRecord[] = [];

  constructor() {
    const now = new Date();
    for (const entry of CATALOG) {
      const id = randomUUID();
      this.games.set(id, { id, type: entry.type, name: entry.name, description: entry.description, isActive: true, createdAt: now, updatedAt: now });
    }
  }

  async listActiveGames(): Promise<GameRecord[]> {
    return [...this.games.values()].filter((g) => g.isActive).sort((a, b) => a.name.localeCompare(b.name));
  }

  async findGameById(id: string): Promise<GameRecord | null> {
    return this.games.get(id) ?? null;
  }

  async createSession(input: CreateSessionInput): Promise<GameSessionRecord> {
    const session: GameSessionRecord = { id: randomUUID(), createdAt: new Date(), ...input };
    this.sessions.push(session);
    return session;
  }

  async listRecentSessions(elderId: string, gameId: string, limit: number): Promise<SessionOutcome[]> {
    return this.sessions
      .filter((s) => s.elderId === elderId && s.gameId === gameId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit)
      .map((s) => ({ difficulty: s.difficulty, mistakes: s.mistakes, completed: s.completed }));
  }

  async listSessionsForElder(elderId: string, from: Date, to: Date, gameId?: string): Promise<GameSessionRecord[]> {
    return this.sessions
      .filter((s) => s.elderId === elderId && s.createdAt >= from && s.createdAt <= to && (!gameId || s.gameId === gameId))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }
}
