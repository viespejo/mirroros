export const FACTS_FORMAT_VERSION = 2;
export const TARGET_DEFINITION_FORMAT_VERSION = 1;
export const DISCOVERY_POLICY_FORMAT_VERSION = 1;
export const EXIT_VALID = 0;
export const EXIT_INVALID_INPUT = 2;
export const EXIT_UPSTREAM_FAILURE = 5;
export const EXIT_INTERNAL = 6;

export const SOURCES = ['baseline', 'detected', 'override', 'runtime'];
export const PROVENANCE_CLASSES = ['personal_preference', 'hardware_detection', 'arch_guidance', 'technical_necessity'];
export const PROFILE_STATUSES = ['matched', 'unqualified'];
export const PROFILE_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
export const INELIGIBLE_REASONS = [
  'loop',
  'rom',
  'zram',
  'unsupported_type',
  'removable',
  'read_only',
  'live_medium',
  'mounted',
  'below_minimum_size',
  'size_unknown',
];

const SECURE_BOOT_STATES = ['enabled', 'disabled', 'unknown'];
const NETWORK_STEPS = ['default_route', 'dns', 'https'];
const INTERFACE_KINDS = ['wired', 'wireless', 'other'];
const VENDOR_CLASSES = ['amd', 'intel', 'nvidia', 'qemu_virtual', 'unknown'];

export class DiscoveryContractError extends Error {
  constructor(errors) {
    super(Array.isArray(errors) ? errors.join('\n') : String(errors));
    this.name = 'DiscoveryContractError';
    this.errors = Array.isArray(errors) ? errors : [String(errors)];
  }
}

export function reason(code, message, nextStep) {
  return { code, message, next_step: nextStep };
}

export function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function exitStatusFor(document) {
  return document.validation.status === 'valid' ? EXIT_VALID : EXIT_INVALID_INPUT;
}

function validateFirmware(firmware, reasons, warnings) {
  if (firmware.boot_mode === undefined) return;
  if (firmware.boot_mode !== 'uefi') {
    reasons.push(reason(
      'boot_mode_not_uefi',
      'The system was not booted in UEFI mode; only 64-bit UEFI is supported.',
      'Boot the installation medium in UEFI mode, disable CSM or legacy boot in firmware setup, and rerun discovery.',
    ));
    return;
  }
  if (firmware.platform_bits === 32) {
    reasons.push(reason(
      'uefi_platform_32bit',
      'The firmware is 32-bit UEFI; only 64-bit UEFI is supported.',
      'Use a machine with 64-bit UEFI firmware.',
    ));
  }
  if (firmware.efivars_available === false) {
    reasons.push(reason(
      'efivars_unavailable',
      'UEFI variables are not available, so boot entries cannot be managed.',
      'Boot the installation medium in UEFI mode with efivars enabled and rerun discovery.',
    ));
  }
  if (firmware.secure_boot === 'enabled') {
    reasons.push(reason(
      'secure_boot_enabled',
      'Secure Boot is enabled, but the MVP boot loader is unsigned.',
      'Disable Secure Boot in firmware setup and rerun discovery.',
    ));
  } else if (firmware.secure_boot === 'unknown') {
    warnings.push(reason(
      'secure_boot_unknown',
      'The Secure Boot state could not be determined.',
      'Confirm in firmware setup that Secure Boot is disabled before installing.',
    ));
  }
}

function validateArchitecture(hardware, reasons) {
  if (hardware.architecture !== undefined && hardware.architecture !== 'x86_64') {
    reasons.push(reason(
      'unsupported_architecture',
      `The architecture "${hardware.architecture}" is not supported; only x86_64 is.`,
      'Use an x86_64 machine.',
    ));
  }
}

