import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  CHECK_IDS,
  MAX_DETAIL_LENGTH,
  applicableChecks,
  evaluateChecks,
  parseObservations,
  validateResult,
} from '../../../install/postconditions/evaluate.mjs';
import {
  ESP_UUID, OFFSET, ROOT_UUID, VALID_PLANS, changed, evaluatePath, goodObservations, planFixture,
} from './helpers.mjs';

const failedIds = (plan, observations) => evaluateChecks(plan, observations).failed_checks;
const detailOf = (plan, observations, id) => evaluateChecks(plan, observations).checks.find(check => check.id === id).detail;

test('the checks that apply follow the storage option and the hibernation state', () => {
  const expected = {
    'ext4-systemd-boot--password': ['bootloader_systemd_boot', 'swapfile'],
    'ext4-systemd-boot--hibernation-disabled': ['bootloader_systemd_boot', 'swap_absent'],
    'btrfs-rescue--locked': ['bootloader_systemd_boot', 'swapfile'],
    'btrfs-rescue--hibernation-disabled': ['bootloader_systemd_boot', 'swap_absent'],
    'btrfs-limine--password': ['bootloader_limine', 'swapfile'],
    'btrfs-limine--hibernation-disabled': ['bootloader_limine', 'swap_absent'],
  };
  for (const [name, [loader, swap]] of Object.entries(expected)) {
    const ids = applicableChecks(planFixture(name));
    assert.ok(ids.includes(loader) && ids.includes(swap), name);
    assert.equal(ids.includes('bootloader_limine') && ids.includes('bootloader_systemd_boot'), false, name);
    assert.equal(ids.includes('swapfile') && ids.includes('swap_absent'), false, name);
    assert.deepEqual(ids, CHECK_IDS.filter(id => ids.includes(id)), `${name} keeps the declared order`);
  }
});

test('a correct installation passes every check for every storage option, with and without hibernation', () => {
  for (const name of VALID_PLANS) {
    const plan = planFixture(name);
    const result = evaluateChecks(plan, goodObservations(plan));
    assert.equal(result.status, 'passed', `${name}: ${JSON.stringify(result.checks.filter(check => check.status === 'failed'))}`);
    assert.deepEqual(result.failed_checks, []);
    assert.deepEqual(result.checks.map(check => check.id), applicableChecks(plan));
    assert.deepEqual(validateResult(result, plan), [], name);
    assert.ok(result.checks.every(check => !('detail' in check)));
  }
});

test('every check runs even after a failure, and none is skipped', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const result = evaluateChecks(plan, new Map());
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.checks.map(check => check.id), applicableChecks(plan));
  assert.ok(result.checks.every(check => check.status === 'failed' && check.detail.length > 0));
});

test('a missing kernel fails kernel_installed alone and names the file', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const observations = changed(goodObservations(plan), { 'stat:/boot/vmlinuz-linux': undefined });
  assert.deepEqual(failedIds(plan, observations), ['kernel_installed']);
  assert.match(detailOf(plan, observations, 'kernel_installed'), /\/boot\/vmlinuz-linux is missing/);
});

test('kernel_installed rejects an empty or non-regular file, a missing fallback image, and a missing package', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  assert.deepEqual(failedIds(plan, changed(good, { 'stat:/boot/initramfs-linux.img': 'regular empty file|644|0' })), ['kernel_installed']);
  assert.deepEqual(failedIds(plan, changed(good, { 'stat:/boot/initramfs-linux.img': 'directory|755|4096' })), ['kernel_installed']);
  assert.ok(failedIds(plan, changed(good, { 'stat:/boot/initramfs-linux-fallback.img': undefined })).includes('kernel_installed'));
  assert.ok(failedIds(plan, changed(good, { packages: 'base 1-1\nzram-generator 1-1\nnetworkmanager 1-1\namd-ucode 1-1' })).includes('kernel_installed'));
  const limine = planFixture('btrfs-limine--password');
  const withoutFallback = goodObservations(limine);
  assert.equal(withoutFallback.has('stat:/boot/initramfs-linux-fallback.img'), false);
  assert.equal(evaluateChecks(limine, withoutFallback).status, 'passed');
});

