const WIDTH = 80;
const LABEL_WIDTH = 18;
const GIBIBYTE = 1024 ** 3;
const MEBIBYTE = 1024 ** 2;

function wrap(text, firstPrefix, restPrefix) {
  const lines = [];
  let line = firstPrefix;
  let empty = true;
  for (const word of String(text).split(/\s+/).filter(Boolean)) {
    if (!empty && line.length + 1 + word.length > WIDTH) {
      lines.push(line);
      line = restPrefix;
      empty = true;
    }
    line += empty ? word : ` ${word}`;
    empty = false;
  }
  lines.push(line);
  return lines;
}

function field(label, value, indent = 2) {
  const prefix = `${' '.repeat(indent)}${label.padEnd(LABEL_WIDTH)}`;
  return wrap(value, prefix, ' '.repeat(prefix.length));
}

function section(title, number) {
  const heading = `${number}. ${title}`;
  return ['', heading, '='.repeat(heading.length)];
}

function format(value) {
  if (Array.isArray(value)) return value.length === 0 ? '(none)' : value.map(format).join(', ');
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).map(([key, item]) => `${key}=${format(item)}`).join('; ');
  }
  return String(value);
}

function size(bytes) {
  if (bytes === undefined) return 'unknown size';
  if (bytes >= GIBIBYTE) return `${bytes} bytes (${(bytes / GIBIBYTE).toFixed(1)} GiB)`;
  return `${bytes} bytes (${(bytes / MEBIBYTE).toFixed(1)} MiB)`;
}

function orderedChoiceKeys(choices) {
  const first = ['target_disk', 'storage_option'].filter(key => key in choices);
  const rest = Object.keys(choices).filter(key => !first.includes(key)).sort();
  return [...first, ...rest];
}

function renderTarget(plan) {
  const { disk } = plan.target;
  const lines = [...section('Target', 1)];
  lines.push(...field('Target', plan.target.target_id));
  for (const [label, key] of [['Disk path', 'path'], ['Disk by-id', 'by_id'], ['WWN', 'wwn'], ['Serial', 'serial'], ['Model', 'model']]) {
    if (disk[key] !== undefined) lines.push(...field(label, disk[key]));
  }
  if (disk.size_bytes !== undefined) lines.push(...field('Size', size(disk.size_bytes)));
  lines.push('');
  lines.push(...wrap('DESTRUCTIVE: every partition and all data on this disk will be erased.', '  ', '  '));
  const layout = disk.current_layout;
  lines.push('', '  Current layout (this content will be destroyed):');
  if (layout.partition_table !== undefined) {
    lines.push(...field('Partition table', `${layout.partition_table.type ?? 'unknown'}${layout.partition_table.uuid === undefined ? '' : ` ${layout.partition_table.uuid}`}`, 4));
  } else {
    lines.push('    No partition table.');
  }
  if (layout.partitions.length === 0) lines.push('    No partitions.');
  for (const partition of layout.partitions) {
    const details = [size(partition.size_bytes)];
    if (partition.fstype !== undefined) details.push(partition.fstype);
    if (partition.label !== undefined) details.push(`label ${partition.label}`);
    if (partition.mountpoints !== undefined && partition.mountpoints.length > 0) details.push(`mounted at ${partition.mountpoints.join(', ')}`);
    lines.push(...wrap(details.join('; '), `    ${partition.path}  `, '      '));
  }
  return lines;
}

function renderChoices(plan) {
  const lines = [...section('Choices and defaults', 2)];
  for (const key of orderedChoiceKeys(plan.choices)) {
    const entry = plan.choices[key];
    lines.push(...wrap(`${key}: ${format(entry.value)}`, '  ', '      '));
    const labels = `provenance ${entry.provenance}; source ${entry.source}${entry.editable ? ' [editable]' : ''}`;
    lines.push(...wrap(labels, '      ', '      '));
    if (key === 'storage_option') {
      lines.push(...wrap(
        `tier ${entry.tier}; filesystem ${entry.filesystem}; boot loader ${entry.bootloader}`,
        '      ',
        '      ',
      ));
      lines.push(...wrap(`resume offset method: ${entry.resume_offset_method}`, '      ', '        '));
    }
  }
  return lines;
}

function renderDestructive(plan) {
  const lines = [...section('Destructive operations', 3)];
  const destructive = plan.operations.filter(operation => operation.destructive);
  if (destructive.length === 0) lines.push('  None.');
  for (const operation of destructive) {
    lines.push(...wrap(`DESTRUCTIVE  ${operation.kind}`, '  ', '    '));
    lines.push(...wrap(operation.description, '      ', '      '));
  }
  return lines;
}

