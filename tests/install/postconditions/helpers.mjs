import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const sourceRoot = resolve(here, '../../..');
export const evaluatePath = join(sourceRoot, 'install/postconditions/evaluate.mjs');
export const checkPath = join(sourceRoot, 'install/postconditions/check');

export const TARGET_ROOT = '/run/mirroros/target';
export const ROOT_UUID = '11111111-2222-4333-8444-555555555555';
export const ESP_UUID = 'ABCD-1234';
export const OFFSET = '34816';
export const MACHINE = '602fb108992848dfa504d317934f9444';
export const VALID_PLANS = [
  'ext4-systemd-boot--password', 'ext4-systemd-boot--locked', 'ext4-systemd-boot--hibernation-disabled',
  'btrfs-rescue--password', 'btrfs-rescue--locked', 'btrfs-rescue--hibernation-disabled',
  'btrfs-limine--password', 'btrfs-limine--locked', 'btrfs-limine--hibernation-disabled',
];

export function planFixture(name) {
  return JSON.parse(readFileSync(join(sourceRoot, 'tests/fixtures/plan/valid', `${name}.json`), 'utf8'));
}

const operation = (plan, kind) => plan.operations.find(item => item.kind === kind);
const file = (size = 1024, mode = '644') => `regular file|${mode}|${size}`;