test('mounts_active compares filesystem types, the ESP options, and every planned Btrfs subvolume and option', () => {
  const ext4 = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(ext4);
  assert.deepEqual(failedIds(ext4, changed(good, { mounts: good.get('mounts').replace('ext4', 'xfs') })), ['mounts_active']);
  assert.deepEqual(failedIds(ext4, changed(good, { mounts: good.get('mounts').replace(',umask=0077', '') })), ['mounts_active']);
  assert.deepEqual(failedIds(ext4, changed(good, { mounts: undefined })), ['mounts_active']);
  const btrfs = planFixture('btrfs-rescue--password');
  const base = goodObservations(btrfs);
  const mounts = base.get('mounts').split('\n');
  assert.deepEqual(failedIds(btrfs, changed(base, { mounts: mounts.filter(line => !line.includes('/@home')).join('\n') })), ['mounts_active']);
  assert.deepEqual(failedIds(btrfs, changed(base, { mounts: base.get('mounts').replace('compress=zstd:1,', '') })), ['mounts_active']);
  assert.deepEqual(failedIds(btrfs, changed(base, { mounts: base.get('mounts').replace('subvol=/@log', 'subvol=/@other') })), ['mounts_active']);
  assert.match(detailOf(btrfs, changed(base, { mounts: mounts.filter(line => !line.includes('/@swap')).join('\n') }), 'mounts_active'), /@swap/);
});

test('mount paths with escaped blanks are decoded', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const root = '/run/root with space/target';
  const good = goodObservations(plan);
  const escaped = good.get('mounts').replaceAll('/run/mirroros/target', root.replaceAll(' ', '\\x20'));
  assert.equal(evaluateChecks(plan, changed(good, { target_root: root, mounts: escaped })).status, 'passed');
});

test('fstab_by_uuid compares the UUIDs read from the devices and rejects subvolume ids and wrong swap lines', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  const fstab = good.get('text:/etc/fstab');
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': fstab.replace(ROOT_UUID, '99999999-2222-4333-8444-555555555555') })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': fstab.replace(`UUID=${ESP_UUID}`, '/dev/vda1') })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': `${fstab}\n# subvolid=1` })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': fstab.replace('pri=0', 'pri=5') })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': fstab.split('\n').filter(line => !line.includes(' swap ')).join('\n') })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': `${fstab}\n/swapfile2 none swap defaults 0 0` })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/fstab': undefined })), ['fstab_by_uuid']);
  assert.deepEqual(failedIds(plan, changed(good, { 'uuid:/': undefined })).includes('fstab_by_uuid'), true);
  const btrfs = planFixture('btrfs-rescue--password');
  const base = goodObservations(btrfs);
  assert.deepEqual(failedIds(btrfs, changed(base, { 'text:/etc/fstab': base.get('text:/etc/fstab').replace('subvol=/@home', 'subvol=/@elsewhere') })), ['fstab_by_uuid']);
  const disabled = planFixture('ext4-systemd-boot--hibernation-disabled');
  const withoutSwap = goodObservations(disabled);
  assert.deepEqual(failedIds(disabled, changed(withoutSwap, { 'text:/etc/fstab': `${withoutSwap.get('text:/etc/fstab')}\n/swapfile none swap defaults 0 0` })), ['fstab_by_uuid', 'swap_absent']);
});

