import { basename } from 'node:path';
import { normalizeHardware } from '../../hardware/discovery/normalize-hardware.mjs';
import { classifyProfile } from './identify-profile.mjs';
import { resolveLayers, resolvePolicy } from './resolve-layers.mjs';
import { FACTS_FORMAT_VERSION, isRecord, reason, validateDiscovery } from './validate-facts.mjs';

const DMI_FIELDS = ['sys_vendor', 'product_name', 'product_version', 'board_name', 'bios_vendor', 'bios_version', 'bios_date'];
const NETWORK_STEPS = ['default_route', 'dns', 'https'];
const INTERFACE_KINDS = ['wired', 'wireless', 'other'];
const INTERFACE_NAME_PATTERN = /^[A-Za-z0-9_.:-]{1,15}$/;
const TARGET_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function record(value) {
  return isRecord(value) ? value : {};
}

function text(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function toBoolean(value) {
  if (value === true || value === 1 || value === '1' || value === 'true') return true;
  if (value === false || value === 0 || value === '0' || value === 'false') return false;
  return undefined;
}

function toCount(value) {
  const number = typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
  return Number.isSafeInteger(number) && number >= 0 ? number : undefined;
}

function compact(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined));
}

export function missingFactReason(path) {
  return reason(
    'fact_missing',
    `The required fact "${path}" is missing from the discovery output.`,
    'Rerun discovery; if it persists, inspect the retained raw output of the matching collector.',
  );
}

function normalizeFirmware(raw) {
  const source = record(raw);
  const missing = [];
  const bootMode = text(source.boot_mode);
  if (bootMode === undefined) missing.push('firmware.boot_mode');
  const efivars = toBoolean(source.efivars_available);
  if (efivars === undefined) missing.push('firmware.efivars_available');
  const bits = toCount(source.fw_platform_size);
  const platformBits = bits === 32 || bits === 64 ? bits : undefined;
  if (bootMode === 'uefi' && platformBits === undefined) missing.push('firmware.platform_bits');
  const secureBoot = text(source.secure_boot)?.toLowerCase();
  const dmiSource = record(source.dmi);
  const dmi = compact(Object.fromEntries(DMI_FIELDS.map(field => [field, text(dmiSource[field])])));
  const facts = compact({
    boot_mode: bootMode,
    platform_bits: platformBits,
    efivars_available: efivars,
    secure_boot: secureBoot === 'enabled' || secureBoot === 'disabled' ? secureBoot : 'unknown',
    dmi: Object.keys(dmi).length > 0 ? dmi : undefined,
  });
  return { facts, missing };
}

function normalizeNetwork(raw) {
  const source = record(raw);
  const missing = [];
  const defaultRoute = toBoolean(source.default_route);
  const dnsResolved = toBoolean(record(source.dns).resolved);
  const httpsReachable = toBoolean(record(source.https).ok);
  if (defaultRoute === undefined) missing.push('network.default_route');
  if (dnsResolved === undefined) missing.push('network.dns_resolved');
  if (httpsReachable === undefined) missing.push('network.https_reachable');

  const steps = { default_route: defaultRoute, dns: dnsResolved, https: httpsReachable };
  const failingStep = NETWORK_STEPS.find(step => steps[step] !== true);
  const interfaces = (Array.isArray(source.interfaces) ? source.interfaces : [])
    .filter(item => isRecord(item) && INTERFACE_NAME_PATTERN.test(item.name ?? ''))
    .map(item => compact({
      name: item.name,
      kind: INTERFACE_KINDS.includes(item.kind) ? item.kind : 'other',
      state: text(item.state)?.toLowerCase(),
      has_global_ipv4: toBoolean(item.has_global_ipv4),
      has_global_ipv6: toBoolean(item.has_global_ipv6),
    }));
  const facts = compact({
    ready: failingStep === undefined,
    failing_step: failingStep,
    default_route: defaultRoute,
    dns_resolved: dnsResolved,
    https_reachable: httpsReachable,
    wifi_present: interfaces.some(item => item.kind === 'wireless'),
    interfaces,
  });
  return { facts, missing };
}

function mountpointsOf(device) {
  const own = (Array.isArray(device.mountpoints) ? device.mountpoints : [])
    .filter(item => typeof item === 'string' && item.length > 0);
  const children = Array.isArray(device.children) ? device.children : [];
  return [...own, ...children.flatMap(child => mountpointsOf(record(child)))];
}

function devicePaths(device) {
  const children = Array.isArray(device.children) ? device.children : [];
  return [text(device.path), ...children.flatMap(child => devicePaths(record(child)))].filter(Boolean);
}

function chooseById(names) {
  const usable = names.filter(name => !/-part\d+$/.test(name));
  return usable.find(name => name.startsWith('nvme-eui.'))
    ?? usable.find(name => name.startsWith('wwn-'))
    ?? [...usable].sort()[0];
}

function normalizePartition(partition) {
  const mountpoints = mountpointsOf(partition);
  return compact({
    path: text(partition.path) ?? (text(partition.kname) ? `/dev/${text(partition.kname)}` : undefined),
    size_bytes: toCount(partition.size),
    fstype: text(partition.fstype),
    label: text(partition.label),
    uuid: text(partition.uuid),
    partuuid: text(partition.partuuid),
    mountpoints: mountpoints.length > 0 ? mountpoints : undefined,
  });
}

