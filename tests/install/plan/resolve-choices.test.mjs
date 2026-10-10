import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { PlanContractError } from '../../../install/plan/canonical-json.mjs';
import {
  PlanUpstreamError,
  loadChoices,
  loadPlanOverride,
  loadPlanPolicy,
  loadProfileDefinition,
  resolveValues,
} from '../../../install/plan/resolve-choices.mjs';
import {
  CANARY,
  policy,
  policyPath,
  referenceRoot,
  removeDirectory,
  repository,
  targetsRoot,
  temporaryDirectory,
  writeJson,
} from './helpers.mjs';

const root = referenceRoot();
const scratch = temporaryDirectory();
after(() => {
  removeDirectory(root);
  removeDirectory(scratch);
});

const choose = (document, options = {}) => loadChoices(
  writeJson(scratch, `choices-${Math.random()}.json`, document),
  { policy: policy.policy, storageOptions: policy.storageOptions, root, ...options },
);
const codes = result => result.reasons.map(item => item.code);

test('the shipped policy loads with its tier table and a stable hash', () => {
  assert.equal(policy.document.format_version, 2);
  assert.equal(policy.policy.storage_option.value, 'ext4-systemd-boot');
  assert.equal(policy.policy.regional_format.value, 'follow_language');
  assert.equal('locales' in policy.policy, false);
  assert.deepEqual(
    Object.fromEntries(Object.entries(policy.storageOptions).map(([name, option]) => [name, option.tier])),
    { 'ext4-systemd-boot': 'default', 'btrfs-rescue': 'supported', 'btrfs-limine': 'experimental' },
  );
  assert.match(policy.sha256, /^[0-9a-f]{64}$/);
  assert.equal(loadPlanPolicy(policyPath).sha256, policy.sha256);
});

test('a damaged policy is a contract error', () => {
  const damaged = structuredClone(policy.document);
  damaged.policy.kernel.editable = true;
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-editable.json', damaged)), PlanContractError);
  const unknown = structuredClone(policy.document);
  unknown.policy.extra = { value: 1, provenance: 'personal_preference', editable: false };
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-unknown.json', unknown)), PlanContractError);
  const missing = structuredClone(policy.document);
  delete missing.policy.hostname;
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-missing.json', missing)), PlanContractError);
  const badDefault = structuredClone(policy.document);
  badDefault.policy.storage_option.value = 'zfs';
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-default.json', badDefault)), PlanContractError);
  assert.throws(() => loadPlanPolicy(join(scratch, 'absent.json')), PlanContractError);
});

test('a policy of an earlier format or with a derived key is a contract error', () => {
  const earlier = structuredClone(policy.document);
  earlier.format_version = 1;
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-v1.json', earlier)), PlanContractError);
  for (const key of ['locales', 'locale_categories']) {
    const derived = structuredClone(policy.document);
    derived.policy[key] = { value: ['en_US.UTF-8'], provenance: 'personal_preference', editable: true };
    assert.throws(() => loadPlanPolicy(writeJson(scratch, `policy-${key}.json`, derived)), PlanContractError, key);
  }
  const unsupportedLanguage = structuredClone(policy.document);
  unsupportedLanguage.policy.lang.value = 'de_DE.UTF-8';
  assert.throws(() => loadPlanPolicy(writeJson(scratch, 'policy-lang.json', unsupportedLanguage)), PlanContractError);
});

test('every allowed key is accepted with a valid value', () => {
  const document = {
    format_version: 2,
    target_disk: 'virtio-SYNTH-VDA-0001',
    storage_option: 'btrfs-rescue',
    swapfile_size: 8192,
    lang: 'es_ES.UTF-8',
    regional_format: 'en_US.UTF-8',
    console_keymap: 'dvorak',
    timezone: 'America/New_York',
    hostname: 'laptop.example.org',
    user_name: 'alice',
    root_account: 'password',
  };
  const result = choose(document);
  assert.deepEqual(result.reasons, []);
  const { format_version: _version, ...expected } = document;
  assert.deepEqual(result.values, expected);
});

