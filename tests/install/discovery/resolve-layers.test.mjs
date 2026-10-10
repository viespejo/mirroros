import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  loadAllTargets,
  loadBaselinePolicy,
  loadOverride,
  loadTarget,
  resolveEffective,
  resolveLayers,
  resolvePolicy,
} from '../../../install/discovery/resolve-layers.mjs';
import {
  DISCOVERY_POLICY_FORMAT_VERSION,
  DiscoveryContractError,
  FACTS_FORMAT_VERSION,
  TARGET_DEFINITION_FORMAT_VERSION,
} from '../../../install/discovery/validate-facts.mjs';
import { baseline, codes, targetsRoot } from './helpers.mjs';

function temporaryRoot(t) {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-layers-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}

test('the baseline policy carries the three allowlisted keys with provenance', () => {
  assert.deepEqual(Object.keys(baseline), ['minimum_disk_bytes', 'https_probe_url', 'https_probe_timeout_seconds']);
  assert.equal(baseline.minimum_disk_bytes.value, 21474836480);
  assert.equal(baseline.minimum_disk_bytes.provenance, 'technical_necessity');
});

test('a damaged or unknown-key policy file is a contract failure', t => {
  const root = temporaryRoot(t);
  const path = join(root, 'policy.json');
  assert.throws(() => loadBaselinePolicy(path), DiscoveryContractError);
  writeFileSync(path, '{ not json');
  assert.throws(() => loadBaselinePolicy(path), DiscoveryContractError);
  writeFileSync(path, JSON.stringify({ format_version: 1, policy: { selected_disk: { value: 'x', provenance: 'personal_preference' } } }));
  assert.throws(() => loadBaselinePolicy(path), DiscoveryContractError);
});

test('precedence is baseline < detected < override < runtime', () => {
  const layer = value => ({ shared: { value } });
  const all = resolveEffective({ baseline: layer('baseline'), detected: layer('detected'), override: layer('override'), runtime: { shared: {} } });
  assert.deepEqual(all.shared, { source: 'runtime', private: true });
  const noRuntime = resolveEffective({ baseline: layer('baseline'), detected: layer('detected'), override: layer('override') });
  assert.deepEqual(noRuntime.shared, { value: 'override', source: 'override' });
  const noOverride = resolveEffective({ baseline: layer('baseline'), detected: layer('detected') });
  assert.deepEqual(noOverride.shared, { value: 'detected', source: 'detected' });
  assert.deepEqual(resolveEffective({ baseline: layer('baseline') }).shared, { value: 'baseline', source: 'baseline' });
});

test('resolveLayers keeps the four layers separate and tags every effective value', () => {
  const { layers, effective } = resolveLayers({
    baseline,
    detected: { firmware: { boot_mode: 'uefi' }, storage: { disks: [] } },
    accepted: { minimum_disk_bytes: 42949672960 },
    runtimeNames: ['user_password'],
  });
  assert.deepEqual(Object.keys(layers), ['portable_baseline', 'detected', 'target_override', 'runtime_private']);
  assert.equal(layers.portable_baseline.policy.minimum_disk_bytes.value, 21474836480);
  assert.deepEqual(layers.target_override.policy, { minimum_disk_bytes: 42949672960 });
  assert.deepEqual(layers.runtime_private, { required_inputs: ['user_password'] });
  assert.equal(effective['policy.minimum_disk_bytes'].source, 'override');
  assert.equal(effective['policy.https_probe_url'].source, 'baseline');
  assert.equal(effective['firmware.boot_mode'].source, 'detected');
  assert.deepEqual(effective['storage.disks'], { value: [], source: 'detected' });
  assert.deepEqual(effective['runtime.user_password'], { source: 'runtime', private: true });
});

