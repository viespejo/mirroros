// Usage: node --test tests/capabilities/desktop/shell/theme-palette.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { parse } = require('../../../../capabilities/desktop/shell/Commons/ThemePalette.js');
const palette = fs.readFileSync('capabilities/visual/theme/default/colors.toml', 'utf8');

test('the shipped palette supplies all shell roles', () => {
  assert.deepEqual(parse(palette), {
    foreground: '#C1C497', background: '#111c18', accent: '#509475',
    muted: '#53685B', red: '#FF5345',
  });
});

test('missing, invalid and duplicate required values reject the entire palette', () => {
  assert.equal(parse(''), null);
  assert.equal(parse(palette.replace('accent = "#509475"', 'accent = "red"')), null);
  assert.equal(parse(palette + '\naccent = "#123456"\n'), null);
  assert.equal(parse(palette.replace('red = "#FF5345"', 'red = "#FF5345ff"')), null);
});

test('shell resolves selection through the product helper and keeps built-in fallback', () => {
  const color = fs.readFileSync('capabilities/desktop/shell/Commons/Color.qml', 'utf8');
  assert.match(color, /\/usr\/share\/mirroros\/themes\/resolve-current/);
  assert.match(color, /code === 0 && lines\[0\] === "\/usr\/share\/mirroros\/themes\/default"/);
  assert.match(color, /root\.palette && root\.palettePath && root\.trustedThemeSurfaces/);
  assert.match(color, /property string palettePath: ""/);
  assert.match(color, /Cannot resolve MirrorOS shell theme; using defaults/);
});

test('jade surfaces match the reference while missing palettes retain previous defaults', () => {
  const color = fs.readFileSync('capabilities/desktop/shell/Commons/Color.qml', 'utf8');
  assert.match(color, /"tooltip\.background-alpha", root\.background, root\.palette \? 0\.97 : 1\.0/);
  assert.match(color, /"menu\.selected-border-alpha", root\.foreground, root\.palette \? 0\.25 : 0\.0/);
});

test('only root-level values are used; comments and unrelated keys are allowed', () => {
  assert.equal(parse(palette.replace('red = "#FF5345"', '[other]\nred = "#FF5345"')), null);
  assert.equal(parse(palette.replace('accent = "#509475"', 'accent = "#509475" # jade')).accent, '#509475');
});
