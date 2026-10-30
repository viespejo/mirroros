import assert from 'node:assert/strict';
import test from 'node:test';

import { applicableChecks, evaluateChecks } from '../../../install/postconditions/evaluate.mjs';
import { changed, goodObservations, planFixture } from './helpers.mjs';

const OPTIONS = ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'];
const failures = (plan, observations) => evaluateChecks(plan, observations).failed_checks;

for (const option of OPTIONS) {
  for (const mode of ['password', 'replace']) {
    test(`${option} ${mode}: UEFI entry and delivered command pass`, () => {
      const plan = planFixture(`${option}--${mode}`);
      const observations = goodObservations(plan);
      assert.equal(evaluateChecks(plan, observations).status, 'passed');
      assert.equal(applicableChecks(plan).includes('untouched_partitions'), mode === 'replace');
    });

    test(`${option} ${mode}: UEFI entry fails closed on missing, duplicate, wrong path or identity, and bad order`, () => {
      const plan = planFixture(`${option}--${mode}`);
      const good = goodObservations(plan);
      const listing = good.get('uefi_entries');
      const entry = listing.split('\n')[1];
      for (const value of [undefined, '', listing.replace('0001,0002', '0002,0001'),
        listing.replace('0001,0002', '0001,0001'), listing.replace('0001,0002', '0001,9999'),
        `${listing}\nBootOrder: 0001,0002`, `${listing}\n${entry.replace('0001', '0003')}`,
        listing.replace(/File\([^)]*\)/, 'File(\\EFI\\wrong.efi)'),
        listing.replace(good.get('partuuid:/boot'), 'ffffffff-ffff-4fff-8fff-ffffffffffff'),
        listing.replace('\tHD(', ' HD(')]) {
        assert.deepEqual(failures(plan, changed(good, { uefi_entries: value })), ['uefi_boot_entry']);
      }
      for (const value of [undefined, '', 'not-a-guid']) {
        assert.deepEqual(failures(plan, changed(good, { 'partuuid:/boot': value })), ['uefi_boot_entry']);
      }
      const uppercase = listing.replace(/HD\([^)]*\)\/File\([^)]*\)/, match => match.toUpperCase());
      assert.equal(evaluateChecks(plan, changed(good, { uefi_entries: uppercase })).status, 'passed');
      const spoofed = `BootOrder: 0002\nBoot0002* ${entry.slice(entry.indexOf('HD('))}\tVenHw(example)`;
      assert.deepEqual(failures(plan, changed(good, { uefi_entries: spoofed })), ['uefi_boot_entry']);
    });
  }

  test(`${option}: preservation compares fresh table and identities with the pre-run baseline`, () => {
    const plan = planFixture(`${option}--replace`);
    if (plan.target.disk.current_layout.partitions.length === 2) {
      const other = planFixture('btrfs-limine--replace').target.disk.current_layout.partitions.slice(2);
      plan.target.disk.current_layout.partitions.push(...other.map(p => ({ ...p,
        path: `${plan.target.disk.path}${/\d$/.test(plan.target.disk.path) ? 'p' : ''}${p.partition_number}`,
      })));
    }
    const good = goodObservations(plan);
    for (const value of [undefined, '', '{', '{}', '{"table":[],"partitions":[]}']) {
      assert.deepEqual(failures(plan, changed(good, { untouched_partitions_before: value })), ['untouched_partitions']);
    }
    for (const key of ['partition_table', 'storage']) {
      assert.deepEqual(failures(plan, changed(good, { [key]: undefined })), ['untouched_partitions']);
    }
    const table = good.get('partition_table');
    assert.deepEqual(failures(plan, changed(good, { partition_table: table.replace('unit: sectors', 'unit: bytes') })), ['untouched_partitions']);
    const other = plan.target.disk.current_layout.partitions[2];
    assert.deepEqual(failures(plan, changed(good, { partition_table: table.replace(`start=${other.start_sector}`, `start=${other.start_sector + 1}`) })), ['untouched_partitions']);
    assert.deepEqual(failures(plan, changed(good, { partition_table: table.split('\n').filter(line => !line.startsWith(other.path)).join('\n') })), ['untouched_partitions']);
    for (const field of ['uuid', 'partuuid', 'size', 'parttype', 'start', 'label']) {
      const raw = JSON.parse(good.get('storage'));
      raw.blockdevices[0].children[2][field] = typeof raw.blockdevices[0].children[2][field] === 'number' ? 123 : 'changed';
      assert.deepEqual(failures(plan, changed(good, { storage: JSON.stringify(raw) })), ['untouched_partitions'], field);
    }
    const raw = JSON.parse(good.get('storage'));
    raw.blockdevices[0].children[0].uuid = 'FFFF-FFFF';
    raw.blockdevices[0].children[1].uuid = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
    assert.equal(evaluateChecks(plan, changed(good, { storage: JSON.stringify(raw) })).status, 'passed');
    const wrongGuid = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
    assert.deepEqual(failures(plan, changed(good, {
      'partuuid:/boot': wrongGuid,
      uefi_entries: good.get('uefi_entries').replace(good.get('partuuid:/boot'), wrongGuid),
    })), ['uefi_boot_entry']);
  });
}

test('boot-first delivery requires the exact launcher, a nonempty executable command and its regular library', () => {
  const plan = planFixture('btrfs-limine--password');
  const good = goodObservations(plan);
  for (const value of [undefined, '/usr/bin/other', '../lib/mirroros/operations/boot-first']) {
    assert.deepEqual(failures(plan, changed(good, { 'link:/usr/local/bin/mirroros-boot-first': value })), ['boot_first_delivered']);
  }
  for (const path of ['/usr/local/lib/mirroros/operations/boot-first', '/usr/local/lib/mirroros/operations/lib/uefi-boot-entry.sh']) {
    for (const value of [undefined, 'regular file|644|0', 'symbolic link|777|1024', 'regular file|600|1024']) {
      assert.deepEqual(failures(plan, changed(good, { [`stat:${path}`]: value })), ['boot_first_delivered']);
    }
  }
});
