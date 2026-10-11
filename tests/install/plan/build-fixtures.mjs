import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { withDigest, sha256Canonical } from '../../../install/plan/digest-plan.mjs';
import { OPERATION_DESCRIPTIONS } from '../../../install/plan/generate-plan.mjs';
import { operationSequence } from '../../../install/plan/validate-plan.mjs';
import { discover } from '../discovery/helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
export const planFixturesRoot = resolve(here, '../../fixtures/plan');
const policyPath = resolve(here, '../../../install/plan/policy.json');
const profileDefinitionPath = resolve(here, '../../../targets/reference-vm/target.json');
const assetsRoot = resolve(here, '../../../install/plan/assets');

export const STORAGE_OPTION_NAMES = ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'];
export const ROOT_ACCOUNT_MODES = ['locked', 'password'];

export function fixtureFacts() {
  return discover('reference-vm-layout');
}

function readPolicy() {
  return JSON.parse(readFileSync(policyPath, 'utf8'));
}

// Independent of the generator: the raw-byte SHA-256 of an asset under install/plan/assets.
function assetSha256(source) {
  return createHash('sha256').update(readFileSync(resolve(assetsRoot, source))).digest('hex');
}

function parametersFor(kind, context) {
  const { values, option, disk } = context;
  switch (kind) {
    case 'wipe_disk_signatures':
      return { disk };
    case 'create_partition_table':
      return { disk, table: values.partition_table };
    case 'create_partitions':
      return { disk, esp_size_bytes: values.esp.size_bytes, esp_mount_point: values.esp.mount_point, root: 'remaining_space' };
    case 'format_filesystems':
      return { esp_filesystem: values.esp.filesystem, root_filesystem: option.filesystem };
    case 'create_btrfs_subvolumes':
      return { subvolumes: subvolumesOf(option, values.hibernation), mount_options: option.mount_options };
    case 'mount_target':
      return option.subvolumes === undefined
        ? { esp_mount_point: values.esp.mount_point }
        : { esp_mount_point: values.esp.mount_point, subvolumes: subvolumesOf(option, values.hibernation) };
    case 'install_packages':
      return { packages: [...values.packages, values.network.package, ...option.additional_packages] };
    case 'generate_fstab':
      return { identifier: 'uuid' };
    case 'configure_zram':
      return {
        destination: '/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf',
        source_sha256: assetSha256('usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf'),
        zram_size: 'ram',
        compression_algorithm: 'zstd',
        swap_priority: 100,
      };
    case 'configure_memory_reclaim':
      return {
        destination: '/usr/lib/sysctl.d/60-mirroros-memory.conf',
        source_sha256: assetSha256('usr/lib/sysctl.d/60-mirroros-memory.conf'),
        'vm.swappiness': 180,
        'vm.page-cluster': 0,
        'vm.watermark_scale_factor': 125,
        'vm.watermark_boost_factor': 0,
      };
    case 'create_swapfile':
      return { path: '/swapfile', size_mib: values.swapfile_size, priority: 0 };
    case 'configure_locale_time_console':
      return {
        locales: values.locales,
        lang: values.lang,
        locale_categories: values.locale_categories,
        console_keymap: values.console_keymap,
        timezone: values.timezone,
        hardware_clock: values.hardware_clock,
        time_sync: values.time_sync,
      };
    case 'configure_hostname_network':
      return { hostname: values.hostname, network_manager: values.network.manager };
    case 'create_user':
      return { user_name: values.user_name, groups: values.user_groups, shell: values.user_shell };
    case 'configure_root_account':
      return { mode: values.root_account };
    case 'configure_sudo_sysrq_pacman':
      return { sudoers: values.sudoers, sysrq: values.sysrq, pacman_options: values.pacman_options };
    case 'install_bootloader':
      return { bootloader: option.bootloader, kernel_cmdline: values.kernel_cmdline, options: values.bootloader_options };
    case 'enable_services':
      return { services: [values.network.manager, values.time_sync, values.fstrim] };
    default:
      return {};
  }
}

function subvolumesOf(option, hibernation) {
  return option.subvolumes.filter(name => hibernation || name !== '@swap');
}

function resolvedAtApply(kind, option, hibernation) {
  if (kind === 'format_filesystems') return [{ name: 'partition_uuids', method: 'blkid' }];
  if (kind === 'create_swapfile') return [{ name: 'resume_offset', method: option.resume_offset_method }];
  if (kind === 'install_bootloader') {
    return [
      { name: 'root_uuid', method: 'blkid' },
      ...(hibernation ? [{ name: 'resume_offset', method: option.resume_offset_method }] : []),
    ];
  }
  return undefined;
}

