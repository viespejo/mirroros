import { basename } from 'node:path';

const GIBIBYTE = 1073741824;
const MEBIBYTE = 1048576;

export function formatSize(bytes) {
  if (typeof bytes !== 'number') return 'unknown size';
  return bytes >= GIBIBYTE ? `${(bytes / GIBIBYTE).toFixed(1)} GiB` : `${(bytes / MEBIBYTE).toFixed(1)} MiB`;
}

// Markdown-significant characters in dynamic text are escaped so `gum format` shows them literally.
function escape(text) {
  return String(text).replace(/([\\`*_{}[\]<>#|~])/g, '\\$1');
}

function formatValue(value) {
  if (Array.isArray(value)) return value.map(formatValue).join(', ');
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).map(([key, item]) => `${key}=${formatValue(item)}`).join('; ');
  }
  return String(value);
}

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

function layoutLines(layout) {
  const table = layout.partition_table?.type ?? 'none';
  const partitions = layout.partitions ?? [];
  if (partitions.length === 0) return [`- Partition table: ${escape(table)}, no partitions`];
  const lines = [`- Partition table: ${escape(table)}, ${partitions.length} partition(s)`];
  for (const partition of partitions) {
    const detail = [partition.fstype ?? 'no filesystem', formatSize(partition.size_bytes)];
    if (partition.label !== undefined) detail.push(`"${partition.label}"`);
    if (partition.mountpoints !== undefined && partition.mountpoints.length > 0) detail.push(`mounted ${partition.mountpoints.join(', ')}`);
    lines.push(`  - ${escape(partition.path)}: ${escape(detail.join(', '))}`);
  }
  return lines;
}

// The review dashboard (plan review flow, steps 1 to 5) as Markdown for `gum format`. Every value
// shown comes from the plan; the same rendering applies to every target.
export function reviewMarkdown(plan) {
  const disk = plan.target.disk;
  const lines = [
    '# Installation plan review',
    '',
    `Digest sha256:${digestPrefix(plan)} for target ${escape(plan.target.target_id)}`,
    '',
    '## Target disk',
    '',
    `- Disk: ${escape(diskLabel(plan))}`,
  ];
  if (disk.by_id !== undefined) lines.push(`- Identifier: ${escape(disk.by_id)}`);
  lines.push(...layoutLines(disk.current_layout));

  lines.push('', '## Choices', '');
  for (const [key, entry] of Object.entries(plan.choices)) {
    lines.push(`- ${escape(key)}: ${escape(formatValue(entry.value))} (${escape(entry.provenance)}, ${escape(entry.source)})`);
  }

  const destructive = plan.operations.filter(operation => operation.destructive);
  const others = plan.operations.filter(operation => !operation.destructive);
  lines.push('', '## Operations', '');
  for (const operation of destructive) lines.push(`- \`DESTRUCTIVE\` ${escape(operation.id)}: ${escape(operation.description)}`);
  lines.push('', `Then, without erasing the disk: ${escape(others.map(operation => operation.id).join(', '))}`);

  lines.push('', '## Secrets requested later', '');
  for (const secret of plan.secret_requirements) {
    lines.push(`- ${escape(secret.name)}: ${escape(secret.channel)}, required by ${escape(secret.required_by.join(', '))}`);
  }

  if (plan.warnings.length > 0) {
    lines.push('', '## Warnings', '');
    for (const warning of plan.warnings) lines.push(`- ${escape(warning.message)}`);
  }
  return `${lines.join('\n')}\n`;
}
