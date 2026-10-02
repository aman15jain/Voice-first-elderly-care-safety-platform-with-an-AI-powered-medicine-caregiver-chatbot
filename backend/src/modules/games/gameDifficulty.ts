import type { SessionOutcome } from './games.types';

export const MIN_DIFFICULTY = 1;
export const MAX_DIFFICULTY = 3;

/**
 * Pure and deterministic — never an LLM judgment (spec section 17). `recentSessions` must
 * be newest-first, as `GamesRepository.listRecentSessions` returns them.
 *
 * - No sessions yet -> start at the easiest level.
 * - Last session unfinished, or 3+ mistakes -> step down (never below MIN).
 * - Last two sessions both completed at the same difficulty with <=1 mistake each -> step up
 *   (never above MAX).
 * - Otherwise -> stay at the difficulty last played.
 */
export function suggestNextDifficulty(recentSessions: SessionOutcome[]): number {
  const [last, secondLast] = recentSessions;
  if (!last) return MIN_DIFFICULTY;

  if (!last.completed || last.mistakes >= 3) {
    return Math.max(MIN_DIFFICULTY, last.difficulty - 1);
  }

  const bothStrong = last.mistakes <= 1 && secondLast?.completed && secondLast.mistakes <= 1 && secondLast.difficulty === last.difficulty;
  if (bothStrong) {
    return Math.min(MAX_DIFFICULTY, last.difficulty + 1);
  }

  return last.difficulty;
}