test('systemd-boot content: loader, entry options, fallback entry, and EFI binaries', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  const entry = good.get('text:/boot/loader/entries/mirroros.conf');
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/loader.conf': 'default other.conf\ntimeout 3\neditor no' })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/loader.conf': 'default mirroros.conf\ntimeout 3\neditor yes' })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/entries/mirroros.conf': entry.replace('title MirrorOS', 'title Other') })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/entries/mirroros.conf': entry.replace('rw ', 'ro ') })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/entries/mirroros-fallback.conf': undefined })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'stat:/boot/EFI/systemd/systemd-bootx64.efi': undefined })), ['bootloader_systemd_boot']);
  assert.deepEqual(failedIds(plan, changed(good, { 'stat:/boot/EFI/BOOT/BOOTX64.EFI': 'regular empty file|644|0' })), ['bootloader_systemd_boot']);
  const rescue = planFixture('btrfs-rescue--password');
  const base = goodObservations(rescue);
  assert.match(base.get('text:/boot/loader/entries/mirroros.conf'), /rootflags=subvol=@/);
  const noFlags = base.get('text:/boot/loader/entries/mirroros.conf').replace(' rootflags=subvol=@', '');
  assert.deepEqual(failedIds(rescue, changed(base, { 'text:/boot/loader/entries/mirroros.conf': noFlags })), ['bootloader_systemd_boot']);
});

test('a fallback entry that the plan does not have is a failure', () => {
  const plan = structuredClone(planFixture('ext4-systemd-boot--password'));
  plan.operations.find(item => item.kind === 'install_bootloader').parameters.options.fallback_entry = false;
  const good = goodObservations(plan);
  assert.equal(evaluateChecks(plan, good).status, 'passed');
  const withFallback = changed(good, {
    'text:/boot/loader/entries/mirroros-fallback.conf': good.get('text:/boot/loader/entries/mirroros.conf').replace('title MirrorOS', 'title MirrorOS (fallback initramfs)'),
  });
  assert.deepEqual(failedIds(plan, withFallback), ['bootloader_systemd_boot']);
});

test('Limine content: defaults, configuration, snapshot entries, referenced files, and unified kernel images', () => {
  const plan = planFixture('btrfs-limine--password');
  const good = goodObservations(plan);
  const config = good.get('text:/boot/limine.conf');
  const defaults = good.get('text:/etc/default/limine');
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/default/limine': defaults.replace('SKIP_UEFI=yes', 'SKIP_UEFI=no') })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/default/limine': defaults.replace(' rootflags=subvol=@', '') })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/default/limine': undefined })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'stat:/boot/EFI/BOOT/BOOTX64.EFI': undefined })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/limine.conf': config.replace('timeout: 3', 'timeout: 9') })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/limine.conf': config.slice(0, config.indexOf('//Snapshots')) })), ['bootloader_limine']);
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/limine.conf': undefined })), ['bootloader_limine', 'boot_root_uuid', 'boot_zswap_disabled', 'boot_resume_parameters']);
  assert.deepEqual(failedIds(plan, changed(good, { 'list:/boot/EFI/Linux': 'mirroros.efi\n' })), ['bootloader_limine']);
  assert.equal(evaluateChecks(plan, changed(good, { 'list:/boot/EFI/Linux': '' })).status, 'passed');
  const reference = [...good.keys()].find(key => key.endsWith('/vmlinuz'));
  assert.deepEqual(failedIds(plan, changed(good, { [reference]: undefined })), ['bootloader_limine']);
  assert.match(detailOf(plan, changed(good, { [reference]: undefined }), 'bootloader_limine'), /vmlinuz, which is missing/);
  const snapshotReference = [...good.keys()].find(key => key.includes('limine_history/initramfs'));
  assert.deepEqual(failedIds(plan, changed(good, { [snapshotReference]: undefined })), ['bootloader_limine']);
});

