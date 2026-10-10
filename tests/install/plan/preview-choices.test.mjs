import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { previewChoices, validateChoice } from '../../../install/plan/preview-choices.mjs';
import {
  CANARY,
  facts,
  generate,
  policy,
  referenceOverride,
  referenceRoot,
  removeDirectory,
  secondEligibleDisk,
  unqualifiedFacts,
} from './helpers.mjs';

const root = referenceRoot();
after(() => removeDirectory(root));

const EDITABLE_KEYS = [
  'storage_option', 'swapfile_size', 'lang', 'regional_format', 'console_keymap', 'timezone', 'hostname',
  'user_name', 'root_account', 'target_disk',
];

function preview({ factsDocument = facts(), choices = {}, override = referenceOverride() } = {}) {
  return previewChoices({ facts: factsDocument, policy, choices: { values: choices }, override });
}

function check(key, value, { factsDocument = facts(), choices = {} } = {}) {
  return validateChoice({
    facts: factsDocument,
    policy,
    choices: { values: choices },
    override: referenceOverride(),
    key,
    value,
    root,
  });
}

const codes = result => result.reasons.map(item => item.code);

test('the preview holds exactly the editable choices with their labels, and no derived or fixed value', () => {
  const { document, reasons } = preview();
  assert.equal(reasons, undefined);
  assert.equal(document.format_version, 2);
  assert.deepEqual(Object.keys(document.choices).sort(), [...EDITABLE_KEYS].sort());
  for (const entry of Object.values(document.choices)) {
    assert.deepEqual(Object.keys(entry), ['value', 'provenance', 'source', 'editable']);
    assert.equal(entry.editable, true);
  }
  assert.deepEqual(document.choices.hostname, {
    value: 'mirroros-ref', provenance: 'personal_preference', source: 'override', editable: true,
  });
  assert.deepEqual(document.choices.target_disk, {
    value: 'virtio-SYNTH-VDA-0001', provenance: 'hardware_detection', source: 'detected', editable: true,
  });
  assert.deepEqual(document.choices.regional_format.value, 'follow_language');
  assert.deepEqual(Object.keys(document), ['format_version', 'choices', 'options', 'derived', 'warnings']);
});

test('the preview lists the allowed values and the rule of each free-text key', () => {
  const { options } = preview().document;
  assert.deepEqual(options.target_disk, [{
    value: 'virtio-SYNTH-VDA-0001', path: '/dev/vda', size_bytes: 34359738368,
  }]);
  assert.deepEqual(options.storage_option.map(option => [option.value, option.tier, option.filesystem, option.bootloader]), [
    ['ext4-systemd-boot', 'default', 'ext4', 'systemd-boot'],
    ['btrfs-rescue', 'supported', 'btrfs', 'systemd-boot'],
    ['btrfs-limine', 'experimental', 'btrfs', 'limine'],
  ]);
  assert.deepEqual(options.swapfile_size, { minimum: 512, maximum: 65536, unit: 'MiB' });
  assert.deepEqual(options.lang, ['en_US.UTF-8', 'es_ES.UTF-8']);
  assert.deepEqual(options.regional_format, ['follow_language', 'en_US.UTF-8', 'es_ES.UTF-8']);
  assert.deepEqual(options.root_account, ['locked', 'password']);
  for (const key of ['hostname', 'user_name', 'timezone', 'console_keymap']) {
    assert.deepEqual(Object.keys(options[key]), ['rule'], key);
    assert.ok(options[key].rule.length > 0, key);
  }
  assert.doesNotMatch(JSON.stringify(options), /sr0|live_medium/);
});

test('the derived localization follows the previewed language and regional formats', () => {
  assert.deepEqual(preview().document.derived.locales, ['en_US.UTF-8']);
  const spanish = preview({ choices: { lang: 'es_ES.UTF-8' } }).document;
  assert.deepEqual(spanish.derived.locales, ['es_ES.UTF-8']);
  assert.equal(spanish.derived.locale_categories.LC_TIME, 'es_ES.UTF-8');
  assert.equal(spanish.choices.regional_format.source, 'policy');
  const mixed = preview({ choices: { lang: 'es_ES.UTF-8', regional_format: 'en_US.UTF-8' } }).document;
  assert.deepEqual(mixed.derived.locales, ['es_ES.UTF-8', 'en_US.UTF-8']);
  assert.equal(mixed.derived.locale_categories.LANG, 'es_ES.UTF-8');
  assert.equal(mixed.derived.locale_categories.LC_NUMERIC, 'en_US.UTF-8');
  assert.equal('LC_ALL' in mixed.derived.locale_categories, false);
  assert.deepEqual(mixed.choices.regional_format, {
    value: 'en_US.UTF-8', provenance: 'personal_preference', source: 'choice', editable: true,
  });
});

