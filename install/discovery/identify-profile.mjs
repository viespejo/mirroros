import { reason } from './validate-facts.mjs';

// A profile identity is verifiable only through the fields its definition declares: the optional
// virtualization and each DMI value. "detected" needs only firmware.dmi and hardware.virtualization.
function declaredFields(identity, detected) {
  const fields = [];
  if (identity.virtualization !== undefined) {
    fields.push({ label: 'virtualization', expected: identity.virtualization, actual: detected.hardware?.virtualization });
  }
  for (const [field, expected] of Object.entries(identity.dmi ?? {})) {
    fields.push({ label: `DMI ${field}`, expected, actual: detected.firmware?.dmi?.[field] });
  }
  return fields;
}

// Every declared field must be observed and equal; a pending identity never matches.
export function matchesIdentity(detected, target) {
  const { identity } = target;
  if (identity.status !== 'defined') return false;
  const fields = declaredFields(identity, detected);
  return fields.length > 0 && fields.every(field => field.actual !== undefined && field.actual === field.expected);
}

// An explicit --target is an assertion: it is accepted only if the identity is defined and verified.
export function assertProfile({ detected, target }) {
  const { identity } = target;
  const reasons = [];
  const fields = declaredFields(identity, detected);
  const mismatches = fields
    .filter(field => field.actual !== undefined && field.actual !== field.expected)
    .map(field => `${field.label} is "${field.actual}", expected "${field.expected}"`);
  const unobserved = fields.filter(field => field.actual === undefined).map(field => field.label);
  if (mismatches.length > 0) {
    reasons.push(reason(
      'target_identity_mismatch',
      `The detected facts contradict the identity of profile "${target.target_id}": ${mismatches.join('; ')}.`,
      'Run discovery without --target to identify this machine, or run it on the intended machine.',
    ));
  }
  if (unobserved.length > 0) {
    reasons.push(reason(
      'target_identity_unobserved',
      `The identity of profile "${target.target_id}" cannot be verified because it was not observed: ${unobserved.join(', ')}.`,
      'Rerun discovery on the intended machine; if it persists, inspect the retained raw output of the firmware and hardware collectors.',
    ));
  }
  if (identity.status === 'pending_capture') {
    reasons.push(reason(
      'target_identity_pending_capture',
      `The identity of profile "${target.target_id}" has not been captured yet (${identity.dmi_fields_pending.join(', ')}).`,
      `Record the DMI ${identity.dmi_fields_pending.join(' and ')} in targets/${target.target_id}/target.json after capturing them on the machine, then rerun discovery.`,
    ));
  }
  return reasons;
}

// Classifies the machine. "requested" is the loadTarget result of an explicit --target, or null for
// automatic identification over "targets" (the loaded definitions). The returned target is the verified
// profile definition, or null when no profile may adjust anything.
export function classifyProfile({ detected, targets = [], requested = null }) {
  if (requested !== null) {
    if (requested.target === null) return { profile: { status: 'unqualified' }, target: null, reasons: [] };
    const reasons = assertProfile({ detected, target: requested.target });
    if (reasons.length > 0) return { profile: { status: 'unqualified' }, target: null, reasons };
    return {
      profile: { status: 'matched', profile_id: requested.target.target_id },
      target: requested.target,
      reasons: [],
    };
  }
  const matches = targets.filter(target => matchesIdentity(detected, target));
  if (matches.length === 1) {
    return { profile: { status: 'matched', profile_id: matches[0].target_id }, target: matches[0], reasons: [] };
  }
  if (matches.length > 1) {
    return {
      profile: { status: 'unqualified' },
      target: null,
      reasons: [reason(
        'profile_ambiguous',
        `More than one defined profile matches this machine: ${matches.map(target => target.target_id).join(', ')}.`,
        'Make the identities in targets/<id>/target.json distinguishable, then rerun discovery.',
      )],
    };
  }
  return { profile: { status: 'unqualified' }, target: null, reasons: [] };
}
