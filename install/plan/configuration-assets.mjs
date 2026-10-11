import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { PlanContractError } from './canonical-json.mjs';

// The installed-system configuration the installation policy owns (ADR 0007). The sources live under
// install/plan/assets/ and mirror their destinations; only these fixed paths are ever read. They are embedded
// with the installer code and never installed into the live system's configuration locations.
export const CONFIGURATION_ASSETS = {
  configure_zram: {
    source: 'usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf',
    destination: '/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf',
  },
  configure_memory_reclaim: {
    source: 'usr/lib/sysctl.d/60-mirroros-memory.conf',
    destination: '/usr/lib/sysctl.d/60-mirroros-memory.conf',
  },
};
export const ASSET_ROOT = 'install/plan/assets';

const ZRAM_SECTION = '[zram0]';
const ZRAM_KEYS = ['zram-size', 'compression-algorithm', 'swap-priority'];
const SYSCTL_KEYS = ['vm.swappiness', 'vm.page-cluster', 'vm.watermark_scale_factor', 'vm.watermark_boost_factor'];

function contentLines(text) {
  return text
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '' && !line.startsWith('#') && !line.startsWith(';'));
}

function keyValue(line, label) {
  const match = /^([A-Za-z0-9._-]+)\s*=\s*(\S+)$/.exec(line);
  if (match === null) throw new PlanContractError(`${label} has a line that is not "key = value": ${line}`);
  return [match[1], match[2]];
}

function collect(lines, allowed, label) {
  const settings = {};
  for (const line of lines) {
    const [key, value] = keyValue(line, label);
    if (!allowed.includes(key)) throw new PlanContractError(`${label} sets "${key}", which the policy does not declare`);
    if (key in settings) throw new PlanContractError(`${label} sets "${key}" more than once`);
    settings[key] = value;
  }
  const missing = allowed.filter(key => !(key in settings));
  if (missing.length > 0) throw new PlanContractError(`${label} does not set ${missing.join(', ')}`);
  return settings;
}

// The settings of the zram-generator drop-in: exactly one [zram0] section with the three declared keys.
export function parseZramAsset(text) {
  const label = 'the zram-generator asset';
  const [section, ...rest] = contentLines(text);
  if (section !== ZRAM_SECTION || rest.some(line => line.startsWith('['))) {
    throw new PlanContractError(`${label} must contain exactly one ${ZRAM_SECTION} section`);
  }
  return collect(rest, ZRAM_KEYS, label);
}

// The settings of the sysctl drop-in: exactly the four declared vm.* keys.
export function parseSysctlAsset(text) {
  return collect(contentLines(text), SYSCTL_KEYS, 'the sysctl asset');
}

function readAsset(codeRoot, kind) {
  const path = join(codeRoot, ASSET_ROOT, CONFIGURATION_ASSETS[kind].source);
  try {
    return readFileSync(path);
  } catch (error) {
    throw new PlanContractError(`the configuration asset for ${kind} is missing or unreadable: ${path} (${error.code ?? error.name})`);
  }
}

function agree(actual, expected, label, errors) {
  for (const [key, value] of Object.entries(expected)) {
    if (actual[key] !== String(value)) errors.push(`${label} sets ${key} to "${actual[key]}", but the policy declares "${value}"`);
  }
}

// Reads the allowlisted source assets, hashes their raw bytes, and checks that the settings they hold agree
// with the declarations of the installation policy. Returns the destination and SHA-256 per operation kind.
// A missing or damaged asset, or a divergence, is a contract failure (exit 6): the plan is never approved with
// incomplete or inconsistent delivery. `policy` is the result of loadPlanPolicy.
export function loadConfigurationAssets(codeRoot, policy) {
  const errors = [];
  const assets = {};
  const zram = policy.policy.zram.value;
  const reclaim = policy.policy.memory_reclaim.value;
  const declared = { configure_zram: zram.destination, configure_memory_reclaim: reclaim.destination };
  for (const kind of Object.keys(CONFIGURATION_ASSETS)) {
    const bytes = readAsset(codeRoot, kind);
    if (declared[kind] !== CONFIGURATION_ASSETS[kind].destination) {
      errors.push(`the policy destination of ${kind} is not the allowlisted ${CONFIGURATION_ASSETS[kind].destination}`);
    }
    assets[kind] = {
      destination: CONFIGURATION_ASSETS[kind].destination,
      sha256: createHash('sha256').update(bytes).digest('hex'),
    };
    const text = bytes.toString('utf8');
    if (kind === 'configure_zram') {
      agree(parseZramAsset(text), {
        'zram-size': zram.zram_size,
        'compression-algorithm': zram.compression_algorithm,
        'swap-priority': zram.swap_priority,
      }, 'the zram-generator asset', errors);
    } else {
      agree(parseSysctlAsset(text), reclaim.settings, 'the sysctl asset', errors);
    }
  }
  if (errors.length > 0) throw new PlanContractError(errors);
  return assets;
}
