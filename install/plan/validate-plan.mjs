import { RULES, evaluateValues } from '../../hardware/rules/evaluate-rules.mjs';
import { isRecord, reason } from '../discovery/validate-facts.mjs';
import { canonicalize } from './canonical-json.mjs';
import { sha256Canonical, verifyDigest } from './digest-plan.mjs';
import {
  SWAPFILE_MINIMUM_MIB,
  SWAPFILE_PRIORITY,
  hasResumeParameters,
  isMemoryBytes,
  isSwapfileSizeInRange,
  requiredDiskBytes,
} from './swap-policy.mjs';

export const PLAN_FORMAT_VERSION = 5;
export const PLAN_POLICY_FORMAT_VERSION = 3;
export const CHOICES_FORMAT_VERSION = 3;
export const EXIT_VALID = 0;
export const EXIT_INVALID_INPUT = 2;
export const EXIT_UPSTREAM_FAILURE = 5;
export const EXIT_INTERNAL = 6;

export const PROVENANCE_CLASSES = ['personal_preference', 'hardware_detection', 'arch_guidance', 'technical_necessity'];
export const SOURCES = ['policy', 'detected', 'override', 'choice'];
export const STORAGE_OPTIONS = ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'];
export const TIERS = ['default', 'supported', 'experimental'];
export const ROOT_ACCOUNT_MODES = ['locked', 'password'];
export const ACCOUNT_PASSWORD = 'account_password';
export const SECRET_NAMES = [ACCOUNT_PASSWORD];
export const SECRET_CHANNEL = 'protected_prompt';
export const MIBIBYTE = 1048576;
export const PROFILE_STATUSES = ['matched', 'unqualified'];
export const LANGUAGES = ['en_US.UTF-8', 'es_ES.UTF-8'];
export const REGIONAL_FORMATS = ['follow_language', ...LANGUAGES];
export const FORMAT_CATEGORIES = ['LC_TIME', 'LC_NUMERIC', 'LC_MONETARY', 'LC_MEASUREMENT'];
export const DERIVED_KEYS = ['locales', 'locale_categories'];
const MACHINE_DMI_KEYS = ['sys_vendor', 'product_name'];

// The only place where locales and category values are derived from the language and the regional formats.
export function deriveLocalization(lang, regionalFormat) {
  const formats = regionalFormat === 'follow_language' ? lang : regionalFormat;
  return {
    locales: [...new Set([lang, formats])],
    locale_categories: { LANG: lang, ...Object.fromEntries(FORMAT_CATEGORIES.map(category => [category, formats])) },
  };
}

// The consumers of the single account_password requirement for a root account mode.
export function accountPasswordConsumers(rootAccount) {
  return rootAccount === 'password' ? ['create_user', 'configure_root_account'] : ['create_user'];
}

function projectMachine({ architecture, memory_total_bytes: memoryTotalBytes, virtualization, dmi } = {}) {
  const machine = { architecture };
  if (memoryTotalBytes !== undefined) machine.memory_total_bytes = memoryTotalBytes;
  if (virtualization !== undefined) machine.virtualization = virtualization;
  const kept = {};
  for (const key of MACHINE_DMI_KEYS) {
    if (dmi?.[key] !== undefined) kept[key] = dmi[key];
  }
  if (Object.keys(kept).length > 0) machine.dmi = kept;
  return machine;
}

// The observed safety identity projection of a facts document: architecture, detected memory, virtualization,
// and the allowlisted DMI sys_vendor and product_name, each omitted when it was not observed.
export function machineProjection(facts) {
  const detected = facts.layers?.detected ?? {};
  return projectMachine({
    architecture: detected.hardware?.architecture,
    memory_total_bytes: detected.hardware?.memory_total_bytes,
    virtualization: detected.hardware?.virtualization,
    dmi: detected.firmware?.dmi,
  });
}

export const TARGET_MODES = ['whole_disk', 'replace_installation'];

export const KINDS = {
  record_disk_partuuids: false,
  remove_stale_uefi_entries: false,
  wipe_partition_signatures: true,
  format_partitions: true,
  register_uefi_boot_entry: false,
  wipe_disk_signatures: true,
  create_partition_table: true,
  create_partitions: true,
  format_filesystems: true,
  create_btrfs_subvolumes: false,
  mount_target: false,
  install_packages: false,
  generate_fstab: false,
  configure_zram: false,
  configure_memory_reclaim: false,
  create_swapfile: false,
  configure_locale_time_console: false,
  configure_hostname_network: false,
  create_user: false,
  configure_root_account: false,
  configure_sudo_sysrq_pacman: false,
  install_bootloader: false,
  install_limine_snapshot_tools: false,
  configure_snapper: false,
  enable_services: false,
  create_baseline_snapshot: false,
  sync_limine_snapshot_entries: false,
};

const EXT4_SEQUENCE = [
  'wipe_disk_signatures',
  'create_partition_table',
  'create_partitions',
  'format_filesystems',
  'mount_target',
  'install_packages',
  'configure_zram',
  'configure_memory_reclaim',
  'generate_fstab',
  'create_swapfile',
  'configure_locale_time_console',
  'configure_hostname_network',
  'create_user',
  'configure_root_account',
  'configure_sudo_sysrq_pacman',
  'install_bootloader',
  'enable_services',
];

function insertAfter(sequence, anchor, ...kinds) {
  const index = sequence.indexOf(anchor);
  return [...sequence.slice(0, index + 1), ...kinds, ...sequence.slice(index + 1)];
}

const RESCUE_SEQUENCE = insertAfter(
  insertAfter(
    insertAfter(EXT4_SEQUENCE, 'format_filesystems', 'create_btrfs_subvolumes'),
    'install_bootloader',
    'configure_snapper',
  ),
  'enable_services',
  'create_baseline_snapshot',
);

const LIMINE_SEQUENCE = [
  ...insertAfter(RESCUE_SEQUENCE, 'install_bootloader', 'install_limine_snapshot_tools'),
  'sync_limine_snapshot_entries',
];

const SEQUENCES = {
  'ext4-systemd-boot': EXT4_SEQUENCE,
  'btrfs-rescue': RESCUE_SEQUENCE,
  'btrfs-limine': LIMINE_SEQUENCE,
};

// The fixed operation order of a storage option. create_swapfile exists only when hibernation is enabled;
// omitting it does not change the relative order of the other operations.
export function operationSequence(storageOption, hibernation = true, targetMode = 'whole_disk') {
  let sequence = SEQUENCES[storageOption];
  if (sequence === undefined || !TARGET_MODES.includes(targetMode)) return undefined;
  if (targetMode === 'replace_installation') {
    sequence = ['wipe_partition_signatures', 'format_partitions', ...sequence.slice(4)];
  } else {
    sequence = ['record_disk_partuuids', ...insertAfter(sequence, 'create_partitions', 'remove_stale_uefi_entries')];
  }
  return [...sequence.filter(kind => hibernation || kind !== 'create_swapfile'), 'register_uefi_boot_entry'];
}

