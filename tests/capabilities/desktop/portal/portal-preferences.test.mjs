import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

// The Hyprland provider's portal preferences must stay consistent with the neutral desktop/portal declarations
// (DEC-012) and with the selected FileChooser outcome of the Story 4.5 evaluation (DEC-003, DEC-006). The share-picker
// defaults follow the laboratory amendment of DEC-012: only the restore token is checked by default.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const read = file => readFileSync(path.join(repo, file), 'utf8');

function preferred(text) {
  const values = new Map();
  let section = '';
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (line === '' || line.startsWith('#')) continue;
    const header = line.match(/^\[(.+)\]$/);
    if (header) { section = header[1]; continue; }
    const separator = line.indexOf('=');
    assert.ok(separator > 0, `not a key: ${line}`);
    assert.equal(section, 'preferred', `key outside [preferred]: ${line}`);
    const key = line.slice(0, separator).trim();
    assert.ok(!values.has(key), `duplicate key: ${key}`);
    values.set(key, line.slice(separator + 1).trim());
  }
  return values;
}

const preferences = preferred(read('capabilities/desktop/compositor/providers/hyprland/hyprland-portals.conf'));
const portalPackages = read('capabilities/desktop/portal/packages').split('\n')
  .filter(line => line.trim() !== '' && !line.startsWith('#')).map(line => line.split(/\s+/)[0]);

test('preferences keep the packaged hyprland;gtk default and declare only the selected interfaces', () => {
  assert.equal(preferences.get('default'), 'hyprland;gtk');
  assert.deepEqual([...preferences.keys()].sort(), ['default', 'org.freedesktop.impl.portal.FileChooser',
    'org.freedesktop.impl.portal.Secret']);
});

test('the Secret backend is the gnome-keyring declared by desktop/portal', () => {
  assert.equal(preferences.get('org.freedesktop.impl.portal.Secret'), 'gnome-keyring');
  assert.ok(portalPackages.includes('gnome-keyring'));
  for (const name of ['xdg-desktop-portal', 'xdg-desktop-portal-gtk']) assert.ok(portalPackages.includes(name), name);
});

test('the FileChooser backend is the selected strata;gtk outcome and the recipe ships its backend', () => {
  assert.equal(preferences.get('org.freedesktop.impl.portal.FileChooser'), 'strata;gtk');
  const recipe = read('capabilities/desktop/files/strata/PKGBUILD');
  assert.match(recipe, /\/usr\/share\/xdg-desktop-portal\/portals\/strata\.portal"/);
  assert.match(recipe, /\/usr\/share\/dbus-1\/services\/org\.freedesktop\.impl\.portal\.desktop\.strata\.service"/);
});

test('the Hyprland backend is provider-owned and no generic portals.conf is delivered', () => {
  const provider = read('capabilities/desktop/compositor/providers/hyprland/packages');
  assert.match(provider, /^xdg-desktop-portal-hyprland extra$/m);
  assert.ok(!portalPackages.includes('xdg-desktop-portal-hyprland'));
  const applies = read('capabilities/desktop/compositor/providers/hyprland/apply') + read('capabilities/desktop/portal/apply');
  assert.match(applies, /\/etc\/xdg\/xdg-desktop-portal\/hyprland-portals\.conf 0644/);
  assert.doesNotMatch(applies, /xdg-desktop-portal\/portals\.conf/);
});

test('the share picker defaults are a user file checking only the restore token, and grim backs Screenshot', () => {
  const provider = 'capabilities/desktop/compositor/providers/hyprland';
  assert.match(read(`${provider}/apply`), /^cfg_user_file "\$STEP_DIR\/xdph\.conf" \.config\/hypr\/xdph\.conf$/m);
  const settings = read(`${provider}/xdph.conf`).split('\n').map(line => line.trim())
    .filter(line => line !== '' && !line.startsWith('#'));
  assert.deepEqual(settings, ['screencopy {', 'allow_token_by_default = true', '}']);
  assert.match(read(`${provider}/packages`), /^grim extra$/m);
});
