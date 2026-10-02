import type { VoiceInteraction, VoiceIntentType } from '@prisma/client';

export type VoiceInteractionRecord = VoiceInteraction;
export type { VoiceIntentType };

export interface CreateVoiceInteractionInput {
  elderId: string;
  transcript: string;
  language: string;
  intentType: VoiceIntentType;
}

export interface VoiceRepository {
  createInteraction(input: CreateVoiceInteractionInput): Promise<VoiceInteractionRecord>;
  listInteractionsForElder(elderId: string, from: Date, to: Date): Promise<VoiceInteractionRecord[]>;
}

/** The one action type Flutter is allowed to execute from a voice response — nothing else
 * (spec section 26: "never let Flutter execute arbitrary instructions"). TRIGGER_SOS only
 * navigates to the confirm screen; it never fires the emergency directly (section 15). */
export interface VoiceActionPayload {
  type: 'CALL_CONTACT' | 'TRIGGER_SOS';
  contactId?: string;
  contactName?: string;
  phone?: string;
}

/** Shaped after the AI response contract (spec section 26) on purpose: Phase 8's real
 * agent can replace the deterministic matcher behind this without Flutter changing at all. */
export interface VoiceProcessResult {
  type: 'information' | 'action';
  response: string;
  language: string;
  action: VoiceActionPayload | null;
}
