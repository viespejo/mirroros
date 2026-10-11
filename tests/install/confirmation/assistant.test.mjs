import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { previewChoices } from '../../../install/plan/preview-choices.mjs';
import {
  CANARY, facts, generate, policy, referenceOverride, removeDirectory, repository, temporaryDirectory, unqualifiedFacts, withMemory,
} from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));

const helper = join(repository, 'install/confirmation/assistant.mjs');
const run = (...args) => spawnSync('node', [helper, ...args], { encoding: 'utf8' });

function write(name, document) {
  const path = join(scratch, name);
  writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
  return path;
}

const rows = stdout => stdout.trimEnd().split('\n').map(line => line.split('\t'));

test('disks lists the eligible disks as key, label, and path, with the reference label format', () => {
  const result = run('disks', write('facts.json', facts()));
  assert.equal(result.status, 0, result.stderr);
  const [[identifier, label, path], ...others] = rows(result.stdout);
  assert.equal(others.length, 0);
  assert.equal(identifier, 'virtio-SYNTH-VDA-0001');
  assert.equal(path, '/dev/vda');
  assert.match(label, /^\/dev\/vda \(32G\) \[.+\]$/);
  assert.ok(!label.includes('\t') && !label.includes('\n'));
});

test('disks rejects a facts file that fails its validator with exit 2', () => {
  const result = run('disks', write('broken.json', { format_version: 2 }));
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Next step:/);
});

test('profile reports a match with its id and an unqualified machine without one', () => {
  assert.deepEqual(rows(run('profile', write('matched.json', facts())).stdout), [['matched', 'reference-vm']]);
  assert.equal(run('profile', write('unqualified.json', unqualifiedFacts())).stdout, 'unqualified\t\n');
});

test('review-values prints the plan values and the plan reference, and nothing secret-like', () => {
  const { plan } = generate();
  const result = run('review-values', write('plan.json', plan));
  assert.equal(result.status, 0, result.stderr);
  const values = Object.fromEntries(rows(result.stdout));
  assert.equal(values.machine, 'Recognized (reference-vm)');
  assert.equal(values.storage_option, plan.choices.storage_option.value);
  assert.equal(values.storage_tier, plan.choices.storage_option.tier);
  assert.equal(values.hibernation, 'true');
  assert.equal(values.hibernation_label, 'Enabled (swapfile 4096 MiB)');
  assert.equal(values.swapfile_below_ram, 'false');
  assert.equal('swapfile_size' in values, false);
  assert.equal(values.format_locale, plan.choices.locale_categories.value.LC_TIME);
  assert.equal(values.plan_reference, plan.digest.value.slice(0, 12));
  assert.ok(!/password|secret|token/i.test(result.stdout));
});

test('review-values labels an unqualified machine as experimental', () => {
  const { plan } = generate({ factsDocument: unqualifiedFacts() });
  const values = Object.fromEntries(rows(run('review-values', write('unqualified-plan.json', plan)).stdout));
  assert.equal(values.machine, 'Unqualified (experimental)');
});

test('get prints a scalar, JSON for an object, and nothing for an absent path', () => {
  const preview = previewChoices({ facts: facts(), policy, override: referenceOverride() }).document;
  const path = write('preview.json', preview);
  assert.equal(run('get', path, 'choices.swapfile_size.value').stdout, `${preview.choices.swapfile_size.value}\n`);
  assert.equal(run('get', path, 'options.swapfile_size.maximum').stdout, `${preview.options.swapfile_size.maximum}\n`);
  assert.deepEqual(JSON.parse(run('get', path, 'derived.locales').stdout), preview.derived.locales);
  const absent = run('get', path, 'choices.nothing.value');
  assert.equal(absent.status, 0);
  assert.equal(absent.stdout, '');
});

test('storage lists each storage option with its tier', () => {
  const preview = previewChoices({ facts: facts(), policy, override: referenceOverride() }).document;
  const listed = rows(run('storage', write('preview-storage.json', preview)).stdout);
  assert.deepEqual(listed, preview.options.storage_option.map(option => [option.value, option.tier]));
});

test('reasons-text prints message and next step for a list, a plan run, and a choice validation result', () => {
  const reasons = [{ code: 'x', message: 'First message', next_step: 'First step' }];
  assert.deepEqual(rows(run('reasons-text', write('list.json', reasons)).stdout), [['First message', 'First step']]);
  assert.deepEqual(rows(run('reasons-text', write('plan-run.json', { reasons })).stdout), [['First message', 'First step']]);
  assert.deepEqual(rows(run('reasons-text', write('validation.json', { valid: false, reasons })).stdout), [['First message', 'First step']]);
});

