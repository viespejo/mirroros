import test from 'node:test';
import assert from 'node:assert/strict';
import { applyEdit, editableKeys, parseValue, startingChoices } from '../../../install/confirmation/edit-choices.mjs';
import { validateChoicesRecord } from '../../../install/confirmation/validate-records.mjs';
import { CANARY, generate } from './helpers.mjs';

test('the editable keys match the plan contract', () => {
  assert.deepEqual([...editableKeys()].sort(), [
    'console_keymap', 'hostname', 'lang', 'locales', 'root_account',
    'storage_option', 'swapfile_size', 'target_disk', 'timezone', 'user_name',
  ]);
});

test('a plan without explicit choices starts from an empty choices object', () => {
  assert.deepEqual(startingChoices(generate().plan), { format_version: 1 });
});

test('the starting choices are the entries with source choice', () => {
  const plan = generate({ choices: { hostname: 'laptop', swapfile_size: 8192, locales: ['en_US.UTF-8'], lang: 'en_US.UTF-8' } }).plan;
  assert.deepEqual(startingChoices(plan), {
    format_version: 1, swapfile_size: 8192, locales: ['en_US.UTF-8'], lang: 'en_US.UTF-8', hostname: 'laptop',
  });
});

test('edits accumulate and the last value of a key wins', () => {
  let choices = { format_version: 1 };
  for (const [key, value] of [['hostname', 'one'], ['swapfile_size', 2048], ['hostname', 'two']]) {
    const result = applyEdit(choices, key, value);
    assert.equal(result.reason, undefined);
    choices = result.choices;
  }
  assert.deepEqual(choices, { format_version: 1, hostname: 'two', swapfile_size: 2048 });
});

test('an edit never modifies its input', () => {
  const original = { format_version: 1, hostname: 'one' };
  const { choices } = applyEdit(original, 'hostname', 'two');
  assert.deepEqual(original, { format_version: 1, hostname: 'one' });
  assert.notEqual(choices, original);
});

test('secret-like keys are rejected', () => {
  for (const key of ['user_password', 'root_password', 'passphrase', 'api_token', 'secret']) {
    const result = applyEdit({ format_version: 1 }, key, CANARY);
    assert.equal(result.choices, undefined, key);
    assert.equal(result.reason.code, 'choices_secret_key');
    assert.ok(!JSON.stringify(result.reason).includes(CANARY));
  }
});

test('policy-fixed and unknown keys are rejected', () => {
  assert.equal(applyEdit({ format_version: 1 }, 'kernel', 'linux-lts').reason.code, 'choices_not_editable');
  assert.equal(applyEdit({ format_version: 1 }, 'packages', ['x']).reason.code, 'choices_not_editable');
  assert.equal(applyEdit({ format_version: 1 }, 'colour', 'blue').reason.code, 'choices_unknown_key');
});

test('widget text is parsed per key', () => {
  assert.equal(parseValue('swapfile_size', '4096'), 4096);
  assert.equal(parseValue('swapfile_size', '4 GiB'), '4 GiB');
  assert.equal(parseValue('swapfile_size', '1.5'), '1.5');
  assert.deepEqual(parseValue('locales', 'en_US.UTF-8\nes_ES.UTF-8\n'), ['en_US.UTF-8', 'es_ES.UTF-8']);
  assert.equal(parseValue('hostname', 'laptop'), 'laptop');
});

test('accumulated choices regenerate a plan with a new digest and keep earlier edits', () => {
  const first = generate().plan;
  const one = applyEdit(startingChoices(first), 'hostname', 'laptop').choices;
  const second = generate({ choices: { hostname: 'laptop' } }).plan;
  const two = applyEdit(startingChoices(second), 'swapfile_size', 8192).choices;
  const third = generate({ choices: { hostname: 'laptop', swapfile_size: 8192 } }).plan;
  assert.deepEqual(two, { format_version: 1, hostname: 'laptop', swapfile_size: 8192 });
  assert.notEqual(first.digest.value, second.digest.value);
  assert.notEqual(second.digest.value, third.digest.value);
  assert.equal(third.choices.hostname.value, 'laptop');
  assert.equal(one.hostname, 'laptop');
});

test('an invalid combination is rejected by the plan generator, not by the edit', () => {
  const edited = applyEdit({ format_version: 1 }, 'lang', 'fr_FR.UTF-8');
  assert.equal(edited.reason, undefined);
  assert.equal(generate({ choices: { lang: 'fr_FR.UTF-8' } }).plan, undefined);
});

test('a choices object with a secret-like key fails record validation', () => {
  assert.deepEqual(validateChoicesRecord({ format_version: 1, hostname: 'x' }), []);
  assert.ok(validateChoicesRecord({ format_version: 1, user_password: CANARY }).length > 0);
  assert.ok(validateChoicesRecord({ hostname: 'x' }).length > 0);
});
