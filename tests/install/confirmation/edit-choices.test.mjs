import test from 'node:test';
import assert from 'node:assert/strict';
import { CHOICES_FORMAT_VERSION, applyEdit, editableKeys, parseValue, startingChoices } from '../../../install/confirmation/edit-choices.mjs';
import { CHOICES_FORMAT_VERSION as PLAN_CHOICES_FORMAT_VERSION } from '../../../install/plan/validate-plan.mjs';
import { validateChoicesRecord } from '../../../install/confirmation/validate-records.mjs';
import { validateChoice } from '../../../install/plan/preview-choices.mjs';
import { CANARY, facts, generate, policy } from './helpers.mjs';

test('the editable keys match the plan contract', () => {
  assert.deepEqual([...editableKeys()].sort(), [
    'console_keymap', 'hibernation', 'hostname', 'lang', 'regional_format', 'root_account',
    'storage_option', 'swapfile_size', 'target_disk', 'timezone', 'user_name',
  ]);
});

test('the choices format version is the one of the plan component', () => {
  assert.equal(CHOICES_FORMAT_VERSION, PLAN_CHOICES_FORMAT_VERSION);
  assert.equal(CHOICES_FORMAT_VERSION, 3);
});

test('derived locales cannot be edited', () => {
  for (const key of ['locales', 'locale_categories']) {
    assert.equal(applyEdit({ format_version: 3 }, key, ['en_US.UTF-8']).reason.code, 'choices_not_editable', key);
  }
});

test('a plan without explicit choices starts from an empty choices object', () => {
  assert.deepEqual(startingChoices(generate().plan), { format_version: 3 });
});

test('the starting choices are the entries with source choice', () => {
  const plan = generate({ choices: { hostname: 'laptop', swapfile_size: 2048, regional_format: 'es_ES.UTF-8' } }).plan;
  assert.deepEqual(startingChoices(plan), {
    format_version: 3, swapfile_size: 2048, regional_format: 'es_ES.UTF-8', hostname: 'laptop',
  });
});

test('an unchanged proposal is not recorded as a choice and keeps its provenance', () => {
  const plan = generate({ choices: { lang: 'en_US.UTF-8', hostname: 'laptop' } }).plan;
  assert.deepEqual(startingChoices(plan), { format_version: 3, hostname: 'laptop' });
  assert.equal(plan.choices.lang.source, 'policy');
});

test('edits accumulate and the last value of a key wins', () => {
  let choices = { format_version: 3 };
  for (const [key, value] of [['hostname', 'one'], ['swapfile_size', 2048], ['hostname', 'two']]) {
    const result = applyEdit(choices, key, value);
    assert.equal(result.reason, undefined);
    choices = result.choices;
  }
  assert.deepEqual(choices, { format_version: 3, hostname: 'two', swapfile_size: 2048 });
});

test('an edit never modifies its input', () => {
  const original = { format_version: 3, hostname: 'one' };
  const { choices } = applyEdit(original, 'hostname', 'two');
  assert.deepEqual(original, { format_version: 3, hostname: 'one' });
  assert.notEqual(choices, original);
});

test('secret-like keys are rejected', () => {
  for (const key of ['user_password', 'root_password', 'passphrase', 'api_token', 'secret']) {
    const result = applyEdit({ format_version: 3 }, key, CANARY);
    assert.equal(result.choices, undefined, key);
    assert.equal(result.reason.code, 'choices_secret_key');
    assert.ok(!JSON.stringify(result.reason).includes(CANARY));
  }
});

test('policy-fixed and unknown keys are rejected', () => {
  assert.equal(applyEdit({ format_version: 3 }, 'kernel', 'linux-lts').reason.code, 'choices_not_editable');
  assert.equal(applyEdit({ format_version: 3 }, 'packages', ['x']).reason.code, 'choices_not_editable');
  assert.equal(applyEdit({ format_version: 3 }, 'colour', 'blue').reason.code, 'choices_unknown_key');
});

