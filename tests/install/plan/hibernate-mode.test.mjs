import test from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { CONFIGURATION_ASSETS } from '../../../install/plan/configuration-assets.mjs';
import { verifyDigest, withDigest } from '../../../install/plan/digest-plan.mjs';
import { renderPlan } from '../../../install/plan/render-plan.mjs';
import { loadPlanOverride, loadProfileDefinition } from '../../../install/plan/resolve-choices.mjs';
import { operationSequence, validatePlan } from '../../../install/plan/validate-plan.mjs';
import { discover } from '../discovery/helpers.mjs';
import { STORAGE_OPTION_NAMES } from './build-fixtures.mjs';
import { assets, generate, repository, t14sFacts, targetsRoot, unqualifiedFacts } from './helpers.mjs';

const TARGET_ID = 'thinkpad-t14s-gen1-amd';
const KIND = 'configure_hibernate_mode';
const DESTINATION = '/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf';
const codes = reasons => reasons.map(item => item.code);
const modeOperation = plan => plan.operations.find(operation => operation.kind === KIND);

function t14sPlan(choices = {}, assetsOverride = assets) {
  return generate({
    factsDocument: t14sFacts(),
    override: loadPlanOverride(targetsRoot, TARGET_ID),
    profileDefinition: loadProfileDefinition(targetsRoot, TARGET_ID),
    choices,
    assetsOverride,
  }).plan;
}

test('T14s plans resolve shutdown from the profile and emit the bound operation after the swapfile', () => {
  for (const storage_option of STORAGE_OPTION_NAMES) {
    const plan = t14sPlan({ storage_option });
    assert.equal(plan.format_version, 6);
    assert.deepEqual(plan.target.profile, { status: 'matched', profile_id: TARGET_ID });
    assert.deepEqual(plan.choices.hibernate_mode, {
      value: 'shutdown', provenance: 'arch_guidance', source: 'override', editable: false,
    });
    const kinds = plan.operations.map(operation => operation.kind);
    assert.equal(kinds[kinds.indexOf('create_swapfile') + 1], KIND);
    assert.deepEqual(kinds, operationSequence(storage_option, true, 'whole_disk', 'shutdown'));
    assert.deepEqual(kinds.filter(kind => kind !== KIND), operationSequence(storage_option));
    assert.deepEqual(modeOperation(plan).parameters, {
      destination: DESTINATION,
      source_sha256: assets.configure_hibernate_mode.sha256,
      hibernate_mode: 'shutdown',
    });
    assert.equal(modeOperation(plan).destructive, false);
    assert.equal(verifyDigest(plan), true);
    assert.deepEqual(validatePlan(plan, { facts: t14sFacts(), assets }), []);
    assert.deepEqual(validatePlan(plan), []);
  }
});

test('disabled T14s hibernation keeps the resolved profile value but emits no mode operation', () => {
  for (const storage_option of STORAGE_OPTION_NAMES) {
    const plan = t14sPlan({ storage_option, hibernation: false });
    assert.deepEqual(plan.choices.hibernate_mode, {
      value: 'shutdown', provenance: 'arch_guidance', source: 'override', editable: false,
    });
    assert.equal(modeOperation(plan), undefined);
    assert.deepEqual(plan.operations.map(operation => operation.kind), operationSequence(storage_option, false));
    assert.deepEqual(validatePlan(plan, { facts: t14sFacts(), assets }), []);
  }
});

test('the reference VM, defined Framework fixture, and unmatched machine retain platform without the operation', () => {
  const fixtureTargets = join(repository, 'tests/fixtures/plan/targets');
  const frameworkFacts = discover('synthetic-laptop', { targetId: null, root: fixtureTargets });
  assert.deepEqual(frameworkFacts.profile, { status: 'matched', profile_id: 'framework-13-pro-amd' });
  const plans = [
    generate().plan,
    generate({
      factsDocument: frameworkFacts,
      override: loadPlanOverride(fixtureTargets, 'framework-13-pro-amd'),
      profileDefinition: loadProfileDefinition(fixtureTargets, 'framework-13-pro-amd'),
    }).plan,
    generate({ factsDocument: unqualifiedFacts() }).plan,
  ];
  for (const plan of plans) {
    assert.deepEqual(plan.choices.hibernate_mode, {
      value: 'platform', provenance: 'arch_guidance', source: 'policy', editable: false,
    });
    assert.equal(modeOperation(plan), undefined);
    assert.deepEqual(validatePlan(plan, { assets }), []);
  }
});