test('boot_root_uuid compares the entries with the UUID read from the mounted device', () => {
  for (const name of ['ext4-systemd-boot--password', 'btrfs-limine--password']) {
    const plan = planFixture(name);
    const good = goodObservations(plan);
    const result = evaluateChecks(plan, changed(good, { 'uuid:/': '99999999-2222-4333-8444-555555555555' }));
    assert.ok(result.failed_checks.includes('boot_root_uuid'), name);
    assert.match(result.checks.find(check => check.id === 'boot_root_uuid').detail, new RegExp(ROOT_UUID));
    assert.match(result.checks.find(check => check.id === 'boot_root_uuid').detail, /99999999-2222/);
    assert.ok(result.failed_checks.includes('fstab_by_uuid'), name);
  }
});

test('boot_zswap_disabled requires zswap.enabled=0 in every normal entry', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  const fallback = good.get('text:/boot/loader/entries/mirroros-fallback.conf');
  const observations = changed(good, { 'text:/boot/loader/entries/mirroros-fallback.conf': fallback.replace(' zswap.enabled=0', ' zswap.enabled=1') });
  assert.ok(failedIds(plan, observations).includes('boot_zswap_disabled'));
  assert.match(detailOf(plan, observations, 'boot_zswap_disabled'), /mirroros-fallback\.conf lacks zswap\.enabled=0/);
});

test('a resume offset that differs from the swapfile fails boot_resume_parameters and reports both values', () => {
  for (const name of ['ext4-systemd-boot--password', 'btrfs-rescue--password', 'btrfs-limine--password']) {
    const plan = planFixture(name);
    const good = goodObservations(plan);
    const swapPath = name.startsWith('ext4') ? '/swapfile' : '/swap/swapfile';
    const observations = changed(good, { [`offset:${swapPath}`]: '1234' });
    assert.deepEqual(failedIds(plan, observations), ['boot_resume_parameters'], name);
    const detail = detailOf(plan, observations, 'boot_resume_parameters');
    assert.match(detail, new RegExp(`resume_offset=${OFFSET}`));
    assert.match(detail, /swapfile offset is 1234/);
  }
});

test('boot_resume_parameters checks the resume device and an offset that cannot be computed', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  assert.deepEqual(failedIds(plan, changed(good, { 'offset:/swapfile': 'unavailable' })).includes('boot_resume_parameters'), true);
  const entry = good.get('text:/boot/loader/entries/mirroros.conf');
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/boot/loader/entries/mirroros.conf': entry.replace(`resume=UUID=${ROOT_UUID}`, 'resume=UUID=99999999-2222-4333-8444-555555555555') })).includes('boot_resume_parameters'), true);
});

test('without hibernation no entry may carry resume parameters, and the swap checks are inverted', () => {
  for (const name of ['ext4-systemd-boot--hibernation-disabled', 'btrfs-rescue--hibernation-disabled', 'btrfs-limine--hibernation-disabled']) {
    const plan = planFixture(name);
    const good = goodObservations(plan);
    assert.equal(evaluateChecks(plan, good).status, 'passed', name);
    const path = name.startsWith('btrfs-limine') ? 'text:/etc/default/limine' : 'text:/boot/loader/entries/mirroros.conf';
    const text = good.get(path);
    const infected = changed(good, { [path]: text.includes('"') ? text.replace(' rw ', ' rw resume=UUID=x ') : text.replace(' rw ', ' rw resume_offset=5 ') });
    assert.deepEqual(failedIds(plan, infected), name.startsWith('btrfs-limine') ? ['bootloader_limine', 'boot_resume_parameters'] : ['bootloader_systemd_boot', 'boot_resume_parameters'], name);
    assert.deepEqual(failedIds(plan, changed(good, { 'stat:/swapfile': file() })), ['swap_absent'], name);
    assert.deepEqual(failedIds(plan, changed(good, { 'stat:/swap/swapfile': file() })), ['swap_absent'], name);
  }
  const btrfs = planFixture('btrfs-rescue--hibernation-disabled');
  const good = goodObservations(btrfs);
  assert.deepEqual(failedIds(btrfs, changed(good, { mounts: `${good.get('mounts')}\n/run/mirroros/target/swap /dev/vda2[/@swap] btrfs rw,subvol=/@swap` })), ['swap_absent']);
});