const NEXT_STEPS = {
  replacement_target_invalid: 'Repeat discovery and select an unmounted replacement candidate that meets the storage policy.',
  target_mode_mismatch: 'Regenerate the plan with consistent target mode, partition identities, and operations.',
  plan_not_json: 'Provide a plan produced by operations/install plan.',
  plan_invalid_type: 'Regenerate the plan with operations/install plan; do not edit it by hand.',
  plan_non_integer_number: 'Regenerate the plan; the format allows integers only.',
  plan_format_unsupported: 'Installation plans of earlier versions are not migrated; regenerate the plan from new target facts with operations/install plan.',
  plan_field_missing: 'Regenerate the plan with operations/install plan.',
  plan_label_missing: 'Regenerate the plan; every value needs provenance, source, and editable.',
  plan_unknown_field: 'Regenerate the plan; a plan can never express approval or extra fields.',
  plan_secret_value_present: 'Remove the secret-like field and regenerate the plan; secrets are only named, never stored.',
  operations_storage_mismatch: 'Regenerate the plan so the operations match the storage option.',
  operation_kind_unknown: 'Regenerate the plan; only kinds of the contract vocabulary are allowed.',
  operation_order_invalid: 'Regenerate the plan; the operation order is fixed per storage option.',
  operation_id_invalid: 'Regenerate the plan; an operation id equals its kind.',
  operation_destructive_mismatch: 'Regenerate the plan; the destructive flag is fixed per kind.',
  destructive_without_target_disk: 'Choose a target disk and regenerate the plan.',
  root_account_secret_mismatch: 'Regenerate the plan so root_account and the root consumer of account_password agree.',
  secret_consumer_mismatch: 'Regenerate the plan so the single account_password requirement has its consuming operations.',
  lang_not_in_locales: 'Choose a lang that is one of the locales and regenerate the plan.',
  locale_derivation_mismatch: 'Regenerate the plan; locales and locale_categories are derived from lang and regional_format.',
  machine_identity_mismatch: 'Regenerate the plan from the current target-facts.json.',
  profile_binding_mismatch: 'Regenerate the plan from the current target-facts.json; the profile classification and its bindings must agree.',
  disk_identity_mismatch: 'Regenerate the plan from the current target-facts.json.',
  disk_not_eligible: 'Choose an eligible disk and regenerate the plan.',
  plan_size_does_not_fit: 'Choose a smaller swapfile_size, disable hibernation, or use a larger disk, and regenerate the plan.',
  hibernation_plan_mismatch: 'Regenerate the plan; the swapfile, @swap, and resume settings follow the hibernation choice and the detected memory.',
  hardware_rules_mismatch: 'Regenerate the plan from the current target-facts.json; rule outcomes, rule packages, and rule warnings are derived by the hardware rules and cannot be edited.',
  configuration_asset_mismatch: 'Regenerate the plan from this MirrorOS checkout; the zram, memory reclaim, package, and zswap settings must agree with the policy and its assets.',
  facts_binding_mismatch: 'Regenerate the plan from the current target-facts.json.',
  digest_mismatch: 'Regenerate the plan; its content changed after the digest was computed.',
};

const SECRET_KEY = /password|passphrase|secret|token/i;
const HOSTNAME_LABEL = /^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/;
const USER_NAME = /^[a-z_][a-z0-9_-]*\$?$/;
const HEX_64 = /^[0-9a-f]{64}$/;

export function isHostname(value) {
  return typeof value === 'string'
    && value.length <= 64
    && value.split('.').every(label => HOSTNAME_LABEL.test(label));
}

export function isUserName(value) {
  return typeof value === 'string' && value.length <= 32 && value !== 'root' && USER_NAME.test(value);
}

const isString = value => typeof value === 'string' && value.length > 0;
const isInteger = value => Number.isSafeInteger(value);
const isStringList = value => Array.isArray(value) && value.every(isString);
const isBoolean = value => typeof value === 'boolean';

const hasExactKeys = (value, keys) => isRecord(value)
  && Object.keys(value).length === keys.length
  && keys.every(key => key in value);
const isZramPolicy = value => hasExactKeys(value, ['package', 'package_source', 'destination', 'zram_size', 'compression_algorithm', 'swap_priority'])
  && ['package', 'package_source', 'destination', 'zram_size', 'compression_algorithm'].every(key => isString(value[key]))
  && isInteger(value.swap_priority);
const isMemoryReclaimPolicy = value => hasExactKeys(value, ['destination', 'settings'])
  && isString(value.destination)
  && isRecord(value.settings)
  && Object.keys(value.settings).length > 0
  && Object.values(value.settings).every(isInteger);

const choice = (editable, check, description) => ({ editable, check, description });
const fixed = description => choice(false, () => true, description);

export const CHOICE_SPECS = {
  target_mode: choice(true, value => TARGET_MODES.includes(value), `one of ${TARGET_MODES.join(', ')}`),
  replace_root_partuuid: choice(true, value => typeof value === 'string' && /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value), 'a full root PARTUUID'),
  target_disk: choice(true, isString, 'a disk identifier string'),
  storage_option: choice(true, value => STORAGE_OPTIONS.includes(value), `one of ${STORAGE_OPTIONS.join(', ')}`),
  hibernation: choice(true, isBoolean, 'a boolean'),
  // The upper bound depends on the detected memory; see swap-policy.mjs. Present only when hibernation is true.
  swapfile_size: choice(
    true,
    value => isInteger(value) && value >= SWAPFILE_MINIMUM_MIB,
    `an integer count of MiB, at least ${SWAPFILE_MINIMUM_MIB}`,
  ),
  lang: choice(true, value => LANGUAGES.includes(value), `one of ${LANGUAGES.join(', ')}`),
  regional_format: choice(true, value => REGIONAL_FORMATS.includes(value), `one of ${REGIONAL_FORMATS.join(', ')}`),
  locales: choice(
    false,
    value => isStringList(value) && value.length > 0 && new Set(value).size === value.length,
    'a derived non-empty list of unique locales',
  ),
  locale_categories: choice(false, value => isRecord(value) && Object.values(value).every(isString), 'a derived object of locale strings'),
  console_keymap: choice(true, isString, 'a keymap string'),
  timezone: choice(true, isString, 'a time zone string'),
  hostname: choice(true, isHostname, 'an RFC 1123 hostname of at most 64 characters'),
  user_name: choice(true, isUserName, 'a valid user name other than root'),
  root_account: choice(true, value => ROOT_ACCOUNT_MODES.includes(value), `one of ${ROOT_ACCOUNT_MODES.join(', ')}`),
  firmware_mode: fixed('a fixed policy value'),
  partition_table: fixed('a fixed policy value'),
  esp: fixed('a fixed policy value'),
  root_minimum_bytes: choice(false, value => isInteger(value) && value > 0, 'a positive integer'),
  kernel: fixed('a fixed policy value'),
  initramfs: fixed('a fixed policy value'),
  kernel_cmdline: fixed('a fixed policy value'),
  bootloader_options: fixed('a fixed policy value'),
  zram: choice(false, isZramPolicy, 'the fixed zram policy object'),
  memory_reclaim: choice(false, isMemoryReclaimPolicy, 'the fixed memory reclaim policy object'),
  packages: fixed('a fixed policy value'),
  mirrorlist: fixed('a fixed policy value'),
  hardware_clock: fixed('a fixed policy value'),
  time_sync: fixed('a fixed policy value'),
  network: fixed('a fixed policy value'),
  user_groups: fixed('a fixed policy value'),
  user_shell: fixed('a fixed policy value'),
  sudoers: fixed('a fixed policy value'),
  sysrq: fixed('a fixed policy value'),
  pacman_options: fixed('a fixed policy value'),
  fstrim: fixed('a fixed policy value'),
};

const STORAGE_OPTION_EXTRAS = ['tier', 'filesystem', 'bootloader', 'resume_offset_method'];
const DISK_IDENTITY_KEYS = ['path', 'by_id', 'wwn', 'serial', 'model', 'size_bytes'];
const TOP_LEVEL = [
  'format_version', 'target_mode', 'target', 'choices', 'operations', 'secret_requirements', 'hardware_selections',
  'warnings', 'facts_binding', 'policy_binding', 'digest',
];

