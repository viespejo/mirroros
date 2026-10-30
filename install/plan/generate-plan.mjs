import { readFileSync } from 'node:fs';
import { evaluateRules } from '../../hardware/rules/evaluate-rules.mjs';
import { FACTS_FORMAT_VERSION, isRecord, reason, validateDocument } from '../discovery/validate-facts.mjs';
import { PlanContractError } from './canonical-json.mjs';
import { sha256Canonical, withDigest } from './digest-plan.mjs';
import { choicesConflicts, resolveValues } from './resolve-choices.mjs';
import {
  SWAPFILE_PRIORITY,
  checkSwapfileSize,
  isMemoryBytes,
  isSwapfileBelowRam,
  kernelCommandLine,
  swapfileMaximumMib,
} from './swap-policy.mjs';
import {
  ACCOUNT_PASSWORD,
  KINDS,
  PLAN_FORMAT_VERSION,
  SECRET_CHANNEL,
  accountPasswordConsumers,
  bootEntryParameters,
  replacementProblems,
  machineProjection,
  operationSequence,
  validatePlan,
} from './validate-plan.mjs';

const GIBIBYTE = 1024 ** 3;

// Failures of these rules are caused by what the user asked for, not by a defect of the generator.
const INPUT_CAUSED_CODES = ['lang_not_in_locales', 'plan_size_does_not_fit'];

export const OPERATION_DESCRIPTIONS = {
  record_disk_partuuids: 'Record the target disk partition PARTUUIDs before wiping.',
  remove_stale_uefi_entries: 'Remove only UEFI entries referencing pre-wipe target PARTUUIDs.',
  wipe_partition_signatures: 'Remove signatures only from the selected ESP and root partitions.',
  format_partitions: 'Format only the selected ESP and root, preserving the partition table.',
  register_uefi_boot_entry: 'Register the MirrorOS loader first, preserving other entries.',
  wipe_disk_signatures: 'Remove existing signatures from the target disk.',
  create_partition_table: 'Write an empty GPT on the target disk.',
  create_partitions: 'Create the ESP and a root partition on the remaining space.',
  format_filesystems: 'Format the ESP and the root partition.',
  create_btrfs_subvolumes: 'Create the flat Btrfs subvolumes on the new filesystem.',
  mount_target: 'Mount the root filesystem and the ESP under the target root.',
  install_packages: 'Install packages.',
  configure_zram: 'Configure zram as preferred swap.',
  configure_memory_reclaim: 'Deliver the sysctl drop-in with the memory reclaim settings.',
  generate_fstab: 'Generate /etc/fstab by UUID.',
  create_swapfile: 'Create the fallback swapfile, which also holds the hibernation image.',
  configure_locale_time_console: 'Configure locale, time, and console keymap.',
  configure_hostname_network: 'Set the hostname and configure NetworkManager.',
  create_user: 'Create the user account and set its password from a protected prompt.',
  configure_root_account: 'Configure the root account as selected.',
  configure_sudo_sysrq_pacman: 'Install the sudoers drop-in, the sysrq setting, and the pacman options.',
  install_bootloader: 'Install and configure the boot loader and the kernel command line.',
  install_limine_snapshot_tools: 'Build and install the pinned Limine snapshot tools.',
  configure_snapper: 'Create the Snapper root configuration for the root subvolume only.',
  enable_services: 'Enable the network, time sync, trim, and storage option services.',
  create_baseline_snapshot: 'Take the post-install baseline snapshot.',
  sync_limine_snapshot_entries: 'Write the Limine snapshot boot entries.',
};

export function loadFacts(path) {
  const fail = (code, message, nextStep) => ({ facts: undefined, reasons: [reason(code, message, nextStep)] });
  let facts;
  try {
    facts = JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    return fail(
      'facts_invalid',
      `The facts file cannot be read as JSON (${error.code ?? error.name}).`,
      'Run operations/install discover and pass its target-facts.json.',
    );
  }
  if (!isRecord(facts) || facts.format_version !== FACTS_FORMAT_VERSION) {
    return fail(
      'facts_format_unknown',
      `The facts file is not a target-facts document of format_version ${FACTS_FORMAT_VERSION}; facts of earlier versions are not accepted.`,
      'Run operations/install discover with this version of MirrorOS and pass its target-facts.json.',
    );
  }
  const errors = validateDocument(facts);
  if (errors.length > 0) {
    return fail(
      'facts_invalid',
      `The facts document fails its validator: ${errors.slice(0, 3).join('; ')}.`,
      'Rerun operations/install discover and pass the new target-facts.json.',
    );
  }
  if (facts.validation.status !== 'valid') {
    const codes = facts.validation.reasons.map(item => item.code).join(', ');
    return fail(
      'facts_invalid',
      `The facts are invalid (${codes}); a plan needs valid facts.`,
      'Resolve the discovery reasons, rerun operations/install discover, and pass the new target-facts.json.',
    );
  }
  try {
    sha256Canonical(facts);
  } catch (error) {
    return fail('facts_invalid', `The facts document cannot be canonicalized: ${error.message}`, 'Rerun operations/install discover.');
  }
  return { facts, reasons: [] };
}

