import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const script = resolve('capabilities/visual/theme/resolve-current');
const target = '/usr/share/mirroros/themes/default';

test('selection uses only the trusted reviewed default and warns on invalid links', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-resolve-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const anchor = join(root, 'root');
  const state = join(root, 'state');
  const theme = join(anchor, target);
  const current = join(state, 'mirroros/current');
  mkdirSync(theme, { recursive: true });
  mkdirSync(current, { recursive: true });
  writeFileSync(join(theme, 'colors.toml'), 'palette');
  writeFileSync(join(theme, 'shell.toml'), 'surfaces');
  const run = () => spawnSync('bash', [script, anchor, state, String(process.getuid())], { encoding: 'utf8' });
  let result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${target}\nshell.toml\n`);
  assert.match(result.stderr, /missing/);
  symlinkSync('/unknown/theme', join(current, 'theme'));
  result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${target}\nshell.toml\n`);
  assert.match(result.stderr, /Invalid/);
  rmSync(join(current, 'theme'));
  symlinkSync(target, join(current, 'theme'));
  result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  chmodSync(join(theme, 'shell.toml'), 0o666);
  result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${target}\n`);
  assert.match(result.stderr, /surface settings.*untrusted/);
  rmSync(join(theme, 'shell.toml'));
  symlinkSync('colors.toml', join(theme, 'shell.toml'));
  result = run();
  assert.equal(result.stdout, `${target}\n`);
  assert.match(result.stderr, /surface settings.*untrusted/);
  rmSync(join(theme, 'shell.toml'));
  result = run();
  assert.equal(result.stdout, `${target}\n`);
  assert.match(result.stderr, /surface settings.*unavailable/);
  chmodSync(theme, 0o777);
  result = run();
  assert.equal(result.status, 4);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /untrusted/i);
});

test('Hyprland resolution checks the reviewed file independently of the selection link', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-resolve-hypr-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const anchor = join(root, 'root');
  const state = join(root, 'state');
  const theme = join(anchor, target);
  const current = join(state, 'mirroros/current');
  mkdirSync(theme, { recursive: true });
  mkdirSync(current, { recursive: true });
  writeFileSync(join(theme, 'colors.toml'), 'palette');
  writeFileSync(join(theme, 'hyprland.lua'), 'return {}\n');
  symlinkSync('/unknown/theme', join(current, 'theme'));
  const run = () => spawnSync('bash', [script, anchor, state, String(process.getuid()), 'hyprland'], { encoding: 'utf8' });
  let result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${target}/hyprland.lua\n`);
  assert.match(result.stderr, /Invalid or missing theme selection/);
  rmSync(join(current, 'theme'));
  symlinkSync(target, join(current, 'theme'));
  result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  assert.equal(spawnSync('bash', [script, anchor, state, String(process.getuid()), 'unknown'], { encoding: 'utf8' }).status, 6);
  chmodSync(theme, 0o777);
  assert.equal(run().status, 4);
  chmodSync(theme, 0o755);
  chmodSync(join(theme, 'hyprland.lua'), 0o666);
  result = run();
  assert.equal(result.status, 4);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /Hyprland theme.*untrusted/);
  rmSync(join(theme, 'hyprland.lua'));
  symlinkSync('colors.toml', join(theme, 'hyprland.lua'));
  result = run();
  assert.equal(result.status, 4);
  assert.equal(result.stdout, '');
  rmSync(join(theme, 'hyprland.lua'));
  assert.equal(run().status, 4);
});

test('selection follows the link only to a trusted published theme and otherwise falls back to the default', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-resolve-select-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const anchor = join(root, 'root');
  const state = join(root, 'state');
  const themes = '/usr/share/mirroros/themes';
  const selected = `${themes}/osaka-jade`;
  const current = join(state, 'mirroros/current');
  for (const theme of [target, selected]) {
    mkdirSync(join(anchor, theme), { recursive: true });
    for (const file of ['colors.toml', 'shell.toml', 'gtk-4.0.css']) writeFileSync(join(anchor, theme, file), file);
  }
  writeFileSync(join(anchor, target, 'hyprland.lua'), 'return {}\n');
  writeFileSync(join(anchor, themes, 'resolve-current'), 'helper');
  mkdirSync(current, { recursive: true });
  const select = (value) => {
    rmSync(join(current, 'theme'), { force: true });
    symlinkSync(value, join(current, 'theme'));
  };
  const run = (consumer) => spawnSync('bash', [script, anchor, state, String(process.getuid()), ...(consumer ? [consumer] : [])],
    { encoding: 'utf8' });

  select(selected);
  let result = run();
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${selected}\nshell.toml\n`);
  assert.equal(result.stderr, '');
  result = run('gtk4');
  assert.equal(result.stdout, `${selected}/gtk-4.0.css\n`);
  assert.equal(result.stderr, '');

  // A published theme lacking the consumer's file is not selected for that consumer.
  result = run('hyprland');
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${target}/hyprland.lua\n`);
  assert.match(result.stderr, /selected theme osaka-jade is unavailable or untrusted; using the default theme/);
  writeFileSync(join(anchor, selected, 'hyprland.lua'), 'return {}\n');
  assert.equal(run('hyprland').stdout, `${selected}/hyprland.lua\n`);

  for (const link of ['osaka-jade', `${selected}/`, `${themes}/../themes/osaka-jade`, `${themes}/Osaka`, '/tmp/osaka-jade']) {
    select(link);
    result = run();
    assert.equal(result.stdout, `${target}\nshell.toml\n`, link);
    assert.match(result.stderr, /Invalid or missing theme selection/, link);
  }
  for (const link of [`${themes}/resolve-current`, `${themes}/missing`]) {
    select(link);
    result = run();
    assert.equal(result.stdout, `${target}\nshell.toml\n`, link);
    assert.match(result.stderr, /is unavailable or untrusted; using the default theme/, link);
  }

  select(selected);
  chmodSync(join(anchor, selected, 'colors.toml'), 0o666);
  result = run();
  assert.equal(result.stdout, `${target}\nshell.toml\n`);
  assert.match(result.stderr, /selected theme osaka-jade is unavailable or untrusted/);
  chmodSync(join(anchor, selected, 'colors.toml'), 0o644);
  rmSync(join(anchor, selected), { recursive: true });
  symlinkSync(join(anchor, target), join(anchor, selected));
  result = run();
  assert.equal(result.stdout, `${target}\nshell.toml\n`);
  assert.match(result.stderr, /selected theme osaka-jade is unavailable or untrusted/);
});
