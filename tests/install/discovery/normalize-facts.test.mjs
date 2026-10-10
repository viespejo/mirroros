import test from 'node:test';
import assert from 'node:assert/strict';
import { renderSummary } from '../../../install/discovery/write-facts.mjs';
import { exitStatusFor, validateDocument } from '../../../install/discovery/validate-facts.mjs';
import { PLANTED_VALUES, codes, discover, fixturesRoot, readFixture } from './helpers.mjs';
import { join } from 'node:path';

const RAW_FIXTURES = [
  'reference-vm-empty',
  'reference-vm-layout',
  'bios',
  'uefi-32bit',
  'efivars-unavailable',
  'secure-boot-enabled',
  'secure-boot-unknown',
  'firmware-missing-fact',
  'network-no-route',
  'network-dns-failed',
  'network-https-failed',
  'disks-none-eligible',
  'disks-mixed',
  'identity-contradiction',
  'synthetic-laptop',
  'planted-sensitive',
];

const EXPECTED = [
  ['reference-vm-empty', [], [], 0],
  ['reference-vm-layout', [], [], 0],
  ['bios', ['boot_mode_not_uefi'], [], 2],
  ['uefi-32bit', ['uefi_platform_32bit'], [], 2],
  ['efivars-unavailable', ['efivars_unavailable'], [], 2],
  ['secure-boot-enabled', ['secure_boot_enabled'], [], 2],
  ['secure-boot-unknown', [], ['secure_boot_unknown'], 0],
  ['firmware-missing-fact', ['fact_missing'], [], 2],
  ['network-no-route', ['network_no_default_route'], [], 2],
  ['network-dns-failed', ['network_dns_failed'], [], 2],
  ['network-https-failed', ['network_https_failed'], [], 2],
  ['identity-contradiction', ['target_identity_mismatch'], [], 2],
  ['synthetic-laptop', ['target_identity_mismatch'], [], 2],
  ['disks-mixed', [], [], 0],
];

for (const [name, reasons, warnings, exit] of EXPECTED) {
  test(`fixture ${name} on reference-vm yields ${exit === 0 ? 'valid' : reasons.join(', ')}`, () => {
    const document = discover(name);
    assert.deepEqual(codes(document.validation.reasons), reasons);
    assert.deepEqual(codes(document.validation.warnings), warnings);
    assert.equal(exitStatusFor(document), exit);
    assert.equal(document.validation.status, exit === 0 ? 'valid' : 'invalid');
  });
}

test('every fixture produces a document that passes its own validator', () => {
  for (const name of RAW_FIXTURES) {
    assert.deepEqual(validateDocument(discover(name)), [], name);
  }
});

test('no eligible disk reports one reason per disk and never selects one', () => {
  const document = discover('disks-none-eligible');
  assert.deepEqual(codes(document.validation.reasons), ['no_eligible_disk', ...Array(8).fill('disk_ineligible')]);
  const reasons = Object.fromEntries(document.layers.detected.storage.disks
    .map(disk => [disk.identity.path, disk.ineligible_reasons]));
  assert.deepEqual(reasons, {
    '/dev/sdb': ['removable'],
    '/dev/sdc': ['below_minimum_size'],
    '/dev/sdd': ['live_medium', 'mounted'],
    '/dev/sde': ['mounted'],
    '/dev/sdf': ['read_only'],
    '/dev/loop0': ['loop', 'below_minimum_size'],
    '/dev/sr0': ['rom', 'removable', 'below_minimum_size'],
    '/dev/zram0': ['zram', 'mounted', 'below_minimum_size'],
  });
  assert.equal(JSON.stringify(document).includes('selected'), false);
});

test('an existing layout does not make a disk ineligible and is recorded', () => {
  const document = discover('reference-vm-layout');
  const [disk] = document.layers.detected.storage.disks;
  assert.equal(disk.eligible, true);
  assert.equal(disk.ineligible_reasons, undefined);
  assert.equal(disk.layout.partition_table.type, 'gpt');
  assert.deepEqual(disk.layout.partitions.map(partition => partition.label), ['SYNTH-ESP', 'SYNTH-DATA']);
});

test('the live medium is excluded and the eligible disk keeps its stable identity', () => {
  const document = discover('disks-mixed');
  const eligible = document.layers.detected.storage.disks.filter(disk => disk.eligible);
  assert.equal(eligible.length, 1);
  assert.deepEqual(eligible[0].identity, {
    path: '/dev/nvme0n1',
    by_id: 'nvme-eui.0000000000000001',
    wwn: 'eui.0000000000000001',
    serial: 'SYNTH-NVME-0001',
    model: 'SYNTH NVMe 1TB',
    size_bytes: 1000204886016,
  });
  assert.equal(eligible[0].layout.partitions.length, 1);
});

test('unavailable identity values are omitted', () => {
  const [disk] = discover('reference-vm-empty').layers.detected.storage.disks;
  assert.deepEqual(disk.identity, {
    path: '/dev/vda',
    by_id: 'virtio-SYNTH-VDA-0001',
    serial: 'SYNTH-VDA-0001',
    size_bytes: 34359738368,
  });
});

test('framework-13-pro-amd exits 2 with a pending-capture reason', () => {
  const document = discover('synthetic-laptop', { targetId: 'framework-13-pro-amd' });
  assert.deepEqual(codes(document.validation.reasons), ['target_identity_pending_capture']);
  assert.equal(exitStatusFor(document), 2);
  assert.match(document.validation.reasons[0].next_step, /sys_vendor and product_name/);
});

