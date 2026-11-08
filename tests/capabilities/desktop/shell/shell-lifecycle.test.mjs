// Static lifecycle contract of the shell entry point (DEC-049): a published runtime never reloads a running shell.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const shellQml = readFileSync(new URL('../../../../capabilities/desktop/shell/shell.qml', import.meta.url), 'utf8');

test('the shell root disables Quickshell file watching', () => {
  const root = shellQml.slice(shellQml.indexOf('ShellRoot {'));
  assert.match(root, /^ {2}settings\.watchFiles: false$/m);
  assert.doesNotMatch(shellQml, /watchFiles\s*[:=]\s*true|Quickshell\.watchFiles/);
});
