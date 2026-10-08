import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  DiscoveryContractError,
  FORMAT_VERSION,
  PROVENANCE_CLASSES,
  isRecord,
  reason,
} from './validate-facts.mjs';

export const DETECTED_ROOTS = ['firmware', 'network', 'storage', 'hardware'];
const TARGET_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const DMI_IDENTITY_FIELDS = ['sys_vendor', 'product_name'];
const POLICY_VALUE_CHECKS = {
  minimum_disk_bytes: value => Number.isSafeInteger(value) && value > 0,
  https_probe_url: value => typeof value === 'string' && /^https:\/\/\S+$/.test(value),
  https_probe_timeout_seconds: value => Number.isSafeInteger(value) && value > 0 && value <= 300,
};

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new DiscoveryContractError(`${label} is missing or damaged: ${path} (${error.code ?? error.name})`);
  }
}

function hasOnlyKeys(value, allowed) {
  return Object.keys(value).every(key => allowed.includes(key));
}

export function loadBaselinePolicy(path) {
  const document = readJson(path, 'discovery policy');
  const errors = [];
  if (!isRecord(document) || !hasOnlyKeys(document, ['format_version', 'policy']) || document.format_version !== FORMAT_VERSION) {
    errors.push('discovery policy must contain only format_version 1 and policy');
  } else if (!isRecord(document.policy)) {
    errors.push('discovery policy.policy must be an object');
  } else {
    for (const [key, entry] of Object.entries(document.policy)) {
      if (!(key in POLICY_VALUE_CHECKS)) {
        errors.push(`discovery policy key "${key}" is not a known policy key`);
      } else if (!isRecord(entry) || !hasOnlyKeys(entry, ['value', 'provenance'])
        || !POLICY_VALUE_CHECKS[key](entry.value) || !PROVENANCE_CLASSES.includes(entry.provenance)) {
        errors.push(`discovery policy key "${key}" must have a valid value and provenance`);
      }
    }
    for (const key of Object.keys(POLICY_VALUE_CHECKS)) {
      if (!(key in document.policy)) errors.push(`discovery policy key "${key}" is missing`);
    }
  }
  if (errors.length > 0) throw new DiscoveryContractError(errors);
  return document.policy;
}

function loadTargetDocument(path, targetId) {
  const document = readJson(path, 'target definition');
  const errors = [];
  const identity = document?.identity;
  if (!isRecord(document) || !hasOnlyKeys(document, ['format_version', 'target_id', 'identity'])
    || document.format_version !== FORMAT_VERSION || document.target_id !== targetId || !isRecord(identity)) {
    errors.push('target definition must contain format_version 1, its own target_id, and identity');
  } else if (!hasOnlyKeys(identity, ['status', 'virtualization', 'dmi', 'dmi_fields_pending'])
    || (identity.virtualization !== undefined && typeof identity.virtualization !== 'string')) {
    errors.push('target identity contains an unknown or invalid field');
  } else if (identity.status === 'defined') {
    const dmi = identity.dmi;
    if (!isRecord(dmi) || !hasOnlyKeys(dmi, DMI_IDENTITY_FIELDS) || Object.keys(dmi).length === 0
      || Object.values(dmi).some(value => typeof value !== 'string' || value.length === 0)
      || identity.dmi_fields_pending !== undefined) {
      errors.push('a defined target identity requires non-empty dmi values and no pending fields');
    }
  } else if (identity.status === 'pending_capture') {
    const pending = identity.dmi_fields_pending;
    if (!Array.isArray(pending) || pending.length === 0 || !pending.every(field => DMI_IDENTITY_FIELDS.includes(field))
      || identity.dmi !== undefined) {
      errors.push('a pending target identity requires dmi_fields_pending and no dmi values');
    }
  } else {
    errors.push('target identity status must be "defined" or "pending_capture"');
  }
  if (errors.length > 0) throw new DiscoveryContractError(errors.map(message => `${path}: ${message}`));
  return document;
}