function file() {
  return 'regular file|600|4096';
}

test('swapfile checks mode, size, NOCOW, the @swap subvolume, and the offset', () => {
  const ext4 = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(ext4);
  assert.deepEqual(failedIds(ext4, changed(good, { 'stat:/swapfile': good.get('stat:/swapfile').replace('|600|', '|644|') })), ['swapfile']);
  assert.deepEqual(failedIds(ext4, changed(good, { 'stat:/swapfile': 'regular file|600|4096' })), ['swapfile']);
  assert.deepEqual(failedIds(ext4, changed(good, { 'stat:/swapfile': undefined })), ['swapfile']);
  assert.deepEqual(failedIds(ext4, changed(good, { 'stat:/swapfile': 'symbolic link|777|10' })).includes('swapfile'), true);
  const btrfs = planFixture('btrfs-rescue--password');
  const base = goodObservations(btrfs);
  assert.deepEqual(failedIds(btrfs, changed(base, { 'attrs:/swap/swapfile': '--------------------' })), ['swapfile']);
  assert.deepEqual(failedIds(btrfs, changed(base, { 'attrs:/swap/swapfile': undefined })), ['swapfile']);
  const mounts = base.get('mounts').split('\n').filter(line => !line.includes('/@swap')).join('\n');
  assert.ok(failedIds(btrfs, changed(base, { mounts })).includes('swapfile'));
});

test('zram and memory settings compare the asset hash and every planned setting', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  const zram = operationOf(plan, 'configure_zram').parameters.destination;
  const memory = operationOf(plan, 'configure_memory_reclaim').parameters.destination;
  assert.deepEqual(failedIds(plan, changed(good, { [`sha256:${zram}`]: 'f'.repeat(64) })), ['zram_configuration']);
  assert.deepEqual(failedIds(plan, changed(good, { [`text:${zram}`]: good.get(`text:${zram}`).replace('zstd', 'lz4') })), ['zram_configuration']);
  assert.deepEqual(failedIds(plan, changed(good, { [`text:${zram}`]: undefined })), ['zram_configuration']);
  assert.ok(failedIds(plan, changed(good, { packages: good.get('packages').replace('zram-generator 1-1\n', '') })).includes('zram_configuration'));
  assert.deepEqual(failedIds(plan, changed(good, { [`sha256:${memory}`]: 'f'.repeat(64) })), ['memory_sysctl_configuration']);
  assert.deepEqual(failedIds(plan, changed(good, { [`text:${memory}`]: good.get(`text:${memory}`).replace('vm.swappiness = 180', 'vm.swappiness = 60') })), ['memory_sysctl_configuration']);
  assert.match(detailOf(plan, changed(good, { [`text:${memory}`]: '' }), 'memory_sysctl_configuration'), /vm\.page-cluster = 0/);
});

function operationOf(plan, kind) {
  return plan.operations.find(item => item.kind === kind);
}

test('network prerequisites: package, enabled service, no predefined connection, and hostname', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  assert.deepEqual(failedIds(plan, changed(good, { 'enabled:NetworkManager.service': 'disabled' })), ['network_manager_enabled']);
  assert.deepEqual(failedIds(plan, changed(good, { 'enabled:NetworkManager.service': undefined })), ['network_manager_enabled']);
  assert.deepEqual(failedIds(plan, changed(good, { 'list:/etc/NetworkManager/system-connections': 'home.nmconnection\n' })), ['network_manager_enabled']);
  assert.equal(evaluateChecks(plan, changed(good, { 'list:/etc/NetworkManager/system-connections': '' })).status, 'passed');
  assert.deepEqual(failedIds(plan, changed(good, { 'text:/etc/hostname': 'other' })), ['network_manager_enabled']);
  assert.deepEqual(failedIds(plan, changed(good, { packages: good.get('packages').replace('networkmanager 1-1\n', '').replace('\nnetworkmanager 1-1', '') })), ['network_manager_enabled']);
});

