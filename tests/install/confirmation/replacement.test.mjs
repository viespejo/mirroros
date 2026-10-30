import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { discover } from '../discovery/helpers.mjs';
import { assets, currentHashes, generate, repository } from './helpers.mjs';
import { compareSafety, diskDifferences } from '../../../install/confirmation/compare-safety.mjs';
import { applyEdit, startingChoices } from '../../../install/confirmation/edit-choices.mjs';
import { compactReview, confirmationLines, confirmationPrompt } from '../../../install/confirmation/review-content.mjs';
import { buildApprovalRecord } from '../../../install/confirmation/write-records.mjs';
import { validateApprovalRecord } from '../../../install/confirmation/validate-records.mjs';

function replacement(option = 'btrfs-limine') {
  const facts = discover(`coexistence-${option}`);
  const disk = facts.layers.detected.storage.disks[0];
  const root = disk.replace_candidates[0].root.partuuid;
  const { plan, reasons } = generate({ factsDocument: facts, choices: {
    target_mode: 'replace_installation', replace_root_partuuid: root, storage_option: option,
  } });
  assert.deepEqual(reasons, []);
  return { plan: structuredClone(plan), facts, disk, root };
}

for (const option of ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine']) {
  test(`${option}: review separates formatted partitions from preserved partitions`, () => {
    const { plan, facts } = replacement(option);
    const rows = Object.fromEntries(compactReview(plan));
    assert.equal(rows.Mode, 'Replace existing MirrorOS');
    for (const role of ['esp', 'root']) {
      assert.ok(rows[`Format ${role === 'esp' ? 'ESP' : role}`].includes(plan.target.installation[role].partuuid));
    }
    for (const partition of plan.target.disk.current_layout.partitions.slice(2)) {
      assert.ok(rows.Preserve.includes(partition.path));
      assert.ok(rows.Preserve.includes(partition.partuuid));
    }
    assert.ok(!rows.Preserve.includes(plan.target.installation.root.partuuid));
    assert.match(confirmationPrompt(plan), /^Replace MirrorOS/);
    assert.ok(confirmationLines(plan).some(line => line.startsWith('Preserve:')));
    assert.deepEqual(compareSafety({ plan, facts, hashes: currentHashes(), assets }), []);
    assert.equal(startingChoices(plan).replace_root_partuuid, plan.target.installation.root.partuuid);
  });
}

test('replacement rejects lost, ambiguous or changed candidate evidence even with an unchanged layout', () => {
  const changes = [
    disk => { disk.replace_candidates = []; },
    disk => { disk.replace_candidates.push(structuredClone(disk.replace_candidates[0])); },
    disk => { disk.replace_candidates[0].esp.partuuid = 'ffffffff-ffff-ffff-ffff-ffffffffffff'; },
    disk => { disk.replace_candidates[0].root.uuid = 'changed'; },
    disk => { disk.replace_candidates[0].storage_option = 'ext4-systemd-boot'; },
  ];
  for (const change of changes) {
    const { plan, facts, disk } = replacement();
    change(disk);
    const reasons = compareSafety({ plan, facts, hashes: currentHashes(), assets });
    assert.ok(reasons.some(item => item.code === 'target_layout_changed'));
  }
});

test('replacement rejects changed partition identities, sizes, table entries and mounts', () => {
  for (const [key, value] of [['partuuid', 'changed'], ['size_bytes', 1024], ['start_sector', 4096], ['mountpoints', ['/mnt']]]) {
    const { plan, disk } = replacement();
    disk.layout.partitions[1][key] = value;
    assert.ok(diskDifferences(plan, disk).some(item => item.code === 'target_layout_changed'), key);
  }
});

test('the safety projection rejects a changed target mode or selected root identity', () => {
  const { plan, disk } = replacement();
  plan.target_mode = 'whole_disk';
  assert.ok(diskDifferences(plan, disk).some(item => item.code === 'target_identity_changed'));
  plan.target_mode = 'replace_installation';
  plan.choices.replace_root_partuuid.value = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  assert.ok(diskDifferences(plan, disk).some(item => item.code === 'target_layout_changed'));
});

test('disk and mode edits cannot retain a stale replacement identity', () => {
  const { plan, root } = replacement();
  const initial = startingChoices(plan);
  const whole = applyEdit(initial, 'target_mode', 'whole_disk').choices;
  assert.equal(whole.replace_root_partuuid, undefined);
  const changed = applyEdit({ ...initial, target_disk: '/dev/nvme0n1' }, 'target_disk', '/dev/vdb').choices;
  assert.equal(changed.target_mode, undefined);
  assert.equal(changed.replace_root_partuuid, undefined);
  const selected = applyEdit(whole, 'replace_root_partuuid', root).choices;
  assert.equal(selected.target_mode, 'replace_installation');
  assert.equal(selected.replace_root_partuuid, root);
  assert.deepEqual(initial, startingChoices(plan));
});

test('approval evidence carries complete replacement identities and rejects inconsistent fields', () => {
  const { plan } = replacement();
  const partitions = Object.fromEntries(['esp', 'root'].map(role => [role, Object.fromEntries(
    ['path', 'partuuid', 'uuid', 'type_guid', 'size_bytes', 'partition_number', 'start_sector']
      .map(key => [key, plan.target.installation[role][key]]),
  )]));
  const record = buildApprovalRecord({ runId: 'synthetic', timestamp: '2026-10-30T12:00:00Z',
    outcome: 'cancelled', targetMode: plan.target_mode, partitions });
  assert.deepEqual(validateApprovalRecord(record), []);
  for (const changed of [
    { ...record, partitions: undefined },
    { ...record, target_mode: 'whole_disk' },
    { ...record, target_mode: 'unknown' },
    { ...record, partitions: { esp: partitions.esp, root: partitions.esp } },
    { ...record, partitions: { ...partitions, root: { ...partitions.root, partuuid: '00000002' } } },
  ]) assert.ok(validateApprovalRecord(changed).length > 0);
});

test('the assistant exposes both the technical mode and its presentation label', () => {
  const path = `${repository}/tests/fixtures/plan/valid/btrfs-limine--replace.json`;
  const result = spawnSync(process.execPath, [`${repository}/install/confirmation/assistant.mjs`, 'review-values', path], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const rows = Object.fromEntries(result.stdout.trim().split('\n').map(line => line.split('\t')));
  const plan = JSON.parse(readFileSync(path, 'utf8'));
  assert.equal(rows.target_mode, 'replace_installation');
  assert.equal(rows.target_mode_label, 'Replace existing MirrorOS');
  assert.equal(rows.root_partuuid, plan.target.installation.root.partuuid);
  assert.ok(rows.target_preserve.includes('/dev/nvme0n1p4'));
});