// The detected total memory of the facts' effective view, or undefined when it is not a positive safe integer.
export function detectedMemoryBytes(facts) {
  const value = facts.effective?.['hardware.memory_total_bytes']?.value;
  return isMemoryBytes(value) ? value : undefined;
}

export function memoryUnavailableReason() {
  return reason(
    'memory_unavailable',
    'The facts do not report the total memory as a positive integer, so zram and the hibernation swapfile cannot be sized; no value is assumed.',
    'Rerun operations/install discover so the memory is detected, and pass the new target-facts.json.',
  );
}

export function diskIdentifier(disk) {
  return disk.identity.by_id ?? disk.identity.path;
}

function describeDisk(disk) {
  const { identity } = disk;
  const size = identity.size_bytes === undefined ? 'unknown size' : `${(identity.size_bytes / GIBIBYTE).toFixed(1)} GiB`;
  return `${diskIdentifier(disk) ?? 'unidentified disk'} (${size}${identity.model === undefined ? '' : `, ${identity.model}`})`;
}

function candidatesText(disks) {
  const eligible = disks.filter(disk => disk.eligible);
  return eligible.length === 0 ? 'none' : eligible.map(describeDisk).join('; ');
}

export function selectDisk(disks, requested) {
  const eligible = disks.filter(disk => disk.eligible);
  if (requested !== undefined) {
    const named = disks.find(disk => disk.identity.by_id === requested || disk.identity.path === requested);
    if (named === undefined) {
      return { reasons: [reason(
        'disk_unknown',
        `The target_disk choice names no disk of the facts. Eligible candidates: ${candidatesText(disks)}.`,
        'Set target_disk to the by_id of an eligible candidate and rerun plan.',
      )] };
    }
    if (!named.eligible) {
      return { reasons: [reason(
        'disk_ineligible',
        `The disk named by target_disk is not eligible (${(named.ineligible_reasons ?? []).join(', ')}). Eligible candidates: ${candidatesText(disks)}.`,
        'Set target_disk to the by_id of an eligible candidate and rerun plan.',
      )] };
    }
    return { disk: named, preselected: false, reasons: [] };
  }
  if (eligible.length === 1) return { disk: eligible[0], preselected: true, reasons: [] };
  if (eligible.length === 0) {
    return { reasons: [reason('facts_invalid', 'The facts list no eligible disk.', 'Rerun operations/install discover and resolve its reasons.')] };
  }
  return { reasons: [reason(
    'disk_selection_required',
    `Several disks are eligible and a plan never guesses. Candidates: ${candidatesText(disks)}.`,
    'Name one candidate as target_disk in a choices file (--choices) and rerun plan.',
  )] };
}