function validateNetwork(network, reasons) {
  if (network.ready !== false) return;
  const steps = {
    default_route: reason(
      'network_no_default_route',
      'No default route exists, so the network is not ready.',
      'Connect a cable or configure Wi-Fi with iwctl, then rerun discovery.',
    ),
    dns: reason(
      'network_dns_failed',
      'DNS resolution failed, so the network is not ready.',
      'Check the network DNS configuration or connection, then rerun discovery.',
    ),
    https: reason(
      'network_https_failed',
      'The HTTPS reachability probe failed, so the network is not ready.',
      'Check internet access or proxy restrictions, then rerun discovery.',
    ),
  };
  reasons.push(steps[network.failing_step]);
}

function validateStorage(storage, reasons) {
  const disks = storage.disks ?? [];
  if (disks.some(disk => disk.eligible)) return;
  reasons.push(reason(
    'no_eligible_disk',
    'No eligible installation disk was found.',
    'Attach an internal non-removable disk of at least the minimum size that is not the live medium, then rerun discovery.',
  ));
  for (const disk of disks) {
    reasons.push(reason(
      'disk_ineligible',
      `${disk.identity.path} is not eligible: ${(disk.ineligible_reasons ?? []).join(', ')}.`,
      'Resolve the listed condition or use another disk, then rerun discovery.',
    ));
  }
}

export function validateDiscovery({ detected }) {
  const reasons = [];
  const warnings = [];
  validateFirmware(detected.firmware, reasons, warnings);
  validateArchitecture(detected.hardware, reasons);
  validateNetwork(detected.network, reasons);
  validateStorage(detected.storage, reasons);
  return { reasons, warnings };
}

const required = check => ({ required: true, check });
const optional = check => ({ required: false, check });

const anyValue = () => {};
const string = (value, path, errors) => {
  if (typeof value !== 'string' || value.length === 0) errors.push(`${path} must be a non-empty string`);
};
const boolean = (value, path, errors) => {
  if (typeof value !== 'boolean') errors.push(`${path} must be a boolean`);
};
const integer = (value, path, errors) => {
  if (!Number.isSafeInteger(value) || value < 0) errors.push(`${path} must be a non-negative integer`);
};
const oneOf = allowed => (value, path, errors) => {
  if (!allowed.includes(value)) errors.push(`${path} must be one of: ${allowed.join(', ')}`);
};
const listOf = check => (value, path, errors) => {
  if (!Array.isArray(value)) {
    errors.push(`${path} must be an array`);
    return;
  }
  value.forEach((item, index) => check(item, `${path}[${index}]`, errors));
};
const mapOf = check => (value, path, errors) => {
  if (!isRecord(value)) {
    errors.push(`${path} must be an object`);
    return;
  }
  for (const [key, item] of Object.entries(value)) check(item, `${path}.${key}`, errors);
};
const shape = fields => (value, path, errors) => {
  if (!isRecord(value)) {
    errors.push(`${path} must be an object`);
    return;
  }
  for (const key of Object.keys(value)) {
    if (!(key in fields)) errors.push(`${path}.${key} is not an allowed field`);
  }
  for (const [key, field] of Object.entries(fields)) {
    if (value[key] === undefined) {
      if (field.required) errors.push(`${path}.${key} is required`);
      continue;
    }
    field.check(value[key], `${path}.${key}`, errors);
  }
};

const reasonShape = shape({
  code: required(string),
  message: required(string),
  next_step: required(string),
});

const partitionFields = {
  path: required(string),
  size_bytes: optional(integer),
  fstype: optional(string),
  label: optional(string),
  uuid: optional(string),
  partuuid: optional(string),
  type_guid: optional(string),
  partition_number: optional(integer),
  start_sector: optional(integer),
  partition_label: optional(string),
  mountpoints: optional(listOf(string)),
};
const partitionShape = shape(partitionFields);
const candidatePartitionShape = shape({
  ...partitionFields,
  size_bytes: required(integer),
  fstype: required(string),
  uuid: required(string),
  partuuid: required(string),
  type_guid: required(string),
  partition_number: required(integer),
  start_sector: required(integer),
});
export const REPLACE_REJECTION_REASONS = [
  'ambiguous_roots', 'unsupported_root', 'disk_ineligible', 'incomplete_identity',
  'missing_esp_binding', 'inspection_unavailable', 'ambiguous_identity',
  'ambiguous_boot_configuration', 'boot_root_mismatch', 'ambiguous_esp_binding',
];

