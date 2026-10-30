import test from 'node:test';
import assert from 'node:assert/strict';
import { discover } from './helpers.mjs';
import { validateDocument } from '../../../install/discovery/validate-facts.mjs';

const diskOf = document => document.layers.detected.storage.disks[0];
const rawDisk = raw => raw.storage.blockdevices[0];
const evidenceOf = raw => raw.storage.installation_inspections[0];

for (const option of ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine']) {
  test(`replacement identifies ${option} and records both partition identities`, () => {
    const document = discover(`coexistence-${option}`);
    assert.deepEqual(validateDocument(document), []);
    const disk = diskOf(document);
    assert.equal(disk.replace_candidates.length, 1);
    assert.deepEqual(disk.replace_rejections, []);
    const [candidate] = disk.replace_candidates;
    assert.equal(candidate.disk_path, disk.identity.path);
    assert.equal(candidate.storage_option, option);
    assert.deepEqual(candidate.esp, disk.layout.partitions[0]);
    assert.deepEqual(candidate.root, disk.layout.partitions[1]);
    assert.equal(candidate.esp.partition_number, 1);
    assert.equal(candidate.root.start_sector, 4196352);
    assert.equal(disk.layout.partition_table.sector_size_bytes, 512);
    assert.equal(candidate.root.partuuid, '10000000-0000-4000-8000-000000000002');
  });
}

test('coexistence leaves the other ESP and encrypted partition as informational facts', () => {
  const disk = diskOf(discover('coexistence-btrfs-limine'));
  assert.equal(disk.layout.partitions.length, 4);
  assert.equal(disk.layout.partitions[3].fstype, 'crypto_LUKS');
  assert.equal(disk.replace_candidates[0].esp.uuid, 'ABCD-0001');
});

for (const [name, expected] of [['ambiguous-roots', 'ambiguous_roots'], ['missing-esp', 'missing_esp_binding']]) {
  test(`replacement rejects fixture ${name} with an explicit reason`, () => {
    const document = discover(`coexistence-${name}`);
    assert.deepEqual(validateDocument(document), []);
    const disk = diskOf(document);
    assert.deepEqual(disk.replace_candidates, []);
    assert.ok(disk.replace_rejections.every(item => item.reason === expected));
    assert.equal(disk.replace_rejections.length, name === 'ambiguous-roots' ? 2 : 1);
    assert.equal(disk.eligible, true);
  });
}

test('a clean disk has no replacement candidates and no invented rejection', () => {
  const disk = diskOf(discover('reference-vm-empty'));
  assert.deepEqual(disk.replace_candidates, []);
  assert.deepEqual(disk.replace_rejections, []);
});

const failures = [
  ['unsupported_root', raw => { rawDisk(raw).children[1].parttype = 'wrong'; }],
  ['unsupported_root', raw => { rawDisk(raw).children[1].fstype = 'crypto_LUKS'; }],
  ['unsupported_root', raw => { rawDisk(raw).pttype = 'dos'; }],
  ['incomplete_identity', raw => { delete rawDisk(raw).children[1].partuuid; }],
  ['incomplete_identity', raw => { delete rawDisk(raw).children[0].start; }],
  ['incomplete_identity', raw => { rawDisk(raw).children[0].size = 0; }],
  ['disk_ineligible', raw => { rawDisk(raw).children[1].mountpoints = ['/mnt']; }],
  ['disk_ineligible', raw => { rawDisk(raw).ro = true; }],
  ['missing_esp_binding', raw => { evidenceOf(raw).fstab_matches = false; }],
  ['inspection_unavailable', raw => { raw.storage.installation_inspections = []; }],
  ['inspection_unavailable', raw => { evidenceOf(raw).status = 'unreadable'; }],
  ['inspection_unavailable', raw => { raw.storage.installation_inspections.push({ ...evidenceOf(raw) }); }],
  ['ambiguous_boot_configuration', raw => { evidenceOf(raw).systemd_boot_present = true; }],
  ['ambiguous_boot_configuration', raw => { evidenceOf(raw).limine_present = false; }],
  ['boot_root_mismatch', raw => { evidenceOf(raw).limine_matches = false; }],
  ['ambiguous_identity', raw => { rawDisk(raw).children[2].uuid = rawDisk(raw).children[0].uuid; }],
  ['ambiguous_identity', raw => { rawDisk(raw).children[2].uuid = rawDisk(raw).children[0].uuid.toLowerCase(); }],
  ['ambiguous_identity', raw => { rawDisk(raw).children[2].partuuid = rawDisk(raw).children[1].partuuid; }],
];
for (const [index, [expected, mutateRaw]] of failures.entries()) {
  test(`replacement fails closed: ${expected} (${index + 1})`, () => {
    const document = discover('coexistence-btrfs-limine', { mutateRaw });
    const disk = diskOf(document);
    assert.deepEqual(validateDocument(document), []);
    assert.deepEqual(disk.replace_candidates, []);
    // The unrelated ESP may lack evidence too; the bound ESP's failure must not be hidden.
    assert.equal(disk.replace_rejections.length, 1);
    assert.equal(disk.replace_rejections[0].reason, expected);
  });
}

test('two ESPs with binding evidence are rejected rather than selected', () => {
  const disk = diskOf(discover('coexistence-btrfs-limine', { mutateRaw(raw) {
    Object.assign(raw.storage.installation_inspections[1], { fstab_matches: true, limine_matches: true });
  } }));
  assert.deepEqual(disk.replace_candidates, []);
  assert.equal(disk.replace_rejections[0].reason, 'ambiguous_esp_binding');
});

for (const [name, mutate] of [
  ['different disk', c => { c.disk_path = '/dev/other'; }],
  ['changed root identity', c => { c.root.partuuid = '30000000-0000-4000-8000-000000000002'; }],
  ['missing geometry', c => { delete c.esp.start_sector; }],
  ['unknown field', c => { c.esp.unsafe = true; }],
  ['wrong option', c => { c.storage_option = 'ext4-systemd-boot'; }],
]) {
  test(`validator refuses replacement candidate with ${name}`, () => {
    const document = discover('coexistence-btrfs-limine');
    mutate(diskOf(document).replace_candidates[0]);
    assert.ok(validateDocument(document).length > 0);
  });
}

test('validator refuses a candidate whose ESP volume ID is duplicated in the layout', () => {
  const document = discover('coexistence-btrfs-limine');
  diskOf(document).layout.partitions[2].uuid = diskOf(document).layout.partitions[0].uuid.toLowerCase();
  assert.ok(validateDocument(document).length > 0);
});

test('additive replacement fields remain optional for earlier format-2 documents', () => {
  const document = discover('reference-vm-empty');
  for (const disk of document.layers.detected.storage.disks) {
    delete disk.replace_candidates;
    delete disk.replace_rejections;
  }
  assert.deepEqual(validateDocument(document), []);
});
