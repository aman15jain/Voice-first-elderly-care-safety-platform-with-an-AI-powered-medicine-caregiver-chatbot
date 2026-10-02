export interface ActivityRepository {
  hasAppOpenedEventInRange(elderId: string, from: Date, to: Date): Promise<boolean>;
  createAppOpenedEvent(elderId: string, occurredAt: Date): Promise<void>;
  /** Timestamps of dose responses (taken/skipped) in range — a real medicine interaction. */
  listMedicineInteractionDates(elderId: string, from: Date, to: Date): Promise<Date[]>;
  listGameSessionDates(elderId: string, from: Date, to: Date): Promise<Date[]>;
}
