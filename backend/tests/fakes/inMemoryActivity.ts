import type { ActivityRepository } from '../../src/modules/activity/activity.types';

export class InMemoryActivityRepository implements ActivityRepository {
  readonly appOpenedEvents: { elderId: string; occurredAt: Date }[] = [];
  medicineInteractionDates: Date[] = [];
  gameSessionDates: Date[] = [];

  async hasAppOpenedEventInRange(elderId: string, from: Date, to: Date): Promise<boolean> {
    return this.appOpenedEvents.some((e) => e.elderId === elderId && e.occurredAt >= from && e.occurredAt <= to);
  }

  async createAppOpenedEvent(elderId: string, occurredAt: Date): Promise<void> {
    this.appOpenedEvents.push({ elderId, occurredAt });
  }

  async listMedicineInteractionDates(_elderId: string, from: Date, to: Date): Promise<Date[]> {
    return this.medicineInteractionDates.filter((d) => d >= from && d <= to);
  }

  async listGameSessionDates(_elderId: string, from: Date, to: Date): Promise<Date[]> {
    return this.gameSessionDates.filter((d) => d >= from && d <= to);
  }
}
