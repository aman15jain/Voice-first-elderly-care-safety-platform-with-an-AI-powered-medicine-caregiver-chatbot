import { randomUUID } from 'node:crypto';
import type { CreateVoiceInteractionInput, VoiceInteractionRecord, VoiceRepository } from '../../src/modules/voice/voice.types';

export class InMemoryVoiceRepository implements VoiceRepository {
  readonly interactions = new Map<string, VoiceInteractionRecord>();

  async createInteraction(input: CreateVoiceInteractionInput): Promise<VoiceInteractionRecord> {
    const interaction: VoiceInteractionRecord = {
      id: randomUUID(),
      elderId: input.elderId,
      transcript: input.transcript,
      language: input.language,
      intentType: input.intentType,
      createdAt: new Date(),
    };
    this.interactions.set(interaction.id, interaction);
    return interaction;
  }

  async listInteractionsForElder(elderId: string, from: Date, to: Date): Promise<VoiceInteractionRecord[]> {
    return [...this.interactions.values()]
      .filter((i) => i.elderId === elderId && i.createdAt >= from && i.createdAt <= to)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }
}
