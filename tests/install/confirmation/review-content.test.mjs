import test from 'node:test';
import assert from 'node:assert/strict';
import {
  compactReview,
  completePlanText,
  confirmationLines,
  confirmationPrompt,
  deviceName,
  digestPrefix,
  diskLabel,
  formatSize,
  hibernationLabel,
  machineLabel,
  reviewWarnings,
  ruleRows,
  swapfileWarning,
} from '../../../install/confirmation/review-content.mjs';
import { renderPlan } from '../../../install/plan/render-plan.mjs';
import { clone, facts, generate, unqualifiedFacts, withoutById } from './helpers.mjs';

const plan = (choices = {}, factsDocument = facts()) => generate({ choices, factsDocument }).plan;
const rows = subject => Object.fromEntries(compactReview(subject));

test('the compact review shows the machine, disk, answers, and the plan reference', () => {
  const subject = plan({ hostname: 'laptop', swapfile_size: 2048 });
  assert.deepEqual(compactReview(subject).map(([label]) => label), [
    'Machine', 'Graphics', 'CPU microcode', 'Battery', 'Virtualization', 'Disk', 'Storage', 'Hibernation', 'Timezone', 'Language', 'Formats', 'Locales',
    'Username', 'Root', 'Hostname', 'Keyboard', 'Plan reference',
  ]);
  const shown = rows(subject);
  assert.equal(shown.Machine, 'Recognized (reference-vm)');
  assert.equal(shown.Disk, '/dev/vda 32.0 GiB');
  assert.equal(shown.Storage, 'btrfs-limine (default)');
  assert.equal(shown.Hibernation, 'Enabled (swapfile 2048 MiB)');
  assert.equal(shown.Hostname, 'laptop');
  assert.equal(shown['Plan reference'], subject.digest.value.slice(0, 12));
  assert.ok(!Object.values(shown).includes(subject.digest.value));
});

test('an unqualified machine is shown as experimental, never as recognized', () => {
  const subject = generate({ factsDocument: unqualifiedFacts() }).plan;
  assert.equal(machineLabel(subject), 'Unqualified (experimental)');
  assert.equal(rows(subject).Machine, 'Unqualified (experimental)');
  assert.ok(!JSON.stringify(compactReview(subject)).includes('Recognized'));
});

test('language, formats, and the derived locales are shown separately', () => {
  const followed = rows(plan());
  assert.equal(followed.Language, 'en_US.UTF-8');
  assert.equal(followed.Formats, 'follow_language (en_US.UTF-8)');
  assert.equal(followed.Locales, 'en_US.UTF-8');
  const regional = rows(plan({ regional_format: 'es_ES.UTF-8' }));
  assert.equal(regional.Language, 'en_US.UTF-8');
  assert.equal(regional.Formats, 'es_ES.UTF-8 (es_ES.UTF-8)');
  assert.equal(regional.Locales, 'en_US.UTF-8 es_ES.UTF-8');
});

test('the root policy follows the plan', () => {
  assert.equal(rows(plan()).Root, 'locked');
  assert.equal(rows(plan({ root_account: 'password' })).Root, 'password');
});

test('every compact value is one line of plain text', () => {
  const subject = clone(plan());
  subject.target.disk.model = 'EVIL\nMODEL\tX\u001b[31m';
  for (const [label, value] of compactReview(subject)) {
    assert.ok(!/[\u0000-\u001f\u007f]/.test(value), label);
  }
  for (const line of confirmationLines(subject)) assert.ok(!/[\u0000-\u001f\u007f]/.test(line), line);
});

test('the confirmation shows the disk, its layout, and the plan reference, not the digest', () => {
  const subject = plan();
  const lines = confirmationLines(subject);
  assert.deepEqual(lines, [
    'Disk: /dev/vda 32.0 GiB',
    'Identifier: virtio-SYNTH-VDA-0001',
    'Partition table: gpt, 2 partition(s)',
    '  /dev/vda1: vfat, 512.0 MiB, "SYNTH-ESP"',
    '  /dev/vda2: ext4, 30.0 GiB, "SYNTH-DATA"',
    `Plan reference: ${digestPrefix(subject)}`,
  ]);
  assert.ok(!lines.join('\n').includes(subject.digest.value));
});

test('a disk without by_id is shown by path and still confirmable', () => {
  const subject = plan({}, withoutById(facts()));
  const lines = confirmationLines(subject);
  assert.ok(lines[0].includes('/dev/vda'));
  assert.ok(!lines.some(line => line.startsWith('Identifier:')));
  assert.equal(deviceName(subject), 'vda');
});

test('a disk without partitions reports it', () => {
  const subject = clone(plan());
  subject.target.disk.current_layout = { partitions: [] };
  assert.ok(confirmationLines(subject).includes('Partition table: none, no partitions'));
});

test('the complete plan is the persisted plan text followed by the plan reference', () => {
  const subject = plan({ storage_option: 'btrfs-limine', root_account: 'password' });
  const text = completePlanText(subject);
  assert.ok(text.startsWith(renderPlan(subject)));
  assert.ok(text.endsWith(`Plan reference: ${digestPrefix(subject)} (the first 12 characters of the digest above)\n`));
});

