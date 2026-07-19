import { describe, it, expect } from 'vitest';
import { validatePlayerAdd, validateResultAdd, validateStart, COLS_MIN, COLS_MAX } from '../game.js';

describe('validatePlayerAdd / validateResultAdd', () => {
  it('rejects an empty name', () => {
    expect(validatePlayerAdd('', 0)).toEqual({ ok: false });
    expect(validatePlayerAdd('   ', 0)).toEqual({ ok: false });
  });

  it('trims whitespace from an accepted name', () => {
    expect(validatePlayerAdd('  철수  ', 0)).toEqual({ ok: true, name: '철수' });
  });

  it('accepts up to COLS_MAX entries and rejects beyond it', () => {
    expect(validatePlayerAdd('영희', COLS_MAX - 1)).toEqual({ ok: true, name: '영희' });
    expect(validatePlayerAdd('영희', COLS_MAX)).toEqual({
      ok: false,
      error: `최대 ${COLS_MAX}명까지 추가할 수 있어요`,
    });
  });

  it('uses the results-specific max-count message', () => {
    expect(validateResultAdd('꽝', COLS_MAX)).toEqual({
      ok: false,
      error: `최대 ${COLS_MAX}개까지 추가할 수 있어요`,
    });
  });
});

describe('validateStart', () => {
  it('rejects fewer than COLS_MIN players', () => {
    expect(validateStart(COLS_MIN - 1, COLS_MIN - 1)).toEqual({
      ok: false,
      error: '참가자를 최소 2명 이상 추가해주세요',
    });
  });

  it('rejects a player/result count mismatch', () => {
    expect(validateStart(4, 3)).toEqual({
      ok: false,
      error: '결과 개수(3)를 참가자 수(4)와 같게 맞춰주세요',
    });
  });

  it('accepts equal counts at or above the minimum', () => {
    expect(validateStart(COLS_MIN, COLS_MIN)).toEqual({ ok: true });
    expect(validateStart(COLS_MAX, COLS_MAX)).toEqual({ ok: true });
  });
});
