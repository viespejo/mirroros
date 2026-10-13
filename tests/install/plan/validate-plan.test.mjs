import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256Canonical, withDigest } from '../../../install/plan/digest-plan.mjs';
import {
  isHostname,
  isUserName,
  operationSequence,
  parsePlanText,
  validatePlan,
} from '../../../install/plan/validate-plan.mjs';
import {
  allFixtures,
  buildValidPlan,
  fixtureFacts,
  INVALID_CASES,
  planFixturesRoot,
  ROOT_ACCOUNT_MODES,
  serializeFixture,
  STORAGE_OPTION_NAMES,
} from './build-fixtures.mjs';
import { discover } from '../discovery/helpers.mjs';
import { assets, generate, unqualifiedFacts } from './helpers.mjs';

const facts = fixtureFacts();
const codes = reasons => reasons.map(item => item.code);

function resigned(change, base = ['ext4-systemd-boot', 'locked']) {
  const plan = structuredClone(buildValidPlan(...base));
  change(plan);
  return withDigest(plan);
}

test('committed fixtures match what the builder produces', () => {
  const expected = allFixtures();
  for (const directory of ['valid', 'invalid']) {
    const onDisk = readdirSync(join(planFixturesRoot, directory)).map(name => `${directory}/${name}`).sort();
    const wanted = [...expected.keys()].filter(name => name.startsWith(`${directory}/`)).sort();
    assert.deepEqual(onDisk, wanted);
  }
  for (const [name, plan] of expected) {
    assert.equal(readFileSync(join(planFixturesRoot, name), 'utf8'), serializeFixture(plan), name);
  }
});

test('a valid plan is accepted for every storage option and root account mode', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      const text = readFileSync(join(planFixturesRoot, 'valid', `${storageOption}--${rootAccount}.json`), 'utf8');
      const { plan, reasons } = parsePlanText(text);
      assert.deepEqual(reasons, []);
      assert.deepEqual(validatePlan(plan, { facts, assets }), [], `${storageOption} ${rootAccount}`);
      assert.deepEqual(validatePlan(plan), [], `${storageOption} ${rootAccount} without facts`);
    }
    const disabled = JSON.parse(readFileSync(join(planFixturesRoot, 'valid', `${storageOption}--hibernation-disabled.json`), 'utf8'));
    assert.deepEqual(validatePlan(disabled, { facts, assets }), [], `${storageOption} hibernation disabled`);
    assert.deepEqual(validatePlan(disabled), [], `${storageOption} hibernation disabled without facts`);
  }
});

test('every invalid fixture is rejected with its own code', () => {
  assert.ok(INVALID_CASES.length >= 28);
  for (const name of readdirSync(join(planFixturesRoot, 'invalid'))) {
    const expected = name.split('--')[0];
    const plan = JSON.parse(readFileSync(join(planFixturesRoot, 'invalid', name), 'utf8'));
    const reasons = validatePlan(plan, { facts, assets });
    assert.ok(codes(reasons).includes(expected), `${name}: expected ${expected}, got ${codes(reasons).join(', ')}`);
  }
});

