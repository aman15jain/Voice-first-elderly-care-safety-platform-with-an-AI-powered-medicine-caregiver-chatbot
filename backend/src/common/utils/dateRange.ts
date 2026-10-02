export function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export function endOfUtcDay(date: Date): Date {
  return new Date(startOfUtcDay(date).getTime() + 86_400_000 - 1);
}

/** The `days`-day window ending today (inclusive), e.g. daysAgoRange(7) = last 7 days including today. */
export function daysAgoRange(days: number, now = new Date()): { from: Date; to: Date } {
  return { from: new Date(startOfUtcDay(now).getTime() - (days - 1) * 86_400_000), to: endOfUtcDay(now) };
}
