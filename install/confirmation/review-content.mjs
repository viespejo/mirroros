import { basename } from 'node:path';
import { renderPlan } from '../plan/render-plan.mjs';

const GIBIBYTE = 1073741824;
const MEBIBYTE = 1048576;

export function formatSize(bytes) {
  if (typeof bytes !== 'number') return 'unknown size';
  return bytes >= GIBIBYTE ? `${(bytes / GIBIBYTE).toFixed(1)} GiB` : `${(bytes / MEBIBYTE).toFixed(1)} MiB`;
}

// The plan reference: the first 12 hex characters of the plan digest. The user never types it.
export function digestPrefix(plan) {
  return plan.digest.value.slice(0, 12);
}

// The kernel device name the user types to confirm, for example `vda` or `nvme0n1`.
export function deviceName(plan) {
  const { path } = plan.target.disk;
  return typeof path === 'string' && path !== '' ? basename(path) : undefined;
}

export function diskLabel(plan) {
  const disk = plan.target.disk;
  const parts = [disk.path ?? disk.by_id];
  if (disk.model !== undefined) parts.push(disk.model);
  parts.push(formatSize(disk.size_bytes));
  return parts.join(' ');
}

export function confirmationPrompt(plan) {
  return `Erase ${diskLabel(plan)} and apply plan ${digestPrefix(plan)}?`;
}

// Recognition identifies the machine; it is not shown as qualification or compatibility.
export function machineLabel(plan) {
  const { profile } = plan.target;
  return profile.status === 'matched' ? `Recognized (${profile.profile_id})` : 'Unqualified (experimental)';
}

function layoutLines(layout) {
  const table = layout.partition_table?.type ?? 'none';
  const partitions = layout.partitions ?? [];
  if (partitions.length === 0) return [`Partition table: ${table}, no partitions`];
  const lines = [`Partition table: ${table}, ${partitions.length} partition(s)`];
  for (const partition of partitions) {
    const detail = [partition.fstype ?? 'no filesystem', formatSize(partition.size_bytes)];
    if (partition.label !== undefined) detail.push(`"${partition.label}"`);
    if (partition.mountpoints !== undefined && partition.mountpoints.length > 0) detail.push(`mounted ${partition.mountpoints.join(', ')}`);
    lines.push(`  ${partition.path}: ${detail.join(', ')}`);
  }
  return lines;
}

// Every value of a row is one line of plain text: control characters become spaces.
const oneLine = text => String(text).replace(/[\u0000-\u001f\u007f]/g, ' ');

// The rows of the compact review, as [label, value] pairs from the validated plan. The assistant owns the
// presentation and adds the rows that are not part of the plan (live connectivity).
export function compactReview(plan) {
  const { choices } = plan;
  const storage = choices.storage_option;
  const rows = [
    ['Machine', machineLabel(plan)],
    ['Disk', diskLabel(plan)],
    ['Storage', `${storage.value} (${storage.tier})`],
    ['Swapfile', `${choices.swapfile_size.value} MiB`],
    ['Timezone', choices.timezone.value],
    ['Language', choices.lang.value],
    ['Formats', `${choices.regional_format.value} (${choices.locale_categories.value.LC_TIME})`],
    ['Locales', choices.locales.value.join(' ')],
    ['Username', choices.user_name.value],
    ['Root', choices.root_account.value],
    ['Hostname', choices.hostname.value],
    ['Keyboard', choices.console_keymap.value],
    ['Plan reference', digestPrefix(plan)],
  ];
  return rows.map(([label, value]) => [label, oneLine(value)]);
}

// The destructive-action screen content: the disk to erase, its identity and current layout, and the plan
// reference.
export function confirmationLines(plan) {
  const disk = plan.target.disk;
  const lines = [`Disk: ${diskLabel(plan)}`];
  if (disk.by_id !== undefined) lines.push(`Identifier: ${disk.by_id}`);
  lines.push(...layoutLines(disk.current_layout));
  lines.push(`Plan reference: ${digestPrefix(plan)}`);
  return lines.map(oneLine);
}

// The complete plan for inspection: the same text the plan component persists, followed by the plan
// reference. It never asks for authorization.
export function completePlanText(plan) {
  return `${renderPlan(plan)}\nPlan reference: ${digestPrefix(plan)} (the first 12 characters of the digest above)\n`;
}
