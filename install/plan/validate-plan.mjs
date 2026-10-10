import { isRecord, reason } from '../discovery/validate-facts.mjs';
import { canonicalize } from './canonical-json.mjs';
import { sha256Canonical, verifyDigest } from './digest-plan.mjs';

export const PLAN_FORMAT_VERSION = 2;
export const PLAN_POLICY_FORMAT_VERSION = 2;
export const CHOICES_FORMAT_VERSION = 2;
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
export const SWAPFILE_MIB_RANGE = [512, 65536];
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

function projectMachine({ architecture, virtualization, dmi } = {}) {
  const machine = { architecture };
  if (virtualization !== undefined) machine.virtualization = virtualization;
  const kept = {};
  for (const key of MACHINE_DMI_KEYS) {
    if (dmi?.[key] !== undefined) kept[key] = dmi[key];
  }
  if (Object.keys(kept).length > 0) machine.dmi = kept;
  return machine;
}

// The observed safety identity projection of a facts document: architecture, virtualization, and the
// allowlisted DMI sys_vendor and product_name, each omitted when it was not observed.
export function machineProjection(facts) {
  const detected = facts.layers?.detected ?? {};
  return projectMachine({
    architecture: detected.hardware?.architecture,
    virtualization: detected.hardware?.virtualization,
    dmi: detected.firmware?.dmi,
  });
}

export const KINDS = {
  wipe_disk_signatures: true,
  create_partition_table: true,
  create_partitions: true,
  format_filesystems: true,
  create_btrfs_subvolumes: false,
  mount_target: false,
  install_packages: false,
  generate_fstab: false,
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

export function operationSequence(storageOption) {
  const sequence = SEQUENCES[storageOption];
  return sequence === undefined ? undefined : [...sequence];
}

const NEXT_STEPS = {
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
  plan_size_does_not_fit: 'Choose a smaller swapfile_size or a larger disk and regenerate the plan.',
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

const choice = (editable, check, description) => ({ editable, check, description });
const fixed = description => choice(false, () => true, description);

export const CHOICE_SPECS = {
  target_disk: choice(true, isString, 'a disk identifier string'),
  storage_option: choice(true, value => STORAGE_OPTIONS.includes(value), `one of ${STORAGE_OPTIONS.join(', ')}`),
  swapfile_size: choice(
    true,
    value => isInteger(value) && value >= SWAPFILE_MIB_RANGE[0] && value <= SWAPFILE_MIB_RANGE[1],
    `an integer from ${SWAPFILE_MIB_RANGE[0]} to ${SWAPFILE_MIB_RANGE[1]} (MiB)`,
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
  zram: fixed('a fixed policy value'),
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
  'format_version', 'target', 'choices', 'operations', 'secret_requirements', 'hardware_selections',
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
    && checkRecord(layout.partition_table, `${path}.partition_table`, [], ['type', 'uuid'], reasons)) {
    for (const key of ['type', 'uuid']) {
      if (layout.partition_table[key] !== undefined) {
        expect(isString(layout.partition_table[key]), `${path}.partition_table.${key}`, 'a non-empty string', reasons);
      }
    }
  }
  if (!expect(Array.isArray(layout.partitions), `${path}.partitions`, 'a list', reasons)) return;
  layout.partitions.forEach((partition, index) => {
    const partitionPath = `${path}.partitions[${index}]`;
    if (!checkRecord(partition, partitionPath, ['path'], ['size_bytes', 'fstype', 'label', 'uuid', 'partuuid', 'mountpoints'], reasons)) return;
    for (const key of ['path', 'fstype', 'label', 'uuid', 'partuuid']) {
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
  if (!checkRecord(machine, path, ['architecture'], ['virtualization', 'dmi'], reasons)) return;
  for (const key of ['architecture', 'virtualization']) {
    if (machine[key] !== undefined) expect(isString(machine[key]), `${path}.${key}`, 'a non-empty string', reasons);
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
  if (!checkRecord(target, 'plan.target', ['machine', 'profile', 'disk'], [], reasons)) return;
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
  for (const key of Object.keys(CHOICE_SPECS)) {
    if (key !== 'target_disk' && choices[key] === undefined) add(reasons, 'plan_field_missing', `plan.choices.${key} is required.`);
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
  if (!checkRecord(hardware, 'plan.hardware_selections', ['selections', 'detected_capabilities'], [], reasons)) return;
  const groups = [
    ['selections', ['id', 'fact', 'value', 'provenance', 'rule']],
    ['detected_capabilities', ['id', 'fact', 'value', 'rule', 'next_story']],
  ];
  for (const [group, fields] of groups) {
    const list = hardware[group];
    if (list === undefined || !expect(Array.isArray(list), `plan.hardware_selections.${group}`, 'a list', reasons)) continue;
    list.forEach((entry, index) => {
      const path = `plan.hardware_selections.${group}[${index}]`;
      if (!checkRecord(entry, path, fields, [], reasons)) return;
      for (const key of ['id', 'fact', 'rule']) {
        if (entry[key] !== undefined) expect(isString(entry[key]), `${path}.${key}`, 'a non-empty string', reasons);
      }
      if (group === 'selections' && entry.provenance !== undefined) {
        expect(entry.provenance === 'hardware_detection', `${path}.provenance`, '"hardware_detection"', reasons);
      }
      if (group === 'detected_capabilities') {
        if (entry.rule !== undefined) expect(entry.rule === 'not_evaluated', `${path}.rule`, '"not_evaluated"', reasons);
        if (entry.next_story !== undefined) expect(entry.next_story === '2.6', `${path}.next_story`, '"2.6"', reasons);
      }
    });
  }
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
  const expected = operationSequence(option);
  if (!kindsKnown || expected === undefined) return;
  const kinds = operations.map(operation => operation.kind);
  if (kinds.length === expected.length && kinds.every((kind, index) => kind === expected[index])) return;
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

function checkSizes(plan, reasons) {
  const disk = plan.target?.disk;
  const esp = plan.choices?.esp?.value?.size_bytes;
  const root = plan.choices?.root_minimum_bytes?.value;
  const swap = plan.choices?.swapfile_size?.value;
  if (![esp, root, swap].every(isInteger) || !isRecord(disk) || !isInteger(disk.size_bytes)) return;
  const required = esp + root + swap * MIBIBYTE;
  if (required > disk.size_bytes) {
    add(reasons, 'plan_size_does_not_fit', `The ESP, the root minimum, and the swapfile need ${required} bytes, but the disk has ${disk.size_bytes}.`);
  }
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
}

export function validatePlan(plan, { facts } = {}) {
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
  checkSecretConsistency(plan, reasons);
  checkDisk(plan, reasons);
  checkSizes(plan, reasons);
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