export function loadTarget(targetsRoot, targetId) {
  if (targetId === undefined || targetId === '') {
    return {
      target: null,
      reasons: [reason(
        'target_missing',
        'No target was specified.',
        'Pass --target with a supported target id, such as reference-vm.',
      )],
    };
  }
  const definition = typeof targetId === 'string' && TARGET_ID_PATTERN.test(targetId)
    ? join(targetsRoot, targetId, 'target.json')
    : null;
  if (definition === null || !existsSync(definition)) {
    return {
      target: null,
      reasons: [reason(
        'target_unknown',
        'The requested target is not supported.',
        'Use a target id that has a definition under targets/, such as reference-vm or framework-13-pro-amd.',
      )],
    };
  }
  return { target: loadTargetDocument(definition, targetId), reasons: [] };
}

export function loadOverride(targetsRoot, targetId) {
  const path = join(targetsRoot, targetId, 'overrides', 'discovery.json');
  if (!existsSync(path)) return { override: {}, reasons: [] };
  try {
    const document = JSON.parse(readFileSync(path, 'utf8'));
    if (isRecord(document)) return { override: document, reasons: [] };
  } catch {
    // fall through to the invalid-format reason
  }
  return {
    override: {},
    reasons: [reason(
      'override_invalid_format',
      `targets/${targetId}/overrides/discovery.json is not a JSON object.`,
      'Fix the override file so that it is a JSON object of allowlisted policy keys, then rerun discovery.',
    )],
  };
}

function isDetectedFactKey(key) {
  return DETECTED_ROOTS.some(root => key === root || key.startsWith(`${root}.`));
}

export function resolvePolicy({ baseline, override }) {
  const allowlist = Object.keys(baseline);
  const accepted = {};
  const reasons = [];
  for (const [key, value] of Object.entries(override)) {
    if (isDetectedFactKey(key)) {
      reasons.push(reason(
        'override_detected_fact',
        `The override key "${key}" targets a detected fact, which can never be overridden.`,
        'Remove the key from the target override; only policy keys are allowed.',
      ));
    } else if (!allowlist.includes(key)) {
      reasons.push(reason(
        'override_unknown_key',
        `The override key "${key}" is not an allowlisted policy key.`,
        `Remove the key from the target override; allowed keys: ${allowlist.join(', ')}.`,
      ));
    } else if (!POLICY_VALUE_CHECKS[key](value)) {
      reasons.push(reason(
        'override_invalid_value',
        `The override value for "${key}" is invalid.`,
        'Correct the value in the target override, then rerun discovery.',
      ));
    } else {
      accepted[key] = value;
    }
  }
  const values = {};
  for (const [key, entry] of Object.entries(baseline)) values[key] = entry.value;
  return { values: { ...values, ...accepted }, accepted, reasons };
}

function flatten(value, prefix, output) {
  for (const [key, item] of Object.entries(value)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (isRecord(item)) flatten(item, path, output);
    else output[path] = { value: item };
  }
  return output;
}

export function resolveEffective({ baseline = {}, detected = {}, override = {}, runtime = {} }) {
  const effective = {};
  for (const [source, layer] of [['baseline', baseline], ['detected', detected], ['override', override], ['runtime', runtime]]) {
    for (const [key, entry] of Object.entries(layer)) {
      effective[key] = source === 'runtime' ? { source, private: true } : { ...entry, source };
    }
  }
  return effective;
}

export function resolveLayers({ baseline, detected, accepted = {}, runtimeNames = [] }) {
  const layers = {
    portable_baseline: { policy: baseline },
    detected,
    target_override: { policy: accepted },
    runtime_private: { required_inputs: [...runtimeNames] },
  };
  const flat = {
    baseline: {},
    detected: flatten(detected, '', {}),
    override: {},
    runtime: {},
  };
  for (const [key, entry] of Object.entries(baseline)) flat.baseline[`policy.${key}`] = entry;
  for (const [key, value] of Object.entries(accepted)) flat.override[`policy.${key}`] = { value };
  for (const name of runtimeNames) flat.runtime[`runtime.${name}`] = {};
  return { layers, effective: resolveEffective(flat) };
}
