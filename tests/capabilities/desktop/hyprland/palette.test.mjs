import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('the Hyprland active border follows the reviewed fixed accent', () => {
  const palette = fs.readFileSync('capabilities/visual/theme/default/colors.toml', 'utf8');
  const config = fs.readFileSync('capabilities/desktop/compositor/providers/hyprland/defaults.lua', 'utf8');
  const theme = fs.readFileSync('capabilities/visual/theme/default/hyprland.lua', 'utf8');
  const accent = palette.match(/^accent = "#([0-9a-f]{6})"$/mi);
  assert.ok(accent);
  assert.ok(config.includes(`active_border = "rgba(${accent[1].toLowerCase()}ff)"`));
  assert.ok(config.includes('inactive_border = "rgba(595959aa)"'));
  assert.match(theme, new RegExp(`active_border = "rgba\\(${accent[1].toLowerCase()}ff\\)"`));
  assert.ok(theme.includes('inactive_border = "rgba(595959aa)"'));
  assert.match(theme, /^--[^\n]*\nreturn \{\n  active_border = "rgba\([0-9a-f]{8}\)",\n  inactive_border = "rgba\([0-9a-f]{8}\)",\n\}\n$/);
});
