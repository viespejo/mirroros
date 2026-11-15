// Polkit agent (ADR 0030): the copied Omarchy model against the delivered PAM stacks, and the MirrorOS
// adaptation bounds of PolkitAgent.qml and its shell.qml instance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const repo = new URL('../../../../', import.meta.url);
const shell = new URL('capabilities/desktop/shell/', repo);
const module = { exports: {} };
vm.runInNewContext(readFileSync(new URL('polkit/PolkitModel.js', shell), 'utf8'), { module });
const Model = module.exports;
const agent = readFileSync(new URL('polkit/PolkitAgent.qml', shell), 'utf8');
const shellQml = readFileSync(new URL('shell.qml', shell), 'utf8');
const code = text => text.split('\n').filter(line => !/^\s*\/\//.test(line)).join('\n');

const vendorStack = '#%PAM-1.0\n\nauth       include      system-auth\naccount    include      system-auth\n'
  + 'password   include      system-auth\nsession    include      system-auth\n';

test('fingerprint is detected in the delivered polkit-1 and sudo stacks with the gate first', () => {
  for (const name of ['polkit-1', 'sudo']) {
    const raw = readFileSync(new URL(`capabilities/system/fingerprint/${name}`, repo), 'utf8');
    const auth = raw.split('\n').filter(line => /^auth\s/.test(line));
    assert.match(auth[0], /pam_exec\.so quiet \/usr\/share\/mirroros\/hardware\/lid-closed$/, name);
    assert.match(auth[1], /^auth sufficient pam_fprintd\.so$/, name);
    assert.equal(Model.fingerprintConfiguredFromPamConfig(raw), true, name);
  }
});

test('fingerprint is not detected in the vendor stack, comments or non-auth lines', () => {
  assert.equal(Model.fingerprintConfiguredFromPamConfig(vendorStack), false);
  assert.equal(Model.fingerprintConfiguredFromPamConfig('# auth sufficient pam_fprintd.so\n'), false);
  assert.equal(Model.fingerprintConfiguredFromPamConfig('account sufficient pam_fprintd.so\n'), false);
  assert.equal(Model.fingerprintConfiguredFromPamConfig(''), false);
  assert.equal(Model.fingerprintConfiguredFromPamConfig(undefined), false);
});

test('fingerprint prompts are recognized', () => {
  assert.equal(Model.promptLooksFingerprint('Place your finger on the fingerprint reader'), true);
  assert.equal(Model.promptLooksFingerprint('Swipe your right index finger'), true);
  assert.equal(Model.promptLooksFingerprint('Password: '), false);
  assert.equal(Model.promptLooksFingerprint('The account is locked due to 3 failed logins.'), false);
  assert.equal(Model.promptLooksFingerprint(null), false);
});

test('authorization label shortens pkexec messages and keeps others', () => {
  const tr = (key, english) => english;
  assert.equal(Model.authorizationLabel("Authentication is needed to run `/usr/bin/true' as the super user", tr),
    "Authorize running '/usr/bin/true'");
  assert.equal(Model.authorizationLabel('Authentication is required to suspend the system', tr),
    'Authentication is required to suspend the system');
  assert.equal(Model.authorizationLabel('', tr), '');
});

test('the agent keeps the ADR 0030 adaptation bounds', () => {
  const body = code(agent);
  assert.match(body, /path: "\/org\/mirroros\/PolkitAgent"/);
  assert.match(body, /command: \["\/usr\/share\/mirroros\/hardware\/lid-closed"\]/);
  assert.match(body, /onExited: function\(exitCode\) \{ root\.laptopClosed = exitCode === 0 \}/);
  assert.equal((body.match(/command:/g) || []).length, 1, 'lid-closed is the only process');
  assert.doesNotMatch(body, /"bash"|bash -c|execDetached|console\.log|console\.info|console\.debug/);
  for (const field of ['currentMessage', 'currentPrompt', 'currentSupplementary', 'passwordInput.text', 'flow'])
    assert.doesNotMatch(body, new RegExp(`console\\.\\w+\\([^)]*${field.replace('.', '\\.')}`), field);
  assert.match(body, /WlrLayershell\.namespace: "mirroros-polkit"/);
  assert.match(body, /path: "\/etc\/pam\.d\/polkit-1"/);
});

test('shell.qml instantiates one isolated agent', () => {
  const instances = code(shellQml).match(/[\w.]*PolkitAgent\s*\{[^}]*\}/g) || [];
  assert.equal(instances.length, 1);
  assert.match(instances[0], /^Polkit\.PolkitAgent\s*\{\s*\}$/);
});
