export interface MedicineInfoItem {
  name: string;
  dosage: string;
}

export interface ResponseBuilders {
  medicineStatus(taken: number, total: number): string;
  medicineInfoList(items: MedicineInfoItem[]): string;
  medicineInfoNone(): string;
  activityStatus(activeDays: number, totalDays: number): string;
  callingContact(name: string): string;
  noContact(target: string): string;
  sosConfirm(): string;
  unknown(): string;
  medicineLookupUnavailable(): string;
}

const EN: ResponseBuilders = {
  medicineStatus: (taken, total) =>
    total === 0
      ? "You don't have any medicines scheduled for today."
      : taken >= total
        ? `Yes, you've taken all ${total} of your medicines today. Well done!`
        : `You've taken ${taken} out of ${total} medicines today. ${total - taken} still left.`,
  medicineInfoList: (items) =>
    items.length === 0
      ? "You don't have any medicines set up right now."
      : `You're currently taking: ${items.map((item) => `${item.name} (${item.dosage})`).join(', ')}.`,
  medicineInfoNone: () => "You don't have any medicines set up right now.",
  activityStatus: (activeDays, totalDays) =>
    `You've been active ${activeDays} out of the last ${totalDays} days.`,
  callingContact: (name) => `Calling ${name} now.`,
  noContact: (target) => `I couldn't find a contact matching "${target}". You can add one from the Family screen.`,
  sosConfirm: () => "I'm opening the emergency screen so you can confirm you need help.",
  unknown: () => "I'm sorry, I didn't understand that. You can try asking about your medicines, your activity, or say 'call' followed by a contact's name.",
  medicineLookupUnavailable: () => "I'm unable to look up that medicine information right now. Please try again.",
};

const HI: Partial<ResponseBuilders> = {
  medicineStatus: (taken, total) =>
    total === 0
      ? 'आज आपके लिए कोई दवा निर्धारित नहीं है।'
      : taken >= total
        ? `हाँ, आपने आज अपनी सभी ${total} दवाइयाँ ले ली हैं।`
        : `आपने आज ${total} में से ${taken} दवाइयाँ ली हैं।`,
  sosConfirm: () => 'मैं आपातकालीन स्क्रीन खोल रहा हूँ ताकि आप पुष्टि कर सकें।',
};

const RESPONSES_BY_LANGUAGE: Record<string, Partial<ResponseBuilders>> = {
  en: EN,
  hi: HI,
};

/** Merges a language's partial response set over the full English set, so any response a
 * language pack hasn't translated yet still falls back to English rather than erroring. */
export function getResponses(language: string): ResponseBuilders {
  const overrides = RESPONSES_BY_LANGUAGE[language];
  return overrides ? { ...EN, ...overrides } : EN;
}
