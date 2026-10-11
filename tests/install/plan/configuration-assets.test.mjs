import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { PlanContractError } from '../../../install/plan/canonical-json.mjs';
import {
  ASSET_ROOT,
  CONFIGURATION_ASSETS,
  loadConfigurationAssets,
  parseSysctlAsset,
  parseZramAsset,
} from '../../../install/plan/configuration-assets.mjs';
import { generate, policy, repository, temporaryDirectory, removeDirectory } from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));

const sha256 = path => createHash('sha256').update(readFileSync(path)).digest('hex');
const ZRAM = CONFIGURATION_ASSETS.configure_zram;
const SYSCTL = CONFIGURATION_ASSETS.configure_memory_reclaim;

// A copy of the embedded asset tree that a test may damage; the checkout is never touched.
function copyRoot(name) {
  const root = join(scratch, name);
  mkdirSync(join(root, ASSET_ROOT), { recursive: true });
  cpSync(join(repository, ASSET_ROOT), join(root, ASSET_ROOT), { recursive: true });
  return root;
}

function rewrite(root, asset, change) {
  const path = join(root, ASSET_ROOT, asset.source);
  writeFileSync(path, change(readFileSync(path, 'utf8')));
}

test('the allowlist mirrors the installed destinations under install/plan/assets', () => {
  assert.equal(ZRAM.destination, `/${ZRAM.source}`);
  assert.equal(SYSCTL.destination, `/${SYSCTL.source}`);
  assert.deepEqual(Object.keys(CONFIGURATION_ASSETS), ['configure_zram', 'configure_memory_reclaim']);
  assert.equal(ASSET_ROOT, 'install/plan/assets');
});

