import { canonicalize } from '../plan/canonical-json.mjs';

export const NEXT_STEP_REGENERATE = 'Regenerate and review the installation plan.';

const IDENTITY_KEYS = ['path', 'by_id', 'wwn', 'serial', 'model', 'size_bytes'];

function invalidation(code, message) {
  return { code, message, next_step: NEXT_STEP_REGENERATE };
}

function describeDisk(disk) {
  return disk.by_id ?? disk.path ?? 'the selected disk';
}

// The facts disk that the plan selected: by_id when the plan carries one, otherwise by path.
export function selectedDisk(plan, facts) {
  const wanted = plan.target.disk;
  const disks = facts.layers?.detected?.storage?.disks ?? [];
  return disks.find(disk => (wanted.by_id !== undefined
    ? disk.identity?.by_id === wanted.by_id
    : disk.identity?.path === wanted.path));
}

function sameValue(left, right) {
  if (left === undefined || right === undefined) return left === right;
  return canonicalize(left) === canonicalize(right);
}

// Pure comparison of a valid plan with fresh facts (DEC-005). `hashes` holds the recomputed
// `policy_sha256` and `override_sha256` (undefined when no override applies). `baselineFacts` is the
// facts document of the first discovery of the run; the plan does not record Secure Boot, so that state
// is compared between the two discoveries. Returns an empty list when nothing differs.
export function compareSafety({ plan, facts, hashes, baselineFacts }) {
  const reasons = [];

  if (facts.source?.target_id !== plan.target.target_id) {
    reasons.push(invalidation(
      'target_identity_changed',
      `The rediscovered target is not ${plan.target.target_id}, the target of the plan.`,
    ));
  }

  const firmware = facts.layers?.detected?.firmware ?? {};
  if (firmware.boot_mode !== plan.choices.firmware_mode.value) {
    reasons.push(invalidation(
      'target_identity_changed',
      'The firmware boot mode differs from the one the plan was generated for.',
    ));
  }
  if (baselineFacts !== undefined) {
    const baseline = baselineFacts.layers?.detected?.firmware ?? {};
    if (baseline.secure_boot !== firmware.secure_boot) {
      reasons.push(invalidation(
        'target_identity_changed',
        'The Secure Boot state differs from the one detected when the review started.',
      ));
    }
  }

  const planned = plan.target.disk;
  const disk = selectedDisk(plan, facts);
  if (disk === undefined) {
    reasons.push(invalidation(
      'target_identity_changed',
      `The disk ${describeDisk(planned)} selected by the plan is no longer present.`,
    ));
  } else {
    const differing = IDENTITY_KEYS.filter(key => !sameValue(planned[key], disk.identity[key]));
    if (differing.length > 0) {
      reasons.push(invalidation(
        'target_identity_changed',
        `The identity of ${describeDisk(planned)} differs from the plan (${differing.join(', ')}).`,
      ));
    }
    if (disk.eligible !== true) {
      reasons.push(invalidation(
        'target_layout_changed',
        `The disk ${describeDisk(planned)} is no longer eligible for installation.`,
      ));
    }
    if (!sameValue(planned.current_layout, disk.layout)) {
      reasons.push(invalidation(
        'target_layout_changed',
        `The partition layout of ${describeDisk(planned)} differs from the plan.`,
      ));
    }
  }

  const binding = plan.policy_binding;
  if (binding.policy_sha256 !== hashes.policy_sha256) {
    reasons.push(invalidation('policy_changed', 'The installation policy differs from the one the plan was generated with.'));
  }
  if (binding.override_sha256 !== hashes.override_sha256) {
    reasons.push(invalidation('policy_changed', 'The target override differs from the one the plan was generated with.'));
  }
  return reasons;
}