function add(reasons, code, message) {
  reasons.push(reason(code, message, NEXT_STEPS[code]));
}

function walkNumbers(value, path, reasons) {
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) {
      add(reasons, 'plan_non_integer_number', `${path} is not an integer; the plan format allows integers only.`);
    }
  } else if (Array.isArray(value)) {
    value.forEach((item, index) => walkNumbers(item, `${path}[${index}]`, reasons));
  } else if (isRecord(value)) {
    for (const [key, item] of Object.entries(value)) walkNumbers(item, `${path}.${key}`, reasons);
  }
}

function walkSecretKeys(value, path, reasons) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => walkSecretKeys(item, `${path}[${index}]`, reasons));
  } else if (isRecord(value)) {
    for (const [key, item] of Object.entries(value)) {
      if (SECRET_KEY.test(key)) {
        add(reasons, 'plan_secret_value_present', `${path}.${key} has a secret-like name; secrets are never stored in a plan.`);
      }
      walkSecretKeys(item, `${path}.${key}`, reasons);
    }
  }
}

function checkRecord(value, path, required, optional, reasons) {
  if (!isRecord(value)) {
    add(reasons, 'plan_invalid_type', `${path} must be an object.`);
    return false;
  }
  for (const key of required) {
    if (value[key] === undefined) add(reasons, 'plan_field_missing', `${path}.${key} is required.`);
  }
  const allowed = new Set([...required, ...optional]);
  for (const key of Object.keys(value)) {
    if (allowed.has(key)) continue;
    if (SECRET_KEY.test(key)) {
      add(reasons, 'plan_secret_value_present', `${path}.${key} has a secret-like name; secrets are never stored in a plan.`);
    } else {
      add(reasons, 'plan_unknown_field', `${path}.${key} is not an allowed field.`);
    }
  }
  return true;
}

function expect(condition, path, description, reasons) {
  if (!condition) add(reasons, 'plan_invalid_type', `${path} must be ${description}.`);
  return condition;
}

function checkReasonList(list, path, reasons) {
  if (!expect(Array.isArray(list), path, 'a list', reasons)) return;
  list.forEach((entry, index) => {
    const entryPath = `${path}[${index}]`;
    if (checkRecord(entry, entryPath, ['code', 'message', 'next_step'], [], reasons)) {
      for (const key of ['code', 'message', 'next_step']) {
        if (entry[key] !== undefined) expect(isString(entry[key]), `${entryPath}.${key}`, 'a non-empty string', reasons);
      }
    }
  });
}

function checkLayout(layout, path, reasons) {
  if (!checkRecord(layout, path, ['partitions'], ['partition_table'], reasons)) return;
  if (layout.partition_table !== undefined
    && checkRecord(layout.partition_table, `${path}.partition_table`, [], ['type', 'uuid', 'sector_size_bytes'], reasons)) {
    if (layout.partition_table.sector_size_bytes !== undefined) expect(isInteger(layout.partition_table.sector_size_bytes) && layout.partition_table.sector_size_bytes > 0, `${path}.partition_table.sector_size_bytes`, 'a positive integer', reasons);
    for (const key of ['type', 'uuid']) {
      if (layout.partition_table[key] !== undefined) {
        expect(isString(layout.partition_table[key]), `${path}.partition_table.${key}`, 'a non-empty string', reasons);
      }
    }
  }
  if (!expect(Array.isArray(layout.partitions), `${path}.partitions`, 'a list', reasons)) return;
  layout.partitions.forEach((partition, index) => {
    const partitionPath = `${path}.partitions[${index}]`;
    if (!checkRecord(partition, partitionPath, ['path'], ['size_bytes', 'fstype', 'label', 'uuid', 'partuuid', 'mountpoints', 'type_guid', 'partition_number', 'start_sector', 'partition_label'], reasons)) return;
    for (const key of ['partition_number', 'start_sector']) {
      if (partition[key] !== undefined) expect(isInteger(partition[key]) && partition[key] > 0, `${partitionPath}.${key}`, 'a positive integer', reasons);
    }
    for (const key of ['path', 'fstype', 'label', 'uuid', 'partuuid', 'type_guid', 'partition_label']) {
      if (partition[key] !== undefined) expect(isString(partition[key]), `${partitionPath}.${key}`, 'a non-empty string', reasons);
    }
    if (partition.size_bytes !== undefined) {
      expect(isInteger(partition.size_bytes) && partition.size_bytes >= 0, `${partitionPath}.size_bytes`, 'a non-negative integer', reasons);
    }
    if (partition.mountpoints !== undefined) {
      expect(isStringList(partition.mountpoints), `${partitionPath}.mountpoints`, 'a list of strings', reasons);
    }
  });
}

function checkMachine(machine, reasons) {
  const path = 'plan.target.machine';
  if (!checkRecord(machine, path, ['architecture', 'memory_total_bytes'], ['virtualization', 'dmi'], reasons)) return;
  for (const key of ['architecture', 'virtualization']) {
    if (machine[key] !== undefined) expect(isString(machine[key]), `${path}.${key}`, 'a non-empty string', reasons);
  }
  if (machine.memory_total_bytes !== undefined) {
    expect(isMemoryBytes(machine.memory_total_bytes), `${path}.memory_total_bytes`, 'a positive integer', reasons);
  }
  if (machine.dmi !== undefined && checkRecord(machine.dmi, `${path}.dmi`, [], MACHINE_DMI_KEYS, reasons)) {
    for (const key of MACHINE_DMI_KEYS) {
      if (machine.dmi[key] !== undefined) expect(isString(machine.dmi[key]), `${path}.dmi.${key}`, 'a non-empty string', reasons);
    }
    expect(Object.keys(machine.dmi).length > 0, `${path}.dmi`, 'omitted when no value was observed', reasons);
  }
}

function checkProfile(profile, reasons) {
  const path = 'plan.target.profile';
  if (!checkRecord(profile, path, ['status'], ['profile_id'], reasons)) return;
  if (profile.status !== undefined) expect(PROFILE_STATUSES.includes(profile.status), `${path}.status`, `one of ${PROFILE_STATUSES.join(', ')}`, reasons);
  if (profile.profile_id !== undefined) expect(isString(profile.profile_id), `${path}.profile_id`, 'a non-empty string', reasons);
}

function checkTarget(target, reasons) {
  if (!checkRecord(target, 'plan.target', ['machine', 'profile', 'disk'], ['installation'], reasons)) return;
  if (target.machine !== undefined) checkMachine(target.machine, reasons);
  if (target.profile !== undefined) checkProfile(target.profile, reasons);
  const path = 'plan.target.disk';
  if (target.disk === undefined) return;
  if (!checkRecord(target.disk, path, ['eligible', 'current_layout'], DISK_IDENTITY_KEYS, reasons)) return;
  for (const key of ['path', 'by_id', 'wwn', 'serial', 'model']) {
    if (target.disk[key] !== undefined) expect(isString(target.disk[key]), `${path}.${key}`, 'a non-empty string', reasons);
  }
  if (target.disk.size_bytes !== undefined) {
    expect(isInteger(target.disk.size_bytes) && target.disk.size_bytes > 0, `${path}.size_bytes`, 'a positive integer', reasons);
  }
  if (target.disk.eligible !== undefined) expect(typeof target.disk.eligible === 'boolean', `${path}.eligible`, 'a boolean', reasons);
  if (target.disk.by_id === undefined && target.disk.path === undefined) {
    add(reasons, 'plan_field_missing', `${path} needs by_id or path to identify the disk.`);
  }
  if (target.disk.current_layout !== undefined) checkLayout(target.disk.current_layout, `${path}.current_layout`, reasons);
}