test('the shipped assets hold exactly the accepted settings', () => {
  const zram = readFileSync(join(repository, ASSET_ROOT, ZRAM.source), 'utf8');
  const sysctl = readFileSync(join(repository, ASSET_ROOT, SYSCTL.source), 'utf8');
  assert.deepEqual(parseZramAsset(zram), { 'zram-size': 'ram', 'compression-algorithm': 'zstd', 'swap-priority': '100' });
  assert.equal(zram.match(/^\[/gm).length, 1);
  assert.match(zram, /^\[zram0\]$/m);
  assert.deepEqual(parseSysctlAsset(sysctl), {
    'vm.swappiness': '180',
    'vm.page-cluster': '0',
    'vm.watermark_scale_factor': '125',
    'vm.watermark_boost_factor': '0',
  });
  // No resident limit, recompression, writeback device, or algorithm fallback is selected.
  for (const forbidden of ['host-memory-limit', 'recompression', 'writeback-device', 'fs-type', 'zstd\\(']) {
    assert.doesNotMatch(zram, new RegExp(forbidden), forbidden);
  }
  assert.doesNotMatch(sysctl, /zswap/);
});

test('assets are hashed over their raw bytes and carry their destination', () => {
  const assets = loadConfigurationAssets(repository, policy);
  assert.deepEqual(Object.keys(assets), ['configure_zram', 'configure_memory_reclaim']);
  assert.equal(assets.configure_zram.sha256, sha256(join(repository, ASSET_ROOT, ZRAM.source)));
  assert.equal(assets.configure_memory_reclaim.sha256, sha256(join(repository, ASSET_ROOT, SYSCTL.source)));
  assert.equal(assets.configure_zram.destination, ZRAM.destination);
  assert.equal(assets.configure_memory_reclaim.destination, SYSCTL.destination);
});

test('a changed byte changes the hash, even when the settings still agree', () => {
  const root = copyRoot('comment-change');
  const before = loadConfigurationAssets(root, policy);
  rewrite(root, ZRAM, text => `${text}# an extra comment\n`);
  const after = loadConfigurationAssets(root, policy);
  assert.notEqual(after.configure_zram.sha256, before.configure_zram.sha256);
  assert.equal(after.configure_memory_reclaim.sha256, before.configure_memory_reclaim.sha256);
  const first = generate().plan;
  const changed = generate({ assetsOverride: after }).plan;
  assert.notEqual(changed.digest.value, first.digest.value);
});

test('a missing asset is a contract failure', () => {
  for (const asset of [ZRAM, SYSCTL]) {
    const root = copyRoot(`missing-${asset.source.replaceAll('/', '-')}`);
    rmSync(join(root, ASSET_ROOT, asset.source));
    assert.throws(() => loadConfigurationAssets(root, policy), PlanContractError);
  }
  const empty = join(scratch, 'empty-root');
  mkdirSync(empty);
  assert.throws(() => loadConfigurationAssets(empty, policy), PlanContractError);
});

test('an asset that diverges from the policy declarations is a contract failure', () => {
  const divergences = [
    [ZRAM, text => text.replace('swap-priority = 100', 'swap-priority = 10')],
    [ZRAM, text => text.replace('zstd', 'lz4')],
    [ZRAM, text => text.replace('zram-size = ram', 'zram-size = ram / 2')],
    [SYSCTL, text => text.replace('vm.swappiness = 180', 'vm.swappiness = 60')],
    [SYSCTL, text => text.replace('vm.page-cluster = 0', 'vm.page-cluster = 3')],
    [SYSCTL, text => text.replace('vm.watermark_scale_factor = 125', 'vm.watermark_scale_factor = 10')],
    [SYSCTL, text => text.replace('vm.watermark_boost_factor = 0', 'vm.watermark_boost_factor = 15000')],
  ];
  for (const [index, [asset, change]] of divergences.entries()) {
    const root = copyRoot(`divergence-${index}`);
    rewrite(root, asset, change);
    assert.throws(() => loadConfigurationAssets(root, policy), PlanContractError, `divergence ${index}`);
  }
});

test('damaged assets are rejected: extra, missing, duplicated, or malformed settings', () => {
  const damaged = [
    [ZRAM, text => text.replace('[zram0]', '[zram1]')],
    [ZRAM, text => `${text}[zram1]\nzram-size = ram\n`],
    [ZRAM, text => `${text}host-memory-limit = 1024\n`],
    [ZRAM, text => `${text}swap-priority = 100\n`],
    [ZRAM, text => text.replace('compression-algorithm = zstd\n', '')],
    [ZRAM, text => text.replace('zram-size = ram', 'zram-size')],
    [ZRAM, () => ''],
    [SYSCTL, text => `${text}vm.overcommit_memory = 1\n`],
    [SYSCTL, text => text.replace('vm.swappiness = 180\n', '')],
    [SYSCTL, text => `${text}vm.swappiness = 180\n`],
    [SYSCTL, text => text.replace('vm.page-cluster = 0', 'vm.page-cluster')],
    [SYSCTL, () => ''],
  ];
  for (const [index, [asset, change]] of damaged.entries()) {
    const root = copyRoot(`damaged-${index}`);
    rewrite(root, asset, change);
    assert.throws(() => loadConfigurationAssets(root, policy), PlanContractError, `damaged ${index}`);
  }
});

test('a policy that names another destination is a contract failure', () => {
  const moved = structuredClone(policy);
  moved.policy.zram.value.destination = '/etc/systemd/zram-generator.conf';
  assert.throws(() => loadConfigurationAssets(repository, moved), PlanContractError);
  const reclaimMoved = structuredClone(policy);
  reclaimMoved.policy.memory_reclaim.value.destination = '/etc/sysctl.d/99-other.conf';
  assert.throws(() => loadConfigurationAssets(repository, reclaimMoved), PlanContractError);
  const diverged = structuredClone(policy);
  diverged.policy.memory_reclaim.value.settings['vm.swappiness'] = 100;
  assert.throws(() => loadConfigurationAssets(repository, diverged), PlanContractError);
});

test('comments and blank lines are ignored by the parsers and nothing else is', () => {
  assert.deepEqual(parseZramAsset('# c\n\n; c\n[zram0]\nzram-size=ram\ncompression-algorithm =  zstd\nswap-priority= 100\n'), {
    'zram-size': 'ram', 'compression-algorithm': 'zstd', 'swap-priority': '100',
  });
  assert.throws(() => parseZramAsset('zram-size = ram\n'), PlanContractError);
  assert.throws(() => parseSysctlAsset('vm.swappiness = 180 # inline\n'), PlanContractError);
});
