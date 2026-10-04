import { describe, expect, it } from 'vitest';
import { isMedicineKnowledgeQuestion, matchIntent } from '../../src/modules/voice/voiceLanguagePacks';

describe('matchIntent (English)', () => {
  it('matches emergency phrases before the generic call pattern', () => {
    expect(matchIntent('help, help!', 'en').intent).toBe('EMERGENCY_SOS');
    expect(matchIntent('call for help', 'en').intent).toBe('EMERGENCY_SOS');
    expect(matchIntent("I've fallen", 'en').intent).toBe('EMERGENCY_SOS');
  });

  it('matches medicine status vs medicine info', () => {
    expect(matchIntent('did I take my medicine today', 'en').intent).toBe('MEDICINE_STATUS');
    expect(matchIntent('what medicine do I take', 'en').intent).toBe('MEDICINE_INFO');
  });

  it('matches activity status', () => {
    expect(matchIntent('how am I doing this week', 'en').intent).toBe('ACTIVITY_STATUS');
  });

  it('captures the target from call commands', () => {
    expect(matchIntent('call my son', 'en')).toEqual({ intent: 'CALL_CONTACT', target: 'son' });
    expect(matchIntent('call Priya', 'en')).toEqual({ intent: 'CALL_CONTACT', target: 'Priya' });
  });

  it('falls back to UNKNOWN for unrecognized transcripts', () => {
    expect(matchIntent('what is the weather today', 'en').intent).toBe('UNKNOWN');
  });
});

describe('matchIntent (Hindi, with English fallback)', () => {
  it('matches the minimal Hindi patterns directly', () => {
    expect(matchIntent('मदद करो', 'hi').intent).toBe('EMERGENCY_SOS');
    expect(matchIntent('क्या मैंने दवा ली', 'hi').intent).toBe('MEDICINE_STATUS');
  });

  it('falls back to English patterns for intents the Hindi pack does not cover', () => {
    expect(matchIntent('call my son', 'hi')).toEqual({ intent: 'CALL_CONTACT', target: 'son' });
  });

  it('falls back to English patterns entirely for an unknown language code', () => {
    expect(matchIntent('help', 'fr').intent).toBe('EMERGENCY_SOS');
  });
});

describe('isMedicineKnowledgeQuestion', () => {
  it('recognizes general medicine-information phrasing', () => {
    for (const q of ['What is metformin used for?', 'side effects of lisinopril', 'Tell me about Glucophage', 'Can metformin cause stomach problems?']) {
      expect(isMedicineKnowledgeQuestion(q)).toBe(true);
    }
  });

  it('does not match plain commands or chatter', () => {
    for (const q of ['good morning', 'call my son', 'did I take my medicine', 'thank you']) {
      expect(isMedicineKnowledgeQuestion(q)).toBe(false);
    }
  });
});
