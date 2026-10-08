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

export const STORAGE_OPTION_NAMES = ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'];
export const ROOT_ACCOUNT_MODES = ['locked', 'password'];

export function fixtureFacts() {
  return discover('reference-vm-layout');
}

function readPolicy() {
  return JSON.parse(readFileSync(policyPath, 'utf8'));
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
      return { subvolumes: option.subvolumes, mount_options: option.mount_options };
    case 'mount_target':
      return { esp_mount_point: values.esp.mount_point };
    case 'install_packages':
      return { packages: [...values.packages, values.network.package, ...option.additional_packages] };
    case 'generate_fstab':
      return { identifier: 'uuid' };
    case 'create_swapfile':
      return { path: '/swapfile', size_mib: values.swapfile_size };
    case 'configure_locale_time_console':
      return {
        locales: values.locales,
        lang: values.lang,
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

function resolvedAtApply(kind, option) {
  if (kind === 'format_filesystems') return [{ name: 'partition_uuids', method: 'blkid' }];
  if (kind === 'create_swapfile') return [{ name: 'resume_offset', method: option.resume_offset_method }];
  if (kind === 'install_bootloader') {
    return [
      { name: 'root_uuid', method: 'blkid' },
      { name: 'resume_offset', method: option.resume_offset_method },
    ];
  }
  return undefined;
}

export function buildValidPlan(storageOption, rootAccount) {
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
  const operations = operationSequence(storageOption).map(kind => {
    const operation = {
      id: kind,
      kind,
      destructive: ['wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'format_filesystems'].includes(kind),
      parameters: parametersFor(kind, context),
      description: OPERATION_DESCRIPTIONS[kind],
    };
    const resolved = resolvedAtApply(kind, option);
    if (resolved !== undefined) operation.resolved_at_apply = resolved;
    return operation;
  });

  const secrets = [{
    name: 'user_password',
    purpose: 'Password of the created user account.',
    required_by: ['create_user'],
    channel: 'protected_prompt',
    provenance: 'technical_necessity',
  }];
  if (rootAccount === 'password') {
    secrets.push({
      name: 'root_password',
      purpose: 'Password of the root account.',
      required_by: ['configure_root_account'],
      channel: 'protected_prompt',
      provenance: 'personal_preference',
    });
  }

  const warnings = option.tier === 'experimental'
    ? [{
      code: 'storage_option_experimental',
      message: `The storage option ${storageOption} is experimental and has no support commitment.`,
      next_step: 'Select ext4-systemd-boot unless the experimental option is intended.',
    }]
    : [];

  const plan = {
    format_version: 1,
    target: {
      target_id: facts.source.target_id,
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
      target_id: facts.source.target_id,
      commit: facts.source.commit,
      dirty: facts.source.dirty,
    },
    policy_binding: {
      policy_sha256: sha256Canonical(policy),
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
  ['secret_consumer_mismatch--wrong-operation', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements[0].required_by = ['configure_root_account']; }],
  ['secret_consumer_mismatch--user-undeclared', ['ext4-systemd-boot', 'locked'], plan => { plan.secret_requirements = []; }],
  ['lang_not_in_locales--lang', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.lang.value = 'fr_FR.UTF-8'; }],
  ['disk_identity_mismatch--target-disk', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.target_disk.value = 'virtio-OTHER'; }],
  ['disk_identity_mismatch--facts-serial', ['ext4-systemd-boot', 'locked'], plan => { plan.target.disk.serial = 'OTHER-SERIAL'; }],
  ['disk_not_eligible--flag', ['ext4-systemd-boot', 'locked'], plan => { plan.target.disk.eligible = false; }],
  ['plan_size_does_not_fit--swapfile', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.swapfile_size.value = 65536; }],
  ['facts_binding_mismatch--target-id', ['ext4-systemd-boot', 'locked'], plan => { plan.facts_binding.target_id = 'other-target'; }],
  ['facts_binding_mismatch--facts-hash', ['ext4-systemd-boot', 'locked'], plan => { plan.facts_binding.facts_sha256 = 'f'.repeat(64); }],
  ['digest_mismatch--edited-content', ['ext4-systemd-boot', 'locked'], plan => { plan.choices.hostname.value = 'edited'; }, false],
];

export function buildInvalidPlan([, [storageOption, rootAccount], mutate, resign = true]) {
  const plan = structuredClone(buildValidPlan(storageOption, rootAccount));
  mutate(plan);
  return resign ? withDigest(plan) : plan;
}

export function allFixtures() {
  const files = new Map();
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      files.set(`valid/${storageOption}--${rootAccount}.json`, buildValidPlan(storageOption, rootAccount));
    }
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
