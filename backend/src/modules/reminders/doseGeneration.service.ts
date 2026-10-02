import { buildDoseInputs } from './doseSchedule';
import type { DoseGenerator, DoseRepository, ScheduleForGeneration } from './reminders.types';

export class DoseGenerationService implements DoseGenerator {
  constructor(
    private readonly repo: DoseRepository,
    private readonly defaultDaysAhead: number,
  ) {}

  generateForSchedule(schedule: ScheduleForGeneration, daysAhead = this.defaultDaysAhead, now = new Date()): Promise<number> {
    const inputs = buildDoseInputs(schedule, daysAhead, now);
    return this.repo.createManySkipDuplicates(inputs);
  }

  /** Run periodically (see jobs/reminderSweep.ts) so doses exist a few days ahead of when they're due. */
  async generateForAllActiveSchedules(now = new Date()): Promise<number> {
    const schedules = await this.repo.listActiveSchedules();
    let created = 0;
    for (const schedule of schedules) {
      created += await this.generateForSchedule(schedule, this.defaultDaysAhead, now);
    }
    return created;
  }
}
