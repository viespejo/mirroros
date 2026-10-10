import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { PlanContractError } from '../../../install/plan/canonical-json.mjs';
import { generatePlan, loadFacts } from '../../../install/plan/generate-plan.mjs';
import { machineProjection, validatePlan } from '../../../install/plan/validate-plan.mjs';
import { buildValidPlan, ROOT_ACCOUNT_MODES, STORAGE_OPTION_NAMES } from './build-fixtures.mjs';
import {
  CANARY,
  facts,
  generate,
  policy,
  referenceOverride,
  referenceProfileDefinition,
  removeDirectory,
  secondEligibleDisk,
  temporaryDirectory,
  unqualifiedFacts,
  writeJson,
} from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));
const codes = result => result.reasons.map(item => item.code);

test('defaults for the reference VM produce the independent fixture exactly', () => {
  const { plan, reasons } = generate();
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan, buildValidPlan('ext4-systemd-boot', 'locked'));
  assert.deepEqual(validatePlan(plan, { facts: facts() }), []);
});

test('every storage option and root account mode matches its fixture', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      const choices = {};
      if (storageOption !== 'ext4-systemd-boot') choices.storage_option = storageOption;
      if (rootAccount !== 'locked') choices.root_account = rootAccount;
      const { plan, reasons } = generate({ choices });
      assert.deepEqual(reasons, []);
      assert.deepEqual(plan, buildValidPlan(storageOption, rootAccount), `${storageOption} ${rootAccount}`);
    }
  }
});

test('every value carries provenance, source, and editable, and the hostname comes from the override', () => {
  const { plan } = generate();
  for (const [key, entry] of Object.entries(plan.choices)) {
    assert.ok(['personal_preference', 'hardware_detection', 'arch_guidance', 'technical_necessity'].includes(entry.provenance), key);
    assert.ok(['policy', 'detected', 'override', 'choice'].includes(entry.source), key);
    assert.equal(typeof entry.editable, 'boolean', key);
  }
  assert.equal(plan.choices.hostname.value, 'mirroros-ref');
  assert.equal(plan.choices.hostname.source, 'override');
  assert.equal(generate({ override: { values: {} } }).plan.choices.hostname.value, 'mirroros');
});

test('the plan identifies the disk, its layout, and the destructive operations', () => {
  const { plan } = generate();
  assert.equal(plan.target.target_id, undefined);
  assert.equal(plan.target.disk.path, '/dev/vda');
  assert.equal(plan.target.disk.by_id, 'virtio-SYNTH-VDA-0001');
  assert.equal(plan.target.disk.serial, 'SYNTH-VDA-0001');
  assert.equal(plan.target.disk.size_bytes, 34359738368);
  assert.equal(plan.target.disk.current_layout.partitions.length, 2);
  assert.deepEqual(plan.operations.filter(operation => operation.destructive).map(operation => operation.kind), [
    'wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'format_filesystems',
  ]);
});

test('the single eligible disk is preselected as hardware detection', () => {
  const { plan } = generate();
  assert.deepEqual(plan.choices.target_disk, {
    value: 'virtio-SYNTH-VDA-0001', provenance: 'hardware_detection', source: 'detected', editable: true,
  });
  assert.equal(plan.hardware_selections.selections[0].id, 'target_disk');
  assert.equal(plan.hardware_selections.selections[0].rule, 'single_eligible_disk');
  assert.equal(plan.hardware_selections.selections[1].id, 'boot_mode');
  for (const capability of plan.hardware_selections.detected_capabilities) {
    assert.equal(capability.rule, 'not_evaluated');
    assert.equal(capability.next_story, '2.6');
  }
});

test('several eligible disks are never guessed', () => {
  const result = generate({ factsDocument: secondEligibleDisk(facts()) });
  assert.equal(result.plan, undefined);
  assert.deepEqual(codes(result), ['disk_selection_required']);
  assert.match(result.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  assert.match(result.reasons[0].message, /virtio-SYNTH-VDB-0002/);
  assert.doesNotMatch(result.reasons[0].message, /sr0/);
});

test('a choice selects among several disks and is recorded as a choice', () => {
  const many = secondEligibleDisk(facts());
  const { plan, reasons } = generate({ factsDocument: many, choices: { target_disk: 'virtio-SYNTH-VDB-0002' } });
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan.choices.target_disk, {
    value: 'virtio-SYNTH-VDB-0002', provenance: 'personal_preference', source: 'choice', editable: true,
  });
  assert.equal(plan.target.disk.path, '/dev/vdb');
  assert.equal(plan.hardware_selections.selections.some(entry => entry.id === 'target_disk'), false);
  const byPath = generate({ factsDocument: many, choices: { target_disk: '/dev/vdb' } });
  assert.equal(byPath.plan.choices.target_disk.value, 'virtio-SYNTH-VDB-0002');
});