test('framework-13-pro-amd in a virtual machine is also contradictory', () => {
  const document = discover('reference-vm-empty', { targetId: 'framework-13-pro-amd' });
  assert.deepEqual(codes(document.validation.reasons), ['target_identity_mismatch', 'target_identity_pending_capture']);
});

test('a defined synthetic laptop target is valid and records its capabilities', () => {
  const document = discover('synthetic-laptop', { targetId: 'synthetic-laptop', root: join(fixturesRoot, 'targets') });
  assert.equal(document.validation.status, 'valid');
  const { hardware, network } = document.layers.detected;
  assert.equal(hardware.graphics[0].vendor, 'amd');
  assert.equal(hardware.battery_present, true);
  assert.equal(network.wifi_present, true);
  assert.equal(hardware.wifi_reference, 'network.wifi_present');
});

test('graphics devices are classified by vendor id', () => {
  const document = discover('reference-vm-empty');
  assert.deepEqual(document.layers.detected.hardware.graphics, [
    { vendor: 'qemu_virtual', vendor_id: '1234', device_id: '1111', driver: 'bochs-drm', boot_vga: true },
  ]);
});

test('unknown, missing, and malformed target ids are rejected', () => {
  assert.deepEqual(codes(discover('reference-vm-empty', { targetId: 'no-such-target' }).validation.reasons), ['target_unknown']);
  assert.deepEqual(codes(discover('reference-vm-empty', { targetId: '../targets' }).validation.reasons), ['target_unknown']);
  const empty = discover('reference-vm-empty', { targetId: '' });
  assert.deepEqual(codes(empty.validation.reasons), ['target_unknown']);
  assert.equal(empty.source.requested_profile_id, undefined);
  assert.deepEqual(empty.profile, { status: 'unqualified' });
});

test('effective values carry the source of the winning layer', () => {
  const { effective } = discover('reference-vm-empty');
  assert.deepEqual(effective['policy.minimum_disk_bytes'], {
    value: 21474836480,
    provenance: 'technical_necessity',
    source: 'baseline',
  });
  assert.deepEqual(effective['firmware.boot_mode'], { value: 'uefi', source: 'detected' });
  assert.equal(effective['network.ready'].source, 'detected');
  for (const entry of Object.values(effective)) assert.ok(['baseline', 'detected', 'override', 'runtime'].includes(entry.source));
});

test('an allowlisted override wins over the baseline while the layers stay separate', () => {
  const document = discover('reference-vm-empty', { overrideFixture: 'valid' });
  assert.deepEqual(document.layers.portable_baseline.policy.minimum_disk_bytes.value, 21474836480);
  assert.deepEqual(document.layers.target_override.policy, { minimum_disk_bytes: 42949672960 });
  assert.deepEqual(document.effective['policy.minimum_disk_bytes'], { value: 42949672960, source: 'override' });
  assert.equal(document.layers.detected.storage.disks[0].eligible, false);
  assert.deepEqual(document.layers.detected.storage.disks[0].ineligible_reasons, ['below_minimum_size']);
  assert.deepEqual(readFixture('raw/reference-vm-empty.json').storage.blockdevices[0].size, 34359738368);
});

test('unknown override keys, detected-fact overrides, and invalid values exit 2', () => {
  const unknown = discover('reference-vm-empty', { overrideFixture: 'unknown-key' });
  assert.deepEqual(codes(unknown.validation.reasons).filter(code => code.startsWith('override_')), ['override_unknown_key']);
  assert.equal(exitStatusFor(unknown), 2);
  assert.equal(unknown.layers.target_override.policy.selected_disk, undefined);

  const detected = discover('reference-vm-empty', { overrideFixture: 'detected-fact' });
  assert.deepEqual(codes(detected.validation.reasons), ['override_detected_fact']);
  assert.deepEqual(detected.layers.target_override.policy, {});
  assert.equal(detected.effective['firmware.boot_mode'].source, 'detected');

  const invalid = discover('reference-vm-empty', { overrideFixture: 'invalid-value' });
  assert.deepEqual(codes(invalid.validation.reasons), ['override_invalid_value']);
  assert.equal(invalid.effective['policy.https_probe_timeout_seconds'].source, 'baseline');
});

test('runtime private input holds names only and never values', () => {
  const document = discover('reference-vm-empty', { runtimeNames: ['root_password'] });
  assert.deepEqual(document.layers.runtime_private, { required_inputs: ['root_password'] });
  assert.deepEqual(document.effective['runtime.root_password'], { source: 'runtime', private: true });
});

test('planted sensitive values never reach the document or the summary', () => {
  const document = discover('planted-sensitive');
  const serialized = JSON.stringify(document);
  const summary = renderSummary(document);
  for (const planted of PLANTED_VALUES) {
    assert.equal(serialized.includes(planted), false, `document leaks ${planted}`);
    assert.equal(summary.includes(planted), false, `summary leaks ${planted}`);
  }
  for (const text of [serialized, summary]) {
    assert.equal(/(?:[0-9a-f]{2}:){5}[0-9a-f]{2}/i.test(text), false);
    assert.equal(/PLANTED/.test(text), false);
  }
  assert.equal(document.layers.detected.hardware.battery_present, true);
  assert.equal(serialized.includes('SYNTH-VDA-0001'), true);
});