test('several eligible disks leave the selection pending instead of failing the preview', () => {
  const many = secondEligibleDisk(facts());
  const pending = preview({ factsDocument: many }).document;
  assert.equal('target_disk' in pending.choices, false);
  assert.deepEqual(pending.options.target_disk.map(option => option.value), ['virtio-SYNTH-VDA-0001', 'virtio-SYNTH-VDB-0002']);
  const chosen = preview({ factsDocument: many, choices: { target_disk: 'virtio-SYNTH-VDB-0002' } }).document;
  assert.deepEqual(chosen.choices.target_disk, {
    value: 'virtio-SYNTH-VDB-0002', provenance: 'personal_preference', source: 'choice', editable: true,
  });
});

test('an unknown or ineligible disk in the choices is reported, and so is an unidentifiable one', () => {
  assert.deepEqual(codes(preview({ choices: { target_disk: '/dev/sr0' } })), ['disk_ineligible']);
  assert.deepEqual(codes(preview({ choices: { target_disk: `${CANARY}-disk` } })), ['disk_unknown']);
  const anonymous = facts();
  delete anonymous.layers.detected.storage.disks[0].identity.by_id;
  delete anonymous.layers.detected.storage.disks[0].identity.path;
  assert.deepEqual(codes(preview({ factsDocument: anonymous })), ['disk_unidentifiable']);
});

test('warnings cover the unqualified machine, the experimental option, and a disk without by_id', () => {
  assert.deepEqual(preview().document.warnings, []);
  const unqualified = preview({ factsDocument: unqualifiedFacts() }).document;
  assert.deepEqual(unqualified.warnings.map(warning => warning.code), ['machine_unqualified']);
  assert.equal(unqualified.choices.hostname.value, 'mirroros');
  assert.equal(unqualified.choices.hostname.source, 'policy');
  const experimental = preview({ choices: { storage_option: 'btrfs-limine' } }).document;
  assert.deepEqual(experimental.warnings.map(warning => warning.code), ['storage_option_experimental']);
  const noById = facts();
  delete noById.layers.detected.storage.disks[0].identity.by_id;
  assert.deepEqual(preview({ factsDocument: noById }).document.warnings.map(warning => warning.code), ['disk_without_by_id']);
});

test('the preview is exactly what generation resolves for the same choices', () => {
  for (const choices of [
    {},
    { storage_option: 'btrfs-rescue', swapfile_size: 8192, hostname: 'laptop' },
    { lang: 'es_ES.UTF-8', regional_format: 'en_US.UTF-8', console_keymap: 'es', root_account: 'password' },
  ]) {
    const { document } = preview({ choices });
    const { plan } = generate({ choices });
    for (const [key, entry] of Object.entries(document.choices)) {
      const { value, provenance, source, editable } = plan.choices[key];
      assert.deepEqual(entry, { value, provenance, source, editable }, key);
    }
    assert.deepEqual(document.derived.locales, plan.choices.locales.value);
    assert.deepEqual(document.derived.locale_categories, plan.choices.locale_categories.value);
    assert.deepEqual(document.warnings, plan.warnings);
  }
});

test('previewing and validating change no input and need no plan', () => {
  const factsDocument = facts();
  const choices = { values: { hostname: 'laptop' } };
  const before = JSON.stringify({ factsDocument, choices, policy });
  previewChoices({ facts: factsDocument, policy, choices, override: referenceOverride() });
  validateChoice({ facts: factsDocument, policy, choices, override: referenceOverride(), key: 'lang', value: 'es_ES.UTF-8', root });
  assert.equal(JSON.stringify({ factsDocument, choices, policy }), before);
});

