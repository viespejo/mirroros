import { reason } from '../discovery/validate-facts.mjs';
import { CHOICE_SPECS } from '../plan/validate-plan.mjs';

export const CHOICES_FORMAT_VERSION = 1;

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

// Widgets return text: `swapfile_size` is an integer count of MiB and `locales` is one locale per
// line. A value that does not parse stays text so the plan generator rejects it with its own reason.
export function parseValue(key, text) {
  if (key === 'swapfile_size') return /^[0-9]+$/.test(text) ? Number(text) : text;
  if (key === 'locales') return text.split('\n').map(line => line.trim()).filter(line => line !== '');
  return text;
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
  return { choices: { format_version: CHOICES_FORMAT_VERSION, ...rest, [key]: value } };
}
