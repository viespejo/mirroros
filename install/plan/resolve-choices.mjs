import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { isDeepStrictEqual } from 'node:util';
import { isRecord, reason } from '../discovery/validate-facts.mjs';
import { PlanContractError } from './canonical-json.mjs';
import { sha256Canonical } from './digest-plan.mjs';
import {
  CHOICES_FORMAT_VERSION,
  CHOICE_SPECS,
  DERIVED_KEYS,
  PLAN_POLICY_FORMAT_VERSION,
  PROVENANCE_CLASSES,
  TIERS,
  deriveLocalization,
} from './validate-plan.mjs';
import { checkSwapfileSize } from './swap-policy.mjs';

export class PlanUpstreamError extends Error {
  constructor(message) {
    super(message);
    this.name = 'PlanUpstreamError';
  }
}

export const OVERRIDE_ALLOWED_KEYS = ['hostname'];
// Editable choices that are not policy keys: the disk, and the swapfile size, which exists only while
// hibernation is enabled and whose default is derived from the detected memory.
export const CHOICE_ONLY_KEYS = ['target_disk', 'replace_root_partuuid', 'swapfile_size'];
export const TARGET_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const SECRET_LIKE_KEY = /password|passphrase|secret|token/i;
const ZONE_PATTERN = /^[A-Za-z0-9_+-]+(\/[A-Za-z0-9_+-]+)*$/;
const KEYMAP_PATTERN = /^[A-Za-z0-9_.+-]+$/;
const STORAGE_OPTION_KEYS = ['tier', 'filesystem', 'bootloader', 'resume_offset_method', 'subvolumes', 'mount_options', 'additional_packages'];

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new PlanContractError(`${label} is missing or damaged: ${path} (${error.code ?? error.name})`);
  }
}

export function loadPlanPolicy(path) {
  const document = readJson(path, 'installation policy');
  const errors = [];
  if (!isRecord(document) || document.format_version !== PLAN_POLICY_FORMAT_VERSION
    || !isRecord(document.policy) || !isRecord(document.storage_options)
    || Object.keys(document).some(key => !['format_version', 'policy', 'storage_options'].includes(key))) {
    throw new PlanContractError(`installation policy must contain only format_version ${PLAN_POLICY_FORMAT_VERSION}, policy, and storage_options`);
  }
  for (const [key, entry] of Object.entries(document.policy)) {
    const spec = CHOICE_SPECS[key];
    if (DERIVED_KEYS.includes(key)) {
      errors.push(`installation policy key "${key}" is derived and cannot be set by the policy`);
    } else if (spec === undefined || CHOICE_ONLY_KEYS.includes(key)) {
      errors.push(`installation policy key "${key}" is not a known policy key`);
    } else if (!isRecord(entry) || Object.keys(entry).some(field => !['value', 'provenance', 'editable'].includes(field))
      || !PROVENANCE_CLASSES.includes(entry.provenance) || entry.editable !== spec.editable || !spec.check(entry.value)) {
      errors.push(`installation policy key "${key}" must have a valid value, provenance, and editable flag`);
    }
  }
  for (const key of Object.keys(CHOICE_SPECS)) {
    if (!CHOICE_ONLY_KEYS.includes(key) && !DERIVED_KEYS.includes(key) && !(key in document.policy)) errors.push(`installation policy key "${key}" is missing`);
  }
  for (const [name, option] of Object.entries(document.storage_options)) {
    if (!isRecord(option) || !TIERS.includes(option.tier)
      || !['filesystem', 'bootloader', 'resume_offset_method'].every(field => typeof option[field] === 'string')
      || !Array.isArray(option.additional_packages)
      || Object.keys(option).some(field => !STORAGE_OPTION_KEYS.includes(field))) {
      errors.push(`installation policy storage option "${name}" is malformed`);
    }
  }
  if (!(document.policy.storage_option?.value in document.storage_options)) {
    errors.push('the default storage_option is not in the tier table');
  }
  if (errors.length > 0) throw new PlanContractError(errors);
  return {
    document,
    policy: document.policy,
    storageOptions: document.storage_options,
    sha256: sha256Canonical(document),
  };
}

function referenceDirectory(root, relative) {
  const path = join(root, relative);
  if (!existsSync(path)) throw new PlanUpstreamError(`Reference data is unavailable: ${path}`);
  return path;
}

function isTimeZone(root, zone) {
  const directory = referenceDirectory(root, 'usr/share/zoneinfo');
  if (!ZONE_PATTERN.test(zone)) return false;
  try {
    return statSync(join(directory, zone)).isFile();
  } catch {
    return false;
  }
}

