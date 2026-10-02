import type { PrismaClient } from '@prisma/client';
import type { CreateVoiceInteractionInput, VoiceInteractionRecord, VoiceRepository } from './voice.types';

export class PrismaVoiceRepository implements VoiceRepository {
  constructor(private readonly prisma: PrismaClient) {}

  createInteraction(input: CreateVoiceInteractionInput): Promise<VoiceInteractionRecord> {
    return this.prisma.voiceInteraction.create({ data: input });
  }

  listInteractionsForElder(elderId: string, from: Date, to: Date): Promise<VoiceInteractionRecord[]> {
    return this.prisma.voiceInteraction.findMany({
      where: { elderId, createdAt: { gte: from, lte: to } },
      orderBy: { createdAt: 'desc' },
    });
  }
}