function normalizeDisk(device, context, missing) {
  const path = text(device.path) ?? (text(device.kname) ? `/dev/${text(device.kname)}` : undefined);
  if (path === undefined) {
    missing.push('storage.disks.path');
    return undefined;
  }
  const type = text(device.type);
  if (type === undefined) missing.push(`storage.disks[${path}].type`);
  const size = toCount(device.size);
  if (size === undefined) missing.push(`storage.disks[${path}].size_bytes`);
  const removable = toBoolean(device.rm);
  const readOnly = toBoolean(device.ro);
  const identity = compact({
    path,
    by_id: chooseById(context.byId.get(path) ?? []),
    wwn: text(device.wwn),
    serial: text(device.serial),
    model: text(device.model),
    size_bytes: size,
  });
  const partitions = (Array.isArray(device.children) ? device.children : [])
    .filter(child => isRecord(child) && child.type === 'part')
    .map(normalizePartition)
    .filter(partition => partition.path !== undefined);
  const tableType = text(device.pttype);
  const tableUuid = text(device.ptuuid);

  const ineligible = [];
  if (type === 'loop') ineligible.push('loop');
  else if (type === 'rom') ineligible.push('rom');
  else if (type !== 'disk') ineligible.push('unsupported_type');
  if (basename(path).startsWith('zram')) ineligible.push('zram');
  if (removable === true) ineligible.push('removable');
  if (readOnly === true) ineligible.push('read_only');
  if (context.liveMedium !== undefined && devicePaths(device).includes(context.liveMedium)) ineligible.push('live_medium');
  if (mountpointsOf(device).length > 0) ineligible.push('mounted');
  if (size === undefined) ineligible.push('size_unknown');
  else if (size < context.minimumBytes) ineligible.push('below_minimum_size');

  return compact({
    identity,
    type: type ?? 'unknown',
    transport: text(device.tran),
    removable,
    read_only: readOnly,
    layout: compact({
      partition_table: tableType !== undefined || tableUuid !== undefined
        ? compact({ type: tableType, uuid: tableUuid })
        : undefined,
      partitions,
    }),
    eligible: ineligible.length === 0,
    ineligible_reasons: ineligible.length > 0 ? ineligible : undefined,
  });
}

function normalizeStorage(raw, minimumBytes) {
  const source = record(raw);
  const missing = [];
  if (!Array.isArray(source.blockdevices)) missing.push('storage.blockdevices');
  const byId = new Map();
  for (const link of Array.isArray(source.by_id) ? source.by_id : []) {
    const name = text(record(link).name);
    const target = text(record(link).target);
    if (name !== undefined && target !== undefined) byId.set(target, [...(byId.get(target) ?? []), name]);
  }
  const context = { byId, liveMedium: text(source.live_medium_device), minimumBytes };
  const disks = (Array.isArray(source.blockdevices) ? source.blockdevices : [])
    .filter(isRecord)
    .map(device => normalizeDisk(device, context, missing))
    .filter(disk => disk !== undefined);
  const facts = compact({ live_medium_device: context.liveMedium, disks });
  return { facts, missing };
}

// The detected facts that take part in profile identification; they do not depend on policy.
export function detectIdentity(raw) {
  return { firmware: normalizeFirmware(raw?.firmware), hardware: normalizeHardware(raw?.hardware) };
}

// "targets" are the defined profiles for automatic identification; "requested" is the loadTarget result
// of an explicit --target assertion (null otherwise). An override is read only for a verified profile.
export function normalizeFacts({
  raw,
  baseline,
  targets = [],
  requested = null,
  loadOverride = () => ({ override: {}, reasons: [] }),
  source,
  runtimeNames = [],
}) {
  const { firmware, hardware } = detectIdentity(raw);
  const classification = classifyProfile({
    detected: { firmware: firmware.facts, hardware: hardware.facts },
    targets,
    requested,
  });
  const loadReasons = requested === null ? [] : [...requested.reasons];
  let override = {};
  if (classification.target !== null) {
    const loadedOverride = loadOverride(classification.target.target_id);
    override = loadedOverride.override;
    loadReasons.push(...loadedOverride.reasons);
  }
  const policy = resolvePolicy({ baseline, override });
  const network = normalizeNetwork(raw?.network);
  const storage = normalizeStorage(raw?.storage, policy.values.minimum_disk_bytes);
  const detected = {
    firmware: firmware.facts,
    network: network.facts,
    storage: storage.facts,
    hardware: hardware.facts,
  };
  const missing = [...firmware.missing, ...network.missing, ...storage.missing, ...hardware.missing];
  const { layers, effective } = resolveLayers({ baseline, detected, accepted: policy.accepted, runtimeNames });
  const discovery = validateDiscovery({ detected });
  const reasons = [
    ...loadReasons,
    ...policy.reasons,
    ...missing.map(missingFactReason),
    ...discovery.reasons,
    ...classification.reasons,
  ];
  const requestedId = TARGET_ID_PATTERN.test(source.requested_profile_id ?? '') ? source.requested_profile_id : undefined;
  return {
    format_version: FACTS_FORMAT_VERSION,
    source: compact({
      run_id: source.run_id,
      commit: source.commit,
      dirty: source.dirty,
      requested_profile_id: requestedId,
    }),
    profile: classification.profile,
    layers,
    effective,
    validation: {
      status: reasons.length === 0 ? 'valid' : 'invalid',
      reasons,
      warnings: discovery.warnings,
    },
  };
}
