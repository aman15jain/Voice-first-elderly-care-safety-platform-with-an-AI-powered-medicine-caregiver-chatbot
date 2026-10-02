import { daysAgoRange, endOfUtcDay, startOfUtcDay } from '../../common/utils/dateRange';
import type { ActivityService } from '../activity/activity.service';
import type { EmergencyContactRecord, EmergencyRepository } from '../emergency/emergency.types';
import type { MedicinesRepository } from '../medicines/medicines.types';
import type { DoseRepository } from '../reminders/reminders.types';
import { matchIntent } from './voiceLanguagePacks';
import { getResponses } from './voiceResponses';
import type { VoiceProcessResult, VoiceRepository } from './voice.types';

const ACTIVITY_WINDOW_DAYS = 7;

/**
 * Deterministic voice command processing — intent matching and every response below is
 * keyword/rule-based, never an LLM (spec sections 13/15/26). This keeps emergency and
 * medicine-status handling reliable and lets Phase 8's real agent later sit behind the
 * exact same `process()` contract without any Flutter-side change.
 */
export class VoiceService {
  constructor(
    private readonly repo: VoiceRepository,
    private readonly doses: Pick<DoseRepository, 'listForElderInRange'>,
    private readonly medicines: Pick<MedicinesRepository, 'listMedicinesForElder'>,
    private readonly activity: ActivityService,
    private readonly emergency: Pick<EmergencyRepository, 'listContactsForElder'>,
  ) {}

  async process(elderId: string, transcript: string, language = 'en'): Promise<VoiceProcessResult> {
    const { intent, target } = matchIntent(transcript, language);
    const responses = getResponses(language);
    const result = await this.resolveIntent(elderId, intent, target, responses);

    await this.repo.createInteraction({ elderId, transcript, language, intentType: intent });

    return { ...result, language };
  }

  listInteractions(elderId: string, from: Date, to: Date) {
    return this.repo.listInteractionsForElder(elderId, from, to);
  }

  private async resolveIntent(
    elderId: string,
    intent: ReturnType<typeof matchIntent>['intent'],
    target: string | undefined,
    responses: ReturnType<typeof getResponses>,
  ): Promise<Omit<VoiceProcessResult, 'language'>> {
    switch (intent) {
      case 'MEDICINE_STATUS': {
        const now = new Date();
        const doses = await this.doses.listForElderInRange(elderId, startOfUtcDay(now), endOfUtcDay(now));
        const taken = doses.filter((d) => d.status === 'TAKEN').length;
        return { type: 'information', response: responses.medicineStatus(taken, doses.length), action: null };
      }
      case 'MEDICINE_INFO': {
        const medicines = await this.medicines.listMedicinesForElder(elderId, false);
        const response =
          medicines.length === 0
            ? responses.medicineInfoNone()
            : responses.medicineInfoList(medicines.map((m) => ({ name: m.name, dosage: m.dosage })));
        return { type: 'information', response, action: null };
      }
      case 'ACTIVITY_STATUS': {
        const { from, to } = daysAgoRange(ACTIVITY_WINDOW_DAYS);
        const days = await this.activity.dailySummary(elderId, from, to);
        const activeDays = days.filter((d) => d.active).length;
        return { type: 'information', response: responses.activityStatus(activeDays, days.length), action: null };
      }
      case 'CALL_CONTACT': {
        const contacts = await this.emergency.listContactsForElder(elderId);
        const contact = target ? findContactByTarget(contacts, target) : undefined;
        if (!contact) return { type: 'information', response: responses.noContact(target ?? ''), action: null };
        return {
          type: 'action',
          response: responses.callingContact(contact.name),
          action: { type: 'CALL_CONTACT', contactId: contact.id, contactName: contact.name, phone: contact.phone },
        };
      }
      case 'EMERGENCY_SOS':
        // Never auto-triggers the real SOS — only navigates the elder to the existing
        // confirmation screen so a human still explicitly confirms (spec sections 13/15).
        return { type: 'action', response: responses.sosConfirm(), action: { type: 'TRIGGER_SOS' } };
      case 'UNKNOWN':
      default:
        return { type: 'information', response: responses.unknown(), action: null };
    }
  }
}

/** Matches first by relationship (e.g. "son"), then by name substring, both case-insensitive. */
export function findContactByTarget(contacts: EmergencyContactRecord[], target: string): EmergencyContactRecord | undefined {
  const needle = target.trim().toLowerCase();
  if (!needle) return undefined;
  return (
    contacts.find((c) => c.relationship?.toLowerCase().includes(needle)) ??
    contacts.find((c) => c.name.toLowerCase().includes(needle))
  );
}
