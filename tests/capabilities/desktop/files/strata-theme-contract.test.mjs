// Strata's theme contract, pinned at the recipe revision: Strata v1.2.1, tag commit
// 491e6ba9735e821f9f49910ffd2582076196865c, src/ui/theme/omarchy_state.rs (SHA-256
// 9e59b9988cd2924317b8fe58dbdde83570416e9eac9714af85de3827e77b6580). Strata reads only
// $HOME/.local/state/omarchy/current/theme.name and .../theme/colors.toml and maps the Quattro keys below.
// Whenever capabilities/desktop/files/strata/PKGBUILD changes its tag, rerun this test against the new upstream
// source with MIRROROS_STRATA_SOURCE=<checkout at the new tag>, then update the pins here and in
// capabilities/desktop/files/sources.md.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const files = resolve(root, 'capabilities/desktop/files');
const theme = resolve(root, 'capabilities/visual/theme/default');
const pinnedVersion = '1.2.1';
const readPaths = ['theme.name', 'theme/colors.toml'];
const quattroKeys = ['background', 'dark_background', 'lighter_background', 'foreground', 'accent', 'selection', 'muted'];
const upstream = process.env.MIRROROS_STRATA_SOURCE;

test('the recipe is still the revision this contract was pinned against', () => {
  const recipe = readFileSync(join(files, 'strata/PKGBUILD'), 'utf8');
  assert.match(recipe, new RegExp(`^pkgver=${pinnedVersion.replaceAll('.', '\\.')}$`, 'm'),
    'the Strata tag changed: rerun this contract against the new upstream source and update its pins');
  assert.match(recipe, /491e6ba9735e821f9f49910ffd2582076196865c/);
});

test('the bridge provides exactly the paths Strata reads, resolving to the MirrorOS theme', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-strata-bridge-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home');
  const current = join(home, '.local/state/mirroros/current');
  mkdirSync(current, { recursive: true });
  symlinkSync(theme, join(current, 'theme'));
  // The offer marker already exists, so prepare-strata does not run Strata here.
  mkdirSync(join(home, '.config/strata'), { recursive: true });
  writeFileSync(join(home, '.config/strata/portal-opt-in-v1'), '1\n');
  const result = spawnSync('bash', [join(files, 'prepare-strata'), 'apply', '--default'], {
    encoding: 'utf8', env: { PATH: process.env.PATH, HOME: home },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'changed\n');
  const state = join(home, '.local/state/omarchy/current');
  assert.equal(readlinkSync(join(state, 'theme')), join(current, 'theme'));
  for (const path of readPaths) assert.ok(existsSync(join(state, path)), path);
  assert.equal(realpathSync(join(state, 'theme/colors.toml')), join(theme, 'colors.toml'));
  assert.equal(readFileSync(join(state, 'theme.name'), 'utf8').trim(), 'osaka-jade');
  const again = spawnSync('bash', [join(files, 'prepare-strata'), 'apply', '--default'], {
    encoding: 'utf8', env: { PATH: process.env.PATH, HOME: home },
  });
  assert.equal(again.stdout, 'unchanged\n', again.stderr);
});

test('the MirrorOS palette carries every Quattro key Strata maps as a hex color', () => {
  const colors = readFileSync(join(theme, 'colors.toml'), 'utf8');
  for (const key of quattroKeys) assert.match(colors, new RegExp(`^${key} = "#[0-9A-Fa-f]{6}"$`, 'm'), key);
  assert.match(colors, /^mode = "dark"$/m);
});

test('the upstream source still reads the pinned paths and keys', { skip: !upstream && 'set MIRROROS_STRATA_SOURCE to a Strata checkout' }, () => {
  const source = readFileSync(join(upstream, 'src/ui/theme/omarchy_state.rs'), 'utf8');
  assert.match(source, /home_dir\(\)\.join\("\.local\/state\/omarchy\/current"\)/);
  for (const path of readPaths) assert.match(source, new RegExp(`read\\("${path.replace('/', '\\/').replace('.', '\\.')}"\\)`), path);
  for (const key of quattroKeys) assert.match(source, new RegExp(`get\\("${key}"\\)`), key);
});
