import { readFileSync } from 'node:fs';
import { loadFacts } from '../plan/generate-plan.mjs';
import { EXIT_INTERNAL, EXIT_INVALID_INPUT, EXIT_VALID } from '../plan/validate-plan.mjs';
import { standardReason } from './outcomes.mjs';
import { digestPrefix, hibernationLabel, machineLabel, swapfileWarning } from './review-content.mjs';
import { detectedMemoryBytes, memoryUnavailableReason } from '../plan/generate-plan.mjs';

// Read-only data helpers for the guided assistant (install/confirmation/lib). The assistant is a Bash flow
// that cannot parse JSON by itself; this module reads documents the plan, discovery, and review components
// already produced and prints plain text. It resolves no policy and validates no choice.

const KIBIBYTE = 1024;
const MEBIBYTE = KIBIBYTE ** 2;
const GIBIBYTE = KIBIBYTE ** 3;
const TEBIBYTE = KIBIBYTE ** 4;

// Discovery reasons the user can correct by fixing the network and retrying.
export const RECOVERABLE_CODES = ['network_no_default_route', 'network_dns_failed', 'network_https_failed'];

const FLOW_REASONS = {
  live_network_not_ready: {
    message: 'The live network check failed: a default route, name resolution, or the validated HTTPS check is not ready.',
    next_step: 'Connect the live environment to the network and retry the connection check.',
  },
  live_clock_not_ready: {
    message: 'The system clock was not reported as synchronized within the wait.',
    next_step: 'Make sure the network works so automatic time synchronization can complete, then retry the clock check.',
  },
  live_keyring_not_ready: {
    message: 'The live package keyring was not reported as initialized within the wait.',
    next_step: 'Wait a moment so pacman-init.service can finish, then retry the keyring check.',
  },
  stage_failed: {
    message: 'A phase failed unexpectedly.',
    next_step: 'Check install.log in the run directory, then rerun mirroros-install.',
  },
};

// Every value shown on a line is plain text: control characters become spaces.
export const oneLine = value => String(value).replace(/[\u0000-\u001f\u007f]/g, ' ');

function rounded(value) {
  return Math.round(value * 10) / 10;
}

// The reference's capacity format: one decimal place, with T, G, or M as the unit.
export function capacity(bytes) {
  if (bytes >= TEBIBYTE) return `${rounded(bytes / TEBIBYTE)}T`;
  if (bytes >= GIBIBYTE) return `${rounded(bytes / GIBIBYTE)}G`;
  return `${rounded(bytes / MEBIBYTE)}M`;
}

export function diskKey(identity) {
  return identity.by_id ?? identity.path;
}

