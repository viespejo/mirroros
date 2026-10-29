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

test('the lock colors match the palette roles (ADR 0021)', () => {
  const palette = new Map();
  for (const match of readFileSync(resolve(theme, 'default/colors.toml'), 'utf8').matchAll(/^([a-z_]+) = "#([0-9a-fA-F]{6})"$/gm))
    palette.set(match[1], match[2].match(/../g).map(pair => parseInt(pair, 16)));
  const lock = new Map();
  for (const line of readFileSync(resolve(theme, 'default/hyprlock.conf'), 'utf8').split('\n')) {
    if (!line || line.startsWith('#')) continue;
    const match = /^\$([a-z_]+) = rgba?\(([0-9., ]+)\)$/.exec(line);
    assert.ok(match, `unexpected lock line: ${line}`);
    lock.set(match[1], match[2].split(',').map(Number));
  }
  assert.deepEqual([...lock.keys()].sort(), ['accent', 'background', 'failure', 'field', 'foreground']);
  assert.deepEqual(lock.get('background'), palette.get('background'));
  assert.deepEqual(lock.get('field'), [...palette.get('background'), 0.8]);
  assert.deepEqual(lock.get('foreground'), palette.get('foreground'));
  assert.deepEqual(lock.get('accent'), palette.get('accent'));
  assert.deepEqual(lock.get('failure'), palette.get('red'));
});

test('the Omarchy MIT notice is retained with the palette', () => {
  const notice = readFileSync(resolve(theme, 'default/LICENSE.omarchy'), 'utf8');
  assert.match(notice, /Copyright \(c\) David Heinemeier Hansson/);
  assert.match(notice, /Permission is hereby granted, free of charge/);
  assert.match(notice, /THE SOFTWARE IS PROVIDED "AS IS"/);
  assert.equal(notice, readFileSync(resolve(root, 'capabilities/desktop/shell/LICENSE.omarchy'), 'utf8'));
});
