import { canonicalize } from '../plan/canonical-json.mjs';
import { machineProjection } from '../plan/validate-plan.mjs';

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

const MACHINE_FIELDS = [
  ['architecture', machine => machine.architecture],
  ['memory_total_bytes', machine => machine.memory_total_bytes],
  ['virtualization', machine => machine.virtualization],
  ['dmi.sys_vendor', machine => machine.dmi?.sys_vendor],
  ['dmi.product_name', machine => machine.dmi?.product_name],
];

// Compares two machine projections by value and by availability: a field that appeared or disappeared differs.
function machineDifferences(planned, observed) {
  const differences = [];
  for (const [name, read] of MACHINE_FIELDS) {
    const before = read(planned);
    const after = read(observed);
    if (before === after) continue;
    if (before === undefined) differences.push(`${name} appeared`);
    else if (after === undefined) differences.push(`${name} is no longer observed`);
    else differences.push(`${name} changed`);
  }
  return differences;
}

const ASSET_OPERATIONS = ['configure_zram', 'configure_memory_reclaim'];

// The configuration operations of the plan against the current source assets: destination and SHA-256.
function assetDifferences(plan, assets) {
  if (assets === undefined) {
    return [invalidation(
      'configuration_assets_changed',
      'A configuration asset is missing or damaged, so the reviewed configuration cannot be confirmed.',
    )];
  }
  const reasons = [];
  for (const kind of ASSET_OPERATIONS) {
    const parameters = plan.operations.find(operation => operation.kind === kind)?.parameters;
    const current = assets[kind];
    if (parameters === undefined || current === undefined
      || parameters.destination !== current.destination || parameters.source_sha256 !== current.sha256) {
      reasons.push(invalidation(
        'configuration_assets_changed',
        `The configuration asset of ${kind} differs from the one the plan was generated with.`,
      ));
    }
  }
  return reasons;
}

function withoutMountpoints(layout) {
  if (layout === undefined || !Array.isArray(layout.partitions)) return layout;
  return {
    ...layout,
    partitions: layout.partitions.map(({ mountpoints: _mountpoints, ...partition }) => partition),
  };
}

// The comparison of the plan's disk with its fresh facts disk (undefined when the disk is gone): identity,
// eligibility, and layout. With `ignoreMounts` the mount points of the layout and the `mounted` ineligibility
// are left out: occupancy is a separate check of the installation engine.
export function diskDifferences(plan, disk, { ignoreMounts = false } = {}) {
  const reasons = [];
  const planned = plan.target.disk;
  if (disk === undefined) {
    reasons.push(invalidation(
      'target_identity_changed',
      `The disk ${describeDisk(planned)} selected by the plan is no longer present.`,
    ));
    return reasons;
  }
  const differing = IDENTITY_KEYS.filter(key => !sameValue(planned[key], disk.identity[key]));
  if (differing.length > 0) {
    reasons.push(invalidation(
      'target_identity_changed',
      `The identity of ${describeDisk(planned)} differs from the plan (${differing.join(', ')}).`,
    ));
  }
  const eligible = ignoreMounts
    ? (disk.ineligible_reasons ?? []).filter(item => item !== 'mounted').length === 0
    : disk.eligible === true;
  if (!eligible) {
    reasons.push(invalidation(
      'target_layout_changed',
      `The disk ${describeDisk(planned)} is no longer eligible for installation.`,
    ));
  }
  if (plan.target_mode !== plan.choices.target_mode?.value
    || (plan.target_mode !== 'whole_disk' && plan.target_mode !== 'replace_installation')) {
    reasons.push(invalidation('target_identity_changed', 'The target mode differs from the reviewed choice.'));
  }
  if (plan.target_mode === 'replace_installation') {
    const candidates = disk.replace_candidates ?? [];
    if (candidates.length !== 1 || !sameValue(plan.target.installation, candidates[0])
      || plan.choices.replace_root_partuuid?.value !== plan.target.installation?.root.partuuid) {
      reasons.push(invalidation('target_layout_changed', 'The replacement installation no longer matches the reviewed partition identities and binding.'));
    }
  }
  const observedLayout = ignoreMounts ? withoutMountpoints(disk.layout) : disk.layout;
  const plannedLayout = ignoreMounts ? withoutMountpoints(planned.current_layout) : planned.current_layout;
  if (!sameValue(plannedLayout, observedLayout)) {
    reasons.push(invalidation(
      'target_layout_changed',
      `The partition layout of ${describeDisk(planned)} differs from the plan.`,
    ));
  }
  return reasons;
}

// Pure comparison of a valid plan with fresh facts (DEC-005). `hashes` holds the recomputed
// `policy_sha256`, `profile_definition_sha256`, and `override_sha256` (each undefined when it does not
// apply, that is, without a matched profile or without an override). `baselineFacts` is the facts document
// of the first discovery of the run; the plan does not record Secure Boot, so that state is compared
// between the two discoveries. `assets` holds the destination and SHA-256 recomputed from the current
// configuration assets (loadConfigurationAssets), or is undefined when they are missing or damaged, which
// invalidates the plan. Returns an empty list when nothing differs.
export function compareSafety({ plan, facts, hashes, baselineFacts, assets }) {
  const reasons = [];

  const machine = machineDifferences(plan.target.machine, machineProjection(facts));
  if (machine.length > 0) {
    reasons.push(invalidation(
      'machine_identity_changed',
      `The machine differs from the one the plan was generated for (${machine.join('; ')}).`,
    ));
  }

  const plannedProfile = plan.target.profile;
  const observedProfile = facts.profile ?? {};
  const sameProfile = plannedProfile.status === observedProfile.status && plannedProfile.profile_id === observedProfile.profile_id;
  if (!sameProfile) {
    reasons.push(invalidation(
      'profile_binding_changed',
      'The machine profile classification differs from the one the plan was generated for.',
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

  reasons.push(...diskDifferences(plan, selectedDisk(plan, facts)));

  const binding = plan.policy_binding;
  if (binding.policy_sha256 !== hashes.policy_sha256) {
    reasons.push(invalidation('policy_changed', 'The installation policy differs from the one the plan was generated with.'));
  }
  // With a different classification the profile reason above already invalidates the plan.
  if (sameProfile && binding.profile_definition_sha256 !== hashes.profile_definition_sha256) {
    reasons.push(invalidation('profile_binding_changed', 'The definition of the matched profile differs from the one the plan was generated with.'));
  }
  if (sameProfile && binding.override_sha256 !== hashes.override_sha256) {
    reasons.push(invalidation('policy_changed', 'The target override differs from the one the plan was generated with.'));
  }
  reasons.push(...assetDifferences(plan, assets));
  return reasons;
}