test('all three storage options are accepted', () => {
  for (const option of ['ext4-systemd-boot', 'btrfs-rescue', 'btrfs-limine']) {
    assert.deepEqual(choose({ format_version: 2, storage_option: option }).reasons, [], option);
  }
});

test('unknown keys, fixed or derived keys, and secret-like keys are rejected without a value', () => {
  assert.deepEqual(codes(choose({ format_version: 2, shell: 'zsh' })), ['choices_unknown_key']);
  for (const key of ['kernel', 'packages', 'esp', 'firmware_mode', 'root_minimum_bytes', 'locales', 'locale_categories']) {
    assert.deepEqual(codes(choose({ format_version: 2, [key]: 'x' })), ['choices_not_editable'], key);
  }
  for (const key of ['password', 'root_password', 'user_password', 'account_password', 'passphrase', 'api_token', 'secret']) {
    const result = choose({ format_version: 2, [key]: CANARY });
    assert.deepEqual(codes(result), ['choices_secret_key'], key);
    assert.doesNotMatch(JSON.stringify(result), new RegExp(CANARY));
    assert.deepEqual(result.values, {});
  }
});

test('invalid values are rejected and never echoed', () => {
  const invalid = {
    storage_option: 'zfs',
    swapfile_size: 100,
    lang: 'xx_XX.UTF-8',
    regional_format: 'xx_XX.UTF-8',
    console_keymap: 'nope',
    timezone: 'Mars/Base',
    hostname: '-bad',
    user_name: 'root',
    root_account: 'sudo',
    target_disk: '',
  };
  for (const [key, value] of Object.entries(invalid)) {
    const result = choose({ format_version: 2, [key]: value });
    assert.deepEqual(codes(result), ['choices_invalid_value'], key);
    assert.deepEqual(result.values, {});
  }
  for (const value of [70000, 511, 1.5, '4096', null]) {
    assert.deepEqual(codes(choose({ format_version: 2, swapfile_size: value })), ['choices_invalid_value'], String(value));
  }
  for (const key of ['hostname', 'timezone', 'console_keymap', 'user_name']) {
    const result = choose({ format_version: 2, [key]: `${CANARY}_x` });
    assert.deepEqual(codes(result), ['choices_invalid_value'], key);
    assert.doesNotMatch(JSON.stringify(result), new RegExp(CANARY));
  }
});

test('only the two offered languages and regional formats are valid, even when the system supports more', () => {
  for (const key of ['lang', 'regional_format']) {
    assert.deepEqual(codes(choose({ format_version: 2, [key]: 'de_DE.UTF-8' })), ['choices_invalid_value'], key);
    assert.deepEqual(codes(choose({ format_version: 2, [key]: ['en_US.UTF-8'] })), ['choices_invalid_value'], key);
  }
  assert.deepEqual(choose({ format_version: 2, lang: 'es_ES.UTF-8', regional_format: 'follow_language' }).reasons, []);
  assert.deepEqual(codes(choose({ format_version: 2, lang: 'follow_language' })), ['choices_invalid_value']);
});

test('time zones cannot escape the zoneinfo directory or name a directory', () => {
  for (const zone of ['../../etc/passwd', 'Europe', 'Europe/', '/Europe/Madrid', 'Europe//Madrid', '']) {
    assert.deepEqual(codes(choose({ format_version: 2, timezone: zone })), ['choices_invalid_value'], zone);
  }
  assert.deepEqual(choose({ format_version: 2, timezone: 'UTC' }).reasons, []);
});

test('every problem of a file is reported at once', () => {
  const result = choose({ format_version: 2, shell: 'zsh', kernel: 'x', hostname: '-bad', user_password: CANARY });
  assert.deepEqual(codes(result).sort(), ['choices_invalid_value', 'choices_not_editable', 'choices_secret_key', 'choices_unknown_key']);
});

