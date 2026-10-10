import {
  chmodSync,
  closeSync,
  existsSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { DiscoveryContractError, validateDocument } from './validate-facts.mjs';

const FACTS_FILE = 'target-facts.json';

export function ensurePrivateDirectory(path) {
  const missing = [];
  for (let current = path; !existsSync(current); current = dirname(current)) missing.unshift(current);
  for (const directory of missing) {
    mkdirSync(directory, { mode: 0o700 });
    chmodSync(directory, 0o700);
  }
}

export function writePrivateFile(directory, name, content) {
  ensurePrivateDirectory(directory);
  const temporary = join(directory, `.${name}.${process.pid}.tmp`);
  const descriptor = openSync(temporary, 'wx', 0o600);
  try {
    writeSync(descriptor, content);
    fsyncSync(descriptor);
  } catch (error) {
    closeSync(descriptor);
    unlinkSync(temporary);
    throw error;
  }
  closeSync(descriptor);
  chmodSync(temporary, 0o600);
  return temporary;
}

export function writeFacts(document, directory) {
  const errors = validateDocument(document);
  if (errors.length > 0) throw new DiscoveryContractError(errors);
  const temporary = writePrivateFile(directory, FACTS_FILE, `${JSON.stringify(document, null, 2)}\n`);
  const written = validateDocument(JSON.parse(readFileSync(temporary, 'utf8')));
  if (written.length > 0) {
    unlinkSync(temporary);
    throw new DiscoveryContractError(written);
  }
  const destination = join(directory, FACTS_FILE);
  renameSync(temporary, destination);
  return destination;
}

function describe(entry) {
  if (entry === undefined) return 'unavailable';
  return `${entry.value} [${entry.source}]`;
}

function gibibytes(bytes) {
  return `${(bytes / 1024 ** 3).toFixed(1)} GiB`;
}

export function renderSummary(document) {
  const { effective, source, profile, validation } = document;
  const { firmware, network, storage, hardware } = document.layers.detected;
  const lines = [
    `Profile: ${profile.status === 'matched' ? `matched ${profile.profile_id}` : 'unqualified (experimental; no compatibility or support is promised)'} (commit ${source.commit}, dirty ${source.dirty})`,
    `Validation: ${validation.status}`,
    `Firmware: ${describe(effective['firmware.boot_mode'])}, platform ${describe(effective['firmware.platform_bits'])}, Secure Boot ${describe(effective['firmware.secure_boot'])}`,
    `Network: ${describe(effective['network.ready'])}${network.failing_step ? `, failing step ${network.failing_step}` : ''}`,
    `Storage: ${storage.disks.length} disk(s), ${storage.disks.filter(disk => disk.eligible).length} eligible [detected]`,
  ];
  for (const disk of storage.disks) {
    const size = disk.identity.size_bytes === undefined ? 'unknown size' : gibibytes(disk.identity.size_bytes);
    const state = disk.eligible ? 'eligible' : `ineligible (${disk.ineligible_reasons.join(', ')})`;
    lines.push(`  ${disk.identity.path}  ${size}  ${state}`);
  }
  lines.push(`Hardware: ${hardware.cpu?.vendor ?? 'unknown CPU'}, virtualization ${describe(effective['hardware.virtualization'])}`);
  for (const [key, entry] of Object.entries(effective)) {
    if (key.startsWith('policy.')) lines.push(`Policy ${key.slice('policy.'.length)}: ${describe(entry)}`);
  }
  for (const item of validation.reasons) lines.push(`Reason ${item.code}: ${item.message} Next: ${item.next_step}`);
  for (const item of validation.warnings) lines.push(`Warning ${item.code}: ${item.message} Next: ${item.next_step}`);
  if (firmware.dmi?.sys_vendor !== undefined) lines.push(`Machine: ${firmware.dmi.sys_vendor} ${firmware.dmi.product_name ?? ''}`.trimEnd());
  return `${lines.join('\n')}\n`;
}