function checkChoices(choices, reasons) {
  if (!isRecord(choices)) {
    add(reasons, 'plan_invalid_type', 'plan.choices must be an object.');
    return;
  }
  // swapfile_size exists only while hibernation is enabled; checkHibernation owns its presence rules.
  for (const key of Object.keys(CHOICE_SPECS)) {
    if (!['target_disk', 'swapfile_size', 'replace_root_partuuid'].includes(key) && choices[key] === undefined) {
      add(reasons, 'plan_field_missing', `plan.choices.${key} is required.`);
    }
  }
  for (const [key, entry] of Object.entries(choices)) {
    const path = `plan.choices.${key}`;
    const spec = CHOICE_SPECS[key];
    if (spec === undefined) {
      add(reasons, SECRET_KEY.test(key) ? 'plan_secret_value_present' : 'plan_unknown_field', `${path} is not an allowed choice.`);
      continue;
    }
    const extras = key === 'storage_option' ? STORAGE_OPTION_EXTRAS : [];
    if (!checkRecord(entry, path, ['value'], ['provenance', 'source', 'editable', ...extras], reasons)) continue;
    for (const label of ['provenance', 'source', 'editable']) {
      if (entry[label] === undefined) add(reasons, 'plan_label_missing', `${path}.${label} is required.`);
    }
    if (entry.value !== undefined) expect(spec.check(entry.value), `${path}.value`, spec.description, reasons);
    if (entry.provenance !== undefined) {
      expect(PROVENANCE_CLASSES.includes(entry.provenance), `${path}.provenance`, `one of ${PROVENANCE_CLASSES.join(', ')}`, reasons);
    }
    if (entry.source !== undefined) expect(SOURCES.includes(entry.source), `${path}.source`, `one of ${SOURCES.join(', ')}`, reasons);
    if (entry.editable !== undefined) {
      expect(entry.editable === spec.editable, `${path}.editable`, `${spec.editable} for this choice`, reasons);
    }
    if (key === 'storage_option') {
      for (const extra of STORAGE_OPTION_EXTRAS) {
        if (entry[extra] === undefined) add(reasons, 'plan_field_missing', `${path}.${extra} is required.`);
        else expect(isString(entry[extra]), `${path}.${extra}`, 'a non-empty string', reasons);
      }
      if (entry.tier !== undefined) expect(TIERS.includes(entry.tier), `${path}.tier`, `one of ${TIERS.join(', ')}`, reasons);
    }
  }
}

function checkOperations(operations, reasons) {
  if (!expect(Array.isArray(operations), 'plan.operations', 'a list', reasons)) return;
  operations.forEach((operation, index) => {
    const path = `plan.operations[${index}]`;
    if (!checkRecord(operation, path, ['id', 'kind', 'destructive', 'parameters', 'description'], ['resolved_at_apply'], reasons)) return;
    if (operation.id !== undefined) expect(isString(operation.id), `${path}.id`, 'a non-empty string', reasons);
    if (operation.kind !== undefined) expect(isString(operation.kind), `${path}.kind`, 'a non-empty string', reasons);
    if (operation.destructive !== undefined) expect(typeof operation.destructive === 'boolean', `${path}.destructive`, 'a boolean', reasons);
    if (operation.description !== undefined) expect(isString(operation.description), `${path}.description`, 'a non-empty string', reasons);
    if (operation.parameters !== undefined && expect(isRecord(operation.parameters), `${path}.parameters`, 'an object', reasons)) {
      walkSecretKeys(operation.parameters, `${path}.parameters`, reasons);
    }
    if (operation.resolved_at_apply !== undefined
      && expect(Array.isArray(operation.resolved_at_apply), `${path}.resolved_at_apply`, 'a list', reasons)) {
      operation.resolved_at_apply.forEach((item, itemIndex) => {
        const itemPath = `${path}.resolved_at_apply[${itemIndex}]`;
        if (!checkRecord(item, itemPath, ['name', 'method'], [], reasons)) return;
        for (const key of ['name', 'method']) {
          if (item[key] !== undefined) expect(isString(item[key]), `${itemPath}.${key}`, 'a non-empty string', reasons);
        }
      });
    }
  });
}

function checkSecrets(secrets, reasons) {
  if (!expect(Array.isArray(secrets), 'plan.secret_requirements', 'a list', reasons)) return;
  secrets.forEach((secret, index) => {
    const path = `plan.secret_requirements[${index}]`;
    if (!isRecord(secret)) {
      add(reasons, 'plan_invalid_type', `${path} must be an object.`);
      return;
    }
    const allowed = ['name', 'purpose', 'required_by', 'channel', 'provenance'];
    for (const key of allowed) {
      if (secret[key] === undefined) add(reasons, 'plan_field_missing', `${path}.${key} is required.`);
    }
    for (const key of Object.keys(secret)) {
      if (!allowed.includes(key)) {
        add(reasons, 'plan_secret_value_present', `${path}.${key} is not allowed; a secret entry holds only its name, purpose, consumers, channel, and provenance.`);
      }
    }
    if (secret.name !== undefined) expect(SECRET_NAMES.includes(secret.name), `${path}.name`, `one of ${SECRET_NAMES.join(', ')}`, reasons);
    if (secret.purpose !== undefined) expect(isString(secret.purpose), `${path}.purpose`, 'a non-empty string', reasons);
    if (secret.required_by !== undefined) expect(isStringList(secret.required_by), `${path}.required_by`, 'a list of operation ids', reasons);
    if (secret.channel !== undefined) expect(secret.channel === SECRET_CHANNEL, `${path}.channel`, `"${SECRET_CHANNEL}"`, reasons);
    if (secret.provenance !== undefined) {
      expect(PROVENANCE_CLASSES.includes(secret.provenance), `${path}.provenance`, `one of ${PROVENANCE_CLASSES.join(', ')}`, reasons);
    }
  });
}

function checkHardware(hardware, reasons) {
  if (!checkRecord(hardware, 'plan.hardware_selections', ['selections', 'rule_outcomes', 'rule_packages'], [], reasons)) return;
  const groups = [
    ['selections', ['id', 'fact', 'value', 'provenance', 'rule']],
    ['rule_outcomes', ['rule', 'fact', 'value', 'outcome', 'explanation']],
    ['rule_packages', ['name', 'rule', 'provenance', 'source', 'editable']],
  ];
  for (const [group, fields] of groups) {
    const list = hardware[group];
    if (list === undefined || !expect(Array.isArray(list), `plan.hardware_selections.${group}`, 'a list', reasons)) continue;
    list.forEach((entry, index) => {
      const path = `plan.hardware_selections.${group}[${index}]`;
      if (!checkRecord(entry, path, fields, [], reasons)) return;
      for (const key of ['id', 'fact', 'rule', 'outcome', 'explanation', 'name']) {
        if (entry[key] !== undefined) expect(isString(entry[key]), `${path}.${key}`, 'a non-empty string', reasons);
      }
      if (group === 'selections' && entry.provenance !== undefined) {
        expect(entry.provenance === 'hardware_detection', `${path}.provenance`, '"hardware_detection"', reasons);
      }
    });
  }
}

const POLICY_WARNING_CODES = ['machine_unqualified', 'disk_without_by_id', 'storage_option_experimental', 'swapfile_below_ram'];