function hasKeymap(directory, name) {
  if (!KEYMAP_PATTERN.test(name)) return false;
  const wanted = new Set([`${name}.map`, `${name}.map.gz`]);
  const pending = [directory];
  while (pending.length > 0) {
    const current = pending.pop();
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      if (entry.isDirectory()) pending.push(join(current, entry.name));
      else if (wanted.has(entry.name)) return true;
    }
  }
  return false;
}

function supportedLocales(root) {
  const path = referenceDirectory(root, 'usr/share/i18n/SUPPORTED');
  return new Set(readFileSync(path, 'utf8').split('\n').map(line => line.split(/\s+/)[0]).filter(Boolean));
}

// Parses the text form of a choice value, as the choice helpers and the assistant receive it: a boolean is
// exactly `true` or `false`, and an integer is a plain digit string. Anything else stays text, so the value
// checks reject it with their own reason.
export function parseChoiceText(key, text) {
  if (key === 'hibernation') {
    if (text === 'true') return true;
    if (text === 'false') return false;
    return text;
  }
  if (key === 'swapfile_size') return /^[0-9]+$/.test(text) ? Number(text) : text;
  return text;
}

// Returns an error description, or undefined when the value is acceptable. Messages never echo the value.
// `memoryTotalBytes` bounds swapfile_size from above; without it only the minimum is checked here.
export function checkChoiceValue(key, value, { root = '/', storageOptions, memoryTotalBytes } = {}) {
  const spec = CHOICE_SPECS[key];
  if (spec === undefined || !spec.check(value)) return `${key} must be ${spec?.description ?? 'a supported value'}`;
  if (key === 'swapfile_size' && memoryTotalBytes !== undefined) return checkSwapfileSize(value, memoryTotalBytes);
  if (key === 'storage_option' && storageOptions !== undefined && !(value in storageOptions)) {
    return `storage_option must be one of ${Object.keys(storageOptions).join(', ')}`;
  }
  if (key === 'timezone' && !isTimeZone(root, value)) return 'timezone is not a known time zone';
  if (key === 'console_keymap' && !hasKeymap(referenceDirectory(root, 'usr/share/kbd/keymaps'), value)) {
    return 'console_keymap is not an installed keymap';
  }
  if (key === 'lang' && !supportedLocales(root).has(value)) return 'lang is not a supported locale';
  if (key === 'regional_format' && value !== 'follow_language' && !supportedLocales(root).has(value)) {
    return 'regional_format is not a supported locale';
  }
  return undefined;
}

function readOptionalJson(path) {
  let text;
  try {
    text = readFileSync(path, 'utf8');
  } catch (error) {
    return { error: error.code === 'ENOENT' ? 'absent' : 'unreadable' };
  }
  try {
    return { document: JSON.parse(text) };
  } catch {
    return { error: 'not_json' };
  }
}

// hibernation: false cannot carry a swapfile size: the size is rejected rather than silently ignored.
export function choicesConflicts(values) {
  if (values.hibernation === false && values.swapfile_size !== undefined) {
    return [reason(
      'choices_conflict',
      'hibernation is disabled but swapfile_size is set; a disabled plan has no swapfile.',
      'Remove swapfile_size from the choices, or enable hibernation.',
    )];
  }
  return [];
}

export function loadChoices(path, { policy, storageOptions, root = '/', memoryTotalBytes }) {
  const reasons = [];
  const read = readOptionalJson(path);
  const invalidFormat = message => reason(
    'choices_invalid_format',
    message,
    `Provide a flat JSON object with format_version ${CHOICES_FORMAT_VERSION}; choices files of earlier versions are not migrated. See contracts/installation-plan.md.`,
  );
  if (read.error !== undefined) {
    reasons.push(invalidFormat(read.error === 'not_json' ? 'The choices file is not valid JSON.' : 'The choices file cannot be read.'));
    return { values: {}, reasons };
  }
  if (!isRecord(read.document) || read.document.format_version !== CHOICES_FORMAT_VERSION) {
    reasons.push(invalidFormat(`The choices file must be a JSON object with format_version ${CHOICES_FORMAT_VERSION}.`));
    return { values: {}, reasons };
  }
  const values = {};
  const allowed = [...Object.keys(policy).filter(key => policy[key].editable), ...CHOICE_ONLY_KEYS];
  for (const [key, value] of Object.entries(read.document)) {
    if (key === 'format_version') continue;
    if (SECRET_LIKE_KEY.test(key)) {
      reasons.push(reason(
        'choices_secret_key',
        'The choices file contains a secret-like key; secrets never travel through this file.',
        'Remove the key; secrets are requested by a protected prompt when the plan is approved and applied.',
      ));
    } else if (DERIVED_KEYS.includes(key) || (key in policy && !policy[key].editable)) {
      reasons.push(reason('choices_not_editable', `${key} is fixed by the installation policy and cannot be chosen.`, `Remove ${key} from the choices file.`));
    } else if (!allowed.includes(key)) {
      reasons.push(reason('choices_unknown_key', `${key} is not a known choice.`, `Use only: ${allowed.join(', ')}.`));
    } else {
      const problem = checkChoiceValue(key, value, { root, storageOptions, memoryTotalBytes });
      if (problem !== undefined) reasons.push(reason('choices_invalid_value', `${problem}.`, `Fix ${key} in the choices file.`));
      else values[key] = value;
    }
  }
  if (reasons.length === 0) reasons.push(...choicesConflicts(values));
  return { values, reasons };
}

