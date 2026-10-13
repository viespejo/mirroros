import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

import { parsePlanText, validatePlan } from '../plan/validate-plan.mjs';

// Structured side of the read-only postconditions checker (contracts/installation-postconditions.md). The Bash
// side only observes the mounted target and streams the observations; every comparison with the plan, and the
// result document, is produced here. Nothing in this file touches the filesystem except the plan and stdin.

export const POSTCONDITIONS_FORMAT_VERSION = 1;
export const EXIT_PASSED = 0;
export const EXIT_INVALID_INPUT = 2;
export const EXIT_FAILED = 4;
export const EXIT_INTERNAL = 6;

export const CHECK_IDS = [
  'kernel_installed',
  'mounts_active',
  'fstab_by_uuid',
  'bootloader_systemd_boot',
  'bootloader_limine',
  'boot_root_uuid',
  'boot_zswap_disabled',
  'boot_resume_parameters',
  'swapfile',
  'swap_absent',
  'zram_configuration',
  'memory_sysctl_configuration',
  'network_manager_enabled',
  'microcode_selection',
];

export const MAX_DETAIL_LENGTH = 512;

const MIBIBYTE = 1048576;
const SYSTEMD_BOOT_OPTIONS = ['ext4-systemd-boot', 'btrfs-rescue'];
const ROOTFLAGS = 'rootflags=subvol=@';
const ROOT_PATTERN = '[0-9A-Fa-f-]+';
const OFFSET_PATTERN = '[0-9]+';
const RESUME_TOKEN = /^resume(_offset)?=/;
const RESUME_IN_TEXT = /(^|[\s"])resume(_offset)?=/m;
// Where the engine mounts each flat subvolume; the checker derives the same table independently of the engine.
const SUBVOLUME_MOUNT_POINTS = {
  '@': '/', '@home': '/home', '@log': '/var/log', '@pkg': '/var/cache/pacman/pkg', '@snapshots': '/.snapshots', '@swap': '/swap',
};
const MICROCODE = {
  'amd-ucode': 'kernel/x86/microcode/AuthenticAMD.bin',
  'intel-ucode': 'kernel/x86/microcode/GenuineIntel.bin',
};
const MICROCODE_DIRECTORY = 'kernel/x86/microcode/';

const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);

// ---------------------------------------------------------------------------------------------------------------
// Observations: a NUL-delimited stream of key and value pairs. An absent key means "not present or not readable".

export function parseObservations(text) {
  const fields = text.split('\0');
  if (fields.at(-1) === '') fields.pop();
  if (fields.length % 2 !== 0) throw new Error('the observation stream is truncated');
  const observations = new Map();
  for (let index = 0; index < fields.length; index += 2) {
    if (observations.has(fields[index])) throw new Error(`the observation ${fields[index]} appears twice`);
    observations.set(fields[index], fields[index + 1]);
  }
  return observations;
}

const lines = text => (text ?? '').split('\n').map(line => line.trim());
const tokens = text => text.trim().split(/\s+/).filter(token => token !== '');

function statOf(observations, path) {
  const value = observations.get(`stat:${path}`);
  if (value === undefined) return undefined;
  const [type, mode, size] = value.split('|');
  return { regular: type.startsWith('regular'), mode, size: Number(size) };
}

// Problems of a file that must be a regular, non-empty file.
function fileProblems(observations, path) {
  const stat = statOf(observations, path);
  if (stat === undefined) return [`${path} is missing`];
  if (!stat.regular) return [`${path} is not a regular file`];
  if (!(stat.size > 0)) return [`${path} is empty`];
  return [];
}

function packagesOf(observations) {
  const value = observations.get('packages');
  if (value === undefined) return undefined;
  const packages = new Map();
  for (const line of lines(value)) {
    if (line === '') continue;
    const [name, version] = line.split(/\s+/);
    packages.set(name, version);
  }
  return packages;
}

// The mounts of the target by their path relative to the target root; the topmost mount of a path wins.
function mountsOf(observations) {
  const value = observations.get('mounts');
  const root = observations.get('target_root');
  if (value === undefined || root === undefined) return undefined;
  const decode = field => field.replace(/\\x([0-9a-fA-F]{2})/g, (_match, hex) => String.fromCharCode(Number.parseInt(hex, 16)));
  const mounts = new Map();
  for (const line of value.split('\n')) {
    if (line.trim() === '') continue;
    const [target, source, fstype, options = ''] = line.split(' ').map(decode);
    let relative;
    if (target === root) relative = '/';
    else if (target.startsWith(`${root}/`)) relative = target.slice(root.length);
    else continue;
    mounts.set(relative, { source, fstype, options: options.split(',') });
  }
  return mounts;
}

function fstabOf(observations) {
  const text = observations.get('text:/etc/fstab');
  if (text === undefined) return undefined;
  const entries = [];
  for (const line of lines(text)) {
    if (line === '' || line.startsWith('#')) continue;
    const [spec, point, type, options = ''] = line.split(/\s+/);
    entries.push({ spec, point, type, options: options.split(',') });
  }
  return { text, entries };
}

function operation(plan, kind) {
  return plan.operations.find(item => item.kind === kind);
}

// ---------------------------------------------------------------------------------------------------------------
// Boot entries.

function tokenPattern(token) {
  return new RegExp(`^${token.split(/(<root>|<resume_offset>)/).map(part => {
    if (part === '<root>') return ROOT_PATTERN;
    if (part === '<resume_offset>') return OFFSET_PATTERN;
    return part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }).join('')}$`);
}

// The command line equals the plan's template token by token; the root UUID and the resume offset are patterns
// here and are compared with the independently observed values by boot_root_uuid and boot_resume_parameters.
function matchesTemplate(actual, template) {
  const found = tokens(actual);
  const wanted = tokens(template);
  return found.length === wanted.length && wanted.every((token, index) => tokenPattern(token).test(found[index]));
}

function limineSections(observations) {
  const text = observations.get('text:/boot/limine.conf');
  if (text === undefined) return undefined;
  const all = text.split('\n');
  const split = all.findIndex(line => /^\s*\/\/Snapshots\s*$/.test(line));
  return split === -1 ? { normal: all, snapshots: [] } : { normal: all.slice(0, split), snapshots: all.slice(split + 1) };
}

function limineCmdline(section) {
  for (const line of section) {
    const match = /^\s*cmdline:\s*(.*)$/.exec(line);
    if (match !== null) return match[1];
  }
  return undefined;
}

function expectedCmdline(context) {
  const template = context.bootloaderPlan.parameters.kernel_cmdline;
  if (context.bootloader === 'limine' || context.option === 'btrfs-rescue') return `${template} ${ROOTFLAGS}`;
  return template;
}

// The normal boot entries as { name, cmdline }, or problems when one cannot be read.
function normalEntries(context) {
  const { observations } = context;
  if (context.bootloader === 'limine') {
    const sections = limineSections(observations);
    if (sections === undefined) return { problems: ['/boot/limine.conf is missing'], entries: [] };
    const cmdline = limineCmdline(sections.normal);
    if (cmdline === undefined) return { problems: ['/boot/limine.conf has no normal entry with a command line'], entries: [] };
    return { problems: [], entries: [{ name: 'the Limine normal entry', cmdline }] };
  }
  const entries = [];
  const problems = [];
  for (const [file, required] of [['mirroros.conf', true], ['mirroros-fallback.conf', false]]) {
    const text = observations.get(`text:/boot/loader/entries/${file}`);
    if (text === undefined) {
      if (required) problems.push(`/boot/loader/entries/${file} is missing`);
      continue;
    }
    const options = lines(text).find(line => line.startsWith('options '));
    if (options === undefined) problems.push(`/boot/loader/entries/${file} has no options line`);
    else entries.push({ name: file, cmdline: options.slice('options '.length) });
  }
  return { problems, entries };
}

function parameter(cmdline, key) {
  return tokens(cmdline).find(token => token.startsWith(`${key}=`));
}

// ---------------------------------------------------------------------------------------------------------------
// The checks. Each returns the list of problems it found; an empty list means it passed.

function kernelInstalled(context) {
  const { observations, bootloader, fallbackEntry } = context;
  const problems = [];
  const files = ['/boot/vmlinuz-linux', '/boot/initramfs-linux.img'];
  if (bootloader === 'systemd-boot' && fallbackEntry) files.push('/boot/initramfs-linux-fallback.img');
  for (const path of files) problems.push(...fileProblems(observations, path));
  if (context.packages === undefined) problems.push('the package database of the target cannot be read');
  else if (!context.packages.has('linux')) problems.push('the package linux is not installed');
  return problems;
}

function mountsActive(context) {
  const { mounts, filesystem } = context;
  if (mounts === undefined) return ['the mount table of the target cannot be read'];
  const problems = [];
  const root = mounts.get('/');
  if (root === undefined) problems.push('the root filesystem is not mounted at the target root');
  else if (root.fstype !== filesystem) problems.push(`the root filesystem is ${root.fstype}, expected ${filesystem}`);
  const esp = mounts.get('/boot');
  if (esp === undefined) problems.push('the ESP is not mounted at /boot');
  else {
    if (esp.fstype !== 'vfat') problems.push(`the ESP at /boot is ${esp.fstype}, expected vfat`);
    if (!esp.options.includes('umask=0077')) problems.push('the ESP at /boot is not mounted with umask=0077');
  }
  if (filesystem === 'btrfs') {
    for (const name of context.subvolumes) {
      const point = SUBVOLUME_MOUNT_POINTS[name];
      const mount = mounts.get(point);
      if (mount === undefined) {
        problems.push(`the subvolume ${name} is not mounted at ${point}`);
        continue;
      }
      if (!mount.options.includes(`subvol=/${name}`)) problems.push(`${point} is not the subvolume ${name} (options ${mount.options.join(',')})`);
      for (const option of context.btrfsOptions) {
        if (!mount.options.includes(option)) problems.push(`${point} lacks the mount option ${option}`);
      }
    }
  }
  return problems;
}

function fstabByUuid(context) {
  const { fstab, filesystem, rootUuid, espUuid } = context;
  if (fstab === undefined) return ['/etc/fstab is missing'];
  const problems = [];
  if (rootUuid === undefined) problems.push('the UUID of the root filesystem cannot be read');
  if (espUuid === undefined) problems.push('the UUID of the ESP cannot be read');
  if (fstab.text.includes('subvolid=')) problems.push('/etc/fstab holds a subvolume id');
  const byPoint = new Map(fstab.entries.filter(entry => entry.type !== 'swap').map(entry => [entry.point, entry]));
  for (const entry of byPoint.values()) {
    if (!entry.spec.startsWith('UUID=')) problems.push(`the fstab entry of ${entry.point} is not by UUID (${entry.spec})`);
  }
  const expect = (point, uuid, label, subvolume) => {
    const entry = byPoint.get(point);
    if (entry === undefined) {
      problems.push(`/etc/fstab has no entry for ${label}`);
      return;
    }
    if (uuid !== undefined && entry.spec !== `UUID=${uuid}`) problems.push(`the fstab entry of ${label} is ${entry.spec}, the device is UUID=${uuid}`);
    if (subvolume !== undefined && !entry.options.includes(`subvol=/${subvolume}`)) problems.push(`the fstab entry of ${label} lacks subvol=/${subvolume}`);
  };
  expect('/', rootUuid, 'the root', filesystem === 'btrfs' ? '@' : undefined);
  expect('/boot', espUuid, 'the ESP');
  if (filesystem === 'btrfs') {
    for (const name of context.subvolumes.filter(item => item !== '@')) expect(SUBVOLUME_MOUNT_POINTS[name], rootUuid, `the subvolume ${name}`, name);
  }
  const swaps = fstab.entries.filter(entry => entry.type === 'swap');
  if (context.hibernation) {
    if (swaps.length !== 1) problems.push(`/etc/fstab has ${swaps.length} swap lines, expected exactly one`);
    else {
      if (swaps[0].spec !== context.swapPath) problems.push(`the swap line is ${swaps[0].spec}, expected ${context.swapPath}`);
      if (!swaps[0].options.includes(`pri=${context.swapPriority}`)) problems.push(`the swap line lacks pri=${context.swapPriority}`);
    }
  } else if (swaps.length > 0) {
    problems.push('/etc/fstab has a swap line although hibernation is disabled');
  }
  return problems;
}

function bootloaderSystemdBoot(context) {
  const { observations } = context;
  const problems = [];
  const loader = observations.get('text:/boot/loader/loader.conf');
  if (loader === undefined) problems.push('/boot/loader/loader.conf is missing');
  else {
    const present = lines(loader);
    const wanted = ['default mirroros.conf', `timeout ${context.bootloaderPlan.parameters.options.timeout}`,
      context.bootloaderPlan.parameters.options.editor === false ? 'editor no' : 'editor yes'];
    for (const line of wanted) if (!present.includes(line)) problems.push(`loader.conf lacks "${line}"`);
  }
  const wantedCmdline = expectedCmdline(context);
  const entryProblems = (file, title, initrd) => {
    const text = observations.get(`text:/boot/loader/entries/${file}`);
    if (text === undefined) return [`/boot/loader/entries/${file} is missing`];
    const present = lines(text);
    const found = [];
    for (const line of [`title ${title}`, 'linux /vmlinuz-linux', `initrd ${initrd}`]) {
      if (!present.includes(line)) found.push(`${file} lacks "${line}"`);
    }
    const options = present.find(line => line.startsWith('options '));
    if (options === undefined) found.push(`${file} has no options line`);
    else if (!matchesTemplate(options.slice('options '.length), wantedCmdline)) {
      found.push(`${file} options are "${options.slice('options '.length)}", expected "${wantedCmdline}"`);
    }
    return found;
  };
  problems.push(...entryProblems('mirroros.conf', 'MirrorOS', '/initramfs-linux.img'));
  const fallbackText = observations.get('text:/boot/loader/entries/mirroros-fallback.conf');
  if (context.fallbackEntry) problems.push(...entryProblems('mirroros-fallback.conf', 'MirrorOS (fallback initramfs)', '/initramfs-linux-fallback.img'));
  else if (fallbackText !== undefined) problems.push('the fallback entry exists although the plan has none');
  for (const path of ['/boot/EFI/systemd/systemd-bootx64.efi', '/boot/EFI/BOOT/BOOTX64.EFI']) problems.push(...fileProblems(observations, path));
  return problems;
}

function bootloaderLimine(context) {
  const { observations } = context;
  const problems = [];
  const defaults = observations.get('text:/etc/default/limine');
  if (defaults === undefined) problems.push('/etc/default/limine is missing');
  else {
    const present = lines(defaults);
    for (const line of ['ESP_PATH="/boot"', 'SKIP_UEFI=yes']) if (!present.includes(line)) problems.push(`/etc/default/limine lacks ${line}`);
    const setting = present.map(line => /^KERNEL_CMDLINE\[default\]="(.*)"$/.exec(line)).find(match => match !== null);
    if (setting === undefined) problems.push('/etc/default/limine has no KERNEL_CMDLINE[default]');
    else if (!matchesTemplate(setting[1], expectedCmdline(context))) {
      problems.push(`KERNEL_CMDLINE[default] is "${setting[1]}", expected "${expectedCmdline(context)}"`);
    }
  }
  problems.push(...fileProblems(observations, '/boot/EFI/BOOT/BOOTX64.EFI'));
  const sections = limineSections(observations);
  if (sections === undefined) {
    problems.push('/boot/limine.conf is missing');
  } else {
    const timeout = `${context.bootloaderPlan.parameters.options.timeout}`;
    if (!sections.normal.some(line => new RegExp(`^timeout:\\s*${timeout}\\s*$`).test(line))) problems.push(`limine.conf lacks the global timeout ${timeout}`);
    const cmdline = limineCmdline(sections.normal);
    if (cmdline === undefined) problems.push('limine.conf has no normal entry with a command line');
    else if (!matchesTemplate(cmdline, expectedCmdline(context))) problems.push(`the Limine normal entry is "${cmdline}", expected "${expectedCmdline(context)}"`);
    if (sections.snapshots.length === 0 || !sections.snapshots.some(line => /^\s*\/\/\/[^/]/.test(line))) {
      problems.push('limine.conf has no snapshot entry below //Snapshots');
    }
    for (const line of [...sections.normal, ...sections.snapshots]) {
      const match = /^\s*(?:module_)?path:\s*boot\(\):(\/[^#\s]+)/.exec(line);
      if (match === null) continue;
      if (match[1].includes('..')) problems.push(`a Limine entry references ${match[1]}`);
      else if (!(statOf(observations, `/boot${match[1]}`)?.size > 0)) problems.push(`a Limine entry references ${match[1]}, which is missing or empty on the ESP`);
    }
  }
  const unified = (observations.get('list:/boot/EFI/Linux') ?? '').split('\n').filter(name => name.endsWith('.efi'));
  if (unified.length > 0) problems.push(`a unified kernel image exists on the ESP (${unified.join(', ')})`);
  return problems;
}

function bootEntryChecks(context, inspect) {
  const { problems, entries } = normalEntries(context);
  const found = [...problems];
  for (const entry of entries) found.push(...inspect(entry));
  return found;
}

function bootRootUuid(context) {
  if (context.rootUuid === undefined) return ['the UUID of the root filesystem cannot be read'];
  return bootEntryChecks(context, entry => {
    const root = parameter(entry.cmdline, 'root');
    return root === `root=UUID=${context.rootUuid}` ? [] : [`${entry.name} has ${root ?? 'no root parameter'}, the root device is UUID=${context.rootUuid}`];
  });
}

function bootZswapDisabled(context) {
  return bootEntryChecks(context, entry => (tokens(entry.cmdline).includes('zswap.enabled=0') ? [] : [`${entry.name} lacks zswap.enabled=0`]));
}

function observedOffset(context) {
  const value = context.observations.get(`offset:${context.swapPath}`);
  return /^[1-9][0-9]*$/.test(value ?? '') ? value : undefined;
}

function bootResumeParameters(context) {
  const { observations } = context;
  if (context.hibernation) {
    const offset = observedOffset(context);
    const found = [];
    if (offset === undefined) found.push('the resume offset cannot be computed from the swapfile');
    if (context.rootUuid === undefined) found.push('the UUID of the root filesystem cannot be read');
    found.push(...bootEntryChecks(context, entry => {
      const problems = [];
      const resume = parameter(entry.cmdline, 'resume');
      const entryOffset = parameter(entry.cmdline, 'resume_offset');
      if (context.rootUuid !== undefined && resume !== `resume=UUID=${context.rootUuid}`) {
        problems.push(`${entry.name} has ${resume ?? 'no resume parameter'}, the root device is UUID=${context.rootUuid}`);
      }
      if (offset !== undefined && entryOffset !== `resume_offset=${offset}`) {
        problems.push(`${entry.name} has ${entryOffset ?? 'no resume_offset'}, the swapfile offset is ${offset}`);
      }
      return problems;
    }));
    return found;
  }
  const found = [];
  for (const path of ['/boot/loader/entries/mirroros.conf', '/boot/loader/entries/mirroros-fallback.conf', '/etc/default/limine', '/boot/limine.conf']) {
    const text = observations.get(`text:${path}`);
    if (text !== undefined && RESUME_IN_TEXT.test(text)) found.push(`${path} carries resume parameters although hibernation is disabled`);
  }
  const loader = observations.get('text:/boot/loader/loader.conf');
  if (loader !== undefined && tokens(loader).some(token => RESUME_TOKEN.test(token))) found.push('loader.conf carries resume parameters');
  return found;
}

function swapfile(context) {
  const { observations, swapPath } = context;
  const stat = statOf(observations, swapPath);
  if (stat === undefined) return [`${swapPath} is missing`];
  const problems = [];
  if (!stat.regular) problems.push(`${swapPath} is not a regular file`);
  if (stat.mode !== '600') problems.push(`${swapPath} has mode ${stat.mode}, expected 600`);
  const expected = context.swapSizeMib * MIBIBYTE;
  if (stat.size !== expected) problems.push(`${swapPath} has size ${stat.size}, expected ${expected}`);
  if (observedOffset(context) === undefined) problems.push('the resume offset of the swapfile is not a positive integer');
  if (context.filesystem === 'btrfs') {
    const attributes = (observations.get(`attrs:${swapPath}`) ?? '').trim().split(/\s+/)[0] ?? '';
    if (!attributes.includes('C')) problems.push(`${swapPath} is not NOCOW (attributes ${attributes === '' ? 'unreadable' : attributes})`);
    const swapMount = context.mounts?.get('/swap');
    if (swapMount === undefined || !swapMount.options.includes('subvol=/@swap')) problems.push(`${swapPath} does not lie on the @swap subvolume`);
  }
  return problems;
}

function swapAbsent(context) {
  const problems = [];
  for (const path of ['/swapfile', '/swap/swapfile']) {
    if (statOf(context.observations, path) !== undefined) problems.push(`${path} exists although hibernation is disabled`);
  }
  if (context.mounts?.has('/swap')) problems.push('a subvolume is mounted at /swap although hibernation is disabled');
  if (context.fstab?.entries.some(entry => entry.type === 'swap')) problems.push('/etc/fstab has a swap entry although hibernation is disabled');
  return problems;
}

function assetProblems(context, operationKind, label, wantedLines) {
  const { observations } = context;
  const parameters = operation(context.plan, operationKind).parameters;
  const path = parameters.destination;
  const problems = [];
  const text = observations.get(`text:${path}`);
  if (text === undefined) return [`${path} is missing`];
  const hash = observations.get(`sha256:${path}`);
  if (hash !== parameters.source_sha256) problems.push(`${path} has SHA-256 ${hash ?? 'unreadable'}, the plan has ${parameters.source_sha256}`);
  const present = lines(text);
  for (const line of wantedLines(parameters)) if (!present.includes(line)) problems.push(`${label} lacks "${line}"`);
  return problems;
}

function zramConfiguration(context) {
  const problems = [];
  if (context.packages === undefined) problems.push('the package database of the target cannot be read');
  else if (!context.packages.has('zram-generator')) problems.push('the package zram-generator is not installed');
  problems.push(...assetProblems(context, 'configure_zram', 'the zram drop-in', parameters => [
    `zram-size = ${parameters.zram_size}`,
    `compression-algorithm = ${parameters.compression_algorithm}`,
    `swap-priority = ${parameters.swap_priority}`,
  ]));
  return problems;
}

function memorySysctlConfiguration(context) {
  return assetProblems(context, 'configure_memory_reclaim', 'the memory drop-in', parameters => (
    Object.entries(parameters).filter(([key]) => key.startsWith('vm.')).map(([key, value]) => `${key} = ${value}`)
  ));
}

function networkManagerEnabled(context) {
  const { observations } = context;
  const problems = [];
  const name = context.plan.choices.network.value.package;
  if (context.packages === undefined) problems.push('the package database of the target cannot be read');
  else if (!context.packages.has(name)) problems.push(`the package ${name} is not installed`);
  const enabled = observations.get('enabled:NetworkManager.service');
  if (enabled === undefined || enabled.trim() !== 'enabled') problems.push(`NetworkManager.service is ${enabled === undefined ? 'unreadable' : enabled.trim() || 'not enabled'}, expected enabled`);
  const connections = observations.get('list:/etc/NetworkManager/system-connections');
  if (connections !== undefined && connections.trim() !== '') problems.push('a predefined NetworkManager connection exists');
  const hostname = observations.get('text:/etc/hostname');
  const wanted = operation(context.plan, 'configure_hostname_network').parameters.hostname;
  if (hostname === undefined) problems.push('/etc/hostname is missing');
  else if (hostname.trim() !== wanted) problems.push(`/etc/hostname is ${hostname.trim()}, expected ${wanted}`);
  return problems;
}

function microcodeSelection(context) {
  const { observations, packages } = context;
  if (packages === undefined) return ['the package database of the target cannot be read'];
  const planned = context.plan.hardware_selections.rule_packages.map(entry => entry.name).filter(name => name in MICROCODE).sort();
  const installed = [...packages.keys()].filter(name => name in MICROCODE).sort();
  const problems = [];
  if (planned.join(',') !== installed.join(',')) {
    problems.push(`the microcode packages installed are [${installed.join(', ')}], the plan selects [${planned.join(', ')}]`);
  }
  const images = ['/boot/initramfs-linux.img'];
  if (statOf(observations, '/boot/initramfs-linux-fallback.img')?.regular) images.push('/boot/initramfs-linux-fallback.img');
  for (const image of images) {
    const listing = observations.get(`microcode:${image}`);
    if (listing === undefined) {
      problems.push(`the early archive of ${image} cannot be listed`);
      continue;
    }
    const entries = lines(listing).filter(line => line !== '').map(line => line.replace(/^\.\//, ''));
    for (const name of planned) {
      if (!entries.includes(MICROCODE[name])) problems.push(`${image} does not contain ${MICROCODE[name]}`);
    }
    if (planned.length === 0 && entries.some(entry => entry.startsWith(MICROCODE_DIRECTORY))) problems.push(`${image} contains a microcode image although none is planned`);
  }
  return problems;
}

const CHECKS = {
  kernel_installed: kernelInstalled,
  mounts_active: mountsActive,
  fstab_by_uuid: fstabByUuid,
  bootloader_systemd_boot: bootloaderSystemdBoot,
  bootloader_limine: bootloaderLimine,
  boot_root_uuid: bootRootUuid,
  boot_zswap_disabled: bootZswapDisabled,
  boot_resume_parameters: bootResumeParameters,
  swapfile,
  swap_absent: swapAbsent,
  zram_configuration: zramConfiguration,
  memory_sysctl_configuration: memorySysctlConfiguration,
  network_manager_enabled: networkManagerEnabled,
  microcode_selection: microcodeSelection,
};

// The checks that apply to a plan, in the declared order.
export function applicableChecks(plan) {
  const option = plan.choices.storage_option.value;
  const hibernation = plan.choices.hibernation.value;
  const systemdBoot = SYSTEMD_BOOT_OPTIONS.includes(option);
  return CHECK_IDS.filter(id => {
    if (id === 'bootloader_systemd_boot') return systemdBoot;
    if (id === 'bootloader_limine') return !systemdBoot;
    if (id === 'swapfile') return hibernation;
    if (id === 'swap_absent') return !hibernation;
    return true;
  });
}

function buildContext(plan, observations) {
  const storage = plan.choices.storage_option;
  const hibernation = plan.choices.hibernation.value;
  const filesystem = storage.filesystem ?? (storage.value.startsWith('ext4') ? 'ext4' : 'btrfs');
  const bootloaderPlan = operation(plan, 'install_bootloader');
  const subvolumeOperation = operation(plan, 'create_btrfs_subvolumes');
  const swapOperation = operation(plan, 'create_swapfile');
  return {
    plan,
    observations,
    option: storage.value,
    filesystem,
    hibernation,
    bootloader: bootloaderPlan.parameters.bootloader,
    bootloaderPlan,
    fallbackEntry: bootloaderPlan.parameters.options.fallback_entry === true,
    subvolumes: operation(plan, 'mount_target').parameters.subvolumes ?? [],
    btrfsOptions: (subvolumeOperation?.parameters.mount_options ?? '').split(',').filter(option => option !== ''),
    swapPath: filesystem === 'btrfs' ? '/swap/swapfile' : '/swapfile',
    swapSizeMib: swapOperation?.parameters.size_mib,
    swapPriority: swapOperation?.parameters.priority,
    packages: packagesOf(observations),
    mounts: mountsOf(observations),
    fstab: fstabOf(observations),
    rootUuid: observations.get('uuid:/'),
    espUuid: observations.get('uuid:/boot'),
  };
}

export function formatDetail(problems) {
  const text = problems.join('; ').replace(/\s+/g, ' ').trim();
  return text.length > MAX_DETAIL_LENGTH ? `${text.slice(0, MAX_DETAIL_LENGTH - 3)}...` : text;
}

// Evaluates every applicable check of a valid plan against the observations; none is skipped after a failure.
export function evaluateChecks(plan, observations) {
  const context = buildContext(plan, observations);
  const checks = applicableChecks(plan).map(id => {
    const problems = CHECKS[id](context);
    return problems.length === 0 ? { id, status: 'passed' } : { id, status: 'failed', detail: formatDetail(problems) };
  });
  const failed = checks.filter(check => check.status === 'failed').map(check => check.id);
  return {
    format_version: POSTCONDITIONS_FORMAT_VERSION,
    status: failed.length === 0 ? 'passed' : 'failed',
    checks,
    failed_checks: failed,
  };
}

// Validates a result document. With the plan, every check that applies to it must be present, in order.
export function validateResult(result, plan) {
  const errors = [];
  if (!isRecord(result)) return ['the result must be an object'];
  for (const key of Object.keys(result)) {
    if (!['format_version', 'status', 'checks', 'failed_checks'].includes(key)) errors.push(`${key} is not a known field`);
  }
  if (result.format_version !== POSTCONDITIONS_FORMAT_VERSION) errors.push(`format_version must be ${POSTCONDITIONS_FORMAT_VERSION}`);
  if (!['passed', 'failed'].includes(result.status)) errors.push('status must be passed or failed');
  if (!Array.isArray(result.checks) || !Array.isArray(result.failed_checks)) {
    errors.push('checks and failed_checks must be lists');
    return errors;
  }
  const failed = [];
  for (const check of result.checks) {
    if (!isRecord(check)) {
      errors.push('a check must be an object');
      continue;
    }
    for (const key of Object.keys(check)) if (!['id', 'status', 'detail'].includes(key)) errors.push(`a check has the unknown field ${key}`);
    if (!CHECK_IDS.includes(check.id)) errors.push(`${check.id} is not a known check`);
    if (!['passed', 'failed'].includes(check.status)) errors.push(`the check ${check.id} has an invalid status`);
    if (check.status === 'passed' && 'detail' in check) errors.push(`the passed check ${check.id} has a detail`);
    if (check.status === 'failed') {
      failed.push(check.id);
      if (typeof check.detail !== 'string' || check.detail === '' || check.detail.length > MAX_DETAIL_LENGTH || check.detail.includes('\n')) {
        errors.push(`the failed check ${check.id} needs a one-line detail of at most ${MAX_DETAIL_LENGTH} characters`);
      }
    }
  }
  if (result.failed_checks.join(',') !== failed.join(',')) errors.push('failed_checks disagrees with the checks');
  if ((result.status === 'passed') !== (failed.length === 0)) errors.push('status disagrees with failed_checks');
  if (plan !== undefined && result.checks.map(check => check.id).join(',') !== applicableChecks(plan).join(',')) {
    errors.push('the checks are not exactly the ones that apply to the plan');
  }
  return errors;
}

// Reads the plan, validates it, recomputes its digest through the plan validator, and compares it with the
// confirmed digest. Returns { plan } or { message }.
export function loadVerifiedPlan(path, digest) {
  let text;
  try {
    text = readFileSync(path, 'utf8');
  } catch (error) {
    return { message: `the plan cannot be read (${error.code ?? error.name})` };
  }
  const parsed = parsePlanText(text);
  if (parsed.plan === undefined) return { message: parsed.reasons[0].message };
  const problems = validatePlan(parsed.plan);
  if (problems.length > 0) return { message: `${problems[0].code}: ${problems[0].message} ${problems[0].next_step}` };
  if (parsed.plan.digest.value !== digest) return { message: 'the plan digest differs from the confirmed digest' };
  return { plan: parsed.plan };
}

function readOption(args, name) {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

function main(args) {
  const [mode] = args;
  const loaded = loadVerifiedPlan(readOption(args, '--plan'), readOption(args, '--digest'));
  if (loaded.plan === undefined) {
    process.stderr.write(`MirrorOS postconditions: ${loaded.message}\n`);
    return EXIT_INVALID_INPUT;
  }
  if (mode === 'validate') return EXIT_PASSED;
  if (mode !== 'evaluate') {
    process.stderr.write('Usage: evaluate.mjs validate|evaluate --plan <file> --digest <hex>\n');
    return EXIT_INVALID_INPUT;
  }
  const result = evaluateChecks(loaded.plan, parseObservations(readFileSync(0, 'utf8')));
  const errors = validateResult(result, loaded.plan);
  if (errors.length > 0) throw new Error(`the result failed its own validation: ${errors.join('; ')}`);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result.status === 'passed' ? EXIT_PASSED : EXIT_FAILED;
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`The postconditions evaluator failed an internal contract check: ${error.message}\n`);
    process.exitCode = EXIT_INTERNAL;
  }
}
