// Run with Foot installed; all configuration files are temporary.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const foot = '/usr/bin/foot';

test('Foot accepts multiple included files and rejects a missing theme target', { skip: !existsSync(foot) }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-foot-include-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const defaults = join(dir, 'defaults.ini');
  const theme = join(dir, 'theme.ini');
  const current = join(dir, 'current.ini');
  const config = join(dir, 'foot.ini');
  const recovery = join(dir, 'recovery.ini');
  writeFileSync(recovery, '[main]\nfont=monospace:size=9\npad=14x14 center\n[colors-dark]\nbackground=111c18\nforeground=c1c497\n');
  writeFileSync(defaults, 'font=monospace:size=11\npad=2x2\n');
  writeFileSync(theme, '[colors-dark]\nbackground=111c18\nforeground=c1c497\n');
  symlinkSync(theme, current);
  writeFileSync(config, `include=${defaults}\ninclude=${current}\nfont=monospace:size=9\npad=14x14 center\n`);
  const check = () => spawnSync(foot, ['--check-config', '--config', config], { encoding: 'utf8' });
  let result = check();
  assert.equal(result.status, 0, result.stderr);
  rmSync(theme);
  result = check();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /failed to open/);
  const recoveryCheck = spawnSync(foot, ['--check-config', '--config', recovery], { encoding: 'utf8' });
  assert.equal(recoveryCheck.status, 0, recoveryCheck.stderr);
  writeFileSync(theme, '[colors-dark]\nbackground=111c18\nforeground=c1c497\n');
  result = check();
  assert.equal(result.status, 0, result.stderr);

  const personal = readFileSync(config, 'utf8');
  rmSync(defaults);
  result = check();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /failed to open/);
  writeFileSync(defaults, 'font=monospace:size=11\npad=2x2\n');
  assert.equal(check().status, 0);

  writeFileSync(theme, '[colors-dark]\nbackground=not-a-color\n');
  result = check();
  assert.notEqual(result.status, 0);
  writeFileSync(theme, '[colors-dark]\nbackground=111c18\nforeground=c1c497\n');
  assert.equal(check().status, 0);
  assert.equal(readFileSync(config, 'utf8'), personal);
});

test('the personal template loads the default-state theme and supports manual recovery', { skip: !existsSync(foot) }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-foot-template-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home');
  const current = join(home, '.local/state/mirroros/current');
  const theme = join(dir, 'theme');
  mkdirSync(current, { recursive: true });
  mkdirSync(theme);
  writeFileSync(join(theme, 'foot.ini'), readFileSync(resolve('capabilities/visual/theme/default/foot.ini')));
  symlinkSync(theme, join(current, 'theme'));
  const defaults = join(dir, 'defaults.ini');
  writeFileSync(defaults, readFileSync(resolve('capabilities/desktop/terminal/defaults.ini')));
  const config = join(dir, 'personal.ini');
  const template = readFileSync(resolve('capabilities/desktop/terminal/personal-foot.ini'), 'utf8');
  writeFileSync(config, template.replace('/usr/share/mirroros/foot/defaults.ini', defaults));
  const check = path => spawnSync(foot, ['--check-config', '--config', path], { encoding: 'utf8', env: { ...process.env, HOME: home } });
  let result = check(config);
  assert.equal(result.status, 0, result.stderr);
  rmSync(join(current, 'theme'));
  result = check(config);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /failed to open/);
  const recovery = join(dir, 'recovery.ini');
  writeFileSync(recovery, readFileSync(resolve('capabilities/desktop/terminal/foot.ini')));
  result = check(recovery);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(config, 'utf8'), template.replace('/usr/share/mirroros/foot/defaults.ini', defaults));
});

test('the shipped standalone Foot configuration validates with temporary device overrides', { skip: !existsSync(foot) }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-foot-recovery-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const recovery = join(dir, 'recovery.ini');
  const shipped = readFileSync(resolve('capabilities/desktop/terminal/foot.ini'), 'utf8');
  assert.doesNotMatch(shipped, /^\s*include\s*=/m);
  writeFileSync(recovery, shipped);
  const result = spawnSync(foot, ['--check-config', '--config', recovery,
    '--override', 'main.font=JetBrainsMono Nerd Font Mono:size=9',
    '--override', 'main.pad=14x14 center'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(recovery, 'utf8'), shipped);
});