function parametersFor(kind, { values, option, disk, assets, rulePackages, installation, partuuids }) {
  switch (kind) {
    case 'record_disk_partuuids':
      return { disk, partuuids };
    case 'remove_stale_uefi_entries':
      return { partuuids };
    case 'wipe_partition_signatures':
      return { esp: installation.esp, root: installation.root };
    case 'format_partitions':
      return { esp: installation.esp, root: installation.root, esp_filesystem: values.esp.filesystem, root_filesystem: option.filesystem };
    case 'register_uefi_boot_entry':
      return bootEntryParameters(option.bootloader);
    case 'wipe_disk_signatures':
      return { disk };
    case 'create_partition_table':
      return { disk, table: values.partition_table };
    case 'create_partitions':
      return { disk, esp_size_bytes: values.esp.size_bytes, esp_mount_point: values.esp.mount_point, root: 'remaining_space' };
    case 'format_filesystems':
      return { esp_filesystem: values.esp.filesystem, root_filesystem: option.filesystem };
    case 'create_btrfs_subvolumes':
      return { subvolumes: subvolumesFor(option, values.hibernation), mount_options: option.mount_options };
    case 'mount_target':
      return option.subvolumes === undefined
        ? { esp_mount_point: values.esp.mount_point }
        : { esp_mount_point: values.esp.mount_point, subvolumes: subvolumesFor(option, values.hibernation) };
    case 'install_packages':
      return {
        packages: [...values.packages, values.network.package, ...option.additional_packages],
        rule_packages: rulePackages.map(entry => entry.name),
      };
    case 'generate_fstab':
      return { identifier: 'uuid' };
    case 'configure_zram':
      return {
        destination: assets.configure_zram.destination,
        source_sha256: assets.configure_zram.sha256,
        zram_size: values.zram.zram_size,
        compression_algorithm: values.zram.compression_algorithm,
        swap_priority: values.zram.swap_priority,
      };
    case 'configure_memory_reclaim':
      return {
        destination: assets.configure_memory_reclaim.destination,
        source_sha256: assets.configure_memory_reclaim.sha256,
        ...values.memory_reclaim.settings,
      };
    case 'create_swapfile':
      return { path: '/swapfile', size_mib: values.swapfile_size, priority: SWAPFILE_PRIORITY };
    case 'configure_locale_time_console':
      return {
        locales: values.locales,
        lang: values.lang,
        locale_categories: values.locale_categories,
        console_keymap: values.console_keymap,
        timezone: values.timezone,
        hardware_clock: values.hardware_clock,
        time_sync: values.time_sync,
      };
    case 'configure_hostname_network':
      return { hostname: values.hostname, network_manager: values.network.manager };
    case 'create_user':
      return { user_name: values.user_name, groups: values.user_groups, shell: values.user_shell };
    case 'configure_root_account':
      return { mode: values.root_account };
    case 'configure_sudo_sysrq_pacman':
      return { sudoers: values.sudoers, sysrq: values.sysrq, pacman_options: values.pacman_options };
    case 'install_bootloader':
      return { bootloader: option.bootloader, kernel_cmdline: values.kernel_cmdline, options: values.bootloader_options };
    case 'enable_services':
      return { services: [values.network.manager, values.time_sync, values.fstrim] };
    default:
      return {};
  }
}

// The @swap subvolume exists only while hibernation is enabled.
function subvolumesFor(option, hibernation) {
  return option.subvolumes.filter(name => hibernation || name !== '@swap');
}

function resolvedAtApply(kind, option, hibernation) {
  if (['format_filesystems', 'format_partitions'].includes(kind)) return [{ name: 'partition_uuids', method: 'blkid' }];
  if (kind === 'create_swapfile') return [{ name: 'resume_offset', method: option.resume_offset_method }];
  if (kind === 'install_bootloader') {
    return [
      { name: 'root_uuid', method: 'blkid' },
      ...(hibernation ? [{ name: 'resume_offset', method: option.resume_offset_method }] : []),
    ];
  }
  return undefined;
}

function buildOperations(storageOption, context) {
  return operationSequence(storageOption, context.values.hibernation, context.values.target_mode).map(kind => {
    const operation = {
      id: kind,
      kind,
      destructive: KINDS[kind],
      parameters: parametersFor(kind, context),
      description: OPERATION_DESCRIPTIONS[kind],
    };
    const resolved = resolvedAtApply(kind, context.option, context.values.hibernation);
    if (resolved !== undefined) operation.resolved_at_apply = resolved;
    return operation;
  });
}

function buildSecrets(rootAccount) {
  return [{
    name: ACCOUNT_PASSWORD,
    purpose: 'Password of the created user account, shared with the root account when root password access is enabled.',
    required_by: accountPasswordConsumers(rootAccount),
    channel: SECRET_CHANNEL,
    provenance: 'technical_necessity',
  }];
}

// The warnings that do not depend on a combination of choices failing. `disk` and `option` may be undefined
// while a preview has not resolved them yet. `swapfileSize` is present only while hibernation is enabled.
export function buildWarnings({ facts, disk, storageOption, option, swapfileSize, memoryTotalBytes }) {
  const warnings = [];
  if (facts.profile.status === 'unqualified') {
    warnings.push(reason(
      'machine_unqualified',
      'This machine matches no known profile; installing on it is experimental.',
      'No compatibility or support is promised; continue only if you accept that and have reviewed every step.',
    ));
  }
  if (disk !== undefined && disk.identity.by_id === undefined) {
    warnings.push(reason(
      'disk_without_by_id',
      'The target disk has no stable by_id; it is addressed by its path, which can change between boots.',
      'Review the disk model and size again before approving the plan.',
    ));
  }
  if (option !== undefined && option.tier === 'experimental') {
    warnings.push(reason(
      'storage_option_experimental',
      `The storage option ${storageOption} is experimental and has no support commitment.`,
      'Select ext4-systemd-boot unless the experimental option is intended.',
    ));
  }
  if (swapfileSize !== undefined && isSwapfileBelowRam(swapfileSize, memoryTotalBytes)) {
    warnings.push(reason(
      'swapfile_below_ram',
      'The swapfile is smaller than the detected memory: hibernation may be unavailable under large memory workloads, because it depends on used memory and free swapfile space.',
      'Increase swapfile_size if that is not acceptable; the default size is not a guarantee of a successful resume either.',
    ));
  }
  warnings.push(...evaluateRules(facts).warnings);
  return warnings;
}