test('single-rule fixtures raise only their rule', () => {
  const only = {
    'plan_unknown_field--approved': ['plan_unknown_field'],
    'plan_unknown_field--approval': ['plan_unknown_field'],
    'lang_not_in_locales--lang': ['lang_not_in_locales'],
    'locale_derivation_mismatch--lc-all': ['locale_derivation_mismatch'],
    'locale_derivation_mismatch--formats': ['locale_derivation_mismatch'],
    'machine_identity_mismatch--architecture': ['machine_identity_mismatch'],
    'machine_identity_mismatch--memory': ['machine_identity_mismatch'],
    'plan_format_unsupported--version-2': ['plan_format_unsupported'],
    'plan_format_unsupported--version-3': ['plan_format_unsupported'],
    'hardware_rules_mismatch--outcome': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--package-added': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--package-editable': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--install-parameter': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--warning-missing': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--warning-added': ['hardware_rules_mismatch'],
    'hardware_rules_mismatch--rule-order': ['hardware_rules_mismatch'],
    'hibernation_plan_mismatch--disabled-with-size': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--disabled-with-swapfile': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--disabled-with-resume': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--disabled-with-swap-subvolume': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--disabled-with-offset-resolution': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--enabled-without-swapfile': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--enabled-without-size': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--size-above-memory-range': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--enabled-without-priority': ['hibernation_plan_mismatch'],
    'hibernation_plan_mismatch--enabled-without-swap-subvolume': ['hibernation_plan_mismatch'],
    'configuration_asset_mismatch--zram-priority': ['configuration_asset_mismatch'],
    'configuration_asset_mismatch--sysctl-value': ['configuration_asset_mismatch'],
    'configuration_asset_mismatch--missing-zram-operation': ['operations_storage_mismatch', 'configuration_asset_mismatch'],
    'configuration_asset_mismatch--missing-package': ['configuration_asset_mismatch'],
    'configuration_asset_mismatch--missing-zswap': ['configuration_asset_mismatch'],
    'configuration_asset_mismatch--source-hash': ['configuration_asset_mismatch'],
    'machine_identity_mismatch--dmi-availability': ['machine_identity_mismatch'],
    'profile_binding_mismatch--matched-without-hash': ['profile_binding_mismatch'],
    'profile_binding_mismatch--unqualified-with-id': ['profile_binding_mismatch'],
    'secret_consumer_mismatch--duplicated': ['secret_consumer_mismatch'],
    'root_account_secret_mismatch--password-undeclared': ['root_account_secret_mismatch'],
    'root_account_secret_mismatch--locked-declared': ['root_account_secret_mismatch'],
    'plan_size_does_not_fit--swapfile': ['plan_size_does_not_fit', 'disk_identity_mismatch'],
    'operation_order_invalid--swapped': ['operation_order_invalid'],
    'operations_storage_mismatch--option': ['operations_storage_mismatch'],
    'digest_mismatch--edited-content': ['digest_mismatch'],
    'destructive_without_target_disk--missing': ['destructive_without_target_disk'],
  };
  for (const [name, expected] of Object.entries(only)) {
    const plan = JSON.parse(readFileSync(join(planFixturesRoot, 'invalid', `${name}.json`), 'utf8'));
    assert.deepEqual([...new Set(codes(validatePlan(plan, { facts, assets })))], expected, name);
  }
});

test('every reason has a code, a message, and a next step', () => {
  for (const name of readdirSync(join(planFixturesRoot, 'invalid'))) {
    const plan = JSON.parse(readFileSync(join(planFixturesRoot, 'invalid', name), 'utf8'));
    for (const item of validatePlan(plan, { facts })) {
      assert.deepEqual(Object.keys(item), ['code', 'message', 'next_step'], name);
      assert.ok(item.message.length > 0 && item.next_step.length > 0, name);
    }
  }
});

test('approval can never be expressed, whatever its shape', () => {
  for (const field of ['approved', 'approval', 'approved_digest', 'confirmation']) {
    for (const value of [true, false, null, 'yes', { digest: 'x' }]) {
      const plan = resigned(candidate => { candidate[field] = value; });
      assert.ok(codes(validatePlan(plan, { facts })).includes('plan_unknown_field'), `${field}=${JSON.stringify(value)}`);
    }
  }
  const nested = resigned(candidate => { candidate.target.approved = true; });
  assert.ok(codes(validatePlan(nested, { facts })).includes('plan_unknown_field'));
});

test('non-objects, bad JSON, and unsupported versions are rejected', () => {
  for (const value of [null, [], 'plan', 3, true]) assert.deepEqual(codes(validatePlan(value)), ['plan_invalid_type']);
  assert.deepEqual(codes(parsePlanText('{not json').reasons), ['plan_not_json']);
  assert.deepEqual(codes(validatePlan({ format_version: 1 })), ['plan_format_unsupported']);
  assert.deepEqual(codes(validatePlan({ format_version: 2 })), ['plan_format_unsupported']);
  assert.deepEqual(codes(validatePlan({ format_version: 3 })), ['plan_format_unsupported']);
  assert.deepEqual(codes(validatePlan({})), ['plan_format_unsupported']);
});