test('microcode_selection compares installed packages with the plan and the content of the initramfs', () => {
  const amd = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(amd);
  assert.deepEqual(failedIds(amd, changed(good, { 'microcode:/boot/initramfs-linux.img': '' })), ['microcode_selection']);
  assert.deepEqual(failedIds(amd, changed(good, { 'microcode:/boot/initramfs-linux-fallback.img': 'kernel/x86/microcode/GenuineIntel.bin' })), ['microcode_selection']);
  assert.deepEqual(failedIds(amd, changed(good, { 'microcode:/boot/initramfs-linux.img': undefined })), ['microcode_selection']);
  assert.deepEqual(failedIds(amd, changed(good, { 'microcode:/boot/initramfs-linux.img': './kernel/x86/microcode/AuthenticAMD.bin' })), []);
  assert.deepEqual(failedIds(amd, changed(good, { packages: good.get('packages').replace('amd-ucode', 'intel-ucode') })), ['microcode_selection']);
  assert.deepEqual(failedIds(amd, changed(good, { packages: good.get('packages').replace('\namd-ucode 1-1', '') })), ['microcode_selection']);
  const intel = structuredClone(amd);
  intel.hardware_selections.rule_packages[0].name = 'intel-ucode';
  const intelGood = goodObservations(intel);
  assert.equal(evaluateChecks(intel, intelGood).status, 'passed');
  assert.deepEqual(failedIds(intel, changed(intelGood, { 'microcode:/boot/initramfs-linux.img': 'kernel/x86/microcode/AuthenticAMD.bin' })), ['microcode_selection']);
});

test('without a planned microcode package the early archive must hold no microcode image', () => {
  const plan = structuredClone(planFixture('ext4-systemd-boot--password'));
  plan.hardware_selections.rule_packages = [];
  const good = goodObservations(plan);
  assert.equal(evaluateChecks(plan, good).status, 'passed');
  const installed = changed(good, { packages: `${good.get('packages')}\namd-ucode 1-1` });
  assert.deepEqual(failedIds(plan, installed), ['microcode_selection']);
  const embedded = changed(good, { 'microcode:/boot/initramfs-linux.img': 'kernel/x86/microcode/AuthenticAMD.bin' });
  assert.deepEqual(failedIds(plan, embedded), ['microcode_selection']);
});

test('a detail is one non-secret line of at most 512 characters', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const good = goodObservations(plan);
  const entry = good.get('text:/boot/loader/entries/mirroros.conf');
  const long = changed(good, { 'text:/boot/loader/entries/mirroros.conf': `${entry} ${'x'.repeat(2000)}\n` });
  const detail = detailOf(plan, long, 'bootloader_systemd_boot');
  assert.ok(detail.length <= MAX_DETAIL_LENGTH);
  assert.ok(detail.endsWith('...'));
  assert.ok(!detail.includes('\n'));
  const multiline = changed(good, { 'text:/boot/loader/entries/mirroros.conf': `title MirrorOS\n\n\noptions broken\t\tline` });
  assert.ok(!/[\n\t]/.test(detailOf(plan, multiline, 'bootloader_systemd_boot')));
});

test('evaluation reads the observations and never modifies them', () => {
  const plan = planFixture('btrfs-limine--password');
  const good = goodObservations(plan);
  const before = JSON.stringify([...good.entries()]);
  evaluateChecks(plan, good);
  evaluateChecks(plan, changed(good, { 'uuid:/': 'other' }));
  assert.equal(JSON.stringify([...good.entries()]), before);
});

