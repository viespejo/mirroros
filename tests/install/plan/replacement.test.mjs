import test from 'node:test';
import assert from 'node:assert/strict';
import { discover } from '../discovery/helpers.mjs';
import { generate, policy } from './helpers.mjs';
import { buildValidPlan } from './build-fixtures.mjs';
import { withDigest } from '../../../install/plan/digest-plan.mjs';
import { validatePlan } from '../../../install/plan/validate-plan.mjs';
import { previewChoices, validateChoice } from '../../../install/plan/preview-choices.mjs';
import { loadChoices } from '../../../install/plan/resolve-choices.mjs';
import { renderPlan, renderSummary } from '../../../install/plan/render-plan.mjs';
import { referenceRoot, removeDirectory, temporaryDirectory, writeJson } from './helpers.mjs';

const OPTIONS = ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'];
const candidateOf = facts => facts.layers.detected.storage.disks[0].replace_candidates[0];
const codes = reasons => reasons.map(item => item.code);
function replacement(option = 'btrfs-limine', extra = {}, facts = discover(`coexistence-${option}`)) {
  return generate({ factsDocument: facts, choices: {
    storage_option: option, target_mode: 'replace_installation',
    replace_root_partuuid: candidateOf(facts)?.root.partuuid, ...extra,
  } });
}