function effectiveValue(facts, path) {
  const entry = facts.effective[path];
  return entry === undefined || entry.value === undefined ? 'unknown' : entry.value;
}

function buildHardwareSelections(facts, identifier, preselected, { rule_outcomes, rule_packages }) {
  const selections = [];
  if (preselected) {
    selections.push({
      id: 'target_disk',
      fact: 'storage.disks',
      value: identifier,
      provenance: 'hardware_detection',
      rule: 'single_eligible_disk',
    });
  }
  selections.push({
    id: 'boot_mode',
    fact: 'firmware.boot_mode',
    value: effectiveValue(facts, 'firmware.boot_mode'),
    provenance: 'hardware_detection',
    rule: 'uefi_boot_mode_check',
  });
  return { selections, rule_outcomes, rule_packages };
}

// The one resolution of disk and choice values, shared by plan generation and the published choice helpers.
// With allowPendingDisk a missing disk selection (several eligible disks, none chosen) is not a failure: the
// result then has no disk, identifier, or target_disk value.
export function resolveSelection({ facts, policy, choices, override, allowPendingDisk = false }) {
  const memoryTotalBytes = detectedMemoryBytes(facts);
  if (memoryTotalBytes === undefined) return { reasons: [memoryUnavailableReason()] };
  const conflicts = choicesConflicts(choices.values);
  if (conflicts.length > 0) return { reasons: conflicts };
  if (choices.values.swapfile_size !== undefined) {
    const problem = checkSwapfileSize(choices.values.swapfile_size, memoryTotalBytes);
    if (problem !== undefined) {
      return { reasons: [reason('choices_invalid_value', `${problem}.`, 'Fix swapfile_size; see the choice preview for the range derived from the detected memory.')] };
    }
  }
  const matched = facts.profile.status === 'matched';
  const appliedOverride = matched ? override : { values: {} };
  const selected = selectDisk(facts.layers.detected.storage.disks, choices.values.target_disk);
  const pending = allowPendingDisk && selected.reasons.length > 0 && selected.reasons.every(item => item.code === 'disk_selection_required');
  if (selected.reasons.length > 0 && !pending) return { reasons: selected.reasons };
  const { disk } = selected;
  // Naming the only eligible disk is an unchanged proposal: it stays a detected selection.
  const eligible = facts.layers.detected.storage.disks.filter(candidate => candidate.eligible);
  const preselected = disk !== undefined && eligible.length === 1 && eligible[0] === disk;
  const identifier = disk === undefined ? undefined : diskIdentifier(disk);
  if (disk !== undefined && identifier === undefined) {
    return { reasons: [reason(
      'disk_unidentifiable',
      'The selected disk exposes neither a by_id nor a path, so it cannot be identified.',
      'Rerun operations/install discover; if the disk stays unidentifiable, it cannot be a target.',
    )] };
  }

  const hibernationEnabled = choices.values.hibernation ?? policy.policy.hibernation.value;
  const detected = preselected
    ? { target_disk: { value: identifier, provenance: 'hardware_detection', editable: true } }
    : {};
  // The default swapfile size is derived from the detected memory and exists only with hibernation.
  if (hibernationEnabled) {
    detected.swapfile_size = { value: swapfileMaximumMib(memoryTotalBytes), provenance: 'hardware_detection', editable: true };
  }
  const resolved = resolveValues({
    policy: policy.policy,
    detected,
    override: appliedOverride.values,
    choices: { ...choices.values, ...(choices.values.target_disk === undefined ? {} : { target_disk: identifier }) },
  });
  resolved.kernel_cmdline.value = kernelCommandLine(resolved.kernel_cmdline.value, resolved.hibernation.value);
  const values = Object.fromEntries(Object.entries(resolved).map(([key, entry]) => [key, entry.value]));
  const option = policy.storageOptions[values.storage_option];
  let installation;
  if (values.target_mode === 'replace_installation') {
    const candidates = disk?.replace_candidates ?? [];
    installation = candidates.find(candidate => candidate.root.partuuid === values.replace_root_partuuid)
      ?? (allowPendingDisk && values.replace_root_partuuid === undefined ? candidates[0] : undefined);
    const problems = replacementProblems(installation, disk?.layout, {
      espBytes: values.esp.size_bytes,
      rootMinimumBytes: values.root_minimum_bytes,
      swapfileMib: values.hibernation ? values.swapfile_size : undefined,
    });
    if (candidates.length !== 1 || installation?.disk_path !== disk?.identity.path) problems.push('Select an unambiguous discovered candidate by its full root PARTUUID.');
    if (problems.length > 0) return { reasons: problems.map(message => reason('replacement_target_invalid', message, 'Repeat discovery and select a replacement candidate that meets the storage policy.')) };
  } else if (values.replace_root_partuuid !== undefined) {
    return { reasons: [reason('choices_conflict', 'A replacement root identity requires replace_installation mode.', 'Remove replace_root_partuuid or select replace_installation.')] };
  }
  resolved.storage_option = {
    ...resolved.storage_option,
    tier: option.tier,
    filesystem: option.filesystem,
    bootloader: option.bootloader,
    resume_offset_method: option.resume_offset_method,
  };
  return { reasons: [], matched, appliedOverride, disk, preselected, identifier, resolved, values, option, memoryTotalBytes, installation };
}