test('resolvePolicy accepts only valid allowlisted keys', () => {
  const result = resolvePolicy({
    baseline,
    override: { https_probe_timeout_seconds: 10, selected_disk: '/dev/vda', 'storage.disks': [], minimum_disk_bytes: 'big' },
  });
  assert.deepEqual(result.accepted, { https_probe_timeout_seconds: 10 });
  assert.deepEqual(codes(result.reasons), ['override_unknown_key', 'override_detected_fact', 'override_invalid_value']);
  assert.equal(result.values.https_probe_timeout_seconds, 10);
  assert.equal(result.values.minimum_disk_bytes, 21474836480);
});

test('the shipped targets load and framework-13-pro-amd stays pending capture', () => {
  assert.equal(loadTarget(targetsRoot, 'reference-vm').target.identity.status, 'defined');
  const framework = loadTarget(targetsRoot, 'framework-13-pro-amd').target;
  assert.equal(framework.identity.status, 'pending_capture');
  assert.equal(framework.identity.dmi, undefined);
  assert.equal(loadTarget(targetsRoot, 'slimbook-creative').target, null);
});

test('a damaged target definition is a contract failure', t => {
  const root = temporaryRoot(t);
  mkdirSync(join(root, 'broken'));
  writeFileSync(join(root, 'broken', 'target.json'), JSON.stringify({
    format_version: 1,
    target_id: 'broken',
    identity: { status: 'defined', virtualization: 'none', dmi: { product_serial: 'x' } },
  }));
  assert.throws(() => loadTarget(root, 'broken'), DiscoveryContractError);
  mkdirSync(join(root, 'mismatch'));
  writeFileSync(join(root, 'mismatch', 'target.json'), JSON.stringify({
    format_version: 1,
    target_id: 'other',
    identity: { status: 'pending_capture', dmi_fields_pending: ['sys_vendor'] },
  }));
  assert.throws(() => loadTarget(root, 'mismatch'), DiscoveryContractError);
});

test('facts, target definitions, and discovery policy version independently', () => {
  assert.deepEqual(
    [FACTS_FORMAT_VERSION, TARGET_DEFINITION_FORMAT_VERSION, DISCOVERY_POLICY_FORMAT_VERSION],
    [2, 1, 1],
  );
});

test('every defined profile loads in order, skipping directories without a definition', t => {
  const root = temporaryRoot(t);
  mkdirSync(join(root, 'zeta'));
  writeFileSync(join(root, 'zeta', 'target.json'), JSON.stringify({
    format_version: 1,
    target_id: 'zeta',
    identity: { status: 'defined', dmi: { sys_vendor: 'Z' } },
  }));
  mkdirSync(join(root, 'alpha'));
  writeFileSync(join(root, 'alpha', 'target.json'), JSON.stringify({
    format_version: 1,
    target_id: 'alpha',
    identity: { status: 'pending_capture', dmi_fields_pending: ['sys_vendor'] },
  }));
  mkdirSync(join(root, 'no-definition'));
  writeFileSync(join(root, 'README.md'), 'not a profile\n');
  assert.deepEqual(loadAllTargets(root).map(target => target.target_id), ['alpha', 'zeta']);
  mkdirSync(join(root, 'broken'));
  writeFileSync(join(root, 'broken', 'target.json'), '{ not json');
  assert.throws(() => loadAllTargets(root), DiscoveryContractError);
});

test('override files are optional and must be JSON objects', t => {
  const root = temporaryRoot(t);
  assert.deepEqual(loadOverride(root, 'absent'), { override: {}, reasons: [] });
  mkdirSync(join(root, 'bad', 'overrides'), { recursive: true });
  writeFileSync(join(root, 'bad', 'overrides', 'discovery.json'), '[1]');
  assert.deepEqual(codes(loadOverride(root, 'bad').reasons), ['override_invalid_format']);
  mkdirSync(join(root, 'good', 'overrides'), { recursive: true });
  writeFileSync(join(root, 'good', 'overrides', 'discovery.json'), '{"minimum_disk_bytes": 30000000000}');
  assert.deepEqual(loadOverride(root, 'good'), { override: { minimum_disk_bytes: 30000000000 }, reasons: [] });
});