test('each editable key accepts a valid value and reports it', () => {
  const valid = {
    storage_option: 'btrfs-rescue',
    swapfile_size: '8192',
    lang: 'es_ES.UTF-8',
    regional_format: 'follow_language',
    console_keymap: 'dvorak',
    timezone: 'America/New_York',
    hostname: 'laptop.example.org',
    user_name: 'alice',
    root_account: 'password',
    target_disk: 'virtio-SYNTH-VDA-0001',
  };
  assert.deepEqual(Object.keys(valid).sort(), [...EDITABLE_KEYS].sort());
  for (const [key, value] of Object.entries(valid)) {
    const result = check(key, value);
    assert.equal(result.valid, true, key);
    assert.equal(result.key, key);
    assert.equal(result.value, key === 'swapfile_size' ? 8192 : value, key);
  }
  assert.equal(check('target_disk', '/dev/vda').valid, true);
});

test('invalid values are reported with the generation reasons and never echoed', () => {
  const invalid = {
    storage_option: 'zfs',
    swapfile_size: '100',
    lang: 'de_DE.UTF-8',
    regional_format: 'de_DE.UTF-8',
    console_keymap: 'nope',
    timezone: 'Mars/Base',
    hostname: '-bad',
    user_name: 'root',
    root_account: 'sudo',
    target_disk: '',
  };
  for (const [key, value] of Object.entries(invalid)) {
    const result = check(key, value);
    assert.equal(result.valid, false, key);
    assert.deepEqual(codes(result), ['choices_invalid_value'], key);
    assert.deepEqual(Object.keys(result), ['valid', 'reasons']);
  }
  for (const key of ['hostname', 'timezone', 'console_keymap', 'user_name', 'lang', 'storage_option']) {
    assert.doesNotMatch(JSON.stringify(check(key, `${CANARY}_x`)), new RegExp(CANARY), key);
  }
});

test('an integer value is parsed from its string and nothing else passes for one', () => {
  assert.equal(check('swapfile_size', '512').value, 512);
  assert.equal(check('swapfile_size', '65536').value, 65536);
  for (const value of ['511', '65537', '1e3', '4096.0', ' 4096', '+4096', '-1', 'abc', '', '99999999999999999999999']) {
    assert.deepEqual(codes(check('swapfile_size', value)), ['choices_invalid_value'], JSON.stringify(value));
  }
  assert.equal(check('hostname', '4096').valid, true);
});

test('secret-like, fixed, derived, and unknown keys are rejected before their value is read', () => {
  for (const key of ['password', 'account_password', 'root_password', 'passphrase', 'api_token', 'secret']) {
    const result = check(key, CANARY);
    assert.deepEqual(codes(result), ['choices_secret_key'], key);
    assert.doesNotMatch(JSON.stringify(result), new RegExp(CANARY));
  }
  for (const key of ['locales', 'locale_categories', 'kernel', 'packages', 'esp']) {
    assert.deepEqual(codes(check(key, 'x')), ['choices_not_editable'], key);
  }
  assert.deepEqual(codes(check('shell', 'zsh')), ['choices_unknown_key']);
});

test('a disk value is checked against the facts', () => {
  assert.deepEqual(codes(check('target_disk', '/dev/sr0')), ['disk_ineligible']);
  assert.deepEqual(codes(check('target_disk', 'virtio-OTHER')), ['disk_unknown']);
  const many = secondEligibleDisk(facts());
  assert.equal(check('target_disk', 'virtio-SYNTH-VDB-0002', { factsDocument: many }).valid, true);
});

test('validating the language or the regional formats reports the derived localization', () => {
  const language = check('lang', 'es_ES.UTF-8');
  assert.deepEqual(language.derived.locales, ['es_ES.UTF-8']);
  const withRegion = check('lang', 'es_ES.UTF-8', { choices: { regional_format: 'en_US.UTF-8' } });
  assert.deepEqual(withRegion.derived.locales, ['es_ES.UTF-8', 'en_US.UTF-8']);
  const region = check('regional_format', 'es_ES.UTF-8', { choices: { lang: 'en_US.UTF-8' } });
  assert.equal(region.derived.locale_categories.LANG, 'en_US.UTF-8');
  assert.equal(region.derived.locale_categories.LC_MONETARY, 'es_ES.UTF-8');
  assert.equal('derived' in check('hostname', 'laptop'), false);
});

test('a single value is validated without the complete combination', () => {
  assert.equal(check('swapfile_size', '65536').valid, true);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: 65536 } })), ['plan_size_does_not_fit']);
});