// The reference's disk label: path, capacity, model, and the filesystems the disk holds today.
export function diskLabel(identity, partitions = []) {
  const parts = partitions.map(partition => {
    const mounts = partition.mountpoints ?? [];
    const suffix = mounts.length > 0 ? `(${mounts.map(oneLine).join(', ')})` : '';
    return oneLine(partition.fstype ?? 'unknown') + suffix;
  });
  let label = `${oneLine(identity.path ?? diskKey(identity))} (${capacity(identity.size_bytes)})`;
  if (identity.model !== undefined && identity.model !== '') label += ` - ${oneLine(identity.model)}`;
  if (parts.length > 0) label += ` [${parts.join(', ')}]`;
  return label;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function walk(document, path) {
  let current = document;
  for (const key of path.split('.')) {
    if (current === null || typeof current !== 'object' || !(key in current)) return undefined;
    current = current[key];
  }
  return current;
}

function printReasons(reasons) {
  for (const item of reasons) process.stderr.write(`MirrorOS install: ${item.message}\nNext step: ${item.next_step}\n`);
}

function get([path, field]) {
  const value = walk(readJson(path), field);
  if (value === undefined) return EXIT_VALID;
  process.stdout.write(`${typeof value === 'object' ? JSON.stringify(value) : value}\n`);
  return EXIT_VALID;
}

// Eligible disks of valid facts: key, label, and kernel path, separated by tabs.
function disks([path]) {
  const loaded = loadFacts(path);
  if (loaded.facts === undefined) {
    printReasons(loaded.reasons);
    return EXIT_INVALID_INPUT;
  }
  for (const disk of loaded.facts.layers.detected.storage.disks.filter(item => item.eligible === true)) {
    const { identity } = disk;
    process.stdout.write(`${[diskKey(identity), diskLabel(identity, disk.layout?.partitions), identity.path ?? diskKey(identity)].join('\t')}\n`);
  }
  return EXIT_VALID;
}

// Exit 0 when the warnings of a plan or a choice preview include the given code; otherwise exit 2. The assistant
// only asks whether a warning the plan component produced exists; it never recomputes the rule behind it.
function hasWarning([path, code]) {
  const warnings = readJson(path).warnings ?? [];
  return warnings.some(item => item.code === code) ? EXIT_VALID : EXIT_INVALID_INPUT;
}

function storage([path]) {
  for (const option of readJson(path).options.storage_option) process.stdout.write(`${option.value}\t${option.tier}\n`);
  return EXIT_VALID;
}

// Exit 0 when the valid facts report the detected memory; otherwise prints the memory_unavailable reason as a
// JSON reasons list on stdout and exits 2, so the flow can end the run as blocked with repeated discovery.
function memory([path]) {
  const loaded = loadFacts(path);
  if (loaded.facts === undefined) {
    printReasons(loaded.reasons);
    return EXIT_INVALID_INPUT;
  }
  if (detectedMemoryBytes(loaded.facts) !== undefined) return EXIT_VALID;
  process.stdout.write(`${JSON.stringify([memoryUnavailableReason()], null, 2)}\n`);
  return EXIT_INVALID_INPUT;
}

function profile([path]) {
  const document = readJson(path).profile;
  process.stdout.write(`${document.status}\t${document.profile_id ?? ''}\n`);
  return EXIT_VALID;
}

// The values the review screen shows, one `key<TAB>value` line each, from the validated plan.
function reviewValues([path]) {
  const plan = readJson(path);
  const { choices } = plan;
  const { disk } = plan.target;
  const rows = [
    ['machine', machineLabel(plan)],
    ['disk', diskLabel(disk, disk.current_layout?.partitions)],
    ['storage_option', choices.storage_option.value],
    ['storage_tier', choices.storage_option.tier],
    ['hibernation', choices.hibernation.value],
    ['hibernation_label', hibernationLabel(plan)],
    ['swapfile_below_ram', swapfileWarning(plan) === undefined ? 'false' : 'true'],
    ['timezone', choices.timezone.value],
    ['lang', choices.lang.value],
    ['regional_format', choices.regional_format.value],
    ['format_locale', choices.locale_categories.value.LC_TIME],
    ['locales', choices.locales.value.join(' ')],
    ['user_name', choices.user_name.value],
    ['root_account', choices.root_account.value],
    ['hostname', choices.hostname.value],
    ['console_keymap', choices.console_keymap.value],
    ['plan_reference', digestPrefix(plan)],
  ];
  for (const [key, value] of rows) process.stdout.write(`${key}\t${oneLine(value)}\n`);
  return EXIT_VALID;
}

// The message and next step of every reason in a list, a plan-run, or a choice validation result.
function reasonsText([path]) {
  const document = readJson(path);
  const list = Array.isArray(document) ? document : document.reasons ?? document.validation?.reasons ?? [document];
  for (const item of list) process.stdout.write(`${oneLine(item.message)}\t${oneLine(item.next_step)}\n`);
  return EXIT_VALID;
}

// Exit 0 only when the reasons are all ones the user can correct by fixing the network.
function recoverable([path]) {
  const document = readJson(path);
  const list = Array.isArray(document) ? document : document.validation?.reasons ?? [];
  return list.length > 0 && list.every(item => RECOVERABLE_CODES.includes(item.code)) ? EXIT_VALID : EXIT_INVALID_INPUT;
}

// A one-element reason list for the record helper: a reason the flow itself owns, or a standard one.
function reasonList([code, child]) {
  const owned = FLOW_REASONS[code];
  const item = owned === undefined ? standardReason(code) : { code, ...owned };
  if (child !== undefined && child !== '') item.child_exit_status = Number(child);
  process.stdout.write(`${JSON.stringify([item], null, 2)}\n`);
  return EXIT_VALID;
}

// The progress of the engine for the progress screen, as one tab-separated line: operations completed, total,
// the one-based position of the current operation, its plan description, and the package count (empty when
// none). It reads only state.json, which the engine rewrites atomically; an unreadable file exits 2.
function engineProgress([path]) {
  let state;
  try {
    state = readJson(path);
  } catch {
    return EXIT_INVALID_INPUT;
  }
  const completed = state.operations.filter(item => item.status === 'completed').length;
  const current = state.operations.find(item => item.id === state.current) ?? state.operations[completed];
  const position = Math.min(completed + 1, state.total);
  process.stdout.write(`${[completed, state.total, position, oneLine(current?.description ?? ''), state.packages_installed ?? ''].join('\t')}\n`);
  return EXIT_VALID;
}

// The facts the failure screen shows from a valid engine record, as one tab-separated line: the failed operation
// (or the operation named by the first reason), whether a destructive operation had started (`true` or `false`),
// and the child exit status, which is last because it may be empty.
function engineSummary([path]) {
  const run = readJson(path);
  const operation = run.failed_operation?.id ?? run.reasons[0]?.operation ?? '';
  const child = run.failed_operation?.child_exit_status ?? run.reasons[0]?.child_exit_status ?? '';
  const destructive = run.completed.includes('wipe_disk_signatures') || operation === 'wipe_disk_signatures';
  process.stdout.write(`${[oneLine(operation || 'unknown'), destructive, child].join('\t')}\n`);
  return EXIT_VALID;
}

const COMMANDS = {
  get, disks, 'has-warning': hasWarning, storage, memory, profile, 'review-values': reviewValues, 'reasons-text': reasonsText,
  recoverable, reason: reasonList, 'engine-progress': engineProgress, 'engine-summary': engineSummary,
};

const [command, ...args] = process.argv.slice(2);
if (COMMANDS[command] === undefined) {
  process.stderr.write(`MirrorOS install: unknown assistant helper command: ${command}\n`);
  process.exitCode = EXIT_INTERNAL;
} else {
  try {
    process.exitCode = COMMANDS[command](args);
  } catch (error) {
    process.stderr.write(`MirrorOS install: the assistant helper failed (${error.code ?? error.name}).\n`);
    process.exitCode = EXIT_INTERNAL;
  }
}
