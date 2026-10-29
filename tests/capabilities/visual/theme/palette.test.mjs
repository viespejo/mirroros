import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const theme = resolve(root, 'capabilities/visual/theme');

test('the reviewed palette has unique valid values and the approved jade roles', () => {
  const text = readFileSync(resolve(theme, 'default/colors.toml'), 'utf8');
  const values = new Map();
  for (const line of text.split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    const match = /^([a-z_]+) = "([^\"]+)"$/.exec(line);
    assert.ok(match, `unexpected palette line: ${line}`);
    assert.equal(values.has(match[1]), false, `duplicate key: ${match[1]}`);
    assert.ok(match[1] === 'mode' ? match[2] === 'dark' : /^#[0-9a-fA-F]{6}$/.test(match[2]));
    values.set(match[1], match[2]);
  }
  assert.equal(values.get('background'), '#111c18');
  assert.equal(values.get('foreground'), '#C1C497');
  assert.equal(values.get('accent'), '#509475');
  assert.equal(values.get('muted'), '#53685B');
  assert.equal(values.get('red'), '#FF5345');
});

test('the Omarchy MIT notice is retained with the palette', () => {
  const notice = readFileSync(resolve(theme, 'default/LICENSE.omarchy'), 'utf8');
  assert.match(notice, /Copyright \(c\) David Heinemeier Hansson/);
  assert.match(notice, /Permission is hereby granted, free of charge/);
  assert.match(notice, /THE SOFTWARE IS PROVIDED "AS IS"/);
  assert.equal(notice, readFileSync(resolve(root, 'capabilities/desktop/shell/LICENSE.omarchy'), 'utf8'));
});
