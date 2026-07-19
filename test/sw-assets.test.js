import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it, expect } from 'vitest';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const swSource = fs.readFileSync(path.join(ROOT, 'sw.js'), 'utf8');

function extractAssets(source) {
  const match = source.match(/const ASSETS = \[([\s\S]*?)\];/);
  if (!match) throw new Error('Could not find ASSETS array in sw.js');
  return [...match[1].matchAll(/'([^']+)'/g)].map(m => m[1]);
}

describe('service worker precache list', () => {
  const assets = extractAssets(swSource);

  it('is non-empty', () => {
    expect(assets.length).toBeGreaterThan(0);
  });

  it.each(assets)('references a file that exists on disk: %s', asset => {
    if (asset === './') {
      expect(fs.existsSync(path.join(ROOT, 'index.html'))).toBe(true);
      return;
    }
    const relative = asset.replace(/^\.\//, '');
    expect(fs.existsSync(path.join(ROOT, relative))).toBe(true);
  });
});