test('ineligible and unknown disks are rejected with the eligible candidates', () => {
  const ineligible = generate({ choices: { target_disk: '/dev/sr0' } });
  assert.deepEqual(codes(ineligible), ['disk_ineligible']);
  assert.match(ineligible.reasons[0].message, /live_medium/);
  assert.match(ineligible.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  const unknown = generate({ choices: { target_disk: `${CANARY}-disk` } });
  assert.deepEqual(codes(unknown), ['disk_unknown']);
  assert.match(unknown.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  assert.doesNotMatch(JSON.stringify(unknown), new RegExp(CANARY));
});

test('a disk without by_id is accepted by path with a warning', () => {
  const noById = facts();
  delete noById.layers.detected.storage.disks[0].identity.by_id;
  const { plan, reasons } = generate({ factsDocument: noById });
  assert.deepEqual(reasons, []);
  assert.equal(plan.choices.target_disk.value, '/dev/vda');
  assert.deepEqual(plan.warnings.map(warning => warning.code), ['disk_without_by_id']);
  assert.deepEqual(validatePlan(plan, { facts: noById }), []);
});

test('a disk with neither by_id nor path is rejected', () => {
  const anonymous = facts();
  delete anonymous.layers.detected.storage.disks[0].identity.by_id;
  delete anonymous.layers.detected.storage.disks[0].identity.path;
  assert.deepEqual(codes(generate({ factsDocument: anonymous })), ['disk_unidentifiable']);
});

test('storage options show their tier and the experimental one warns', () => {
  const tiers = Object.fromEntries(STORAGE_OPTION_NAMES.map(name => {
    const { plan } = generate({ choices: { storage_option: name } });
    return [name, [plan.choices.storage_option.tier, plan.warnings.map(warning => warning.code)]];
  }));
  assert.deepEqual(tiers, {
    'ext4-systemd-boot': ['default', []],
    'btrfs-rescue': ['supported', []],
    'btrfs-limine': ['experimental', ['storage_option_experimental']],
  });
});

test('one shared account password names the root operation only when root password access is enabled', () => {
  const locked = generate().plan;
  assert.deepEqual(locked.secret_requirements.map(secret => secret.name), ['account_password']);
  assert.deepEqual(locked.secret_requirements[0].required_by, ['create_user']);
  const password = generate({ choices: { root_account: 'password' } }).plan;
  assert.deepEqual(password.secret_requirements.map(secret => secret.name), ['account_password']);
  assert.deepEqual(password.secret_requirements[0].required_by, ['create_user', 'configure_root_account']);
  for (const plan of [locked, password]) {
    const [secret] = plan.secret_requirements;
    assert.deepEqual(Object.keys(secret), ['name', 'purpose', 'required_by', 'channel', 'provenance']);
    assert.equal(secret.channel, 'protected_prompt');
    assert.equal(secret.provenance, 'technical_necessity');
    assert.doesNotMatch(JSON.stringify(plan), /root_password|user_password|"(password|hash)":/);
  }
});

test('a recognized profile is recorded with the observed machine and its definition binding', () => {
  const { plan } = generate();
  assert.deepEqual(plan.target.profile, { status: 'matched', profile_id: 'reference-vm' });
  assert.deepEqual(plan.target.machine, {
    architecture: 'x86_64',
    virtualization: 'kvm',
    dmi: { sys_vendor: 'QEMU', product_name: 'Standard PC (Q35 + ICH9, 2009)' },
  });
  assert.deepEqual(plan.target.machine, machineProjection(facts()));
  assert.equal(plan.policy_binding.profile_definition_sha256, referenceProfileDefinition().sha256);
  assert.deepEqual(plan.warnings.map(warning => warning.code), []);
});

test('an unqualified machine produces a plan bound to its observed identity, with no profile adjustments', () => {
  const unqualified = unqualifiedFacts();
  assert.deepEqual(unqualified.profile, { status: 'unqualified' });
  const { plan, reasons } = generate({ factsDocument: unqualified });
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan.target.profile, { status: 'unqualified' });
  assert.equal(plan.target.machine.dmi.sys_vendor, 'Synthetic Vendor');
  assert.equal(plan.policy_binding.profile_definition_sha256, undefined);
  assert.equal(plan.policy_binding.override_sha256, undefined);
  assert.equal(plan.choices.hostname.value, 'mirroros');
  assert.equal(plan.choices.hostname.source, 'policy');
  assert.deepEqual(plan.warnings.map(warning => warning.code), ['machine_unqualified']);
  assert.match(plan.warnings[0].message, /no known profile/);
  assert.match(plan.warnings[0].next_step, /no compatibility or support is promised/i);
  assert.deepEqual(validatePlan(plan, { facts: unqualified }), []);
});

test('the machine projection omits what was not observed and plans keep the field availability', () => {
  const sparse = facts();
  delete sparse.layers.detected.hardware.virtualization;
  delete sparse.layers.detected.firmware.dmi.product_name;
  const { plan } = generate({ factsDocument: sparse });
  assert.deepEqual(plan.target.machine, { architecture: 'x86_64', dmi: { sys_vendor: 'QEMU' } });
  assert.deepEqual(validatePlan(plan, { facts: sparse }), []);
  const none = facts();
  delete none.layers.detected.firmware.dmi;
  assert.equal(generate({ factsDocument: none }).plan.target.machine.dmi, undefined);
});

test('language, regional formats, and keyboard are independent and the formats follow the language by default', () => {
  const english = generate().plan;
  assert.equal(english.choices.regional_format.value, 'follow_language');
  assert.deepEqual(english.choices.locales.value, ['en_US.UTF-8']);
  const spanish = generate({ choices: { lang: 'es_ES.UTF-8' } }).plan;
  assert.deepEqual(spanish.choices.locales.value, ['es_ES.UTF-8']);
  assert.equal(spanish.choices.locale_categories.value.LC_TIME, 'es_ES.UTF-8');
  const mixed = generate({ choices: { lang: 'en_US.UTF-8', regional_format: 'es_ES.UTF-8', console_keymap: 'es' } }).plan;
  assert.deepEqual(mixed.choices.locales.value, ['en_US.UTF-8', 'es_ES.UTF-8']);
  assert.deepEqual(mixed.choices.locale_categories.value, {
    LANG: 'en_US.UTF-8',
    LC_TIME: 'es_ES.UTF-8',
    LC_NUMERIC: 'es_ES.UTF-8',
    LC_MONETARY: 'es_ES.UTF-8',
    LC_MEASUREMENT: 'es_ES.UTF-8',
  });
  assert.equal(mixed.choices.console_keymap.value, 'es');
  const explicitStays = generate({ choices: { regional_format: 'es_ES.UTF-8', lang: 'es_ES.UTF-8' } }).plan;
  assert.deepEqual(explicitStays.choices.locales.value, ['es_ES.UTF-8']);
  for (const plan of [english, spanish, mixed, explicitStays]) {
    assert.equal('LC_ALL' in plan.choices.locale_categories.value, false);
    for (const key of ['locales', 'locale_categories']) {
      assert.deepEqual(
        [plan.choices[key].provenance, plan.choices[key].source, plan.choices[key].editable],
        ['technical_necessity', 'policy', false],
      );
    }
    assert.deepEqual(validatePlan(plan, { facts: facts() }), []);
  }
});

test('an unchanged proposal keeps its provenance and source, and only a changed value becomes a choice', () => {
  const same = generate({ choices: { hostname: 'mirroros-ref', swapfile_size: 4096, target_disk: 'virtio-SYNTH-VDA-0001' } }).plan;
  assert.deepEqual(same, generate().plan);
  assert.equal(same.choices.hostname.source, 'override');
  assert.equal(same.choices.target_disk.source, 'detected');
  const changed = generate({ choices: { swapfile_size: 8192 } }).plan;
  assert.deepEqual(
    [changed.choices.swapfile_size.provenance, changed.choices.swapfile_size.source],
    ['personal_preference', 'choice'],
  );
});

test('identical inputs give an identical digest and no run-specific content', () => {
  const first = generate().plan;
  const second = generate().plan;
  assert.deepEqual(first, second);
  assert.equal(first.digest.value, second.digest.value);
  assert.doesNotMatch(JSON.stringify(first), /"(timestamp|generated_at|created_at)"/);
  assert.equal(first.run_id, undefined);
});

test('the digest binds the facts, the policy, the override, and the choices', () => {
  const base = generate().plan.digest.value;
  const changedFacts = facts();
  changedFacts.layers.detected.hardware.memory_total_bytes += 1;
  assert.notEqual(generate({ factsDocument: changedFacts }).plan.digest.value, base);
  const changedPolicy = structuredClone(policy);
  changedPolicy.sha256 = 'f'.repeat(64);
  assert.notEqual(generate({ policyOverride: changedPolicy }).plan.digest.value, base);
  assert.notEqual(generate({ override: { values: { hostname: 'other' }, sha256: referenceOverride().sha256 } }).plan.digest.value, base);
  assert.notEqual(generate({ override: { values: {} } }).plan.digest.value, base);
  assert.notEqual(generate({ choices: { hostname: 'edited' } }).plan.digest.value, base);
  const { plan } = generate();
  assert.equal(plan.facts_binding.run_id, facts().source.run_id);
  assert.equal(plan.facts_binding.dirty, false);
  assert.equal(plan.policy_binding.policy_sha256, policy.sha256);
  assert.equal(plan.policy_binding.override_sha256, referenceOverride().sha256);
  assert.equal(generate({ override: { values: {} } }).plan.policy_binding.override_sha256, undefined);
});

test('an edited regeneration is a new plan and leaves the original untouched', () => {
  const original = generate().plan;
  const snapshot = JSON.stringify(original);
  const edited = generate({ choices: { hostname: 'edited', storage_option: 'btrfs-rescue' } }).plan;
  assert.notEqual(edited.digest.value, original.digest.value);
  assert.equal(edited.choices.hostname.value, 'edited');
  assert.equal(edited.choices.hostname.source, 'choice');
  assert.equal(JSON.stringify(original), snapshot);
  for (const plan of [original, edited]) {
    assert.equal(plan.approved, undefined);
    assert.equal(plan.approval, undefined);
  }
});

test('choices that contradict the disk are input errors', () => {
  assert.deepEqual(codes(generate({ choices: { swapfile_size: 65536 } })), ['plan_size_does_not_fit']);
});

test('a generated plan that fails its own validator is an invariant violation', () => {
  const broken = structuredClone(policy);
  broken.policy.esp.value.size_bytes = 1.5;
  assert.throws(() => generate({ policyOverride: broken }), PlanContractError);
  const noOption = structuredClone(policy);
  noOption.storageOptions['ext4-systemd-boot'].tier = 'unlisted';
  assert.throws(() => generate({ policyOverride: noOption }), PlanContractError);
});

test('planted secrets never reach the plan', () => {
  const { plan } = generate({ choices: { root_account: 'password' } });
  assert.doesNotMatch(JSON.stringify(plan), new RegExp(CANARY));
  assert.deepEqual(generatePlan({ facts: facts(), policy, profileDefinition: referenceProfileDefinition() }).reasons, []);
});

test('facts that are missing, invalid, or of an unknown format exit as input errors', () => {
  const load = document => loadFacts(writeJson(scratch, `facts-${Math.random()}.json`, document));
  assert.deepEqual(codes(load(facts())), []);
  assert.deepEqual(codes(load('{not json')), ['facts_invalid']);
  assert.deepEqual(codes(loadFacts(`${scratch}/absent.json`)), ['facts_invalid']);
  assert.deepEqual(codes(load([])), ['facts_format_unknown']);
  assert.deepEqual(codes(load({ format_version: 1 })), ['facts_format_unknown']);
  assert.deepEqual(codes(load({ format_version: 3 })), ['facts_format_unknown']);
  const extra = facts();
  extra.layers.detected.firmware.product_serial = CANARY;
  const rejected = load(extra);
  assert.deepEqual(codes(rejected), ['facts_invalid']);
  const invalid = facts('bios');
  assert.equal(invalid.validation.status, 'invalid');
  const result = load(invalid);
  assert.deepEqual(codes(result), ['facts_invalid']);
  assert.match(result.reasons[0].message, /boot_mode_not_uefi/);
});