// facts: a valid target-facts document. policy: the result of loadPlanPolicy. choices and override:
// `{ values }` results of loadChoices and loadPlanOverride (override may also carry `sha256`); the override
// applies only to a matched profile. profileDefinition: `{ sha256 }` of the matched profile's definition.
// assets: the result of loadConfigurationAssets, the destination and SHA-256 of each configuration asset.
// Returns { plan, reasons }: reasons are input problems (exit 2). A plan that fails its own validator for
// any other reason is an invariant violation and throws a PlanContractError (exit 6).
export function generatePlan({ facts, policy, choices = { values: {} }, override = { values: {} }, profileDefinition, assets }) {
  if (assets === undefined) throw new PlanContractError('the configuration assets were not provided to plan generation');
  const selection = resolveSelection({ facts, policy, choices, override });
  if (selection.reasons.length > 0) return { plan: undefined, reasons: selection.reasons };
  const { matched, appliedOverride, disk, preselected, identifier, resolved, values, option, memoryTotalBytes, installation } = selection;

  const warnings = buildWarnings({
    facts, disk, storageOption: values.storage_option, option, swapfileSize: values.swapfile_size, memoryTotalBytes,
  });
  const rules = evaluateRules(facts);

  const binding = {
    facts_sha256: sha256Canonical(facts),
    run_id: facts.source.run_id,
    commit: facts.source.commit,
    dirty: facts.source.dirty,
  };
  const policyBinding = { policy_sha256: policy.sha256 };
  if (matched && profileDefinition?.sha256 !== undefined) policyBinding.profile_definition_sha256 = profileDefinition.sha256;
  if (appliedOverride.sha256 !== undefined) policyBinding.override_sha256 = appliedOverride.sha256;

  const targetDisk = { eligible: disk.eligible, current_layout: disk.layout };
  for (const key of ['path', 'by_id', 'wwn', 'serial', 'model', 'size_bytes']) {
    if (disk.identity[key] !== undefined) targetDisk[key] = disk.identity[key];
  }
  const plan = withDigest({
    format_version: PLAN_FORMAT_VERSION,
    target_mode: values.target_mode,
    target: { machine: machineProjection(facts), profile: structuredClone(facts.profile), disk: targetDisk,
      ...(installation === undefined ? {} : { installation: structuredClone(installation) }) },
    choices: resolved,
    operations: buildOperations(values.storage_option, { values, option, disk: identifier, assets, rulePackages: rules.rule_packages, installation,
      partuuids: disk.layout.partitions.flatMap(partition => partition.partuuid === undefined ? [] : [partition.partuuid]) }),
    secret_requirements: buildSecrets(values.root_account),
    hardware_selections: buildHardwareSelections(facts, identifier, preselected, rules),
    warnings,
    facts_binding: binding,
    policy_binding: policyBinding,
  });

  const problems = validatePlan(plan, { facts, assets });
  const inputProblems = problems.filter(item => INPUT_CAUSED_CODES.includes(item.code));
  const internalProblems = problems.filter(item => !INPUT_CAUSED_CODES.includes(item.code));
  if (internalProblems.length > 0) {
    throw new PlanContractError(internalProblems.map(item => `${item.code}: ${item.message}`));
  }
  if (inputProblems.length > 0) return { plan: undefined, reasons: inputProblems };
  return { plan, reasons: [] };
}
