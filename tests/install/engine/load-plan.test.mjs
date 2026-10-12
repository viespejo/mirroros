import assert from 'node:assert/strict';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { withDigest } from '../../../install/plan/digest-plan.mjs';
import { IDENTITY_COMMIT, loadPlanPath, planText, rawStorage, runNode, streamOperations, verify } from './helpers.mjs';

const EXT4 = 'ext4-systemd-boot--password';

test('a valid plan yields its header and the operations in plan order with flattened parameters', () => {
  const { fields, status } = verify(planText('valid', EXT4));
  assert.equal(status, 0);
  assert.deepEqual(fields.slice(0, 7).slice(0, 4), ['ok', JSON.parse(planText('valid', EXT4)).digest.value, 'ext4-systemd-boot', 'true']);
  assert.deepEqual(fields.slice(4, 7), ['/dev/vda', 'virtio-SYNTH-VDA-0001', '17']);
  const operations = streamOperations(fields);
  assert.equal(operations.length, 17);
  assert.equal(operations[0].id, 'wipe_disk_signatures');
  assert.equal(operations[0].parameters.disk, 'virtio-SYNTH-VDA-0001');
  const locale = operations.find(operation => operation.id === 'configure_locale_time_console');
  assert.equal(locale.parameters['locale_categories.LANG'], 'en_US.UTF-8');
  const packages = operations.find(operation => operation.id === 'install_packages').parameters.packages.split('\n');
  assert.equal(packages[0], 'base');
  assert.equal(operations.find(operation => operation.id === 'install_bootloader').parameters['options.editor'], 'false');
});

test('an unknown kind, a different order, and an edited plan are rejected before anything is emitted', () => {
  for (const name of ['operation_kind_unknown--format-disk', 'operation_order_invalid--swapped', 'operations_storage_mismatch--option']) {
    const { fields } = verify(planText('invalid', name));
    assert.equal(fields[0], 'fail', name);
    assert.equal(fields[1], 'blocked', name);
  }
  const edited = verify(planText('invalid', 'digest_mismatch--edited-content'));
  assert.deepEqual([edited.fields[0], edited.fields[1], edited.fields[2]], ['fail', 'invalidated', 'digest_mismatch']);
});

test('a digest other than the confirmed one is a digest mismatch', () => {
  const { fields } = verify(planText('valid', EXT4), { digest: 'f'.repeat(64) });
  assert.deepEqual([fields[0], fields[1], fields[2]], ['fail', 'invalidated', 'digest_mismatch']);
});

test('a plan of another code identity is an engine version mismatch before validation', () => {
  assert.equal(verify(planText('valid', EXT4), { commit: 'b'.repeat(40) }).fields[2], 'engine_version_mismatch');
  assert.equal(verify(planText('valid', EXT4), { dirty: 'true' }).fields[2], 'engine_version_mismatch');
  assert.equal(verify(planText('valid', EXT4), { commit: IDENTITY_COMMIT }).fields[0], 'ok');
});

test('text that is not JSON is blocked', () => {
  const { fields } = verify('not json', { digest: 'x' });
  assert.deepEqual([fields[0], fields[1], fields[2]], ['fail', 'blocked', 'plan_not_json']);
});

test('operations the engine does not implement yet are rejected naming the kind', () => {
  const { fields } = verify(planText('valid', 'btrfs-rescue--locked'));
  assert.deepEqual([fields[0], fields[1], fields[2]], ['fail', 'blocked', 'stage_failed']);
  assert.equal(fields[5], 'create_btrfs_subvolumes');
});

test('a NUL character in the plan is rejected so the stream stays unambiguous', () => {
  const plan = JSON.parse(planText('valid', EXT4));
  plan.operations[0].description = 'a\u0000b';
  const signed = JSON.stringify(withDigest(plan));
  const { fields } = verify(signed);
  assert.equal(fields[0], 'fail');
});

function checkDisk(plan, storage) {
  const directory = mkdtempSync(join(tmpdir(), 'engine-check-'));
  try {
    const file = join(directory, 'storage.json');
    writeFileSync(file, JSON.stringify(storage));
    return runNode(loadPlanPath, ['check-disk', '--storage', file], plan).stdout.split('\0').slice(0, -1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test('the final disk check accepts the confirmed disk and reports identity and layout changes', () => {
  const plan = planText('valid', EXT4);
  assert.deepEqual(checkDisk(plan, rawStorage()), ['ok']);

  const changedSerial = rawStorage();
  changedSerial.blockdevices.find(device => device.path === '/dev/vda').serial = 'OTHER';
  assert.deepEqual(checkDisk(plan, changedSerial).slice(0, 3), ['fail', 'invalidated', 'target_identity_changed']);

  const changedLayout = rawStorage();
  changedLayout.blockdevices.find(device => device.path === '/dev/vda').children.pop();
  assert.deepEqual(checkDisk(plan, changedLayout).slice(0, 3), ['fail', 'invalidated', 'target_layout_changed']);

  const gone = rawStorage();
  gone.blockdevices = gone.blockdevices.filter(device => device.path !== '/dev/vda');
  assert.deepEqual(checkDisk(plan, gone).slice(0, 3), ['fail', 'invalidated', 'target_identity_changed']);
});

test('an LVM, dm-crypt, or RAID device on the confirmed disk is reported as the disk being in use', () => {
  for (const type of ['lvm', 'crypt', 'raid1']) {
    const held = rawStorage();
    const disk = held.blockdevices.find(device => device.path === '/dev/vda');
    disk.children[1].children = [{ path: '/dev/mapper/x', kname: 'dm-0', type }];
    const result = checkDisk(planText('valid', EXT4), held);
    assert.deepEqual([result[0], result[1], result[2]], ['fail', 'blocked', 'target_disk_in_use'], type);
  }
});

test('a mount on the confirmed disk is left to the occupancy check, not reported as a layout change', () => {
  const mounted = rawStorage();
  const disk = mounted.blockdevices.find(device => device.path === '/dev/vda');
  disk.children[0].mountpoints = ['/run/mirroros/target/boot'];
  assert.deepEqual(checkDisk(planText('valid', EXT4), mounted), ['ok']);
});
