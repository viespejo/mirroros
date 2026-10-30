import { reason } from '../discovery/validate-facts.mjs';
import { parseChoiceText } from '../plan/resolve-choices.mjs';
import { CHOICES_FORMAT_VERSION, CHOICE_SPECS } from '../plan/validate-plan.mjs';

export { CHOICES_FORMAT_VERSION };

const SECRET_LIKE_KEY = /password|passphrase|secret|token/i;

export function editableKeys() {
  return Object.keys(CHOICE_SPECS).filter(key => CHOICE_SPECS[key].editable);
}

// The choices a plan already carries as explicit user choices; the starting point of an edit loop.
export function startingChoices(plan) {
  const choices = { format_version: CHOICES_FORMAT_VERSION };
  for (const [key, entry] of Object.entries(plan.choices)) {
    if (entry.source === 'choice') choices[key] = entry.value;
  }
  return choices;
}

// Widgets return text: `swapfile_size` is an integer count of MiB and `hibernation` is `true` or `false`,
// parsed by the same parser as the choice helpers. A value that does not parse stays text so the plan
// generator rejects it with its own reason.
export function parseValue(key, text) {
  return parseChoiceText(key, text);
}

// Applies one edit to an accumulated choices object. Returns `{ choices }`, or `{ reason }` when the key
// is secret-like, fixed by policy, or unknown. The input object is never modified.
export function applyEdit(choices, key, value) {
  if (SECRET_LIKE_KEY.test(key)) {
    return { reason: reason('choices_secret_key', 'Secrets never travel through the choices.', 'Secrets are requested by a protected prompt when the plan is applied.') };
  }
  if (CHOICE_SPECS[key] === undefined) {
    return { reason: reason('choices_unknown_key', `${key} is not a known choice.`, `Use only: ${editableKeys().join(', ')}.`) };
  }
  if (!CHOICE_SPECS[key].editable) {
    return { reason: reason('choices_not_editable', `${key} is fixed by the installation policy and cannot be chosen.`, `Edit one of: ${editableKeys().join(', ')}.`) };
  }
  const { format_version: _version, ...rest } = choices;
  if (key === 'swapfile_size' && rest.hibernation === false) {
    return { reason: reason('choices_conflict', 'hibernation is disabled, so no swapfile size can be chosen.', 'Enable hibernation before choosing a swapfile size.') };
  }
  // Toggling hibernation drops any explicit size: re-enabling proposes the RAM-derived default again.
  if (key === 'hibernation') delete rest.swapfile_size;
  if (key === 'target_disk' && rest.target_disk !== value) {
    delete rest.target_mode;
    delete rest.replace_root_partuuid;
  }
  if (key === 'target_mode' && value === 'whole_disk') delete rest.replace_root_partuuid;
  if (key === 'replace_root_partuuid') rest.target_mode = 'replace_installation';
  return { choices: { format_version: CHOICES_FORMAT_VERSION, ...rest, [key]: value } };
}