const diskShape = shape({
  identity: required(shape({
    path: required(string),
    by_id: optional(string),
    wwn: optional(string),
    serial: optional(string),
    model: optional(string),
    size_bytes: optional(integer),
  })),
  type: required(string),
  transport: optional(string),
  removable: optional(boolean),
  read_only: optional(boolean),
  layout: required(shape({
    partition_table: optional(shape({ type: optional(string), uuid: optional(string), sector_size_bytes: optional(integer) })),
    partitions: required(listOf(partitionShape)),
  })),
  replace_candidates: optional(listOf(shape({
    disk_path: required(string),
    root: required(candidatePartitionShape),
    esp: required(candidatePartitionShape),
    storage_option: required(oneOf(['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine'])),
  }))),
  replace_rejections: optional(listOf(shape({ root_path: required(string), reason: required(oneOf(REPLACE_REJECTION_REASONS)) }))),
  eligible: required(boolean),
  ineligible_reasons: optional(listOf(oneOf(INELIGIBLE_REASONS))),
});

const documentShape = shape({
  format_version: required(oneOf([FACTS_FORMAT_VERSION])),
  source: required(shape({
    run_id: required(string),
    commit: required(string),
    dirty: required(boolean),
    requested_profile_id: optional(string),
  })),
  profile: required(shape({
    status: required(oneOf(PROFILE_STATUSES)),
    profile_id: optional(string),
  })),
  layers: required(shape({
    portable_baseline: required(shape({
      policy: required(mapOf(shape({
        value: required(anyValue),
        provenance: required(oneOf(PROVENANCE_CLASSES)),
      }))),
    })),
    detected: required(shape({
      firmware: required(shape({
        boot_mode: optional(string),
        platform_bits: optional(oneOf([32, 64])),
        efivars_available: optional(boolean),
        secure_boot: optional(oneOf(SECURE_BOOT_STATES)),
        dmi: optional(shape({
          sys_vendor: optional(string),
          product_name: optional(string),
          product_version: optional(string),
          board_name: optional(string),
          bios_vendor: optional(string),
          bios_version: optional(string),
          bios_date: optional(string),
        })),
      })),
      network: required(shape({
        ready: required(boolean),
        failing_step: optional(oneOf(NETWORK_STEPS)),
        default_route: optional(boolean),
        dns_resolved: optional(boolean),
        https_reachable: optional(boolean),
        wifi_present: optional(boolean),
        interfaces: optional(listOf(shape({
          name: required(string),
          kind: required(oneOf(INTERFACE_KINDS)),
          state: optional(string),
          has_global_ipv4: optional(boolean),
          has_global_ipv6: optional(boolean),
        }))),
      })),
      storage: required(shape({
        live_medium_device: optional(string),
        disks: required(listOf(diskShape)),
      })),
      hardware: required(shape({
        architecture: optional(string),
        cpu: optional(shape({ vendor: optional(string), model: optional(string), cores: optional(integer) })),
        memory_total_bytes: optional(integer),
        graphics: optional(listOf(shape({
          vendor: required(oneOf(VENDOR_CLASSES)),
          vendor_id: required(string),
          device_id: optional(string),
          driver: optional(string),
          boot_vga: optional(boolean),
        }))),
        battery_present: optional(boolean),
        virtualization: optional(string),
        wifi_reference: optional(string),
      })),
    })),
    target_override: required(shape({ policy: required(mapOf(anyValue)) })),
    runtime_private: required(shape({ required_inputs: required(listOf(string)) })),
  })),
  effective: required(mapOf(shape({
    value: optional(anyValue),
    source: required(oneOf(SOURCES)),
    provenance: optional(oneOf(PROVENANCE_CLASSES)),
    private: optional(boolean),
  }))),
  validation: required(shape({
    status: required(oneOf(['valid', 'invalid'])),
    reasons: required(listOf(reasonShape)),
    warnings: required(listOf(reasonShape)),
  })),
});