test('an incomplete plan reports each missing section', () => {
  for (const section of ['target', 'choices', 'operations', 'secret_requirements', 'hardware_selections', 'warnings', 'facts_binding', 'policy_binding', 'digest']) {
    const plan = structuredClone(buildValidPlan('ext4-systemd-boot', 'locked'));
    delete plan[section];
    assert.ok(codes(validatePlan(plan)).includes('plan_field_missing'), section);
  }
});

test('labels, value types, and editability are enforced per choice', () => {
  const missingProvenance = resigned(plan => { delete plan.choices.timezone.provenance; });
  assert.ok(codes(validatePlan(missingProvenance)).includes('plan_label_missing'));
  const badSource = resigned(plan => { plan.choices.timezone.source = 'guess'; });
  assert.ok(codes(validatePlan(badSource)).includes('plan_invalid_type'));
  const fixedMadeEditable = resigned(plan => { plan.choices.kernel.editable = true; });
  assert.ok(codes(validatePlan(fixedMadeEditable)).includes('plan_invalid_type'));
  const badSwap = resigned(plan => { plan.choices.swapfile_size.value = 100; });
  assert.ok(codes(validatePlan(badSwap)).includes('plan_invalid_type'));
  const unknownChoice = resigned(plan => { plan.choices.shell_history = { value: 1 }; });
  assert.ok(codes(validatePlan(unknownChoice)).includes('plan_unknown_field'));
  const noTier = resigned(plan => { delete plan.choices.storage_option.tier; });
  assert.ok(codes(validatePlan(noTier)).includes('plan_field_missing'));
});

test('unknown fields are rejected in every section', () => {
  const mutations = [
    plan => { plan.target.extra = 1; },
    plan => { plan.target.disk.extra = 1; },
    plan => { plan.target.disk.current_layout.extra = 1; },
    plan => { plan.choices.hostname.extra = 1; },
    plan => { plan.hardware_selections.extra = 1; },
    plan => { plan.hardware_selections.selections[0].extra = 1; },
    plan => { plan.facts_binding.extra = 1; },
    plan => { plan.policy_binding.extra = 1; },
    plan => { plan.operations[3].resolved_at_apply[0].extra = 1; },
  ];
  for (const [index, mutation] of mutations.entries()) {
    assert.ok(codes(validatePlan(resigned(mutation))).includes('plan_unknown_field'), `mutation ${index}`);
  }
  const digestExtra = buildValidPlan('ext4-systemd-boot', 'locked');
  digestExtra.digest.extra = 1;
  assert.ok(codes(validatePlan(digestExtra)).includes('plan_unknown_field'));
});

test('secret entries allow only their five fields and values never appear', () => {
  for (const extra of ['value', 'hash', 'length', 'password']) {
    const plan = resigned(candidate => { candidate.secret_requirements[0][extra] = 'x'; });
    assert.ok(codes(validatePlan(plan)).includes('plan_secret_value_present'), extra);
  }
  for (const key of ['password', 'root_password', 'user_password', 'account_password', 'passphrase', 'api_token', 'secret']) {
    const plan = resigned(candidate => { candidate.operations[0].parameters[key] = 'x'; });
    assert.ok(codes(validatePlan(plan)).includes('plan_secret_value_present'), key);
  }
});

test('an installation plan of an earlier version is rejected with regeneration guidance and never migrated', () => {
  const earlier = structuredClone(buildValidPlan('ext4-systemd-boot', 'locked'));
  earlier.format_version = 1;
  const snapshot = JSON.stringify(earlier);
  const reasons = validatePlan(earlier, { facts });
  assert.deepEqual(codes(reasons), ['plan_format_unsupported']);
  assert.match(reasons[0].next_step, /not migrated/);
  assert.match(reasons[0].next_step, /regenerate/i);
  assert.match(reasons[0].next_step, /operations\/install plan/);
  assert.equal(JSON.stringify(earlier), snapshot);
});

