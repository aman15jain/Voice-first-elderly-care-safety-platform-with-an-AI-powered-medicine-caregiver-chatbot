import type { PrismaClient } from '@prisma/client';
import type { CreateSessionInput, GameRecord, GameSessionRecord, GamesRepository, SessionOutcome } from './games.types';

export class PrismaGamesRepository implements GamesRepository {
  constructor(private readonly prisma: PrismaClient) {}

  listActiveGames(): Promise<GameRecord[]> {
    return this.prisma.cognitiveGame.findMany({ where: { isActive: true }, orderBy: { name: 'asc' } });
  }

  findGameById(id: string): Promise<GameRecord | null> {
    return this.prisma.cognitiveGame.findUnique({ where: { id } });
  }

  createSession(input: CreateSessionInput): Promise<GameSessionRecord> {
    return this.prisma.gameSession.create({ data: input });
  }

  listRecentSessions(elderId: string, gameId: string, limit: number): Promise<SessionOutcome[]> {
    return this.prisma.gameSession.findMany({
      where: { elderId, gameId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { difficulty: true, mistakes: true, completed: true },
    });
  }

  listSessionsForElder(elderId: string, from: Date, to: Date, gameId?: string): Promise<GameSessionRecord[]> {
    return this.prisma.gameSession.findMany({
      where: { elderId, createdAt: { gte: from, lte: to }, ...(gameId ? { gameId } : {}) },
      orderBy: { createdAt: 'desc' },
    });
  }
}