test('a malformed choices file is invalid, and a file of an earlier format is not migrated', () => {
  assert.deepEqual(codes(choose('{not json')), ['choices_invalid_format']);
  assert.deepEqual(codes(choose([])), ['choices_invalid_format']);
  assert.deepEqual(codes(choose({ hostname: 'x' })), ['choices_invalid_format']);
  assert.deepEqual(codes(choose({ format_version: 3 })), ['choices_invalid_format']);
  const earlier = choose({ format_version: 1, hostname: 'x' });
  assert.deepEqual(codes(earlier), ['choices_invalid_format']);
  assert.match(earlier.reasons[0].next_step, /not migrated/);
  assert.deepEqual(earlier.values, {});
  const absent = loadChoices(join(scratch, 'absent.json'), { policy: policy.policy, storageOptions: policy.storageOptions, root });
  assert.deepEqual(codes(absent), ['choices_invalid_format']);
});

test('missing reference data is an upstream failure, not a user error', () => {
  const empty = temporaryDirectory();
  try {
    assert.throws(() => choose({ format_version: 2, timezone: 'UTC' }, { root: empty }), PlanUpstreamError);
    assert.throws(() => choose({ format_version: 2, console_keymap: 'us' }, { root: empty }), PlanUpstreamError);
    assert.throws(() => choose({ format_version: 2, lang: 'en_US.UTF-8' }, { root: empty }), PlanUpstreamError);
    assert.throws(() => choose({ format_version: 2, regional_format: 'es_ES.UTF-8' }, { root: empty }), PlanUpstreamError);
    assert.deepEqual(choose({ format_version: 2, regional_format: 'follow_language' }, { root: empty }).reasons, []);
    assert.deepEqual(choose({ format_version: 2, swapfile_size: 2048 }, { root: empty }).reasons, []);
  } finally {
    removeDirectory(empty);
  }
});

test('the reference-vm override sets the hostname and hashes its content', () => {
  const override = loadPlanOverride(targetsRoot, 'reference-vm', { root });
  assert.deepEqual(override.values, { hostname: 'mirroros-ref' });
  assert.match(override.sha256, /^[0-9a-f]{64}$/);
});

test('targets without a plan override resolve to nothing', () => {
  assert.deepEqual(loadPlanOverride(targetsRoot, 'framework-13-pro-amd'), { values: {}, reasons: [] });
  assert.deepEqual(loadPlanOverride(targetsRoot, 'no-such-target'), { values: {}, reasons: [] });
  assert.deepEqual(loadPlanOverride(targetsRoot, '../escape'), { values: {}, reasons: [] });
});

test('an invalid override is rejected', () => {
  const targets = temporaryDirectory();
  try {
    const load = document => {
      writeJson(targets, 't/overrides/plan.json', document);
      return loadPlanOverride(targets, 't', { root });
    };
    assert.deepEqual(codes(load({ hostname: 'ok', timezone: 'UTC' })), ['override_unknown_key']);
    assert.deepEqual(codes(load({ hostname: '-bad' })), ['override_invalid_value']);
    assert.deepEqual(codes(load('{not json')), ['override_invalid_format']);
    assert.deepEqual(codes(load([])), ['override_invalid_format']);
    assert.deepEqual(load({ hostname: 'ok' }).values, { hostname: 'ok' });
  } finally {
    removeDirectory(targets);
  }
});

test('the profile definition is hashed by the canonical implementation', () => {
  const definition = loadProfileDefinition(targetsRoot, 'reference-vm');
  assert.deepEqual(definition.reasons, []);
  assert.match(definition.sha256, /^[0-9a-f]{64}$/);
  assert.equal(loadProfileDefinition(targetsRoot, 'reference-vm').sha256, definition.sha256);
  assert.notEqual(loadProfileDefinition(targetsRoot, 'framework-13-pro-amd').sha256, definition.sha256);
});

test('a matched profile that the checkout does not define is an input problem', () => {
  for (const id of ['no-such-target', '../escape', undefined]) {
    const result = loadProfileDefinition(targetsRoot, id);
    assert.deepEqual(codes(result), ['facts_invalid'], String(id));
    assert.equal(result.sha256, undefined);
  }
});

