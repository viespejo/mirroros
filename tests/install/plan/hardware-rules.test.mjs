import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadChoices } from '../../../install/plan/resolve-choices.mjs';
import { previewChoices } from '../../../install/plan/preview-choices.mjs';
import { validatePlan } from '../../../install/plan/validate-plan.mjs';
import { discover } from '../discovery/helpers.mjs';
import { assets, facts, generate, policy, referenceOverride, repository, targetsRoot } from './helpers.mjs';

const operation = (plan, kind) => plan.operations.find(item => item.kind === kind);
const outcome = (plan, rule) => plan.hardware_selections.rule_outcomes.find(entry => entry.rule === rule);

function factsWith(mutate) {
  return discover('reference-vm-layout', { mutateRaw: mutate });
}

function planFor(mutate, options = {}) {
  const factsDocument = factsWith(mutate);
  const result = generate({ factsDocument, ...options });
  assert.deepEqual(result.reasons, []);
  assert.deepEqual(validatePlan(result.plan, { facts: factsDocument, assets }), []);
  return result.plan;
}

test('the reference VM plan lists the four rule outcomes, in order, instead of unevaluated capabilities', () => {
  const { plan } = generate();
  assert.equal(plan.format_version, 5);
  assert.equal(plan.hardware_selections.detected_capabilities, undefined);
  assert.deepEqual(plan.hardware_selections.rule_outcomes.map(entry => [entry.rule, entry.outcome]), [
    ['graphics', 'kernel_driver_only'],
    ['cpu-microcode', 'amd_microcode'],
    ['battery', 'battery_absent'],
    ['virtualization', 'virtual_machine'],
  ]);
  assert.deepEqual(plan.warnings, []);
});

test('rule packages stay apart from the personal packages and reach install_packages as a separate list', () => {
  const { plan } = generate();
  assert.deepEqual(plan.hardware_selections.rule_packages, [
    { name: 'amd-ucode', rule: 'cpu-microcode', provenance: 'hardware_detection', source: 'detected', editable: false },
  ]);
  const { parameters } = operation(plan, 'install_packages');
  assert.deepEqual(parameters.rule_packages, ['amd-ucode']);
  assert.equal(parameters.packages.includes('amd-ucode'), false);
  assert.equal(plan.choices.packages.value.includes('amd-ucode'), false);
});

test('an Intel CPU plans exactly intel-ucode', () => {
  const plan = planFor(raw => { raw.hardware.cpu.vendor_id = 'GenuineIntel'; });
  assert.equal(outcome(plan, 'cpu-microcode').outcome, 'intel_microcode');
  assert.deepEqual(operation(plan, 'install_packages').parameters.rule_packages, ['intel-ucode']);
  assert.deepEqual(plan.warnings, []);
});

test('a missing or unknown CPU vendor warns, selects nothing, and does not block', () => {
  for (const mutate of [raw => { delete raw.hardware.cpu.vendor_id; }, raw => { raw.hardware.cpu.vendor_id = 'CentaurHauls'; }]) {
    const plan = planFor(mutate);
    assert.equal(outcome(plan, 'cpu-microcode').outcome, 'vendor_not_recognized');
    assert.deepEqual(plan.hardware_selections.rule_packages, []);
    assert.deepEqual(operation(plan, 'install_packages').parameters.rule_packages, []);
    assert.deepEqual(plan.warnings.map(item => item.code), ['cpu_vendor_unknown']);
  }
});

test('an NVIDIA GPU warns, uses nouveau without configuring it, and installs no driver', () => {
  const plan = planFor(raw => { raw.hardware.display_devices[0].vendor_id = '0x10de'; });
  assert.equal(outcome(plan, 'graphics').outcome, 'nvidia_nouveau_fallback');
  assert.deepEqual(plan.warnings.map(item => item.code), ['graphics_nvidia_nouveau']);
  assert.deepEqual(plan.hardware_selections.rule_packages.map(entry => entry.name), ['amd-ucode']);
  const text = JSON.stringify([plan.choices, plan.operations, plan.hardware_selections.rule_packages]);
  assert.doesNotMatch(text, /nvidia|nouveau|blacklist|modprobe\.d|mesa|vulkan/i);
});

test('an unknown GPU vendor or no GPU warns and selects nothing', () => {
  for (const mutate of [raw => { raw.hardware.display_devices[0].vendor_id = '0xabcd'; }, raw => { raw.hardware.display_devices = []; }]) {
    const plan = planFor(mutate);
    assert.equal(outcome(plan, 'graphics').outcome, 'vendor_not_recognized');
    assert.deepEqual(plan.warnings.map(item => item.code), ['graphics_vendor_unknown']);
  }
});

