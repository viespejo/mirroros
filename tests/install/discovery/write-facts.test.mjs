import test from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { renderSummary, writeFacts } from '../../../install/discovery/write-facts.mjs';
import { DiscoveryContractError } from '../../../install/discovery/validate-facts.mjs';
import { discover } from './helpers.mjs';

function temporaryRoot(t) {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-write-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}

const mode = path => statSync(path).mode & 0o777;

test('facts are written atomically with private permissions', t => {
  const root = temporaryRoot(t);
  chmodSync(root, 0o755);
  const directory = join(root, 'evidence', 'install', 'run-1');
  const document = discover('reference-vm-layout');
  const destination = writeFacts(document, directory);

  assert.equal(destination, join(directory, 'target-facts.json'));
  assert.deepEqual(JSON.parse(readFileSync(destination, 'utf8')), document);
  assert.equal(mode(destination), 0o600);
  assert.equal(mode(directory), 0o700);
  assert.equal(mode(join(root, 'evidence', 'install')), 0o700);
  assert.equal(mode(join(root, 'evidence')), 0o700);
  assert.equal(mode(root), 0o755);
  assert.deepEqual(readdirSync(directory), ['target-facts.json']);
});

test('an invalid document is refused and leaves neither output nor temporary files', t => {
  const root = temporaryRoot(t);
  const directory = join(root, 'run');
  const document = structuredClone(discover('reference-vm-empty'));
  document.unexpected = true;
  assert.throws(() => writeFacts(document, directory), DiscoveryContractError);
  assert.equal(existsSync(join(directory, 'target-facts.json')), false);
  assert.deepEqual(existsSync(directory) ? readdirSync(directory) : [], []);
});

test('an invalid-validation document is still written so it can be inspected', t => {
  const root = temporaryRoot(t);
  const document = discover('bios');
  const destination = writeFacts(document, join(root, 'run'));
  assert.equal(JSON.parse(readFileSync(destination, 'utf8')).validation.status, 'invalid');
});

test('the summary shows key facts with their provenance and the reasons', () => {
  const summary = renderSummary(discover('secure-boot-unknown'));
  assert.match(summary, /^Profile: matched reference-vm \(commit a{40}, dirty false\)$/m);
  assert.match(summary, /^Validation: valid$/m);
  assert.match(summary, /Firmware: uefi \[detected\]/);
  assert.match(summary, /Policy minimum_disk_bytes: 21474836480 \[baseline\]/);
  assert.match(summary, /^Warning secure_boot_unknown:/m);

  const unqualified = renderSummary(discover('synthetic-laptop', { targetId: null }));
  assert.match(unqualified, /^Profile: unqualified \(experimental; no compatibility or support is promised\) \(commit a{40}, dirty false\)$/m);

  const failing = renderSummary(discover('bios'));
  assert.match(failing, /^Validation: invalid$/m);
  assert.match(failing, /^Reason boot_mode_not_uefi:.*Next: Boot the installation medium in UEFI mode/m);
});