function sameDocument(left, right) {
  try {
    return canonicalize(left) === canonicalize(right);
  } catch {
    return false;
  }
}

// The rule outcomes, rule packages, and rule warnings must be exactly what the shared rule module derives from the
// detected values recorded in the plan. No facts are read: the plan carries the value each rule saw.
function checkHardwareRules(plan, reasons) {
  const hardware = plan.hardware_selections;
  if (!isRecord(hardware) || !Array.isArray(hardware.rule_outcomes) || !Array.isArray(hardware.rule_packages)
    || !Array.isArray(plan.warnings) || !hardware.rule_outcomes.every(isRecord)) return;
  const problems = [];
  const recorded = hardware.rule_outcomes.map(entry => entry.rule);
  if (!sameDocument(recorded, RULES.map(rule => rule.id))) {
    problems.push(`rule_outcomes list ${recorded.join(', ')} instead of ${RULES.map(rule => rule.id).join(', ')}`);
  } else {
    let derived;
    try {
      derived = evaluateValues(Object.fromEntries(hardware.rule_outcomes.map(entry => [entry.rule, entry.value])));
    } catch (error) {
      problems.push(`a rule cannot evaluate its recorded value (${error.name})`);
    }
    if (derived !== undefined) {
      hardware.rule_outcomes.forEach((entry, index) => {
        const expected = derived.rule_outcomes[index];
        if (entry.fact !== expected.fact) problems.push(`the fact of rule ${entry.rule} is ${entry.fact} instead of ${expected.fact}`);
        if (entry.outcome !== expected.outcome) problems.push(`the outcome of rule ${entry.rule} is ${entry.outcome}, not valid for its value`);
      });
      if (!sameDocument(hardware.rule_packages, derived.rule_packages)) {
        problems.push('rule_packages differs from the packages named by the rule outcomes, or a rule package lacks its labels or is editable');
      }
      const install = operationKinds(plan).find(operation => operation.kind === 'install_packages');
      if (install !== undefined && !sameDocument(install.parameters?.rule_packages, hardware.rule_packages.map(entry => entry?.name))) {
        problems.push('the install_packages rule_packages parameter differs from hardware_selections.rule_packages');
      }
      const split = plan.warnings.length - derived.warnings.length;
      const head = split < 0 ? plan.warnings : plan.warnings.slice(0, split);
      const tail = split < 0 ? [] : plan.warnings.slice(split);
      if (split < 0 || !sameDocument(tail, derived.warnings)) problems.push('the rule warnings are missing from or differ in warnings');
      if (head.some(item => !isRecord(item) || !POLICY_WARNING_CODES.includes(item.code))) {
        problems.push('warnings holds a warning that no policy check or rule outcome produces');
      }
    }
  }
  for (const problem of problems) add(reasons, 'hardware_rules_mismatch', `${problem[0].toUpperCase()}${problem.slice(1)}.`);
}

function checkBindings(plan, reasons) {
  if (checkRecord(plan.facts_binding, 'plan.facts_binding', ['facts_sha256', 'run_id', 'commit', 'dirty'], [], reasons)) {
    const binding = plan.facts_binding;
    if (binding.facts_sha256 !== undefined) expect(HEX_64.test(binding.facts_sha256), 'plan.facts_binding.facts_sha256', 'a SHA-256 hex string', reasons);
    for (const key of ['run_id', 'commit']) {
      if (binding[key] !== undefined) expect(isString(binding[key]), `plan.facts_binding.${key}`, 'a non-empty string', reasons);
    }
    if (binding.dirty !== undefined) expect(typeof binding.dirty === 'boolean', 'plan.facts_binding.dirty', 'a boolean', reasons);
  }
  if (checkRecord(plan.policy_binding, 'plan.policy_binding', ['policy_sha256'], ['profile_definition_sha256', 'override_sha256'], reasons)) {
    for (const key of ['policy_sha256', 'profile_definition_sha256', 'override_sha256']) {
      if (plan.policy_binding[key] !== undefined) {
        expect(HEX_64.test(plan.policy_binding[key]), `plan.policy_binding.${key}`, 'a SHA-256 hex string', reasons);
      }
    }
  }
  if (checkRecord(plan.digest, 'plan.digest', ['algorithm', 'value'], [], reasons)) {
    if (plan.digest.algorithm !== undefined) expect(plan.digest.algorithm === 'sha256', 'plan.digest.algorithm', '"sha256"', reasons);
    if (plan.digest.value !== undefined) expect(HEX_64.test(plan.digest.value), 'plan.digest.value', 'a SHA-256 hex string', reasons);
  }
}

function checkOperationSet(plan, reasons) {
  if (!Array.isArray(plan.operations)) return;
  const operations = plan.operations.filter(isRecord);
  let kindsKnown = true;
  for (const operation of operations) {
    if (typeof operation.kind !== 'string') continue;
    if (KINDS[operation.kind] === undefined) {
      kindsKnown = false;
      add(reasons, 'operation_kind_unknown', `Operation kind "${operation.kind}" is not in the contract vocabulary.`);
      continue;
    }
    if (operation.id !== operation.kind) {
      add(reasons, 'operation_id_invalid', `Operation "${operation.id}" must have an id equal to its kind "${operation.kind}".`);
    }
    if (typeof operation.destructive === 'boolean' && operation.destructive !== KINDS[operation.kind]) {
      add(reasons, 'operation_destructive_mismatch', `Operation "${operation.kind}" must have destructive ${KINDS[operation.kind]}.`);
    }
  }
  const option = plan.choices?.storage_option?.value;
  const hibernation = plan.choices?.hibernation?.value;
  const full = operationSequence(option, true, plan.target_mode);
  if (!kindsKnown || full === undefined) return;
  const allKinds = operations.map(operation => operation.kind);
  // With a boolean hibernation choice, the presence of create_swapfile is a hibernation consistency rule
  // (checkHibernation); here only its position is checked and the other operations keep their fixed order.
  const swapfileRule = typeof hibernation === 'boolean';
  const kinds = swapfileRule ? allKinds.filter(kind => kind !== 'create_swapfile') : allKinds;
  const expected = swapfileRule ? full.filter(kind => kind !== 'create_swapfile') : full;
  if (kinds.length === expected.length && kinds.every((kind, index) => kind === expected[index])) {
    const swapfiles = allKinds.filter(kind => kind === 'create_swapfile').length;
    const positioned = swapfiles === 0 || (swapfiles === 1 && allKinds[allKinds.indexOf('generate_fstab') + 1] === 'create_swapfile');
    if (!swapfileRule || positioned) return;
    add(reasons, 'operation_order_invalid', `The operations are not in the order required by ${option}.`);
    return;
  }
  const sameSet = kinds.length === expected.length && [...kinds].sort().join() === [...expected].sort().join();
  if (sameSet) {
    add(reasons, 'operation_order_invalid', `The operations are not in the order required by ${option}.`);
  } else {
    add(reasons, 'operations_storage_mismatch', `The operations do not match the storage option ${option}.`);
  }
}