test('widget text is parsed per key', () => {
  assert.equal(parseValue('swapfile_size', '4096'), 4096);
  assert.equal(parseValue('swapfile_size', '4 GiB'), '4 GiB');
  assert.equal(parseValue('swapfile_size', '1.5'), '1.5');
  assert.equal(parseValue('hostname', 'laptop'), 'laptop');
  assert.equal(parseValue('hibernation', 'true'), true);
  assert.equal(parseValue('hibernation', 'false'), false);
  assert.equal(parseValue('hibernation', 'Enabled'), 'Enabled');
});

test('disabling hibernation removes the explicit size and re-enabling proposes the default again', () => {
  let choices = applyEdit({ format_version: 3 }, 'swapfile_size', 2048).choices;
  assert.deepEqual(choices, { format_version: 3, swapfile_size: 2048 });
  choices = applyEdit(choices, 'hibernation', false).choices;
  assert.deepEqual(choices, { format_version: 3, hibernation: false });
  assert.equal(generate({ choices: { hibernation: false } }).plan.choices.swapfile_size, undefined);
  choices = applyEdit(choices, 'hibernation', true).choices;
  assert.deepEqual(choices, { format_version: 3, hibernation: true });
  const { plan } = generate({ choices: { hibernation: true } });
  assert.deepEqual(plan.choices.swapfile_size, { value: 4096, provenance: 'hardware_detection', source: 'detected', editable: true });
  assert.deepEqual(startingChoices(plan), { format_version: 3 });
});

test('a swapfile size cannot be edited while hibernation is disabled', () => {
  const result = applyEdit({ format_version: 3, hibernation: false }, 'swapfile_size', 2048);
  assert.equal(result.choices, undefined);
  assert.equal(result.reason.code, 'choices_conflict');
  assert.equal(applyEdit({ format_version: 3, hibernation: true }, 'swapfile_size', 2048).reason, undefined);
});

test('the starting choices of a disabled plan hold the explicit hibernation choice and no size', () => {
  const plan = generate({ choices: { hibernation: false, hostname: 'laptop' } }).plan;
  assert.deepEqual(startingChoices(plan), { format_version: 3, hibernation: false, hostname: 'laptop' });
});

test('accumulated choices regenerate a plan with a new digest and keep earlier edits', () => {
  const first = generate().plan;
  const one = applyEdit(startingChoices(first), 'hostname', 'laptop').choices;
  const second = generate({ choices: { hostname: 'laptop' } }).plan;
  const two = applyEdit(startingChoices(second), 'swapfile_size', 2048).choices;
  const third = generate({ choices: { hostname: 'laptop', swapfile_size: 2048 } }).plan;
  assert.deepEqual(two, { format_version: 3, hostname: 'laptop', swapfile_size: 2048 });
  assert.notEqual(first.digest.value, second.digest.value);
  assert.notEqual(second.digest.value, third.digest.value);
  assert.equal(third.choices.hostname.value, 'laptop');
  assert.equal(one.hostname, 'laptop');
});

test('an invalid value is rejected by the plan component, not by the edit', () => {
  const edited = applyEdit({ format_version: 3 }, 'lang', 'fr_FR.UTF-8');
  assert.equal(edited.reason, undefined);
  const checked = validateChoice({ facts: facts(), policy, key: 'lang', value: 'fr_FR.UTF-8' });
  assert.equal(checked.valid, false);
  assert.equal(checked.reasons[0].code, 'choices_invalid_value');
});

test('a choices object with a secret-like key fails record validation', () => {
  assert.deepEqual(validateChoicesRecord({ format_version: 3, hostname: 'x' }), []);
  assert.ok(validateChoicesRecord({ format_version: 3, user_password: CANARY }).length > 0);
  assert.ok(validateChoicesRecord({ format_version: 1, hostname: 'x' }).length > 0);
  assert.ok(validateChoicesRecord({ hostname: 'x' }).length > 0);
});
