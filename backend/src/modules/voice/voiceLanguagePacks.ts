import type { VoiceIntentType } from './voice.types';

export interface IntentMatch {
  intent: VoiceIntentType;
  /** Captured contact name/relationship for CALL_CONTACT, e.g. "son" or "Priya". */
  target?: string;
}

interface IntentPattern {
  intent: VoiceIntentType;
  pattern: RegExp;
  /** Regex capture group index holding the CALL_CONTACT target, if any. */
  targetGroup?: number;
}

/**
 * Order matters: more specific intents must be checked before the generic ones they could
 * otherwise be swallowed by (e.g. "call for help" must hit EMERGENCY_SOS before the broad
 * CALL_CONTACT "call ..." pattern gets a chance at it).
 */
const EN_PATTERNS: IntentPattern[] = [
  { intent: 'EMERGENCY_SOS', pattern: /\b(help|emergency|sos|call for help|i've fallen|i need help|fallen down)\b/i },
  { intent: 'MEDICINE_STATUS', pattern: /\b(did i take|have i taken|took my (medicine|medication|pills?|tablets?))\b/i },
  { intent: 'MEDICINE_INFO', pattern: /\b(what (medicine|medication|pills?|tablets?)|which (medicine|medication|pills?))\b/i },
  { intent: 'ACTIVITY_STATUS', pattern: /\b(how (am i|have i been) doing|my activity|activity (today|this week)|how active)\b/i },
  { intent: 'CALL_CONTACT', pattern: /\bcall (?:my )?(.+)$/i, targetGroup: 1 },
];

const HI_PATTERNS: IntentPattern[] = [
  { intent: 'EMERGENCY_SOS', pattern: /(मदद|बचाओ|आपातकाल)/ },
  { intent: 'MEDICINE_STATUS', pattern: /(दवा.*ली|दवाई.*ली)/ },
];

const PATTERNS_BY_LANGUAGE: Record<string, IntentPattern[]> = {
  en: EN_PATTERNS,
  hi: HI_PATTERNS,
};

/**
 * Deterministic keyword/pattern matching — not an LLM. See docs/architecture.md: Phase 8's
 * agent can swap this out later without the response contract (VoiceProcessResult) changing.
 * Unknown languages, and intents a language pack doesn't cover, fall back to English patterns
 * so the voice layer degrades gracefully instead of failing outright.
 */
export function matchIntent(transcript: string, language: string): IntentMatch {
  const languagePatterns = PATTERNS_BY_LANGUAGE[language] ?? EN_PATTERNS;
  const patterns = language === 'en' || !PATTERNS_BY_LANGUAGE[language]
    ? EN_PATTERNS
    : [...languagePatterns, ...EN_PATTERNS];

  for (const { intent, pattern, targetGroup } of patterns) {
    const match = transcript.match(pattern);
    if (match) {
      const target = targetGroup !== undefined ? match[targetGroup]?.trim() : undefined;
      return target ? { intent, target } : { intent };
    }
  }
  return { intent: 'UNKNOWN' };
}

/**
 * Phrases that mark an utterance as a general medicine-information question ("what is metformin
 * used for", "side effects of ...", "tell me about ..."). Deliberately a subset of the keywords the
 * Python medicine agent itself requires (agentic-ai `_GENERAL_INFO_KEYWORDS`), so anything routed
 * there is recognized as a general question again on the other side.
 *
 * This is only ever consulted AFTER `matchIntent` returned UNKNOWN: emergency, medicine-status,
 * call and every other deterministic command have already been handled, so a phrase here can never
 * pull an action command away from the rules. Medicine names are not matched in Node — the
 * knowledge base (incl. aliases like Glucophage) is Python's job.
 */
const MEDICINE_QUESTION_PATTERN =
  /\b(what is|what's|what does|side effects?|used for|purpose of|why do i take|tell me about|cause)\b/i;

export function isMedicineKnowledgeQuestion(transcript: string): boolean {
  return MEDICINE_QUESTION_PATTERN.test(transcript);
}
