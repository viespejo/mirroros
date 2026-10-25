#!/usr/bin/env node
// Synthetic generator contract checks; no upstream checkout or Python required.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-i18n-test-'));
try {
  const shell = path.join(tmp, 'shell');
  const upstream = path.join(tmp, 'upstream');
  fs.mkdirSync(path.join(shell, 'Commons'), { recursive: true });
  fs.mkdirSync(path.join(shell, 'nested'));
  fs.mkdirSync(path.join(upstream, 'default/i18n/en'), { recursive: true });
  const script = path.join(here, 'i18n-subset.mjs');
  fs.writeFileSync(path.join(shell, 'Fixture.qml'), 'I18n.t("test.z")\nI18n.tn("test.count", 2)\n');
  fs.writeFileSync(path.join(shell, 'nested/Fixture.qml'), 'I18n.t("test.z")\nI18n.t( "test.a")\n');
  const source = path.join(upstream, 'default/i18n/en/shell.json');
  const catalog = path.join(shell, 'Commons/i18n-en.json');
  const english = { 'test.z': 'Unicode “text”', 'test.count': { one: '%1 item', other: '%1 items' },
    'test.a': 'First', unused: 'Excluded' };
  fs.writeFileSync(source, JSON.stringify(english));
  const run = (args, expected, message) => {
    const result = spawnSync(process.execPath, [script, ...args],
      { encoding: 'utf8', env: { ...process.env, MIRROROS_SHELL_DIR: shell } });
    assert.equal(result.status, expected, result.stderr);
    if (message) assert.ok(result.stderr.includes(message), result.stderr);
  };
  run([upstream], 0);
  const text = fs.readFileSync(catalog, 'utf8');
  assert.equal(text, JSON.stringify({ 'test.a': english['test.a'], 'test.count': english['test.count'],
    'test.z': english['test.z'] }, null, 2) + '\n');
  run([upstream, '--check'], 0);
  run(['--keys-only'], 0);
  fs.writeFileSync(catalog, '{}\n');
  run([upstream, '--check'], 1, 'out of date');
  assert.equal(fs.readFileSync(catalog, 'utf8'), '{}\n');
  run(['--keys-only'], 1, 'missing key: test.a');
  delete english['test.a'];
  fs.writeFileSync(source, JSON.stringify(english));
  run([upstream], 1, 'key not in Omarchy catalog: test.a');
  assert.equal(fs.readFileSync(catalog, 'utf8'), '{}\n');
  run([], 2, 'Usage:');
  run([upstream, '--unknown'], 2, 'Usage:');
  console.log('PASS I18n generator: recursive keys, sorting/deduplication, unchanged Unicode/plurals, check/no-write, missing keys and invalid arguments');
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
