// Usage: node --test tests/capabilities/desktop/terminal/palette.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const paletteText = fs.readFileSync('capabilities/visual/theme/default/colors.toml', 'utf8');
const footText = fs.readFileSync('capabilities/desktop/terminal/foot.ini', 'utf8');
const palette = Object.fromEntries([...paletteText.matchAll(/^([a-z_]+) = "#([0-9a-fA-F]{6})"$/gm)]
  .map(([, key, value]) => [key, value.toLowerCase()]));
const foot = Object.fromEntries([...footText.matchAll(/^([a-z0-9-]+)=([0-9a-f]{6})$/gm)]
  .map(([, key, value]) => [key, value]));

test('layered defaults and theme match the standalone recovery configuration', () => {
  const defaults = fs.readFileSync('capabilities/desktop/terminal/defaults.ini', 'utf8');
  const theme = fs.readFileSync('capabilities/visual/theme/default/foot.ini', 'utf8');
  const sections = text => {
    const result = {};
    let section;
    for (const line of text.split('\n')) {
      const match = line.match(/^\[([^\]]+)\]$/);
      if (match) { section = match[1]; result[section] = []; }
      else if (section && line && !line.startsWith('#')) result[section].push(line);
    }
    return result;
  };
  const recovery = sections(footText);
  assert.deepEqual(sections(theme), { 'colors-dark': recovery['colors-dark'] });
  delete recovery['colors-dark'];
  assert.deepEqual(sections(defaults), recovery);
});

test('Foot uses the reviewed font and padding defaults', () => {
  assert.match(footText, /^font=JetBrainsMono Nerd Font Mono:size=9$/m);
  assert.match(footText, /^pad=14x14 center$/m);
});

test('Foot colors stay synchronized with the reviewed palette', () => {
  const roles = {
    background: 'background', foreground: 'foreground', 'selection-background': 'selection',
    'selection-foreground': 'foreground', urls: 'cyan',
    regular0: 'dark_background', regular1: 'red', regular2: 'green', regular3: 'yellow',
    regular4: 'blue', regular5: 'magenta', regular6: 'cyan', regular7: 'foreground',
    bright0: 'muted', bright1: 'bright_red', bright2: 'bright_green', bright3: 'bright_yellow',
    bright4: 'bright_blue', bright5: 'bright_magenta', bright6: 'bright_cyan', bright7: 'bright_foreground',
  };
  for (const [key, role] of Object.entries(roles)) assert.equal(foot[key], palette[role], key);
  assert.match(footText, /^cursor=111c18 c1c497$/m);
});
