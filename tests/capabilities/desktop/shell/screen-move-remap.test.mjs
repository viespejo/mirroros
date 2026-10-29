import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);

test('screen remap guard is byte-identical to the reviewed Omarchy component', () => {
  const bytes = readFileSync(new URL('Ui/ScreenMoveRemap.qml', shell));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),
    'ae09782672877502015e517c6f58565cf79b82e0aa1dc56ee5655989863ad8a7');
});

test('screen remap guard is registered in the explicit UI module', () => {
  const source = readFileSync(new URL('Ui/qmldir', shell), 'utf8');
  assert.match(source, /^ScreenMoveRemap 1\.0 ScreenMoveRemap\.qml$/m);
});

test('the bar folds the output-position remap guard into its visibility', () => {
  const source = readFileSync(new URL('bar/Bar.qml', shell), 'utf8');
  assert.match(source, /visible: !remapGuard\.remapping/);
  assert.match(source, /ScreenMoveRemap\s*\{\s*id: remapGuard\s*window: barWindow/);
});
