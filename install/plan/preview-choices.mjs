import { reason } from '../discovery/validate-facts.mjs';
import {
  buildWarnings,
  detectedMemoryBytes,
  diskIdentifier,
  memoryUnavailableReason,
  resolveSelection,
  selectDisk,
} from './generate-plan.mjs';
import { CHOICE_ONLY_KEYS, checkChoiceValue, parseChoiceText } from './resolve-choices.mjs';
import { swapfileRange } from './swap-policy.mjs';
import {
  CHOICES_FORMAT_VERSION,
  CHOICE_SPECS,
  DERIVED_KEYS,
  LANGUAGES,
  REGIONAL_FORMATS,
  ROOT_ACCOUNT_MODES,
} from './validate-plan.mjs';

const SECRET_LIKE_KEY = /password|passphrase|secret|token/i;
const FREE_TEXT_KEYS = ['hostname', 'user_name', 'timezone', 'console_keymap'];

function optionsFor({ facts, policy, disk, hibernation, memoryTotalBytes }) {
  const disks = facts.layers.detected.storage.disks.filter(disk => disk.eligible).map(disk => {
    const entry = { value: diskIdentifier(disk) };
    for (const key of ['path', 'model', 'size_bytes']) {
      if (disk.identity[key] !== undefined) entry[key] = disk.identity[key];
    }
    return entry;
  });
  const options = {
    target_disk: disks,
    target_mode: ['whole_disk', ...((disk?.replace_candidates ?? []).length === 1 ? ['replace_installation'] : [])],
    replace_root_partuuid: (disk?.replace_candidates ?? []).map(candidate => ({
      value: candidate.root.partuuid, disk_path: candidate.disk_path, root: candidate.root, esp: candidate.esp,
    })),
    storage_option: Object.entries(policy.storageOptions).map(([value, option]) => ({
      value,
      tier: option.tier,
      filesystem: option.filesystem,
      bootloader: option.bootloader,
    })),
    hibernation: [true, false],
    // The range is derived from the detected memory; the size is editable only while hibernation is enabled.
    swapfile_size: { ...swapfileRange(memoryTotalBytes), editable: hibernation },
    lang: [...LANGUAGES],
    regional_format: [...REGIONAL_FORMATS],
    root_account: [...ROOT_ACCOUNT_MODES],
  };
  for (const key of FREE_TEXT_KEYS) options[key] = { rule: CHOICE_SPECS[key].description };
  return options;
}

// The editable choices the plan would hold for the given choices, the allowed values, and the derived
// localization. Reuses the resolver of plan generation; writes nothing and creates no plan.
// Returns { document } or { reasons }.
export function previewChoices({ facts, policy, choices = { values: {} }, override = { values: {} } }) {
  const selection = resolveSelection({ facts, policy, choices, override, allowPendingDisk: true });
  if (selection.reasons.length > 0) return { reasons: selection.reasons };
  const { resolved, values, disk, option, memoryTotalBytes } = selection;
  const editable = {};
  for (const [key, entry] of Object.entries(resolved)) {
    if (entry.editable) {
      editable[key] = { value: entry.value, provenance: entry.provenance, source: entry.source, editable: entry.editable };
    }
  }
  return {
    document: {
      format_version: CHOICES_FORMAT_VERSION,
      choices: editable,
      options: optionsFor({ facts, policy, disk, hibernation: values.hibernation, memoryTotalBytes }),
      derived: { locales: resolved.locales.value, locale_categories: resolved.locale_categories.value },
      warnings: buildWarnings({
        facts, disk, storageOption: values.storage_option, option, swapfileSize: values.swapfile_size, memoryTotalBytes,
      }),
    },
  };
}

function invalid(...reasons) {
  return { valid: false, reasons };
}

// Checks one value against its own rules and the facts, not the complete combination. `value` is the raw
// string argument: swapfile_size is parsed as an integer and hibernation as a boolean by the shared parser. A
// secret-like key is rejected before its value is read.
export function validateChoice({ facts, policy, choices = { values: {} }, override = { values: {} }, key, value, root = '/' }) {
  if (SECRET_LIKE_KEY.test(key)) {
    return invalid(reason(
      'choices_secret_key',
      'The key is secret-like; secrets never travel through choices.',
      'Use a choice key from the preview; secrets are requested by a protected prompt when the plan is approved and applied.',
    ));
  }
  const editableKeys = [...Object.keys(policy.policy).filter(name => policy.policy[name].editable), ...CHOICE_ONLY_KEYS];
  if (DERIVED_KEYS.includes(key) || (key in policy.policy && !policy.policy[key].editable)) {
    return invalid(reason('choices_not_editable', `${key} is fixed or derived and cannot be chosen.`, `Choose only: ${editableKeys.join(', ')}.`));
  }
  if (!editableKeys.includes(key)) {
    return invalid(reason('choices_unknown_key', `${key} is not a known choice.`, `Choose only: ${editableKeys.join(', ')}.`));
  }
  const parsed = parseChoiceText(key, value);
  let memoryTotalBytes;
  if (key === 'swapfile_size') {
    memoryTotalBytes = detectedMemoryBytes(facts);
    if (memoryTotalBytes === undefined) return invalid(memoryUnavailableReason());
  }
  const problem = checkChoiceValue(key, parsed, { root, storageOptions: policy.storageOptions, memoryTotalBytes });
  if (problem !== undefined) {
    return invalid(reason('choices_invalid_value', `${problem}.`, `Provide a value that satisfies ${key}; see the choice preview.`));
  }
  if (key === 'target_disk') {
    const selected = selectDisk(facts.layers.detected.storage.disks, parsed);
    if (selected.reasons.length > 0) return invalid(...selected.reasons);
  }
  if (key === 'target_mode' || key === 'replace_root_partuuid') {
    const selection = resolveSelection({
      facts, policy, override,
      choices: { values: { ...choices.values, [key]: parsed,
        ...(key === 'replace_root_partuuid' ? { target_mode: 'replace_installation' } : {}) } },
      allowPendingDisk: true,
    });
    if (selection.reasons.length > 0) return invalid(...selection.reasons);
  }
  const result = { valid: true, key, value: parsed };
  if (key === 'lang' || key === 'regional_format') {
    const selection = resolveSelection({
      facts,
      policy,
      choices: { values: { ...choices.values, [key]: parsed } },
      override,
      allowPendingDisk: true,
    });
    if (selection.reasons.length > 0) return invalid(...selection.reasons);
    result.derived = { locales: selection.resolved.locales.value, locale_categories: selection.resolved.locale_categories.value };
  }
  return result;
}