// The detected memory of the reference VM facts fixture is exactly 4 GiB, so the swapfile maximum and default
// is 4096 MiB, which equals the raw memory: the boundary that does not warn.
export const REFERENCE_MEMORY_BYTES = 4294967296;
export const REFERENCE_SWAPFILE_MIB = 4096;

export function buildValidPlan(storageOption, rootAccount, hibernation = true) {
  const facts = fixtureFacts();
  const policy = readPolicy();
  const option = policy.storage_options[storageOption];
  const disk = facts.layers.detected.storage.disks[0];
  const values = {};
  const choices = {};
  for (const [key, entry] of Object.entries(policy.policy)) {
    values[key] = entry.value;
    choices[key] = { value: entry.value, provenance: entry.provenance, source: 'policy', editable: entry.editable };
  }
  values.hibernation = hibernation;
  if (hibernation) {
    values.swapfile_size = REFERENCE_SWAPFILE_MIB;
    choices.swapfile_size = { value: REFERENCE_SWAPFILE_MIB, provenance: 'hardware_detection', source: 'detected', editable: true };
  } else {
    choices.hibernation = { ...choices.hibernation, value: false, source: 'choice' };
    values.kernel_cmdline = values.kernel_cmdline
      .split(' ')
      .filter(token => !token.startsWith('resume=') && !token.startsWith('resume_offset='))
      .join(' ');
    choices.kernel_cmdline = { ...choices.kernel_cmdline, value: values.kernel_cmdline };
  }
  const derivedLocale = { value: undefined, provenance: 'technical_necessity', source: 'policy', editable: false };
  values.locales = ['en_US.UTF-8'];
  values.locale_categories = {
    LANG: 'en_US.UTF-8',
    LC_TIME: 'en_US.UTF-8',
    LC_NUMERIC: 'en_US.UTF-8',
    LC_MONETARY: 'en_US.UTF-8',
    LC_MEASUREMENT: 'en_US.UTF-8',
  };
  choices.locales = { ...derivedLocale, value: values.locales };
  choices.locale_categories = { ...derivedLocale, value: values.locale_categories };
  values.storage_option = storageOption;
  values.root_account = rootAccount;
  values.hostname = 'mirroros-ref';
  choices.storage_option = {
    value: storageOption,
    provenance: policy.policy.storage_option.provenance,
    source: storageOption === 'ext4-systemd-boot' ? 'policy' : 'choice',
    editable: true,
    tier: option.tier,
    filesystem: option.filesystem,
    bootloader: option.bootloader,
    resume_offset_method: option.resume_offset_method,
  };
  choices.root_account = { ...choices.root_account, value: rootAccount, source: rootAccount === 'locked' ? 'policy' : 'choice' };
  choices.hostname = { ...choices.hostname, value: 'mirroros-ref', source: 'override' };
  const identifier = disk.identity.by_id ?? disk.identity.path;
  choices.target_disk = { value: identifier, provenance: 'hardware_detection', source: 'detected', editable: true };

  const context = { values, option, disk: identifier };
  const operations = operationSequence(storageOption, hibernation).map(kind => {
    const operation = {
      id: kind,
      kind,
      destructive: ['wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'format_filesystems'].includes(kind),
      parameters: parametersFor(kind, context),
      description: OPERATION_DESCRIPTIONS[kind],
    };
    const resolved = resolvedAtApply(kind, option, hibernation);
    if (resolved !== undefined) operation.resolved_at_apply = resolved;
    return operation;
  });

  const secrets = [{
    name: 'account_password',
    purpose: 'Password of the created user account, shared with the root account when root password access is enabled.',
    required_by: rootAccount === 'password' ? ['create_user', 'configure_root_account'] : ['create_user'],
    channel: 'protected_prompt',
    provenance: 'technical_necessity',
  }];

  const warnings = option.tier === 'experimental'
    ? [{
      code: 'storage_option_experimental',
      message: `The storage option ${storageOption} is experimental and has no support commitment.`,
      next_step: 'Select ext4-systemd-boot unless the experimental option is intended.',
    }]
    : [];

  const plan = {
    format_version: 3,
    target: {
      machine: {
        architecture: 'x86_64',
        memory_total_bytes: REFERENCE_MEMORY_BYTES,
        virtualization: 'kvm',
        dmi: { sys_vendor: 'QEMU', product_name: 'Standard PC (Q35 + ICH9, 2009)' },
      },
      profile: { status: 'matched', profile_id: 'reference-vm' },
      disk: {
        path: disk.identity.path,
        by_id: disk.identity.by_id,
        serial: disk.identity.serial,
        size_bytes: disk.identity.size_bytes,
        eligible: disk.eligible,
        current_layout: disk.layout,
      },
    },
    choices,
    operations,
    secret_requirements: secrets,
    hardware_selections: {
      selections: [
        {
          id: 'target_disk',
          fact: 'storage.disks',
          value: identifier,
          provenance: 'hardware_detection',
          rule: 'single_eligible_disk',
        },
        {
          id: 'boot_mode',
          fact: 'firmware.boot_mode',
          value: 'uefi',
          provenance: 'hardware_detection',
          rule: 'uefi_boot_mode_check',
        },
      ],
      detected_capabilities: [
        { id: 'graphics_vendor', fact: 'hardware.graphics', value: ['qemu_virtual'], rule: 'not_evaluated', next_story: '2.6' },
        { id: 'battery_present', fact: 'hardware.battery_present', value: false, rule: 'not_evaluated', next_story: '2.6' },
        { id: 'virtualization', fact: 'hardware.virtualization', value: 'kvm', rule: 'not_evaluated', next_story: '2.6' },
        { id: 'cpu_vendor', fact: 'hardware.cpu.vendor', value: 'AuthenticAMD', rule: 'not_evaluated', next_story: '2.6' },
      ],
    },
    warnings,
    facts_binding: {
      facts_sha256: sha256Canonical(facts),
      run_id: facts.source.run_id,
      commit: facts.source.commit,
      dirty: facts.source.dirty,
    },
    policy_binding: {
      policy_sha256: sha256Canonical(policy),
      profile_definition_sha256: sha256Canonical(JSON.parse(readFileSync(profileDefinitionPath, 'utf8'))),
      override_sha256: sha256Canonical({ hostname: 'mirroros-ref' }),
    },
  };
  return withDigest(plan);
}

function operationOf(plan, kind) {
  return plan.operations.find(operation => operation.kind === kind);
}

// Each entry: file name `<expected code>--<variant>`, the valid plan to start from, the mutation,
// and whether to recompute the digest afterwards so that only the intended rule is violated.
export const INVALID_CASES = [
  ['plan_invalid_type--choices-not-object', ['ext4-systemd-boot', 'locked'], plan => { plan.choices = []; }],
  ['plan_non_integer_number--swapfile', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.swapfile_size.value = 1.5; }, false],
  ['plan_format_unsupported--version-1', ['ext4-systemd-boot', 'locked'], plan => { plan.format_version = 1; }],
  ['plan_format_unsupported--version-2', ['ext4-systemd-boot', 'locked'], plan => { plan.format_version = 2; }],
  ['plan_field_missing--target', ['ext4-systemd-boot', 'locked'], plan => { delete plan.target; }],
  ['plan_label_missing--source', ['ext4-systemd-boot', 'locked'], plan => { delete plan.choices.hostname.source; }],
  ['plan_unknown_field--approved', ['ext4-systemd-boot', 'locked'], plan => { plan.approved = true; }],
  ['plan_unknown_field--approval', ['ext4-systemd-boot', 'locked'], plan => { plan.approval = { digest: plan.digest.value }; }],
  ['plan_unknown_field--operation', ['ext4-systemd-boot', 'locked'], plan => { plan.operations[0].extra = 1; }],
  ['plan_secret_value_present--choice-key', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.user_password = { value: 'x' }; }],
  ['plan_secret_value_present--secret-entry', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements[0].value = 'x'; }],
  ['plan_secret_value_present--parameters', ['ext4-systemd-boot', 'locked'], plan => { operationOf(plan, 'create_user').parameters.password = 'x'; }],
  ['operations_storage_mismatch--option', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.storage_option.value = 'btrfs-rescue'; }],
  ['operation_kind_unknown--format-disk', ['ext4-systemd-boot', 'locked'], plan => { plan.operations[3].kind = 'format_disk'; plan.operations[3].id = 'format_disk'; }],
  ['operation_order_invalid--swapped', ['ext4-systemd-boot', 'locked'], plan => {
    [plan.operations[5], plan.operations[6]] = [plan.operations[6], plan.operations[5]];
  }],
  ['operation_id_invalid--renamed', ['ext4-systemd-boot', 'locked'], plan => { plan.operations[4].id = 'mount'; }],
  ['operation_destructive_mismatch--wipe', ['ext4-systemd-boot', 'locked'], plan => { plan.operations[0].destructive = false; }],
  ['destructive_without_target_disk--missing', ['ext4-systemd-boot', 'locked'], plan => { delete plan.choices.target_disk; }],
  ['root_account_secret_mismatch--password-undeclared', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.root_account.value = 'password'; }],
  ['root_account_secret_mismatch--locked-declared', ['ext4-systemd-boot', 'password'], plan => { plan.choices.root_account.value = 'locked'; }],
  ['secret_consumer_mismatch--wrong-operation', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements[0].required_by = ['mount_target']; }],
  ['secret_consumer_mismatch--user-undeclared', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements = []; }],
  ['secret_consumer_mismatch--duplicated', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements.push(structuredClone(plan.secret_requirements[0])); }],
  ['lang_not_in_locales--lang', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.locales.value = ['es_ES.UTF-8']; }],
  ['locale_derivation_mismatch--lc-all', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.locale_categories.value.LC_ALL = 'en_US.UTF-8'; }],
  ['locale_derivation_mismatch--formats', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.regional_format.value = 'es_ES.UTF-8'; }],
  ['plan_field_missing--memory', ['ext4-systemd-boot', 'locked'], plan => { delete plan.target.machine.memory_total_bytes; }],
  ['machine_identity_mismatch--architecture', ['ext4-systemd-boot', 'locked'], plan => { plan.target.machine.architecture = 'aarch64'; }],
  ['machine_identity_mismatch--memory', ['ext4-systemd-boot', 'locked'], plan => { plan.target.machine.memory_total_bytes += 1048576; }],
  ['machine_identity_mismatch--dmi-availability', ['ext4-systemd-boot', 'locked'], plan => { delete plan.target.machine.dmi; }],
  ['profile_binding_mismatch--matched-without-hash', ['ext4-systemd-boot', 'locked'], plan => { delete plan.policy_binding.profile_definition_sha256; }],
  ['profile_binding_mismatch--unqualified-with-id', ['ext4-systemd-boot', 'locked'], plan => { plan.target.profile = { status: 'unqualified', profile_id: 'reference-vm' }; }],
  ['profile_binding_mismatch--facts-classification', ['ext4-systemd-boot', 'locked'], plan => {
    plan.target.profile = { status: 'unqualified' };
    delete plan.policy_binding.profile_definition_sha256;
    delete plan.policy_binding.override_sha256;
  }],
  ['disk_identity_mismatch--target-disk', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.target_disk.value = 'virtio-OTHER'; }],
  ['disk_identity_mismatch--facts-serial', ['ext4-systemd-boot', 'locked'], plan => { plan.target.disk.serial = 'OTHER-SERIAL'; }],
  ['disk_not_eligible--flag', ['ext4-systemd-boot', 'locked'], plan => { plan.target.disk.eligible = false; }],
  ['plan_size_does_not_fit--swapfile', ['ext4-systemd-boot', 'locked'], plan => { plan.target.disk.size_bytes = 17000000000; }],
  ['hibernation_plan_mismatch--disabled-with-size', ['ext4-systemd-boot', 'locked', false], plan => {
    plan.choices.swapfile_size = { value: 4096, provenance: 'hardware_detection', source: 'detected', editable: true };
  }],
  ['hibernation_plan_mismatch--disabled-with-swapfile', ['ext4-systemd-boot', 'locked', false], plan => {
    const fstab = plan.operations.findIndex(operation => operation.kind === 'generate_fstab');
    plan.operations.splice(fstab + 1, 0, {
      id: 'create_swapfile',
      kind: 'create_swapfile',
      destructive: false,
      parameters: { path: '/swapfile', size_mib: 4096, priority: 0 },
      description: OPERATION_DESCRIPTIONS.create_swapfile,
      resolved_at_apply: [{ name: 'resume_offset', method: 'filefrag' }],
    });
  }],
  ['hibernation_plan_mismatch--disabled-with-resume', ['ext4-systemd-boot', 'locked', false], plan => {
    plan.choices.kernel_cmdline.value += ' resume=UUID=<root> resume_offset=<resume_offset>';
  }],
  ['hibernation_plan_mismatch--disabled-with-swap-subvolume', ['btrfs-rescue', 'locked', false], plan => {
    operationOf(plan, 'create_btrfs_subvolumes').parameters.subvolumes.push('@swap');
  }],
  ['hibernation_plan_mismatch--disabled-with-offset-resolution', ['ext4-systemd-boot', 'locked', false], plan => {
    operationOf(plan, 'install_bootloader').resolved_at_apply.push({ name: 'resume_offset', method: 'filefrag' });
  }],
  ['hibernation_plan_mismatch--enabled-without-swapfile', ['ext4-systemd-boot', 'locked'], plan => {
    plan.operations = plan.operations.filter(operation => operation.kind !== 'create_swapfile');
  }],
  ['hibernation_plan_mismatch--enabled-without-size', ['ext4-systemd-boot', 'locked'], plan => { delete plan.choices.swapfile_size; }],
  ['hibernation_plan_mismatch--size-above-memory-range', ['ext4-systemd-boot', 'locked'], plan => {
    plan.choices.swapfile_size.value = 4097;
    operationOf(plan, 'create_swapfile').parameters.size_mib = 4097;
  }],
  ['hibernation_plan_mismatch--enabled-without-priority', ['ext4-systemd-boot', 'locked'], plan => {
    operationOf(plan, 'create_swapfile').parameters.priority = 100;
  }],
  ['hibernation_plan_mismatch--enabled-without-swap-subvolume', ['btrfs-rescue', 'locked'], plan => {
    operationOf(plan, 'mount_target').parameters.subvolumes = ['@', '@home', '@log', '@pkg', '@snapshots'];
  }],
  ['configuration_asset_mismatch--zram-priority', ['ext4-systemd-boot', 'locked'], plan => {
    operationOf(plan, 'configure_zram').parameters.swap_priority = 10;
  }],
  ['configuration_asset_mismatch--sysctl-value', ['ext4-systemd-boot', 'locked'], plan => {
    operationOf(plan, 'configure_memory_reclaim').parameters['vm.swappiness'] = 60;
  }],
  ['configuration_asset_mismatch--missing-zram-operation', ['ext4-systemd-boot', 'locked'], plan => {
    plan.operations = plan.operations.filter(operation => operation.kind !== 'configure_zram');
  }],
  ['configuration_asset_mismatch--missing-package', ['ext4-systemd-boot', 'locked'], plan => {
    const packages = operationOf(plan, 'install_packages').parameters.packages;
    packages.splice(packages.indexOf('zram-generator'), 1);
  }],
  ['configuration_asset_mismatch--missing-zswap', ['ext4-systemd-boot', 'locked'], plan => {
    plan.choices.kernel_cmdline.value = plan.choices.kernel_cmdline.value.replace(' zswap.enabled=0', '');
  }],
  ['configuration_asset_mismatch--source-hash', ['ext4-systemd-boot', 'locked'], plan => {
    operationOf(plan, 'configure_zram').parameters.source_sha256 = 'f'.repeat(64);
  }],
  ['facts_binding_mismatch--run-id', ['ext4-systemd-boot', 'locked'], plan => { plan.facts_binding.run_id = 'other-run'; }],
  ['facts_binding_mismatch--facts-hash', ['ext4-systemd-boot', 'locked'], plan => { plan.facts_binding.facts_sha256 = 'f'.repeat(64); }],
  ['digest_mismatch--edited-content', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.hostname.value = 'edited'; }, false],
];

export function buildInvalidPlan([, [storageOption, rootAccount, hibernation = true], mutate, resign = true]) {
  const plan = structuredClone(buildValidPlan(storageOption, rootAccount, hibernation));
  mutate(plan);
  return resign ? withDigest(plan) : plan;
}

export function allFixtures() {
  const files = new Map();
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      files.set(`valid/${storageOption}--${rootAccount}.json`, buildValidPlan(storageOption, rootAccount));
    }
    files.set(`valid/${storageOption}--hibernation-disabled.json`, buildValidPlan(storageOption, 'locked', false));
  }
  for (const testCase of INVALID_CASES) files.set(`invalid/${testCase[0]}.json`, buildInvalidPlan(testCase));
  return files;
}

export function serializeFixture(plan) {
  return `${JSON.stringify(plan, null, 2)}\n`;
}

if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv.includes('--write')) {
  for (const directory of ['valid', 'invalid']) rmSync(join(planFixturesRoot, directory), { recursive: true, force: true });
  for (const [name, plan] of allFixtures()) {
    const destination = join(planFixturesRoot, name);
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, serializeFixture(plan));
  }
}