test('the target holds the observed machine, the profile classification, and the disk, and no target id', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  assert.deepEqual(Object.keys(plan.target), ['machine', 'profile', 'disk']);
  for (const section of ['machine', 'profile']) {
    const missing = resigned(candidate => { delete candidate.target[section]; });
    assert.ok(codes(validatePlan(missing)).includes('plan_field_missing'), section);
  }
  const targetId = resigned(candidate => { candidate.target.target_id = 'reference-vm'; });
  assert.ok(codes(validatePlan(targetId)).includes('plan_unknown_field'));
  const bindingTarget = resigned(candidate => { candidate.facts_binding.target_id = 'reference-vm'; });
  assert.ok(codes(validatePlan(bindingTarget)).includes('plan_unknown_field'));
  const mutations = [
    candidate => { candidate.target.machine.serial = 'x'; },
    candidate => { candidate.target.machine.dmi.product_serial = 'x'; },
    candidate => { candidate.target.profile.compatibility = 'full'; },
  ];
  for (const [index, mutation] of mutations.entries()) {
    assert.ok(codes(validatePlan(resigned(mutation))).includes('plan_unknown_field'), `mutation ${index}`);
  }
  const emptyDmi = resigned(candidate => { candidate.target.machine.dmi = {}; });
  assert.ok(codes(validatePlan(emptyDmi)).includes('plan_invalid_type'));
  const badStatus = resigned(candidate => { candidate.target.profile.status = 'qualified'; });
  assert.ok(codes(validatePlan(badStatus)).includes('plan_invalid_type'));
});

test('a plan of an unqualified machine validates with and without its facts', () => {
  const unqualified = unqualifiedFacts();
  const { plan } = generate({ factsDocument: unqualified });
  assert.deepEqual(validatePlan(plan), []);
  assert.deepEqual(validatePlan(plan, { facts: unqualified }), []);
  const matchedFacts = discover('reference-vm-layout');
  assert.ok(codes(validatePlan(plan, { facts: matchedFacts })).includes('machine_identity_mismatch'));
  assert.ok(codes(validatePlan(plan, { facts: matchedFacts })).includes('profile_binding_mismatch'));
});

test('an unqualified plan cannot carry a profile id, a profile hash, or an override hash', () => {
  const { plan } = generate({ factsDocument: unqualifiedFacts() });
  const variants = [
    candidate => { candidate.target.profile.profile_id = 'reference-vm'; },
    candidate => { candidate.policy_binding.profile_definition_sha256 = 'a'.repeat(64); },
    candidate => { candidate.policy_binding.override_sha256 = 'a'.repeat(64); },
  ];
  for (const [index, mutation] of variants.entries()) {
    const candidate = withDigest((() => { const copy = structuredClone(plan); mutation(copy); return copy; })());
    assert.deepEqual([...new Set(codes(validatePlan(candidate)))], ['profile_binding_mismatch'], `variant ${index}`);
  }
});

test('the machine projection is compared field by field, including whether a field was observed', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  const variants = [
    candidate => { candidate.target.machine.virtualization = 'none'; },
    candidate => { delete candidate.target.machine.virtualization; },
    candidate => { candidate.target.machine.dmi.sys_vendor = 'Other'; },
    candidate => { delete candidate.target.machine.dmi.product_name; },
    candidate => { candidate.target.machine.memory_total_bytes += 1; },
  ];
  for (const [index, mutation] of variants.entries()) {
    const candidate = withDigest((() => { const copy = structuredClone(plan); mutation(copy); return copy; })());
    assert.ok(codes(validatePlan(candidate, { facts })).includes('machine_identity_mismatch'), `variant ${index}`);
  }
  const sparse = structuredClone(facts);
  delete sparse.layers.detected.hardware.virtualization;
  const rebound = resigned(candidate => { candidate.facts_binding.facts_sha256 = sha256Canonical(sparse); });
  assert.ok(codes(validatePlan(rebound, { facts: sparse })).includes('machine_identity_mismatch'));
});