// The hash of the matched profile's definition (targets/<id>/target.json), by the canonical implementation.
export function loadProfileDefinition(targetsRoot, profileId) {
  const unavailable = () => ({ reasons: [reason(
    'facts_invalid',
    'The facts name a matched profile whose definition this MirrorOS checkout does not provide.',
    'Rerun operations/install discover with this version of MirrorOS and pass its target-facts.json.',
  )] });
  if (typeof profileId !== 'string' || !TARGET_ID_PATTERN.test(profileId)) return unavailable();
  const read = readOptionalJson(join(targetsRoot, profileId, 'target.json'));
  if (read.error !== undefined || !isRecord(read.document)) return unavailable();
  return { sha256: sha256Canonical(read.document), reasons: [] };
}

export function loadPlanOverride(targetsRoot, targetId, { root = '/' } = {}) {
  const none = { values: {}, reasons: [] };
  if (typeof targetId !== 'string' || !TARGET_ID_PATTERN.test(targetId)) return none;
  const path = join(targetsRoot, targetId, 'overrides', 'plan.json');
  const read = readOptionalJson(path);
  if (read.error === 'absent') return none;
  const invalidFormat = message => reason(
    'override_invalid_format',
    message,
    `Fix targets/${targetId}/overrides/plan.json; it must be a flat JSON object.`,
  );
  if (read.error !== undefined || !isRecord(read.document)) {
    return { values: {}, reasons: [invalidFormat('The target plan override is unreadable or not a JSON object.')] };
  }
  const reasons = [];
  const values = {};
  for (const [key, value] of Object.entries(read.document)) {
    if (!OVERRIDE_ALLOWED_KEYS.includes(key)) {
      reasons.push(reason(
        'override_unknown_key',
        `${key} is not allowed in a target plan override.`,
        `Use only: ${OVERRIDE_ALLOWED_KEYS.join(', ')}.`,
      ));
      continue;
    }
    const problem = checkChoiceValue(key, value, { root });
    if (problem !== undefined) reasons.push(reason('override_invalid_value', `${problem}.`, `Fix ${key} in the target plan override.`));
    else values[key] = value;
  }
  if (reasons.length > 0) return { values: {}, reasons };
  return { values, reasons, sha256: sha256Canonical(read.document) };
}

// Precedence: policy < detected < override < choice. `detected` maps a key to { value, provenance, editable }.
// A choice equal to the value it would replace is an unchanged proposal and keeps that value's labels.
// locales and locale_categories are derived here from the resolved lang and regional_format.
export function resolveValues({ policy, detected = {}, override = {}, choices = {} }) {
  const resolved = {};
  for (const [key, entry] of Object.entries(policy)) {
    resolved[key] = { value: structuredClone(entry.value), provenance: entry.provenance, source: 'policy', editable: entry.editable };
  }
  for (const [key, entry] of Object.entries(detected)) {
    resolved[key] = { value: structuredClone(entry.value), provenance: entry.provenance, source: 'detected', editable: entry.editable };
  }
  for (const [key, value] of Object.entries(override)) {
    resolved[key] = { ...resolved[key], value: structuredClone(value), source: 'override' };
  }
  for (const [key, value] of Object.entries(choices)) {
    if (resolved[key] !== undefined && isDeepStrictEqual(resolved[key].value, value)) continue;
    resolved[key] = {
      value: structuredClone(value),
      provenance: policy[key]?.provenance ?? 'personal_preference',
      source: 'choice',
      editable: policy[key]?.editable ?? true,
    };
  }
  const derived = deriveLocalization(resolved.lang.value, resolved.regional_format.value);
  for (const key of DERIVED_KEYS) {
    resolved[key] = { value: derived[key], provenance: 'technical_necessity', source: 'policy', editable: false };
  }
  return resolved;
}