function checkSecretConsistency(plan, reasons) {
  if (!Array.isArray(plan.secret_requirements) || !Array.isArray(plan.operations)) return;
  const secrets = plan.secret_requirements.filter(isRecord);
  const accountSecrets = secrets.filter(secret => secret.name === ACCOUNT_PASSWORD);
  const ids = new Set(plan.operations.filter(isRecord).map(operation => operation.id));
  const rootAccount = plan.choices?.root_account?.value;
  if (accountSecrets.length !== 1) {
    add(reasons, 'secret_consumer_mismatch', `The plan must declare exactly one ${ACCOUNT_PASSWORD} requirement; it declares ${accountSecrets.length}.`);
    return;
  }
  const consumers = accountSecrets[0].required_by;
  if (!Array.isArray(consumers)) return;
  const rootExpected = rootAccount === 'password';
  const rootListed = consumers.includes('configure_root_account');
  if (rootListed !== rootExpected) {
    add(reasons, 'root_account_secret_mismatch', rootExpected
      ? `root_account is "password" but ${ACCOUNT_PASSWORD} is not required by configure_root_account.`
      : `root_account is "${rootAccount}" but ${ACCOUNT_PASSWORD} is required by configure_root_account.`);
  }
  const others = consumers.filter(consumer => consumer !== 'configure_root_account');
  if (others.length !== 1 || others[0] !== 'create_user' || !ids.has('create_user') || consumers.length !== new Set(consumers).size) {
    add(reasons, 'secret_consumer_mismatch', `${ACCOUNT_PASSWORD} must be required by the existing operation "create_user", and by configure_root_account only for a root password.`);
  }
  if (rootExpected && !ids.has('configure_root_account')) {
    add(reasons, 'secret_consumer_mismatch', 'Operation "configure_root_account" needs account_password, but that operation does not exist.');
  }
}

function sameEntries(left, right) {
  return JSON.stringify(Object.entries(left).sort()) === JSON.stringify(Object.entries(right).sort());
}

function checkLocalization(plan, reasons) {
  const { lang, regional_format: formats, locales, locale_categories: categories } = Object.fromEntries(
    Object.entries(plan.choices ?? {}).map(([key, entry]) => [key, entry?.value]),
  );
  if (Array.isArray(locales) && typeof lang === 'string' && !locales.includes(lang)) {
    add(reasons, 'lang_not_in_locales', `lang "${lang}" is not one of the locales.`);
    return;
  }
  if (!LANGUAGES.includes(lang) || !REGIONAL_FORMATS.includes(formats) || !isStringList(locales) || !isRecord(categories)) return;
  const derived = deriveLocalization(lang, formats);
  if (JSON.stringify(locales) !== JSON.stringify(derived.locales) || !sameEntries(categories, derived.locale_categories)) {
    add(reasons, 'locale_derivation_mismatch', 'locales and locale_categories do not match what lang and regional_format derive, or LC_ALL is set.');
  }
}

function checkProfileBinding(plan, reasons) {
  const profile = plan.target?.profile;
  const binding = plan.policy_binding;
  if (!isRecord(profile) || !isRecord(binding)) return;
  if (profile.status === 'matched') {
    if (!isString(profile.profile_id) || binding.profile_definition_sha256 === undefined) {
      add(reasons, 'profile_binding_mismatch', 'A matched profile needs a profile_id and a profile_definition_sha256 binding.');
    }
  } else if (profile.status === 'unqualified') {
    if (profile.profile_id !== undefined || binding.profile_definition_sha256 !== undefined || binding.override_sha256 !== undefined) {
      add(reasons, 'profile_binding_mismatch', 'An unqualified machine has no profile id, profile definition hash, or override hash.');
    }
  }
}

function checkDisk(plan, reasons) {
  const disk = plan.target?.disk;
  const targetChoice = plan.choices?.target_disk;
  const hasDestructive = Array.isArray(plan.operations)
    && plan.operations.some(operation => isRecord(operation) && operation.destructive === true);
  if (targetChoice === undefined) {
    if (hasDestructive) add(reasons, 'destructive_without_target_disk', 'The plan has destructive operations but no target_disk choice.');
    return;
  }
  if (!isRecord(disk)) return;
  if (disk.eligible === false) add(reasons, 'disk_not_eligible', 'The target disk is not eligible.');
  const identifier = disk.by_id ?? disk.path;
  if (isRecord(targetChoice) && targetChoice.value !== undefined && targetChoice.value !== identifier) {
    add(reasons, 'disk_identity_mismatch', 'The target_disk choice does not name the disk in plan.target.disk.');
  }
}

export function replacementProblems(installation, layout, { espBytes, rootMinimumBytes, swapfileMib }) {
  if (!isRecord(installation) || !isRecord(layout) || !Array.isArray(layout.partitions)
    || !layout.partitions.every(isRecord)) return ['Missing replacement identities.'];
  const { root, esp } = installation;
  if (![root, esp].every(isRecord)) return ['Missing root or ESP identity.'];
  const problems = [];
  const guid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
  if (layout.partition_table?.type !== 'gpt' || !STORAGE_OPTIONS.includes(installation.storage_option)
    || root.path === esp.path || root.partuuid === esp.partuuid || root.partition_number === esp.partition_number
    || root.label !== 'mirroros' || root.type_guid !== '0fc63daf-8483-4772-8e79-3d69d8477de4'
    || esp.type_guid !== 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' || esp.fstype !== 'vfat'
    || (installation.storage_option === 'ext4-systemd-boot' ? root.fstype !== 'ext4' : root.fstype !== 'btrfs')
    || !guid.test(root.uuid) || !/^[0-9a-f]{4}-[0-9a-f]{4}$/i.test(esp.uuid)
    || layout.partitions.filter(partition => partition.label === 'mirroros').length !== 1) problems.push('Invalid replacement binding.');
  for (const partition of [esp, root]) {
    if (!isString(partition.path) || !guid.test(partition.partuuid) || !isInteger(partition.size_bytes) || partition.size_bytes <= 0
      || !isInteger(partition.partition_number) || partition.partition_number <= 0
      || !isInteger(partition.start_sector) || partition.start_sector <= 0
      || !sameDocument(layout.partitions.find(item => item.path === partition.path), partition)
      || ['path', 'partuuid', 'uuid', 'partition_number'].some(key => layout.partitions.filter(item =>
        String(item[key]).toLowerCase() === String(partition[key]).toLowerCase()).length !== 1)
      || (partition.mountpoints !== undefined && (!isStringList(partition.mountpoints) || partition.mountpoints.length > 0))) {
      problems.push('Replacement partitions must match unique, complete, unmounted layout identities.');
    }
  }
  const requiredRoot = requiredDiskBytes({ espBytes: 0, rootMinimumBytes, swapfileMib });
  if (!isInteger(espBytes) || esp.size_bytes < espBytes || requiredRoot === undefined || root.size_bytes < requiredRoot) {
    problems.push('Replacement ESP or root is below the policy minimum including the requested swapfile.');
  }
  return problems;
}

export function bootEntryParameters(bootloader) {
  return bootloader === 'limine'
    ? { bootloader, label: 'Limine MirrorOS', loader_path: '\\EFI\\BOOT\\BOOTX64.EFI', first: true }
    : { bootloader, label: 'MirrorOS', loader_path: '\\EFI\\systemd\\systemd-bootx64.efi', first: true };
}