for (const option of OPTIONS) {
  test(`replacement plan for ${option} matches the independent fixture and contains no disk wipe or partition-table operation`, () => {
    const facts = discover(`coexistence-${option}`);
    const { plan, reasons } = replacement(option, {}, facts);
    assert.deepEqual(reasons, []);
    assert.deepEqual(plan, buildValidPlan(option, 'locked', true, 'replace_installation'));
    assert.deepEqual(validatePlan(plan, { facts }), []);
    assert.deepEqual(validatePlan(plan), []);
    assert.deepEqual(plan.target.installation, candidateOf(facts));
    assert.deepEqual(plan.operations.filter(op => op.destructive).map(op => op.kind), ['wipe_partition_signatures', 'format_partitions']);
    assert.ok(!plan.operations.some(op => ['wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'remove_stale_uefi_entries'].includes(op.kind)));
    const register = plan.operations.at(-1);
    assert.equal(register.kind, 'register_uefi_boot_entry');
    assert.equal(register.parameters.first, true);
    assert.equal(register.parameters.label, option === 'btrfs-limine' ? 'Limine MirrorOS' : 'MirrorOS');
    assert.equal(register.parameters.loader_path, option === 'btrfs-limine' ? '\\EFI\\BOOT\\BOOTX64.EFI' : '\\EFI\\systemd\\systemd-bootx64.efi');
    const disabled = replacement(option, { hibernation: false }).plan;
    assert.deepEqual(validatePlan(disabled), []);
    assert.ok(!disabled.operations.some(op => op.kind === 'create_swapfile'));
  });
}

test('replacement can change the filesystem and bootloader without changing the partition targets', () => {
  for (const existing of OPTIONS) {
    const facts = discover(`coexistence-${existing}`);
    for (const selected of OPTIONS) {
      const { plan, reasons } = replacement(selected, {}, facts);
      assert.deepEqual(reasons, []);
      assert.equal(plan.target.installation.storage_option, existing);
      assert.equal(plan.choices.storage_option.value, selected);
      assert.deepEqual(plan.operations[1].parameters.root, candidateOf(facts).root);
      assert.equal(plan.operations[1].parameters.root_filesystem, selected === 'ext4-systemd-boot' ? 'ext4' : 'btrfs');
      assert.deepEqual(validatePlan(plan, { facts }), []);
    }
  }
});

test('malformed replacement partition records are rejected without throwing', () => {
  const plan = replacement().plan;
  plan.target.disk.current_layout.partitions[0] = null;
  assert.ok(validatePlan(withDigest(plan)).length > 0);
});

test('whole-disk cleanup is bound exactly to the observed target PARTUUIDs and precedes formatting', () => {
  for (const option of OPTIONS) {
    const facts = discover(`coexistence-${option}`);
    const { plan } = generate({ factsDocument: facts, choices: { storage_option: option } });
    const partuuids = facts.layers.detected.storage.disks[0].layout.partitions.map(p => p.partuuid);
    assert.equal(plan.target_mode, 'whole_disk');
    assert.equal(plan.target.installation, undefined);
    assert.deepEqual(plan.operations[0].parameters.partuuids, partuuids);
    const cleanup = plan.operations.findIndex(op => op.kind === 'remove_stale_uefi_entries');
    assert.deepEqual(plan.operations[cleanup].parameters, { partuuids });
    assert.equal(plan.operations[cleanup - 1].kind, 'create_partitions');
    assert.equal(plan.operations[cleanup + 1].kind, 'format_filesystems');
    assert.equal(plan.operations.at(-1).kind, 'register_uefi_boot_entry');
    assert.ok(plan.operations.find(op => op.kind === 'install_packages').parameters.packages.includes('efibootmgr'));
  }
});

test('replacement requires an explicit full root identity, never inferred from disk selection', () => {
  for (const identity of [undefined, '00000002', 'ffffffff-ffff-ffff-ffff-ffffffffffff']) {
    assert.ok(codes(replacement('btrfs-limine', { replace_root_partuuid: identity }).reasons).includes('replacement_target_invalid'));
  }
  for (const name of ['reference-vm-empty', 'coexistence-ambiguous-roots', 'coexistence-missing-esp']) {
    const { reasons } = generate({ factsDocument: discover(name), choices: { target_mode: 'replace_installation' } });
    assert.ok(codes(reasons).includes('replacement_target_invalid'), name);
  }
  const { reasons } = generate({ choices: { replace_root_partuuid: '10000000-0000-4000-8000-000000000002' } });
  assert.ok(codes(reasons).includes('choices_conflict'));
});

test('replacement enforces partition sizes, not the size of the shared disk, including swapfile capacity', () => {
  for (const [role, bytes] of [['esp', policy.policy.esp.value.size_bytes - 1], ['root', policy.policy.root_minimum_bytes.value - 1], ['root', policy.policy.root_minimum_bytes.value + 4096 * 1048576 - 1]]) {
    const facts = discover('coexistence-btrfs-limine');
    const candidate = candidateOf(facts);
    candidate[role].size_bytes = bytes;
    facts.layers.detected.storage.disks[0].layout.partitions.find(p => p.path === candidate[role].path).size_bytes = bytes;
    assert.ok(codes(replacement('btrfs-limine', {}, facts).reasons).includes('replacement_target_invalid'), `${role}: ${bytes}`);
  }
  const facts = discover('coexistence-btrfs-limine');
  const candidate = candidateOf(facts);
  candidate.root.size_bytes = policy.policy.root_minimum_bytes.value;
  facts.layers.detected.storage.disks[0].layout.partitions[1].size_bytes = candidate.root.size_bytes;
  assert.deepEqual(replacement('btrfs-limine', { hibernation: false }, facts).reasons, []);
});

test('replacement rejects mounted, incomplete, duplicate, changed and foreign-disk identities', () => {
  for (const mutate of [
    c => { c.root.mountpoints = ['/mnt']; },
    c => { delete c.root.start_sector; },
    c => { delete c.esp.partuuid; },
    c => { c.root.path = '/dev/vda'; },
    c => { c.esp.partition_number = c.root.partition_number; },
    c => { c.disk_path = '/dev/vdb'; },
  ]) {
    const facts = discover('coexistence-btrfs-limine');
    mutate(candidateOf(facts));
    assert.ok(codes(replacement('btrfs-limine', {}, facts).reasons).includes('replacement_target_invalid'));
  }
});

test('resigned plans cannot expand the destructive target or alter the NVRAM scope', () => {
  const mutations = [
    p => { p.operations[0].parameters.root = { path: '/dev/vda' }; },
    p => { p.operations[1].parameters.esp = p.target.disk.current_layout.partitions[2]; },
    p => { p.operations[1].parameters.disk = '/dev/vda'; },
    p => { p.operations[1].parameters.root_filesystem = 'other'; },
    p => { p.target.installation.extra = true; },
    p => { p.target_mode = 'whole_disk'; },
    p => { p.operations.at(-1).parameters.label = 'Omarchy'; },
    p => { p.operations.at(-1).parameters.first = false; },
    p => { p.operations.at(-1).parameters.loader_path = '\\EFI\\other.efi'; },
    p => { p.choices.storage_option.bootloader = 'systemd-boot'; },
    p => { p.target.installation.root.partuuid = 'ffffffff-ffff-ffff-ffff-ffffffffffff'; },
  ];
  for (const mutate of mutations) {
    const plan = structuredClone(replacement().plan);
    mutate(plan);
    assert.ok(validatePlan(withDigest(plan)).length > 0);
  }
  const facts = discover('coexistence-btrfs-limine');
  const plan = replacement('btrfs-limine', {}, facts).plan;
  facts.layers.detected.storage.disks[0].replace_candidates = [];
  assert.ok(codes(validatePlan(plan, { facts })).includes('replacement_target_invalid'));
});

test('replacement review names format targets and preserved partitions, never claiming whole-disk erasure', () => {
  const plan = replacement().plan;
  const text = renderPlan(plan);
  assert.match(text, /Target mode +replace_installation/);
  assert.match(text, /Format esp +\/dev\/nvme0n1p1 PARTUUID=/);
  assert.match(text, /Format root +\/dev\/nvme0n1p2 PARTUUID=/);
  assert.match(text, /\/dev\/nvme0n1p3 +PRESERVE/);
  assert.match(text, /\/dev\/nvme0n1p4 +PRESERVE/);
  assert.doesNotMatch(text, /every partition and all data|this content will be destroyed/);
  assert.match(renderSummary(plan, 'plan.json'), /Format root: \/dev\/nvme0n1p2 PARTUUID=/);
});

test('choice preview offers replacement only with evidence and leaves the root identity for explicit choice', () => {
  const facts = discover('coexistence-btrfs-limine');
  const preview = previewChoices({ facts, policy }).document;
  assert.deepEqual(preview.options.target_mode, ['whole_disk', 'replace_installation']);
  assert.equal(preview.options.replace_root_partuuid[0].value, candidateOf(facts).root.partuuid);
  const pending = previewChoices({ facts, policy, choices: { values: { target_mode: 'replace_installation' } } });
  assert.ok(pending.document);
  assert.equal(pending.document.choices.replace_root_partuuid, undefined);
  const empty = discover('reference-vm-empty');
  assert.deepEqual(previewChoices({ facts: empty, policy }).document.options.target_mode, ['whole_disk']);
  assert.equal(validateChoice({ facts: empty, policy, key: 'target_mode', value: 'replace_installation' }).valid, false);
  assert.equal(validateChoice({ facts, policy, key: 'replace_root_partuuid', value: candidateOf(facts).root.partuuid }).valid, true);
  assert.equal(validateChoice({ facts, policy, key: 'replace_root_partuuid', value: '00000002' }).valid, false);
});

test('choices file accepts the target mode and full root PARTUUID and rejects unsupported values', () => {
  const directory = temporaryDirectory();
  const root = referenceRoot();
  try {
    for (const [mode, identity, valid] of [
      ['replace_installation', '10000000-0000-4000-8000-000000000002', true],
      ['free_space', '10000000-0000-4000-8000-000000000002', false],
      ['replace_installation', '00000002', false],
    ]) {
      const path = writeJson(directory, 'choices.json', { format_version: 3, target_mode: mode, replace_root_partuuid: identity });
      const result = loadChoices(path, { policy: policy.policy, storageOptions: policy.storageOptions, root });
      assert.equal(result.reasons.length === 0, valid);
    }
  } finally {
    removeDirectory(directory);
    removeDirectory(root);
  }
});
