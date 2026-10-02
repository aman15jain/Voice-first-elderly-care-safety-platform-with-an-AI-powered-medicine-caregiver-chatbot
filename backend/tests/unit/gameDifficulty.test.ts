import { describe, expect, it } from 'vitest';
import { suggestNextDifficulty } from '../../src/modules/games/gameDifficulty';

describe('suggestNextDifficulty', () => {
  it('starts at the easiest level with no history', () => {
    expect(suggestNextDifficulty([])).toBe(1);
  });

  it('steps down after an unfinished session', () => {
    expect(suggestNextDifficulty([{ difficulty: 2, mistakes: 0, completed: false }])).toBe(1);
  });

  it('steps down after a session with 3+ mistakes, even if completed', () => {
    expect(suggestNextDifficulty([{ difficulty: 2, mistakes: 3, completed: true }])).toBe(1);
  });

  it('never steps down below the minimum', () => {
    expect(suggestNextDifficulty([{ difficulty: 1, mistakes: 5, completed: false }])).toBe(1);
  });

  it('steps up after two strong sessions in a row at the same difficulty', () => {
    const sessions = [
      { difficulty: 1, mistakes: 0, completed: true },
      { difficulty: 1, mistakes: 1, completed: true },
    ];
    expect(suggestNextDifficulty(sessions)).toBe(2);
  });

  it('never steps up above the maximum', () => {
    const sessions = [
      { difficulty: 3, mistakes: 0, completed: true },
      { difficulty: 3, mistakes: 0, completed: true },
    ];
    expect(suggestNextDifficulty(sessions)).toBe(3);
  });

  it('does not step up if the two strong sessions were at different difficulties', () => {
    const sessions = [
      { difficulty: 2, mistakes: 0, completed: true },
      { difficulty: 1, mistakes: 0, completed: true },
    ];
    expect(suggestNextDifficulty(sessions)).toBe(2);
  });

  it('stays put after one merely-OK session (2 mistakes, completed)', () => {
    expect(suggestNextDifficulty([{ difficulty: 2, mistakes: 2, completed: true }])).toBe(2);
  });
});
