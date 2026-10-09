import test from 'node:test';
import assert from 'node:assert/strict';
import {
  confirmationPrompt,
  deviceName,
  digestPrefix,
  diskLabel,
  formatSize,
  reviewMarkdown,
} from '../../../install/confirmation/review-content.mjs';
import { clone, facts, generate, withoutById } from './helpers.mjs';

const plan = (choices = {}, factsDocument = facts()) => generate({ choices, factsDocument }).plan;

test('the dashboard shows digest, target, disk, and layout', () => {
  const subject = plan();
  const text = reviewMarkdown(subject);
  assert.ok(text.includes(`sha256:${subject.digest.value.slice(0, 12)}`));
  assert.ok(text.includes('reference-vm'));
  assert.ok(text.includes('/dev/vda'));
  assert.ok(text.includes('32.0 GiB'));
  assert.ok(text.includes('virtio-SYNTH-VDA-0001'));
  assert.ok(text.includes('2 partition(s)'));
  assert.ok(text.includes('SYNTH-ESP'));
});

test('every choice appears with provenance and source', () => {
  const subject = plan({ hostname: 'laptop' });
  const text = reviewMarkdown(subject);
  for (const [key, entry] of Object.entries(subject.choices)) {
    const line = text.split('\n').find(candidate => candidate.startsWith(`- ${key.replaceAll('_', '\\_')}:`));
    assert.ok(line !== undefined, key);
    assert.ok(line.includes(entry.provenance.replaceAll('_', '\\_')), key);
    assert.ok(line.includes(entry.source), key);
  }
  assert.match(text, /hostname: laptop \(personal\\_preference, choice\)/);
});

test('every destructive operation is marked and no other is', () => {
  const subject = plan();
  const text = reviewMarkdown(subject);
  const marked = text.split('\n').filter(line => line.includes('`DESTRUCTIVE`'));
  const destructive = subject.operations.filter(operation => operation.destructive);
  assert.equal(marked.length, destructive.length);
  for (const operation of destructive) {
    assert.ok(marked.some(line => line.includes(operation.id.replaceAll('_', '\\_'))), operation.id);
  }
  const rest = subject.operations.filter(operation => !operation.destructive);
  assert.ok(text.includes(rest.map(operation => operation.id).join(', ').replaceAll('_', '\\_')));
});

test('secret requirements show name, channel, and consumer without root_password', () => {
  const text = reviewMarkdown(plan());
  assert.match(text, /user\\_password: protected\\_prompt, required by create\\_user/);
  assert.ok(!text.includes('root\\_password'));
});

test('root_password appears with root_account password', () => {
  const text = reviewMarkdown(plan({ root_account: 'password' }));
  assert.match(text, /user\\_password: protected\\_prompt, required by create\\_user/);
  assert.match(text, /root\\_password: protected\\_prompt, required by configure\\_root\\_account/);
});

test('an experimental storage tier shows its warning', () => {
  const text = reviewMarkdown(plan({ storage_option: 'btrfs-limine' }));
  assert.match(text, /## Warnings/);
  assert.match(text, /experimental/);
  assert.ok(!reviewMarkdown(plan()).includes('## Warnings'));
});

test('a disk without by_id is shown by path and still confirmable', () => {
  const subject = plan({}, withoutById(facts()));
  const text = reviewMarkdown(subject);
  assert.ok(text.includes('/dev/vda'));
  assert.ok(!text.includes('Identifier:'));
  assert.equal(deviceName(subject), 'vda');
});

test('the review is the same for any target id', () => {
  const subject = plan();
  const other = clone(subject);
  other.target.target_id = 'framework-13-pro-amd';
  const strip = text => text.replace(/reference-vm|framework-13-pro-amd/g, 'TARGET');
  assert.equal(strip(reviewMarkdown(subject)), strip(reviewMarkdown(other)));
});

test('the confirmation prompt names the disk and the digest prefix', () => {
  const subject = plan();
  assert.equal(confirmationPrompt(subject), `Erase ${diskLabel(subject)} and apply plan ${digestPrefix(subject)}?`);
  assert.match(confirmationPrompt(subject), /^Erase \/dev\/vda 32\.0 GiB and apply plan [0-9a-f]{12}\?$/);
});

test('the expected device name is the kernel name of the disk path', () => {
  assert.equal(deviceName(plan()), 'vda');
  for (const [path, expected] of [['/dev/nvme0n1', 'nvme0n1'], ['/dev/sda', 'sda']]) {
    const subject = clone(plan());
    subject.target.disk.path = path;
    assert.equal(deviceName(subject), expected);
  }
  const noPath = clone(plan());
  delete noPath.target.disk.path;
  assert.equal(deviceName(noPath), undefined);
});

test('sizes are formatted in binary units', () => {
  assert.equal(formatSize(536870912), '512.0 MiB');
  assert.equal(formatSize(34359738368), '32.0 GiB');
  assert.equal(formatSize(undefined), 'unknown size');
});

test('markdown-significant characters in values are escaped', () => {
  const subject = clone(plan());
  subject.target.disk.current_layout.partitions[0].label = 'A*B_C`D';
  assert.ok(reviewMarkdown(subject).includes('A\\*B\\_C\\`D'));
});