function renderOperations(plan) {
  const lines = [...section('Operations in order', 4)];
  const digits = String(plan.operations.length).length;
  plan.operations.forEach((operation, index) => {
    const number = String(index + 1).padStart(digits, '0');
    lines.push(...wrap(`${number}. ${operation.kind}${operation.destructive ? '  DESTRUCTIVE' : ''}`, '  ', '      '));
    lines.push(...wrap(operation.description, '      ', '      '));
    for (const [key, value] of Object.entries(operation.parameters)) {
      lines.push(...wrap(`${key}: ${format(value)}`, '      ', '        '));
    }
    for (const item of operation.resolved_at_apply ?? []) {
      lines.push(...wrap(`resolved at apply: ${item.name} (${item.method})`, '      ', '        '));
    }
  });
  return lines;
}

function renderSecrets(plan) {
  const lines = [...section('Secret requirements', 5)];
  lines.push(...wrap('Only names are recorded. Values are never stored in the plan.', '  ', '  '));
  for (const secret of plan.secret_requirements) {
    lines.push('', `  ${secret.name}`);
    lines.push(...field('Purpose', secret.purpose, 4));
    lines.push(...field('Required by', format(secret.required_by), 4));
    lines.push(...field('Channel', secret.channel, 4));
    lines.push(...field('Provenance', secret.provenance, 4));
  }
  return lines;
}

function renderHardware(plan) {
  const lines = [...section('Hardware-derived selections', 6)];
  lines.push('  Selections:');
  for (const entry of plan.hardware_selections.selections) {
    lines.push(...wrap(`${entry.id}: ${format(entry.value)}`, '    ', '        '));
    lines.push(...wrap(`fact ${entry.fact}; rule ${entry.rule}; provenance ${entry.provenance}`, '        ', '        '));
  }
  lines.push('', '  Detected capabilities (not evaluated in this stage):');
  for (const entry of plan.hardware_selections.detected_capabilities) {
    lines.push(...wrap(`${entry.id}: ${format(entry.value)}`, '    ', '        '));
    lines.push(...wrap(`fact ${entry.fact}; rule ${entry.rule}; next story ${entry.next_story}`, '        ', '        '));
  }
  return lines;
}

function renderWarnings(plan) {
  const lines = [...section('Warnings', 7)];
  if (plan.warnings.length === 0) lines.push('  None.');
  for (const warning of plan.warnings) {
    lines.push(...wrap(`${warning.code}: ${warning.message}`, '  ', '      '));
    lines.push(...wrap(`Next: ${warning.next_step}`, '      ', '      '));
  }
  return lines;
}

function renderDigest(plan) {
  const lines = [...section('Digest and bindings', 8)];
  lines.push(...field(`Digest (${plan.digest.algorithm})`, plan.digest.value));
  lines.push(...field('Facts sha256', plan.facts_binding.facts_sha256));
  lines.push(...field('Facts run', plan.facts_binding.run_id));
  lines.push(...field('Facts target', plan.facts_binding.target_id));
  lines.push(...field('Code commit', `${plan.facts_binding.commit} (dirty ${plan.facts_binding.dirty})`));
  lines.push(...field('Policy sha256', plan.policy_binding.policy_sha256));
  if (plan.policy_binding.override_sha256 !== undefined) lines.push(...field('Override sha256', plan.policy_binding.override_sha256));
  lines.push('');
  lines.push(...wrap('This plan is not approved. Approval is a separate step bound to this digest.', '  ', '  '));
  return lines;
}

// Pure function of a validated plan: plain text, no ANSI sequences, 80 columns except long values.
export function renderPlan(plan) {
  const lines = [
    `MirrorOS installation plan (format ${plan.format_version})`,
    '='.repeat(WIDTH),
    ...renderTarget(plan),
    ...renderChoices(plan),
    ...renderDestructive(plan),
    ...renderOperations(plan),
    ...renderSecrets(plan),
    ...renderHardware(plan),
    ...renderWarnings(plan),
    ...renderDigest(plan),
  ];
  return `${lines.join('\n')}\n`;
}

export function renderSummary(plan, planPath) {
  const destructive = plan.operations.filter(operation => operation.destructive).length;
  const disk = plan.target.disk;
  const option = plan.choices.storage_option;
  const secrets = plan.secret_requirements.map(secret => secret.name).join(', ');
  return [
    `Target: ${plan.target.target_id}`,
    `Disk: ${disk.by_id ?? disk.path} (${size(disk.size_bytes)})`,
    `Storage option: ${option.value} (${option.tier})`,
    `Destructive operations: ${destructive}`,
    `Secrets required: ${secrets}`,
    `Digest: ${plan.digest.algorithm} ${plan.digest.value}`,
    `Plan: ${planPath}`,
    'Review installation-plan.txt; approval is not part of this stage.',
    '',
  ].join('\n');
}
