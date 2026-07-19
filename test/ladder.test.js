import { describe, it, expect } from 'vitest';
import { generateLadder, computeAssignments, buildPath, ROWS, ROW_H, COLS_MIN, COLS_MAX } from '../game.js';

describe('ladder algorithm', () => {
  for (let n = COLS_MIN; n <= COLS_MAX; n++) {
    it(`computeAssignments is a bijection for n=${n}`, () => {
      for (let trial = 0; trial < 50; trial++) {
        const map = generateLadder(n, ROWS);
        const assignments = computeAssignments(map, n, ROWS);
        const sorted = [...assignments].sort((a, b) => a - b);
        expect(sorted).toEqual([...Array(n).keys()]);
      }
    });

    it(`buildPath.finalCol matches computeAssignments for n=${n}`, () => {
      for (let trial = 0; trial < 20; trial++) {
        const map = generateLadder(n, ROWS);
        const assignments = computeAssignments(map, n, ROWS);
        for (let startCol = 0; startCol < n; startCol++) {
          const { finalCol } = buildPath(map, startCol, ROWS, ROW_H);
          expect(finalCol).toBe(assignments[startCol]);
        }
      }
    });

    it(`no two adjacent columns share a bar on the same row for n=${n}`, () => {
      for (let trial = 0; trial < 50; trial++) {
        const map = generateLadder(n, ROWS);
        for (let row = 0; row < ROWS; row++) {
          for (let col = 0; col < n - 2; col++) {
            expect(map[col][row] && map[col + 1][row]).toBe(false);
          }
        }
      }
    });
  }

  it('handles the minimum ladder size (n=2)', () => {
    const map = generateLadder(2, ROWS);
    const assignments = computeAssignments(map, 2, ROWS);
    expect(assignments.slice().sort()).toEqual([0, 1]);
  });

  it('buildPath produces a segment list ending at the canvas bottom', () => {
    const map = generateLadder(4, ROWS);
    const { segs } = buildPath(map, 0, ROWS, ROW_H);
    const last = segs[segs.length - 1];
    expect(last.y1).toBe(ROWS * ROW_H);
  });
});
