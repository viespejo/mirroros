import assert from 'node:assert/strict';
import test from 'node:test';

import { partitionRecord } from '../../../install/engine/load-plan.mjs';
import { planText, rawStorage, streamOperations, verify } from './helpers.mjs';

function dumpFor(plan) {
  const layout = plan.target.disk.current_layout;
  return ['label: gpt', `label-id: ${layout.partition_table.uuid}`, `device: ${plan.target.disk.path}`, 'unit: sectors',
    `sector-size: ${layout.partition_table.sector_size_bytes}`, '',
    ...layout.partitions.map(p => `${p.path} : start=${p.start_sector}, size=${p.size_bytes / layout.partition_table.sector_size_bytes}, type=${p.type_guid}, uuid=${p.partuuid}`),
  ].join('\n');
}

test('replacement streams contain no disk-destructive operation for every storage option', () => {
  for (const option of ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine']) {
    const { fields } = verify(planText('valid', `${option}--replace`));
    assert.equal(fields[0], 'ok');
    assert.equal(fields[7], 'replace_installation');
    const operations = streamOperations(fields);
    assert.equal(operations[0].id, 'wipe_partition_signatures');
    assert.ok(operations.some(op => op.id === 'format_partitions'));
    assert.equal(operations.at(-1).id, 'register_uefi_boot_entry');
    for (const kind of ['wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'remove_stale_uefi_entries']) {
      assert.ok(!operations.some(op => op.id === kind), kind);
    }
  }
});

test('preservation records exclude only the selected ESP/root and tolerate their new filesystem UUIDs', () => {
  const plan = JSON.parse(planText('valid', 'btrfs-limine--replace'));
  const raw = rawStorage('coexistence-btrfs-limine');
  const dump = dumpFor(plan);
  const before = partitionRecord(plan, dump, raw);
  plan.target.disk.by_id = 'synthetic-confirmed-disk';
  raw.by_id = [];
  assert.equal(partitionRecord(plan, dump, raw), before);
  const record = JSON.parse(before);
  assert.deepEqual(record.partitions.map(p => p.path), ['/dev/nvme0n1p3', '/dev/nvme0n1p4']);
  assert.ok(!record.table.some(line => line.startsWith('/dev/nvme0n1p1 :')));
  assert.ok(!record.table.some(line => line.startsWith('/dev/nvme0n1p2 :')));
  assert.ok(record.table.some(line => line.startsWith('/dev/nvme0n1p3 :')));
  raw.blockdevices[0].children[0].uuid = 'FFFF-FFFF';
  raw.blockdevices[0].children[1].uuid = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  assert.equal(partitionRecord(plan, dump, raw), before);
  raw.blockdevices[0].children[3].uuid = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  assert.notEqual(partitionRecord(plan, dump, raw), before);
});

test('GPT entry changes and missing table metadata fail closed', () => {
  const plan = JSON.parse(planText('valid', 'btrfs-limine--replace'));
  const raw = rawStorage('coexistence-btrfs-limine');
  const dump = dumpFor(plan);
  for (const changed of [
    dump.replace('start=2048', 'start=4096'),
    dump.replace('size=4194304', 'size=1'),
    dump.replace(plan.target.installation.esp.partuuid, 'ffffffff-ffff-4fff-8fff-ffffffffffff'),
    dump.replace('sector-size: 512', 'sector-size: 4096'),
    dump.replace('label: gpt', 'label: dos'),
    dump.split('\n').slice(0, -1).join('\n'),
  ]) assert.throws(() => partitionRecord(plan, changed, raw));
});
