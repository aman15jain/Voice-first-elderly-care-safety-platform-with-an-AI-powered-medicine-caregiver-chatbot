import { AppError } from '../../common/errors/AppError';
import { suggestNextDifficulty } from './gameDifficulty';
import type { CreateSessionInput, GameRecord, GameSessionRecord, GamesRepository } from './games.types';

export interface GameWithSuggestion extends GameRecord {
  suggestedDifficulty: number;
}

const RECENT_SESSIONS_FOR_SUGGESTION = 2;

export class GamesService {
  constructor(private readonly repo: GamesRepository) {}

  async listGames(elderId: string): Promise<GameWithSuggestion[]> {
    const games = await this.repo.listActiveGames();
    return Promise.all(
      games.map(async (game) => {
        const recent = await this.repo.listRecentSessions(elderId, game.id, RECENT_SESSIONS_FOR_SUGGESTION);
        return { ...game, suggestedDifficulty: suggestNextDifficulty(recent) };
      }),
    );
  }

  async recordSession(
    elderId: string,
    gameId: string,
    input: { difficulty: number; score: number; mistakes: number; durationSeconds: number; completed: boolean },
  ): Promise<GameSessionRecord> {
    const game = await this.repo.findGameById(gameId);
    if (!game || !game.isActive) throw AppError.notFound('Game not found');

    const session: CreateSessionInput = { elderId, gameId, ...input };
    return this.repo.createSession(session);
  }

  listSessions(elderId: string, from: Date, to: Date, gameId?: string): Promise<GameSessionRecord[]> {
    return this.repo.listSessionsForElder(elderId, from, to, gameId);
  }
}