test('reasons-text turns control characters into spaces so a line stays one line', () => {
  const reasons = [{ code: 'x', message: 'bad\u001b[31m\nline', next_step: 'ok' }];
  const [[message]] = rows(run('reasons-text', write('control.json', reasons)).stdout);
  assert.ok(!/[\u0000-\u001f]/.test(message));
});

test('recoverable accepts only reasons the user can correct by fixing the network', () => {
  const network = ['network_no_default_route', 'network_dns_failed', 'network_https_failed'].map(code => ({ code, message: 'm', next_step: 'n' }));
  assert.equal(run('recoverable', write('network.json', network)).status, 0);
  assert.equal(run('recoverable', write('mixed.json', [...network, { code: 'disk_not_eligible', message: 'm', next_step: 'n' }])).status, 2);
  assert.equal(run('recoverable', write('empty.json', [])).status, 2);
  assert.equal(run('recoverable', write('facts-validation.json', { validation: { reasons: network } })).status, 0);
});

test('reason builds the flow-owned reasons with the original child status and the standard ones', () => {
  const failed = JSON.parse(run('reason', 'stage_failed', '77').stdout);
  assert.equal(failed.length, 1);
  assert.equal(failed[0].code, 'stage_failed');
  assert.equal(failed[0].child_exit_status, 77);
  for (const code of ['live_network_not_ready', 'live_clock_not_ready']) {
    const [item] = JSON.parse(run('reason', code).stdout);
    assert.equal(item.code, code);
    assert.ok(item.message && item.next_step);
    assert.ok(!('child_exit_status' in item));
  }
  assert.notEqual(JSON.parse(run('reason', 'live_network_not_ready').stdout)[0].message, JSON.parse(run('reason', 'live_clock_not_ready').stdout)[0].message);
  assert.equal(JSON.parse(run('reason', 'engine_not_available').stdout)[0].code, 'engine_not_available');
});

test('an unknown reason code or command fails with exit 6 and prints no secret', () => {
  const unknown = run('reason', `unknown_${CANARY}`);
  assert.equal(unknown.status, 6);
  assert.ok(!unknown.stdout.includes(CANARY) && !unknown.stderr.includes(CANARY));
  assert.equal(run('frobnicate').status, 6);
});

test('review-values reports disabled hibernation and a reduced size without a swapfile value', () => {
  const disabled = Object.fromEntries(rows(run('review-values', write('disabled-plan.json', generate({ choices: { hibernation: false } }).plan)).stdout));
  assert.equal(disabled.hibernation, 'false');
  assert.equal(disabled.hibernation_label, 'Disabled (no swapfile)');
  assert.equal(disabled.swapfile_below_ram, 'false');
  const reduced = Object.fromEntries(rows(run('review-values', write('reduced-plan.json', generate({ choices: { swapfile_size: 2048 } }).plan)).stdout));
  assert.equal(reduced.hibernation_label, 'Enabled (swapfile 2048 MiB)');
  assert.equal(reduced.swapfile_below_ram, 'true');
});

test('memory succeeds for facts with detected memory and blocks with repeated discovery guidance otherwise', () => {
  assert.equal(run('memory', write('with-memory.json', facts())).status, 0);
  const result = run('memory', write('without-memory.json', withMemory(facts(), undefined)));
  assert.equal(result.status, 2);
  const [reason] = JSON.parse(result.stdout);
  assert.equal(reason.code, 'memory_unavailable');
  assert.match(reason.next_step, /discover/);
  assert.equal(run('memory', write('broken-facts.json', { format_version: 2 })).status, 2);
});

test('has-warning exits 0 only when the preview or plan carries the warning code', () => {
  const reduced = previewChoices({ facts: facts(), policy, choices: { values: { swapfile_size: 2048 } }, override: referenceOverride() }).document;
  const exact = previewChoices({ facts: facts(), policy, override: referenceOverride() }).document;
  assert.equal(run('has-warning', write('warn-reduced.json', reduced), 'swapfile_below_ram').status, 0);
  assert.equal(run('has-warning', write('warn-exact.json', exact), 'swapfile_below_ram').status, 2);
  assert.equal(run('has-warning', write('warn-plan.json', generate({ choices: { swapfile_size: 2048 } }).plan), 'swapfile_below_ram').status, 0);
  assert.equal(run('has-warning', write('warn-plan-off.json', generate({ choices: { hibernation: false } }).plan), 'swapfile_below_ram').status, 2);
  assert.equal(run('has-warning', write('warn-none.json', { format_version: 3 }), 'swapfile_below_ram').status, 2);
});