test('the complete plan carries the disk, every choice with provenance, operations, warnings, and secrets', () => {
  const subject = plan({ storage_option: 'btrfs-limine', root_account: 'password' }, unqualifiedFacts());
  const text = completePlanText(subject);
  assert.ok(text.includes('virtio-SYNTH-VDA-0001') && text.includes('SYNTH-ESP'));
  for (const [key, entry] of Object.entries(subject.choices)) {
    assert.ok(text.includes(`${key}: `), key);
    assert.ok(text.includes(`provenance ${entry.provenance}; source ${entry.source}`), key);
  }
  for (const operation of subject.operations.filter(item => item.destructive)) {
    assert.ok(text.includes(`DESTRUCTIVE ${operation.kind}`), operation.kind);
  }
  for (const warning of subject.warnings) assert.ok(text.includes(warning.code), warning.code);
  assert.ok(subject.warnings.length > 0);
  assert.match(text, /account_password/);
  assert.match(text, /Required by\s+create_user, configure_root_account/);
});

test('the shared password requirement names the root consumer only when root has a password', () => {
  assert.match(completePlanText(plan()), /Required by\s+create_user\n/);
  assert.match(completePlanText(plan({ root_account: 'password' })), /Required by\s+create_user, configure_root_account/);
  for (const text of [completePlanText(plan()), completePlanText(plan({ root_account: 'password' }))]) {
    assert.ok(!text.includes('user_password') && !text.includes('root_password'));
  }
});

test('an unqualified plan carries its warning into the complete text', () => {
  const subject = generate({ factsDocument: unqualifiedFacts() }).plan;
  assert.ok(subject.warnings.some(item => item.code === 'machine_unqualified'));
  assert.match(completePlanText(subject), /machine_unqualified/);
});

test('the review of one plan is stable', () => {
  const subject = plan();
  assert.deepEqual(compactReview(subject), compactReview(clone(subject)));
  assert.equal(completePlanText(subject), completePlanText(clone(subject)));
});

test('the confirmation prompt names the disk and the plan reference', () => {
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

test('the hibernation row shows the swapfile size when enabled and no swapfile when disabled', () => {
  assert.equal(rows(plan()).Hibernation, 'Enabled (swapfile 4096 MiB)');
  assert.equal(rows(plan({ hibernation: false })).Hibernation, 'Disabled (no swapfile)');
  assert.equal(hibernationLabel(plan({ swapfile_size: 512 })), 'Enabled (swapfile 512 MiB)');
  for (const subject of [plan(), plan({ hibernation: false })]) {
    assert.equal(Object.keys(rows(subject)).includes('Swapfile'), false);
    assert.doesNotMatch(JSON.stringify(compactReview(subject)), /guarantee/i);
  }
});

test('the below-memory warning persists in the review content only for a reduced size', () => {
  assert.equal(swapfileWarning(plan()), undefined);
  assert.equal(swapfileWarning(plan({ swapfile_size: 4096 })), undefined);
  assert.equal(swapfileWarning(plan({ hibernation: false })), undefined);
  const reduced = plan({ swapfile_size: 2048 });
  assert.equal(swapfileWarning(reduced).code, 'swapfile_below_ram');
  assert.match(completePlanText(reduced), /swapfile_below_ram:/);
  assert.match(completePlanText(plan({ hibernation: false })), /Hibernation is disabled: no swapfile will be created\./);
});

test('the review shows the outcome of every hardware rule in one line, before the disk', () => {
  const subject = plan();
  assert.deepEqual(ruleRows(subject), [
    ['Graphics', 'Kernel driver, nothing additional'],
    ['CPU microcode', 'Installs amd-ucode'],
    ['Battery', 'No battery detected'],
    ['Virtualization', 'Virtual machine'],
  ]);
  const labels = compactReview(subject).map(([label]) => label);
  assert.deepEqual(labels.slice(0, 6), ['Machine', 'Graphics', 'CPU microcode', 'Battery', 'Virtualization', 'Disk']);
});

test('the review rows follow the rule outcomes of other hardware and never hide a warning', () => {
  const nvidia = clone(facts());
  nvidia.effective['hardware.graphics'] = { value: [{ vendor: 'nvidia' }], source: 'detected' };
  nvidia.effective['hardware.cpu.vendor'] = { value: 'GenuineIntel', source: 'detected' };
  nvidia.effective['hardware.battery_present'] = { value: true, source: 'detected' };
  nvidia.effective['hardware.virtualization'] = { value: 'none', source: 'detected' };
  const subject = plan({}, nvidia);
  assert.deepEqual(ruleRows(subject).map(([, value]) => value), [
    'NVIDIA detected, nouveau driver used', 'Installs intel-ucode', 'Battery detected', 'Physical machine',
  ]);
  assert.deepEqual(reviewWarnings(subject).map(item => item.code), ['graphics_nvidia_nouveau']);
  assert.match(completePlanText(subject), /graphics_nvidia_nouveau:/);
  assert.match(completePlanText(subject), /Hardware rule outcomes:/);
});

test('the swapfile warning keeps its own text and is not repeated among the review warnings', () => {
  const reduced = plan({ swapfile_size: 2048 });
  assert.equal(swapfileWarning(reduced).code, 'swapfile_below_ram');
  assert.deepEqual(reviewWarnings(reduced), []);
  assert.deepEqual(reviewWarnings(plan()), []);
});