function checkTargetMode(plan, reasons) {
  const mode = plan.target_mode;
  if (!TARGET_MODES.includes(mode) || plan.choices?.target_mode?.value !== mode) {
    add(reasons, 'target_mode_mismatch', 'The target mode must be known and agree with its choice.');
    return;
  }
  const installation = plan.target?.installation;
  const rootChoice = plan.choices?.replace_root_partuuid?.value;
  const disk = plan.target?.disk;
  const layout = disk?.current_layout;
  if (mode === 'replace_installation') {
    if (checkRecord(installation, 'plan.target.installation', ['disk_path', 'storage_option', 'esp', 'root'], [], reasons)) {
      checkLayout({ partitions: [installation.esp, installation.root].filter(isRecord) }, 'plan.target.installation', reasons);
    }
    const problems = replacementProblems(installation, layout, {
      espBytes: plan.choices?.esp?.value?.size_bytes,
      rootMinimumBytes: plan.choices?.root_minimum_bytes?.value,
      swapfileMib: plan.choices?.hibernation?.value === true ? plan.choices?.swapfile_size?.value : undefined,
    });
    if (installation?.disk_path !== disk?.path || rootChoice === undefined || rootChoice !== installation?.root?.partuuid) {
      problems.push('The replacement choice and disk must match the recorded installation.');
    }
    for (const problem of problems) add(reasons, 'replacement_target_invalid', problem);
  } else if (installation !== undefined || rootChoice !== undefined) {
    add(reasons, 'target_mode_mismatch', 'Whole-disk mode cannot carry a replacement installation or root choice.');
  }
  const identifier = disk?.by_id ?? disk?.path;
  const recorded = Array.isArray(layout?.partitions) ? layout.partitions.flatMap(partition => !isRecord(partition) || partition.partuuid === undefined ? [] : [partition.partuuid]) : [];
  const expectations = mode === 'whole_disk' ? {
    record_disk_partuuids: { disk: identifier, partuuids: recorded },
    wipe_disk_signatures: { disk: identifier },
    create_partition_table: { disk: identifier, table: plan.choices?.partition_table?.value },
    create_partitions: { disk: identifier, esp_size_bytes: plan.choices?.esp?.value?.size_bytes, esp_mount_point: plan.choices?.esp?.value?.mount_point, root: 'remaining_space' },
    remove_stale_uefi_entries: { partuuids: recorded },
    format_filesystems: { esp_filesystem: plan.choices?.esp?.value?.filesystem, root_filesystem: plan.choices?.storage_option?.filesystem },
  } : {
    wipe_partition_signatures: { esp: installation?.esp, root: installation?.root },
    format_partitions: { esp: installation?.esp, root: installation?.root, esp_filesystem: plan.choices?.esp?.value?.filesystem, root_filesystem: plan.choices?.storage_option?.filesystem },
  };
  expectations.register_uefi_boot_entry = bootEntryParameters(plan.choices?.storage_option?.bootloader);
  for (const operation of operationKinds(plan)) {
    if (operation.kind in expectations && !sameDocument(operation.parameters, expectations[operation.kind])) {
      add(reasons, 'target_mode_mismatch', `The ${operation.kind} parameters differ from the declared target.`);
    }
    if (operation.kind === 'format_partitions' && !sameDocument(operation.resolved_at_apply, [{ name: 'partition_uuids', method: 'blkid' }])) {
      add(reasons, 'target_mode_mismatch', 'Replacement formatting must resolve the new filesystem UUIDs.');
    }
  }
  const option = plan.choices?.storage_option;
  const expectedBootloader = option?.value === 'btrfs-limine' ? 'limine' : 'systemd-boot';
  const expectedFilesystem = option?.value === 'ext4-systemd-boot' ? 'ext4' : 'btrfs';
  if (option?.bootloader !== expectedBootloader || option?.filesystem !== expectedFilesystem) {
    add(reasons, 'target_mode_mismatch', 'The bootloader and filesystem must match the selected storage option.');
  }
}

function checkSizes(plan, reasons) {
  if (plan.target_mode === 'replace_installation') return;
  const disk = plan.target?.disk;
  const esp = plan.choices?.esp?.value?.size_bytes;
  const root = plan.choices?.root_minimum_bytes?.value;
  const swap = plan.choices?.hibernation?.value === true ? plan.choices?.swapfile_size?.value : undefined;
  if (![esp, root].every(isInteger) || (swap !== undefined && !isInteger(swap)) || !isRecord(disk) || !isInteger(disk.size_bytes)) return;
  const required = requiredDiskBytes({ espBytes: esp, rootMinimumBytes: root, swapfileMib: swap });
  if (required === undefined || required > disk.size_bytes) {
    const parts = swap === undefined ? 'The ESP and the root minimum' : 'The ESP, the root minimum, and the swapfile';
    add(reasons, 'plan_size_does_not_fit', `${parts} need ${required ?? 'more than the safe integer range of'} bytes, but the disk has ${disk.size_bytes}.`);
  }
}

function operationKinds(plan) {
  return Array.isArray(plan.operations) ? plan.operations.filter(isRecord) : [];
}

function subvolumeLists(operations) {
  return operations
    .filter(operation => ['create_btrfs_subvolumes', 'mount_target'].includes(operation.kind))
    .map(operation => [operation.kind, operation.parameters?.subvolumes])
    .filter(([, list]) => Array.isArray(list));
}

// Hibernation, the swapfile, @swap, and the resume settings follow one boolean choice and the detected memory
// (ADR 0007). Anything present without it, or missing with it, is a contradiction.
function checkHibernation(plan, reasons) {
  const hibernation = plan.choices?.hibernation?.value;
  if (typeof hibernation !== 'boolean') return;
  const problems = [];
  const operations = operationKinds(plan);
  const swapfile = operations.find(operation => operation.kind === 'create_swapfile');
  const bootloader = operations.find(operation => operation.kind === 'install_bootloader');
  const size = plan.choices.swapfile_size?.value;
  const memory = plan.target?.machine?.memory_total_bytes;
  const commandLine = plan.choices.kernel_cmdline?.value;
  const [hasResume, hasOffset] = typeof commandLine === 'string' ? hasResumeParameters(commandLine) : [false, false];
  const resolvesOffset = operations.some(operation => Array.isArray(operation.resolved_at_apply)
    && operation.resolved_at_apply.some(item => isRecord(item) && item.name === 'resume_offset'));
  const swapLists = subvolumeLists(operations);
  if (hibernation) {
    if (plan.choices.swapfile_size === undefined) problems.push('hibernation is enabled but swapfile_size is missing');
    else if (isInteger(size) && isMemoryBytes(memory) && !isSwapfileSizeInRange(size, memory)) {
      problems.push('swapfile_size is outside the range derived from the detected memory');
    }
    if (swapfile === undefined) problems.push('hibernation is enabled but create_swapfile is missing');
    else {
      if (isRecord(swapfile.parameters) && swapfile.parameters.size_mib !== size) problems.push('create_swapfile does not use swapfile_size');
      if (isRecord(swapfile.parameters) && swapfile.parameters.priority !== SWAPFILE_PRIORITY) {
        problems.push(`create_swapfile must have swap priority ${SWAPFILE_PRIORITY}`);
      }
      const offsets = Array.isArray(swapfile.resolved_at_apply) ? swapfile.resolved_at_apply : [];
      if (!offsets.some(item => isRecord(item) && item.name === 'resume_offset')) problems.push('create_swapfile does not resolve resume_offset');
    }
    if (!hasResume || !hasOffset) problems.push('the kernel command line lacks the resume parameters');
    const bootOffsets = Array.isArray(bootloader?.resolved_at_apply) ? bootloader.resolved_at_apply : [];
    if (bootloader !== undefined && !bootOffsets.some(item => isRecord(item) && item.name === 'resume_offset')) {
      problems.push('install_bootloader does not resolve resume_offset');
    }
    for (const [kind, list] of swapLists) {
      if (!list.includes('@swap')) problems.push(`${kind} lacks the @swap subvolume`);
    }
  } else {
    if (plan.choices.swapfile_size !== undefined) problems.push('hibernation is disabled but swapfile_size is present');
    if (swapfile !== undefined) problems.push('hibernation is disabled but create_swapfile is present');
    if (hasResume || hasOffset) problems.push('hibernation is disabled but the kernel command line has resume parameters');
    if (resolvesOffset) problems.push('hibernation is disabled but a resume_offset resolution is present');
    for (const [kind, list] of swapLists) {
      if (list.includes('@swap')) problems.push(`hibernation is disabled but ${kind} has the @swap subvolume`);
    }
  }
  for (const problem of problems) add(reasons, 'hibernation_plan_mismatch', `${problem[0].toUpperCase()}${problem.slice(1)}.`);
}