test('T14s hibernate mode composes with partition-scoped replacement without disk-wide operations', () => {
  for (const storage_option of STORAGE_OPTION_NAMES) {
    const factsDocument = discover(`coexistence-${storage_option}`, {
      targetId: null,
      mutateRaw: raw => {
        raw.firmware.dmi = { sys_vendor: 'LENOVO', product_name: '20UJ001RMX' };
        raw.hardware.virtualization = 'none';
      },
    });
    for (const hibernation of [true, false]) {
      const { plan, reasons } = generate({
        factsDocument,
        choices: {
          storage_option, hibernation, target_mode: 'replace_installation',
          replace_root_partuuid: factsDocument.layers.detected.storage.disks[0].replace_candidates[0].root.partuuid,
        },
        override: loadPlanOverride(targetsRoot, TARGET_ID),
        profileDefinition: loadProfileDefinition(targetsRoot, TARGET_ID),
      });
      assert.deepEqual(reasons, []);
      assert.deepEqual(plan.operations.map(operation => operation.kind),
        operationSequence(storage_option, hibernation, 'replace_installation', 'shutdown'));
      assert.deepEqual(plan.operations.filter(operation => operation.destructive).map(operation => operation.kind),
        ['wipe_partition_signatures', 'format_partitions']);
      assert.equal(modeOperation(plan) !== undefined, hibernation);
      assert.deepEqual(validatePlan(plan, { facts: factsDocument, assets }), []);
    }
  }
});

test('a mode operation with disabled hibernation is a hibernation contradiction', () => {
  const plan = t14sPlan({ hibernation: false });
  const anchor = plan.operations.findIndex(operation => operation.kind === 'generate_fstab');
  plan.operations.splice(anchor + 1, 0, modeOperation(t14sPlan()));
  const reasons = validatePlan(withDigest(plan), { assets });
  assert.ok(codes(reasons).includes('hibernation_plan_mismatch'));
  assert.ok(reasons.every(reason => reason.next_step.length > 0));
});

test('platform with an operation and enabled shutdown without one are mode contradictions', () => {
  const platform = t14sPlan();
  platform.choices.hibernate_mode.value = 'platform';
  const missing = t14sPlan();
  missing.operations = missing.operations.filter(operation => operation.kind !== KIND);
  for (const plan of [platform, missing]) {
    const reasons = validatePlan(withDigest(plan), { assets });
    assert.deepEqual(codes(reasons), ['hibernate_mode_plan_mismatch']);
    assert.ok(reasons[0].next_step.length > 0);
  }
});

test('the mode operation cannot be moved or duplicated', () => {
  const moved = t14sPlan();
  const index = moved.operations.findIndex(operation => operation.kind === KIND);
  [moved.operations[index], moved.operations[index + 1]] = [moved.operations[index + 1], moved.operations[index]];
  assert.deepEqual(codes(validatePlan(withDigest(moved), { assets })), ['operation_order_invalid']);
  const duplicated = t14sPlan();
  duplicated.operations.push(structuredClone(modeOperation(duplicated)));
  assert.ok(codes(validatePlan(withDigest(duplicated), { assets })).includes('hibernate_mode_plan_mismatch'));
});

test('mode operation parameters must match the allowlisted asset and shutdown setting', () => {
  const mutations = [
    parameters => { parameters.destination = '/etc/systemd/sleep.conf.d/local.conf'; },
    parameters => { parameters.source_sha256 = 'f'.repeat(64); },
    parameters => { delete parameters.source_sha256; },
    parameters => { parameters.hibernate_mode = 'platform'; },
    parameters => { parameters.extra = 'shutdown'; },
  ];
  for (const mutate of mutations) {
    const plan = t14sPlan();
    mutate(modeOperation(plan).parameters);
    assert.deepEqual([...new Set(codes(validatePlan(withDigest(plan), { assets })))], ['configuration_asset_mismatch']);
  }
});

test('the mode and asset hash are covered by the plan digest', () => {
  for (const key of ['hibernate_mode', 'source_sha256', 'destination']) {
    const plan = t14sPlan();
    modeOperation(plan).parameters[key] = key === 'source_sha256' ? 'f'.repeat(64) : 'changed';
    assert.equal(verifyDigest(plan), false);
    assert.ok(codes(validatePlan(plan, { assets })).includes('digest_mismatch'));
  }
  const changedAssets = structuredClone(assets);
  changedAssets.configure_hibernate_mode.sha256 = 'f'.repeat(64);
  const changed = t14sPlan({}, changedAssets);
  assert.notEqual(changed.digest.value, t14sPlan().digest.value);
  assert.equal(modeOperation(changed).parameters.source_sha256, 'f'.repeat(64));
  assert.deepEqual(CONFIGURATION_ASSETS.configure_hibernate_mode.destination, DESTINATION);
});

test('the generic full render shows the mode labels and every operation parameter', () => {
  const plan = t14sPlan();
  const text = renderPlan(plan);
  assert.match(text, /hibernate_mode: shutdown\n\s+provenance arch_guidance; source override\n/);
  assert.match(text, /configure_hibernate_mode/);
  for (const [key, value] of Object.entries(modeOperation(plan).parameters)) {
    assert.ok(text.replace(/\s+/g, ' ').includes(`${key}: ${value}`), key);
  }
});