test('locales and category values must be what the language and regional formats derive', () => {
  const variants = [
    candidate => { candidate.choices.locale_categories.value.LC_TIME = 'es_ES.UTF-8'; },
    candidate => { delete candidate.choices.locale_categories.value.LC_MEASUREMENT; },
    candidate => { candidate.choices.locale_categories.value.LC_ALL = 'en_US.UTF-8'; },
    candidate => { candidate.choices.locales.value = ['en_US.UTF-8', 'es_ES.UTF-8']; },
    candidate => { candidate.choices.regional_format.value = 'es_ES.UTF-8'; },
  ];
  for (const [index, mutation] of variants.entries()) {
    assert.ok(codes(validatePlan(resigned(mutation))).includes('locale_derivation_mismatch'), `variant ${index}`);
  }
  const derivedChange = resigned(candidate => {
    candidate.choices.lang.value = 'es_ES.UTF-8';
    candidate.choices.locales.value = ['es_ES.UTF-8'];
    candidate.choices.locale_categories.value = {
      LANG: 'es_ES.UTF-8',
      LC_TIME: 'es_ES.UTF-8',
      LC_NUMERIC: 'es_ES.UTF-8',
      LC_MONETARY: 'es_ES.UTF-8',
      LC_MEASUREMENT: 'es_ES.UTF-8',
    };
  });
  assert.deepEqual(validatePlan(derivedChange, { facts }), []);
  const editable = resigned(candidate => { candidate.choices.locales.editable = true; });
  assert.ok(codes(validatePlan(editable)).includes('plan_invalid_type'));
  const unsupported = resigned(candidate => { candidate.choices.lang.value = 'de_DE.UTF-8'; });
  assert.ok(codes(validatePlan(unsupported)).includes('plan_invalid_type'));
});

test('exactly one account_password requirement names its consumers from the root account mode', () => {
  for (const secret of ['user_password', 'root_password']) {
    const renamed = resigned(candidate => { candidate.secret_requirements[0].name = secret; });
    assert.ok(codes(validatePlan(renamed)).includes('plan_invalid_type'), secret);
  }
  const twoConsumers = resigned(candidate => { candidate.secret_requirements[0].required_by = ['create_user', 'create_user']; });
  assert.ok(codes(validatePlan(twoConsumers)).includes('secret_consumer_mismatch'));
  const rootOnly = resigned(candidate => { candidate.secret_requirements[0].required_by = ['configure_root_account']; }, ['ext4-systemd-boot', 'password']);
  assert.ok(codes(validatePlan(rootOnly)).includes('secret_consumer_mismatch'));
  const rootMissing = resigned(candidate => { candidate.secret_requirements[0].required_by = ['create_user']; }, ['ext4-systemd-boot', 'password']);
  assert.deepEqual([...new Set(codes(validatePlan(rootMissing)))], ['root_account_secret_mismatch']);
  const channel = resigned(candidate => { candidate.secret_requirements[0].channel = 'file'; });
  assert.ok(codes(validatePlan(channel)).includes('plan_invalid_type'));
});

