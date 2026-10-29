import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { parse, resolve } = require('../../../../capabilities/desktop/shell/Commons/SurfacePalette.js');

test('reads only supported colors, aliases and finite alpha values', () => {
  const result = parse(`
[bar]
background = "#111c18" # jade
background-alpha = 0.97 # alpha
text = "foreground"
[popups]
border = "hyprland.active-border"
[font]
base-size = 12
`);
  assert.deepEqual({ ...result.values }, {
    'bar.background': '#111c18', 'bar.background-alpha': '0.97',
    'bar.text': 'foreground', 'popups.border': 'hyprland.active-border',
  });
  assert.deepEqual(result.invalid, []);
});

test('invalid and duplicate settings are omitted without discarding valid neighbors', () => {
  const result = parse(`
[menu]
text = "#123456"
background = "red"
background = "#111111"
scrim-alpha = 1.1
border-alpha = NaN
selected-text = "#12345"
selected-background-alpha = .25
`);
  assert.deepEqual({ ...result.values }, {
    'menu.text': '#123456', 'menu.selected-background-alpha': '.25',
  });
  assert.deepEqual(result.invalid, [
    'menu.background', 'menu.scrim-alpha', 'menu.border-alpha', 'menu.selected-text',
  ]);
});

test('resolves aliases and applies personal settings over theme settings', () => {
  const theme = '[hyprland]\nactive-border = "accent"\n[popups]\nborder = "hyprland.active-border"\ntext = "foreground"\nbackground-alpha = 0.8\n';
  const user = '[popups]\ntext = "#abcdef"\nbackground-alpha = 2\n';
  const result = resolve(theme, user, { accent: '#509475', foreground: '#C1C497' });
  assert.deepEqual({ ...result.values }, {
    'hyprland.active-border': '#509475', 'popups.border': '#509475',
    'popups.text': '#abcdef', 'popups.background-alpha': '0.8',
  });
  assert.deepEqual(result.invalid, ['user:popups.background-alpha']);
});

test('unknown aliases and cycles fall back by setting without leaking raw tokens', () => {
  const theme = '[menu]\ntext = "#111111"\nborder = "#222222"\n';
  const user = '[menu]\ntext = "menu.border"\nborder = "menu.text"\nselected-text = "unknown"\n';
  const result = resolve(theme, user, {});
  assert.equal(result.values['menu.text'], '#111111');
  assert.equal(result.values['menu.border'], '#222222');
  assert.equal(result.values['menu.selected-text'], undefined);
  assert.ok(result.invalid.includes('user:menu.text'));
  assert.ok(result.invalid.includes('user:menu.border'));
  assert.ok(result.invalid.includes('user:menu.selected-text'));
});

test('unsupported sections and malformed headers do not leak into supported sections', () => {
  const result = parse('[bar]\ntext = "#123456"\n[invalid\nactive = "#ffffff"\n[unknown]\ntext = "#ffffff"\n');
  assert.deepEqual({ ...result.values }, { 'bar.text': '#123456' });
});