test('validateResult rejects unknown fields, unknown checks, a detail on a passed check, and disagreeing statuses', () => {
  const plan = planFixture('ext4-systemd-boot--password');
  const result = evaluateChecks(plan, goodObservations(plan));
  assert.deepEqual(validateResult(result, plan), []);
  assert.notDeepEqual(validateResult({ ...result, extra: 1 }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, format_version: 2 }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, status: 'failed' }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, failed_checks: ['kernel_installed'] }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, checks: [{ id: 'made_up', status: 'passed' }, ...result.checks.slice(1)] }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, checks: [{ ...result.checks[0], detail: 'x' }, ...result.checks.slice(1)] }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, checks: result.checks.slice(1) }, plan), []);
  assert.notDeepEqual(validateResult({ ...result, checks: [{ ...result.checks[0], extra: true }, ...result.checks.slice(1)] }, plan), []);
  const failed = { ...result, status: 'failed', failed_checks: [result.checks[0].id], checks: [{ ...result.checks[0], status: 'failed' }, ...result.checks.slice(1)] };
  assert.notDeepEqual(validateResult(failed, plan), [], 'a failed check needs a detail');
  assert.notDeepEqual(validateResult({ ...failed, checks: [{ ...failed.checks[0], detail: 'a\nb' }, ...failed.checks.slice(1)] }, plan), []);
  assert.deepEqual(validateResult({ ...failed, checks: [{ ...failed.checks[0], detail: 'a b' }, ...failed.checks.slice(1)] }, plan), []);
  assert.notDeepEqual(validateResult({ ...failed, checks: [{ ...failed.checks[0], detail: 'x'.repeat(513) }, ...failed.checks.slice(1)] }, plan), []);
});

test('the observation stream is NUL-delimited pairs and rejects a truncated or duplicated stream', () => {
  const observations = parseObservations('a\0one\ntwo\0b\0\0');
  assert.equal(observations.get('a'), 'one\ntwo');
  assert.equal(observations.get('b'), '');
  assert.throws(() => parseObservations('a\0one\0b\0'), /truncated/);
  assert.throws(() => parseObservations('a\0x\0a\0y\0'), /twice/);
});

test('the command line validates the plan first and exits 2 for an invalid plan or a digest mismatch', () => {
  const directory = mkdtempSync(join(tmpdir(), 'postconditions-'));
  try {
    const plan = planFixture('ext4-systemd-boot--password');
    const path = join(directory, 'plan.json');
    writeFileSync(path, JSON.stringify(plan));
    const run = (mode, planPath, digest, input = '') => spawnSync('node', [evaluatePath, mode, '--plan', planPath, '--digest', digest], { input, encoding: 'utf8' });
    assert.equal(run('validate', path, plan.digest.value).status, 0);
    const mismatch = run('validate', path, 'f'.repeat(64));
    assert.equal(mismatch.status, 2);
    assert.match(mismatch.stderr, /digest/);
    assert.equal(mismatch.stdout, '');
    writeFileSync(join(directory, 'edited.json'), JSON.stringify({ ...plan, choices: { ...plan.choices, hostname: { ...plan.choices.hostname, value: 'edited' } } }));
    assert.equal(run('validate', join(directory, 'edited.json'), plan.digest.value).status, 2);
    writeFileSync(join(directory, 'old.json'), JSON.stringify({ ...plan, format_version: 3 }));
    assert.equal(run('validate', join(directory, 'old.json'), plan.digest.value).status, 2);
    assert.equal(run('validate', join(directory, 'missing.json'), plan.digest.value).status, 2);
    const stream = [...goodObservations(plan).entries()].flat().map(field => `${field}\0`).join('');
    const passed = run('evaluate', path, plan.digest.value, stream);
    assert.equal(passed.status, 0, passed.stderr);
    assert.equal(JSON.parse(passed.stdout).status, 'passed');
    const failed = run('evaluate', path, plan.digest.value, '');
    assert.equal(failed.status, 4);
    assert.equal(JSON.parse(failed.stdout).status, 'failed');
    assert.equal(run('evaluate', path, plan.digest.value, 'odd\0').status, 6);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
