import type { CognitiveGame, GameSession } from '@prisma/client';

export type GameRecord = CognitiveGame;
export type GameSessionRecord = GameSession;

export interface CreateSessionInput {
  elderId: string;
  gameId: string;
  difficulty: number;
  score: number;
  mistakes: number;
  durationSeconds: number;
  completed: boolean;
}

/** The minimal shape suggestNextDifficulty needs — decoupled from the full session record. */
export interface SessionOutcome {
  difficulty: number;
  mistakes: number;
  completed: boolean;
}

export interface GamesRepository {
  listActiveGames(): Promise<GameRecord[]>;
  findGameById(id: string): Promise<GameRecord | null>;
  createSession(input: CreateSessionInput): Promise<GameSessionRecord>;
  /** Most recent first, for deterministic difficulty suggestion. */
  listRecentSessions(elderId: string, gameId: string, limit: number): Promise<SessionOutcome[]>;
  listSessionsForElder(elderId: string, from: Date, to: Date, gameId?: string): Promise<GameSessionRecord[]>;
}