test('rule warnings follow the policy-derived warnings and the preview carries the same ones', () => {
  const experimental = structuredClone(policy);
  experimental.storageOptions['btrfs-limine'].tier = 'experimental';
  const mutate = raw => { raw.hardware.display_devices[0].vendor_id = '0x10de'; raw.hardware.cpu.vendor_id = 'Other'; };
  const factsDocument = factsWith(mutate);
  const { plan } = generate({ factsDocument, policyOverride: experimental });
  assert.deepEqual(plan.warnings.map(item => item.code), [
    'storage_option_experimental', 'graphics_nvidia_nouveau', 'cpu_vendor_unknown',
  ]);
  const { document } = previewChoices({ facts: factsDocument, policy: experimental, override: referenceOverride() });
  assert.deepEqual(document.warnings, plan.warnings);
});

test('rule results are never editable by a choices file or an override', () => {
  const directory = mkdtempSync(join(tmpdir(), 'mirroros-rules-'));
  try {
    for (const key of ['rule_packages', 'packages', 'rule_outcomes', 'hardware_selections', 'microcode']) {
      const path = join(directory, `${key}.json`);
      writeFileSync(path, JSON.stringify({ format_version: 3, [key]: ['intel-ucode'] }));
      const { reasons } = loadChoices(path, { policy: policy.policy, storageOptions: policy.storageOptions, memoryTotalBytes: 4294967296 });
      assert.ok(reasons.length > 0, key);
      assert.ok(['choices_unknown_key', 'choices_not_editable'].includes(reasons[0].code), `${key}: ${reasons[0].code}`);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
  // An override can only carry the hostname, so it cannot name a rule package either.
  assert.deepEqual(Object.keys(referenceOverride().values), ['hostname']);
});

test('rules never change the policy or the target override, and generation reads them without writing', () => {
  const hash = path => createHash('sha256').update(readFileSync(path)).digest('hex');
  const files = [join(repository, 'install/plan/policy.json'), ...readdirSync(join(targetsRoot, 'reference-vm/overrides')).map(name => join(targetsRoot, 'reference-vm/overrides', name))];
  const before = files.map(hash);
  const policyBefore = JSON.stringify(policy);
  planFor(raw => { raw.hardware.display_devices[0].vendor_id = '0x10de'; raw.hardware.cpu.vendor_id = 'GenuineIntel'; });
  assert.deepEqual(files.map(hash), before);
  assert.equal(JSON.stringify(policy), policyBefore);
});

test('with and without the reference-vm override the rule outcomes are identical and only the override layer differs', () => {
  const mutate = raw => { raw.hardware.display_devices[0].vendor_id = '0x10de'; raw.hardware.cpu.vendor_id = 'GenuineIntel'; };
  const withOverride = planFor(mutate, { override: referenceOverride() });
  const withoutOverride = planFor(mutate, { override: { values: {} } });
  assert.deepEqual(withOverride.hardware_selections, withoutOverride.hardware_selections);
  assert.deepEqual(withOverride.warnings, withoutOverride.warnings);
  assert.deepEqual(operation(withOverride, 'install_packages').parameters, operation(withoutOverride, 'install_packages').parameters);
  assert.equal(withOverride.choices.hostname.source, 'override');
  assert.equal(withoutOverride.choices.hostname.source, 'policy');
  for (const key of Object.keys(withOverride.choices)) {
    if (key === 'hostname') continue;
    assert.deepEqual(withOverride.choices[key], withoutOverride.choices[key], key);
  }
});

test('every plan entry exposes its origin', () => {
  const { plan } = generate();
  for (const [key, entry] of Object.entries(plan.choices)) assert.ok(['policy', 'detected', 'override', 'choice'].includes(entry.source), key);
  for (const entry of plan.hardware_selections.selections) assert.equal(typeof entry.rule, 'string');
  for (const entry of plan.hardware_selections.rule_outcomes) assert.equal(typeof entry.rule, 'string');
  for (const entry of plan.hardware_selections.rule_packages) assert.equal(entry.source, 'detected');
});

test('a plan of format 3 is rejected with regeneration guidance and facts stay format 2', () => {
  const { plan } = generate();
  const earlier = { ...structuredClone(plan), format_version: 3 };
  const reasons = validatePlan(earlier, { facts: facts() });
  assert.deepEqual(reasons.map(item => item.code), ['plan_format_unsupported']);
  assert.match(reasons[0].next_step, /not migrated/);
  assert.match(reasons[0].next_step, /regenerate/i);
  assert.equal(facts().format_version, 2);
});