// What a correct installation of the plan looks like, as the observations the checker's Bash side would report.
export function goodObservations(plan) {
  const observations = new Map();
  const storage = plan.choices.storage_option;
  const btrfs = storage.filesystem === 'btrfs';
  const limine = storage.bootloader === 'limine';
  const hibernation = plan.choices.hibernation.value;
  const bootloader = operation(plan, 'install_bootloader').parameters;
  const swapPath = btrfs ? '/swap/swapfile' : '/swapfile';
  const subvolumes = operation(plan, 'mount_target').parameters.subvolumes ?? [];
  const points = { '@': '/', '@home': '/home', '@log': '/var/log', '@pkg': '/var/cache/pacman/pkg', '@snapshots': '/.snapshots', '@swap': '/swap' };
  const set = (key, value) => observations.set(key, value);

  set('target_root', TARGET_ROOT);
  const mounts = [];
  if (btrfs) {
    const options = operation(plan, 'create_btrfs_subvolumes').parameters.mount_options;
    for (const name of subvolumes) mounts.push(`${TARGET_ROOT}${points[name] === '/' ? '' : points[name]} /dev/vda2[/${name}] btrfs rw,${options},subvol=/${name}`);
  } else {
    mounts.push(`${TARGET_ROOT} /dev/vda2 ext4 rw,relatime`);
  }
  mounts.push(`${TARGET_ROOT}/boot /dev/vda1 vfat rw,relatime,fmask=0077,dmask=0077`);
  set('mounts', mounts.join('\n'));
  set('uuid:/', ROOT_UUID);
  set('uuid:/boot', ESP_UUID);

  const rulePackages = plan.hardware_selections.rule_packages.map(entry => `${entry.name} 1-1`);
  set('packages', ['base 1-1', 'linux 6.1-1', 'zram-generator 1-1', 'networkmanager 1-1', ...rulePackages].join('\n'));

  set('stat:/boot/vmlinuz-linux', file());
  set('stat:/boot/initramfs-linux.img', file());
  const fallback = !limine && bootloader.options.fallback_entry === true;
  if (fallback) set('stat:/boot/initramfs-linux-fallback.img', file());
  set('stat:/boot/EFI/BOOT/BOOTX64.EFI', file());

  const cmdline = bootloader.kernel_cmdline.replaceAll('<root>', ROOT_UUID).replaceAll('<resume_offset>', OFFSET);
  const bootCmdline = btrfs ? `${cmdline} rootflags=subvol=@` : cmdline;
  if (limine) {
    set('text:/etc/default/limine', `ESP_PATH="/boot"\nSKIP_UEFI=yes\nKERNEL_CMDLINE[default]="${bootCmdline}"`);
    set('text:/boot/limine.conf', [
      `timeout: ${bootloader.options.timeout}`, 'default_entry: 2', '/+Arch Linux', `comment: machine-id=${MACHINE}`, '  //linux', '  protocol: linux',
      `  module_path: boot():/${MACHINE}/linux/initramfs#0123abcd`, `  path: boot():/${MACHINE}/linux/vmlinuz#4567ef01`, `  cmdline: ${bootCmdline}`,
      '', '     //Snapshots', '     comment: 1 snapshots', '     ///1 | 2026-10-12 21:25:57', '     ////linux', '     protocol: linux',
      `     module_path: boot():/${MACHINE}/limine_history/initramfs_sha256_0123#0123abcd`,
      `     path: boot():/${MACHINE}/limine_history/vmlinuz_sha256_0123#4567ef01`,
      `     cmdline: ${bootCmdline.replace('rootflags=subvol=@', 'rootflags=subvol=/@snapshots/1/snapshot')}`,
    ].join('\n'));
    for (const path of [`/${MACHINE}/linux/initramfs`, `/${MACHINE}/linux/vmlinuz`, `/${MACHINE}/limine_history/initramfs_sha256_0123`,
      `/${MACHINE}/limine_history/vmlinuz_sha256_0123`]) set(`stat:/boot${path}`, file());
  } else {
    set('stat:/boot/EFI/systemd/systemd-bootx64.efi', file());
    set('text:/boot/loader/loader.conf', `default mirroros.conf\ntimeout ${bootloader.options.timeout}\n${bootloader.options.editor === false ? 'editor no' : 'editor yes'}`);
    set('text:/boot/loader/entries/mirroros.conf', `title MirrorOS\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions ${bootCmdline}`);
    if (fallback) {
      set('text:/boot/loader/entries/mirroros-fallback.conf',
        `title MirrorOS (fallback initramfs)\nlinux /vmlinuz-linux\ninitrd /initramfs-linux-fallback.img\noptions ${bootCmdline}`);
    }
  }

  const fstab = [`UUID=${ROOT_UUID} / ${btrfs ? 'btrfs rw,relatime,subvol=/@' : 'ext4 rw,relatime'} 0 ${btrfs ? 0 : 1}`];
  if (btrfs) {
    for (const name of subvolumes.filter(item => item !== '@')) fstab.push(`UUID=${ROOT_UUID} ${points[name]} btrfs rw,relatime,subvol=/${name} 0 0`);
  }
  fstab.push(`UUID=${ESP_UUID} /boot vfat rw,umask=0077 0 2`);
  if (hibernation) {
    const priority = operation(plan, 'create_swapfile').parameters.priority;
    fstab.push(`${swapPath} none swap defaults,pri=${priority} 0 0`);
    set(`stat:${swapPath}`, file(operation(plan, 'create_swapfile').parameters.size_mib * 1048576, '600'));
    set(`offset:${swapPath}`, OFFSET);
    if (btrfs) set(`attrs:${swapPath}`, '---------------C------');
  }
  set('text:/etc/fstab', `# /etc/fstab\n${fstab.join('\n')}`);

  const zram = operation(plan, 'configure_zram').parameters;
  set(`text:${zram.destination}`, `[zram0]\nzram-size = ${zram.zram_size}\ncompression-algorithm = ${zram.compression_algorithm}\nswap-priority = ${zram.swap_priority}`);
  set(`sha256:${zram.destination}`, zram.source_sha256);
  const memory = operation(plan, 'configure_memory_reclaim').parameters;
  set(`text:${memory.destination}`, Object.entries(memory).filter(([key]) => key.startsWith('vm.')).map(([key, value]) => `${key} = ${value}`).join('\n'));
  set(`sha256:${memory.destination}`, memory.source_sha256);

  set('enabled:NetworkManager.service', 'enabled');
  set('text:/etc/hostname', operation(plan, 'configure_hostname_network').parameters.hostname);

  const microcodeFile = { 'amd-ucode': 'kernel/x86/microcode/AuthenticAMD.bin', 'intel-ucode': 'kernel/x86/microcode/GenuineIntel.bin' };
  const early = plan.hardware_selections.rule_packages.map(entry => microcodeFile[entry.name]).filter(Boolean).join('\n');
  set('microcode:/boot/initramfs-linux.img', early);
  if (fallback) set('microcode:/boot/initramfs-linux-fallback.img', early);
  return observations;
}

// A copy of the observations with the given changes; a value of undefined removes the key.
export function changed(observations, changes) {
  const copy = new Map(observations);
  for (const [key, value] of Object.entries(changes)) {
    if (value === undefined) copy.delete(key);
    else copy.set(key, value);
  }
  return copy;
}