test('values resolve policy < detected < override < choice and record the source', () => {
  const base = resolveValues({ policy: policy.policy });
  assert.deepEqual(base.hostname, { value: 'mirroros', provenance: 'personal_preference', source: 'policy', editable: true });
  const overridden = resolveValues({ policy: policy.policy, override: { hostname: 'mirroros-ref' } });
  assert.equal(overridden.hostname.value, 'mirroros-ref');
  assert.equal(overridden.hostname.source, 'override');
  assert.equal(overridden.hostname.provenance, 'personal_preference');
  const chosen = resolveValues({ policy: policy.policy, override: { hostname: 'mirroros-ref' }, choices: { hostname: 'mine' } });
  assert.equal(chosen.hostname.value, 'mine');
  assert.equal(chosen.hostname.source, 'choice');
  const detected = { target_disk: { value: 'disk-a', provenance: 'hardware_detection', editable: true } };
  assert.equal(resolveValues({ policy: policy.policy, detected }).target_disk.source, 'detected');
  const picked = resolveValues({ policy: policy.policy, detected, choices: { target_disk: 'disk-b' } }).target_disk;
  assert.deepEqual(picked, { value: 'disk-b', provenance: 'personal_preference', source: 'choice', editable: true });
});

test('a choice equal to its proposal keeps the labels of that proposal', () => {
  const sameAsPolicy = resolveValues({ policy: policy.policy, choices: { hostname: 'mirroros', swapfile_size: 4096 } });
  assert.deepEqual(sameAsPolicy, resolveValues({ policy: policy.policy }));
  const sameAsOverride = resolveValues({ policy: policy.policy, override: { hostname: 'mirroros-ref' }, choices: { hostname: 'mirroros-ref' } });
  assert.equal(sameAsOverride.hostname.source, 'override');
  const detected = { target_disk: { value: 'disk-a', provenance: 'hardware_detection', editable: true } };
  const sameDisk = resolveValues({ policy: policy.policy, detected, choices: { target_disk: 'disk-a' } }).target_disk;
  assert.deepEqual(sameDisk, { value: 'disk-a', provenance: 'hardware_detection', source: 'detected', editable: true });
});

test('locales and category values are derived from the resolved language and regional format', () => {
  const english = resolveValues({ policy: policy.policy });
  assert.deepEqual(english.locales, { value: ['en_US.UTF-8'], provenance: 'technical_necessity', source: 'policy', editable: false });
  assert.equal(english.locale_categories.value.LC_MEASUREMENT, 'en_US.UTF-8');
  const followed = resolveValues({ policy: policy.policy, choices: { lang: 'es_ES.UTF-8' } });
  assert.deepEqual(followed.locales.value, ['es_ES.UTF-8']);
  assert.equal(followed.locale_categories.value.LC_NUMERIC, 'es_ES.UTF-8');
  const explicit = resolveValues({ policy: policy.policy, choices: { lang: 'es_ES.UTF-8', regional_format: 'en_US.UTF-8' } });
  assert.deepEqual(explicit.locales.value, ['es_ES.UTF-8', 'en_US.UTF-8']);
  assert.equal(explicit.locale_categories.value.LANG, 'es_ES.UTF-8');
  for (const category of ['LC_TIME', 'LC_NUMERIC', 'LC_MONETARY', 'LC_MEASUREMENT']) {
    assert.equal(explicit.locale_categories.value[category], 'en_US.UTF-8', category);
  }
  assert.equal('LC_ALL' in explicit.locale_categories.value, false);
});

test('resolution does not alias or mutate the policy', () => {
  const before = JSON.stringify(policy.policy);
  const resolved = resolveValues({ policy: policy.policy, choices: { lang: 'es_ES.UTF-8' } });
  resolved.packages.value.push('extra');
  assert.equal(JSON.stringify(policy.policy), before);
  assert.ok(repository.length > 0);
});