export function validateDocument(document) {
  const errors = [];
  documentShape(document, 'target-facts', errors);
  if (errors.length > 0) return errors;
  const { validation, effective, profile, source } = document;
  if (profile.status === 'matched' && !PROFILE_ID_PATTERN.test(profile.profile_id ?? '')) {
    errors.push('target-facts.profile.profile_id is required for a matched profile');
  }
  if (profile.status === 'unqualified' && profile.profile_id !== undefined) {
    errors.push('target-facts.profile.profile_id must be omitted for an unqualified machine');
  }
  if (source.requested_profile_id !== undefined && !PROFILE_ID_PATTERN.test(source.requested_profile_id)) {
    errors.push('target-facts.source.requested_profile_id is not a valid profile id');
  }
  if (profile.status === 'matched' && source.requested_profile_id !== undefined
    && source.requested_profile_id !== profile.profile_id) {
    errors.push('target-facts.profile.profile_id must equal source.requested_profile_id when a profile was requested');
  }
  if ((validation.status === 'valid') !== (validation.reasons.length === 0)) {
    errors.push('target-facts.validation.status must be "valid" exactly when there are no reasons');
  }
  for (const [key, entry] of Object.entries(effective)) {
    if (entry.source === 'runtime' && entry.value !== undefined) {
      errors.push(`target-facts.effective.${key} must not carry a runtime private value`);
    }
  }
  for (const [index, disk] of document.layers.detected.storage.disks.entries()) {
    const reasons = disk.ineligible_reasons ?? [];
    const candidates = disk.replace_candidates ?? [];
    if (candidates.length > 1 || candidates.length > 0 && (disk.replace_rejections ?? []).length > 0) {
      errors.push(`target-facts.layers.detected.storage.disks[${index}] replacement binding must be unambiguous`);
    }
    for (const candidate of candidates) {
      const root = candidate.root;
      const esp = candidate.esp;
      const guid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
      const samePartition = partition => disk.layout.partitions.filter(p => p.path === partition.path).length === 1
        && Object.entries(partition).every(([key, value]) => JSON.stringify(disk.layout.partitions.find(p => p.path === partition.path)[key]) === JSON.stringify(value));
      if (!disk.eligible || disk.layout.partition_table?.type !== 'gpt' || candidate.disk_path !== disk.identity.path
        || !samePartition(root) || !samePartition(esp) || root.path === esp.path
        || disk.layout.partitions.filter(p => p.label === 'mirroros').length !== 1
        || [root, esp].some(p => ['uuid', 'partuuid'].some(key => disk.layout.partitions
          .filter(other => other[key]?.toLowerCase() === p[key].toLowerCase()).length !== 1))
        || root.label !== 'mirroros' || root.type_guid !== '0fc63daf-8483-4772-8e79-3d69d8477de4'
        || esp.type_guid !== 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' || esp.fstype !== 'vfat'
        || !guid.test(root.uuid) || !/^[0-9a-f]{4}-[0-9a-f]{4}$/i.test(esp.uuid)
        || [root, esp].some(p => !guid.test(p.partuuid) || p.size_bytes === 0 || p.start_sector === 0
          || p.partition_number === 0 || (p.mountpoints ?? []).length > 0)
        || (candidate.storage_option === 'ext4-systemd-boot' ? root.fstype !== 'ext4' : root.fstype !== 'btrfs')) {
        errors.push(`target-facts.layers.detected.storage.disks[${index}] replacement candidate must match its unmounted partition identities and storage option`);
      }
    }
    if (disk.eligible === (reasons.length > 0)) {
      errors.push(`target-facts.layers.detected.storage.disks[${index}] eligibility must match its reasons`);
    }
  }
  return errors;
}