const SOURCE_HASH_KEY = 'source_sha256';

// The zram package, zswap policy, and both configuration operations must agree with the declared policy values
// of the plan; with the allowlisted source assets they must also agree with their destination and hash.
function checkConfiguration(plan, reasons, assets) {
  const zram = plan.choices?.zram?.value;
  const reclaim = plan.choices?.memory_reclaim?.value;
  if (!isZramPolicy(zram) || !isMemoryReclaimPolicy(reclaim)) return;
  const operations = operationKinds(plan);
  const problems = [];
  const packages = operations.find(operation => operation.kind === 'install_packages')?.parameters?.packages;
  if (!Array.isArray(packages) || !packages.includes(zram.package)) problems.push(`install_packages does not include ${zram.package}`);
  const commandLine = plan.choices.kernel_cmdline?.value;
  if (typeof commandLine !== 'string' || !commandLine.split(' ').includes('zswap.enabled=0')) {
    problems.push('the kernel command line lacks zswap.enabled=0');
  }
  const expectations = {
    configure_zram: {
      destination: zram.destination,
      zram_size: zram.zram_size,
      compression_algorithm: zram.compression_algorithm,
      swap_priority: zram.swap_priority,
    },
    configure_memory_reclaim: { destination: reclaim.destination, ...reclaim.settings },
  };
  for (const [kind, expected] of Object.entries(expectations)) {
    const operation = operations.find(item => item.kind === kind);
    if (operation === undefined) {
      problems.push(`${kind} is missing`);
      continue;
    }
    const parameters = operation.parameters;
    if (!isRecord(parameters) || !HEX_64.test(parameters[SOURCE_HASH_KEY] ?? '')) {
      problems.push(`${kind} has no valid ${SOURCE_HASH_KEY}`);
      continue;
    }
    const { [SOURCE_HASH_KEY]: hash, ...settings } = parameters;
    if (sha256Canonical(settings) !== sha256Canonical(expected)) problems.push(`${kind} parameters differ from the declared policy values`);
    const asset = assets?.[kind];
    if (asset !== undefined && (settings.destination !== asset.destination || hash !== asset.sha256)) {
      problems.push(`${kind} differs from its source asset`);
    }
  }
  for (const problem of problems) add(reasons, 'configuration_asset_mismatch', `${problem[0].toUpperCase()}${problem.slice(1)}.`);
}

function checkFacts(plan, facts, reasons) {
  const binding = plan.facts_binding;
  const target = plan.target;
  if (facts === undefined || !isRecord(binding)) return;
  let hash;
  try {
    hash = sha256Canonical(facts);
  } catch {
    add(reasons, 'facts_binding_mismatch', 'The supplied facts document cannot be canonicalized.');
    return;
  }
  const source = isRecord(facts.source) ? facts.source : {};
  if (binding.facts_sha256 !== hash
    || binding.run_id !== source.run_id
    || binding.commit !== source.commit
    || binding.dirty !== source.dirty) {
    add(reasons, 'facts_binding_mismatch', 'facts_binding does not match the supplied facts document.');
  }
  if (isRecord(target?.machine) && JSON.stringify(projectMachine(target.machine)) !== JSON.stringify(machineProjection(facts))) {
    add(reasons, 'machine_identity_mismatch', 'target.machine differs from the machine observed in the bound facts, including its field availability.');
  }
  if (isRecord(target?.profile) && isRecord(facts.profile)
    && (target.profile.status !== facts.profile.status || target.profile.profile_id !== facts.profile.profile_id)) {
    add(reasons, 'profile_binding_mismatch', 'target.profile differs from the profile classification of the bound facts.');
  }
  const disks = facts.layers?.detected?.storage?.disks;
  const disk = target?.disk;
  if (!Array.isArray(disks) || !isRecord(disk)) return;
  const found = disks.find(candidate => isRecord(candidate?.identity)
    && (disk.by_id !== undefined ? candidate.identity.by_id === disk.by_id : candidate.identity.path === disk.path));
  if (found === undefined || DISK_IDENTITY_KEYS.some(key => found.identity[key] !== disk[key])) {
    add(reasons, 'disk_identity_mismatch', 'The target disk does not match any disk of the bound facts.');
    return;
  }
  if (found.eligible !== true) add(reasons, 'disk_not_eligible', 'The target disk is not eligible in the bound facts.');
  if (!sameDocument(found.layout, disk.current_layout)) add(reasons, 'disk_identity_mismatch', 'The current layout differs from the bound facts.');
  if (plan.target_mode === 'replace_installation'
    && !(found.replace_candidates ?? []).some(candidate => sameDocument(candidate, target.installation))) {
    add(reasons, 'replacement_target_invalid', 'The replacement installation is not a candidate in the bound facts.');
  }
}

// `facts` binds the plan to its discovery; `assets` (the result of loadConfigurationAssets) binds the
// configuration operations to the source assets they were generated from.
export function validatePlan(plan, { facts, assets } = {}) {
  const reasons = [];
  if (!isRecord(plan)) {
    add(reasons, 'plan_invalid_type', 'The plan must be a JSON object.');
    return reasons;
  }
  walkNumbers(plan, 'plan', reasons);
  if (plan.format_version !== PLAN_FORMAT_VERSION) {
    add(reasons, 'plan_format_unsupported', `format_version must be ${PLAN_FORMAT_VERSION}.`);
    return reasons;
  }
  checkRecord(plan, 'plan', TOP_LEVEL, [], reasons);
  checkTarget(plan.target, reasons);
  checkChoices(plan.choices, reasons);
  checkOperations(plan.operations, reasons);
  checkSecrets(plan.secret_requirements, reasons);
  checkHardware(plan.hardware_selections, reasons);
  checkReasonList(plan.warnings, 'plan.warnings', reasons);
  checkBindings(plan, reasons);
  checkOperationSet(plan, reasons);
  checkTargetMode(plan, reasons);
  checkSecretConsistency(plan, reasons);
  checkDisk(plan, reasons);
  checkSizes(plan, reasons);
  checkHibernation(plan, reasons);
  checkHardwareRules(plan, reasons);
  checkConfiguration(plan, reasons, assets);
  checkLocalization(plan, reasons);
  checkProfileBinding(plan, reasons);
  checkFacts(plan, facts, reasons);
  if (isRecord(plan.digest) && HEX_64.test(plan.digest.value ?? '') && plan.digest.algorithm === 'sha256') {
    let matches = false;
    try {
      canonicalize(plan);
      matches = verifyDigest(plan);
    } catch {
      matches = true;
    }
    if (!matches) add(reasons, 'digest_mismatch', 'The digest does not match the plan content.');
  }
  return reasons;
}

export function parsePlanText(text) {
  try {
    return { plan: JSON.parse(text), reasons: [] };
  } catch (error) {
    return { plan: undefined, reasons: [reason('plan_not_json', `The plan is not valid JSON: ${error.message}`, NEXT_STEPS.plan_not_json)] };
  }
}