test('operation sequences match the contract for each storage option', () => {
  assert.equal(operationSequence('ext4-systemd-boot').length, 17);
  assert.equal(operationSequence('ext4-systemd-boot', false).length, 16);
  assert.deepEqual(operationSequence('ext4-systemd-boot').slice(5, 10), [
    'install_packages', 'configure_zram', 'configure_memory_reclaim', 'generate_fstab', 'create_swapfile',
  ]);
  for (const option of STORAGE_OPTION_NAMES) {
    const enabled = operationSequence(option);
    assert.deepEqual(operationSequence(option, false), enabled.filter(kind => kind !== 'create_swapfile'));
  }
  assert.deepEqual(operationSequence('btrfs-rescue').slice(3, 6), ['format_filesystems', 'create_btrfs_subvolumes', 'mount_target']);
  const limine = operationSequence('btrfs-limine');
  assert.equal(limine.at(-1), 'sync_limine_snapshot_entries');
  assert.ok(limine.indexOf('install_limine_snapshot_tools') < limine.indexOf('configure_snapper'));
  assert.equal(operationSequence('zfs'), undefined);
  for (const option of STORAGE_OPTION_NAMES) {
    const plan = buildValidPlan(option, 'locked');
    assert.deepEqual(plan.operations.map(operation => operation.kind), operationSequence(option));
  }
});

test('a btrfs plan without its btrfs steps is a storage mismatch', () => {
  const plan = resigned(candidate => {
    candidate.operations = candidate.operations.filter(operation => operation.kind !== 'configure_snapper');
  }, ['btrfs-rescue', 'locked']);
  assert.ok(codes(validatePlan(plan)).includes('operations_storage_mismatch'));
});

test('the facts cross-check detects changed facts and ineligible disks', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  const changed = structuredClone(facts);
  changed.layers.detected.storage.disks[0].identity.model = 'OTHER';
  assert.ok(codes(validatePlan(plan, { facts: changed })).includes('facts_binding_mismatch'));

  const ineligible = structuredClone(facts);
  ineligible.layers.detected.storage.disks[0].eligible = false;
  ineligible.layers.detected.storage.disks[0].ineligible_reasons = ['mounted'];
  const rebound = resigned(candidate => { candidate.facts_binding.facts_sha256 = sha256Canonical(ineligible); });
  assert.ok(codes(validatePlan(rebound, { facts: ineligible })).includes('disk_not_eligible'));

  const missing = structuredClone(facts);
  missing.layers.detected.storage.disks = [];
  const rebound2 = resigned(candidate => { candidate.facts_binding.facts_sha256 = sha256Canonical(missing); });
  assert.ok(codes(validatePlan(rebound2, { facts: missing })).includes('disk_identity_mismatch'));
});

test('a disk addressed by path is valid when it has no by_id', () => {
  const noById = structuredClone(facts);
  delete noById.layers.detected.storage.disks[0].identity.by_id;
  const plan = resigned(candidate => {
    delete candidate.target.disk.by_id;
    candidate.choices.target_disk.value = '/dev/vda';
    candidate.facts_binding.facts_sha256 = sha256Canonical(noById);
  });
  assert.deepEqual(validatePlan(plan, { facts: noById }), []);
  const neither = resigned(candidate => { delete candidate.target.disk.by_id; delete candidate.target.disk.path; });
  assert.ok(codes(validatePlan(neither)).includes('plan_field_missing'));
});

test('the validator does not modify its input and does not touch the filesystem', () => {
  const plan = buildValidPlan('btrfs-limine', 'password');
  const before = JSON.stringify(plan);
  validatePlan(plan, { facts });
  assert.equal(JSON.stringify(plan), before);
  const source = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../../install/plan/validate-plan.mjs'), 'utf8');
  assert.doesNotMatch(source, /node:(fs|child_process|net|http)/);
});

test('hostname and user name rules', () => {
  for (const value of ['mirroros', 'mirroros-ref', 'a', 'host.example.org', 'A1']) assert.equal(isHostname(value), true, value);
  for (const value of ['', '-bad', 'bad-', 'bad_name', 'a..b', 'x'.repeat(65), 'has space', 3]) assert.equal(isHostname(value), false, String(value));
  for (const value of ['mirroros', '_svc', 'a-b_c', 'user$']) assert.equal(isUserName(value), true, value);
  for (const value of ['root', 'Upper', '1abc', '', 'a'.repeat(33), 'a b', 'a:b']) assert.equal(isUserName(value), false, value);
});
