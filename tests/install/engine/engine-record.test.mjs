import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  buildRun,
  buildState,
  operationsOf,
  parseOptions,
  validateRun,
  validateTiming,
  verifyPostconditions,
  validateState,
  writeAtomic,
} from '../../../install/engine/engine-record.mjs';
import { applicableChecks } from '../../../install/postconditions/evaluate.mjs';
import { engineRecordPath, planText, runNode } from './helpers.mjs';

const NOW = '2026-10-12T10:00:00Z';
const text = planText('valid', 'ext4-systemd-boot--password');
const PASSED = { format_version: 1, status: 'passed', checks: [{ id: 'kernel_installed', status: 'passed' }], failed_checks: [] };
const FAILED = {
  format_version: 1,
  status: 'failed',
  checks: [{ id: 'kernel_installed', status: 'failed', detail: '/boot/vmlinuz-linux is missing' }, { id: 'mounts_active', status: 'passed' }],
  failed_checks: ['kernel_installed'],
};

test('the state lists every operation with its status and the position of the current one', () => {
  const operations = operationsOf(text);
  const state = buildState({
    operations, status: 'running', current: 'create_partitions', completed: ['wipe_disk_signatures', 'create_partition_table'], now: NOW,
  });
  assert.deepEqual(validateState(state), []);
  assert.equal(state.index, 3);
  assert.equal(state.total, operations.length + 1);
  assert.deepEqual(state.operations.slice(0, 4).map(item => item.status), ['completed', 'completed', 'running', 'pending']);
  const final = buildState({ operations, status: 'installed', completed: operations.map(item => item.id), now: NOW });
  assert.equal(final.index, operations.length + 1);
  assert.equal(final.current, undefined);
});

test('configure state uses the final position and validates optional marker fields', () => {
  const operations = operationsOf(text);
  const state = buildState({ operations, status: 'running', current: 'configure', completed: operations.map(item => item.id),
    configureStep: 'system/session', configurePosition: '1/5', now: NOW });
  assert.deepEqual(validateState(state), []);
  assert.equal(state.index, operations.length + 1);
  assert.equal(state.configure_step, 'system/session');
  assert.equal(state.configure_position, '1/5');
  assert.notDeepEqual(validateState({ ...state, configure_step: 1 }), []);
  for (const position of [4, '0/5', '6/5', '1/x']) assert.notDeepEqual(validateState({ ...state, configure_position: position }), []);
});

test('not_configured requires a failed configure outcome, passed checks, and no pending operation', () => {
  const options = parseOptions(['--started', NOW, '--outcome', 'not_configured', '--exit', '4',
    '--completed', operationsOf(text).map(item => item.id).join(','), '--postconditions', JSON.stringify(PASSED),
    '--configure-outcome', '4', '--configure-failed-step', 'system/session', '--configure-evidence', '/var/log/mirroros/configure/run']);
  const run = buildRun({ planText: text, options, now: NOW });
  assert.deepEqual(validateRun(run), []);
  assert.equal(run.configure_outcome, 4);
  assert.equal(run.configure_failed_step, 'system/session');
  assert.equal(run.configure_evidence, '/var/log/mirroros/configure/run');
  for (const outcome of [2, 3, 4, 5, 6]) assert.deepEqual(validateRun({ ...run, configure_outcome: outcome }), []);
  for (const outcome of [undefined, 0, 1, 7, '4']) assert.notDeepEqual(validateRun({ ...run, configure_outcome: outcome }), []);
  for (const change of [{ exit_status: 5 }, { postconditions: FAILED }, { not_started: ['create_user'] },
    { configure_evidence: undefined }, { configure_failed_step: undefined }, { format_version: 2 }]) {
    assert.notDeepEqual(validateRun({ ...run, ...change }), []);
  }
  const installed = { ...run, outcome: 'installed', exit_status: 0, configure_outcome: 0 };
  assert.deepEqual(validateRun(installed), []);
  assert.notDeepEqual(validateRun({ ...installed, configure_outcome: undefined }), []);
  assert.notDeepEqual(validateRun({ ...installed, configure_outcome: 5 }), []);
});

test('new engine timing is validated and legacy format 3 remains unchanged', () => {
  const timing = { total: { status: 'available', duration_ms: 1000 }, intervals: [
    { id: 'prechecks', measurement: { status: 'available', duration_ms: 100 } },
    { id: 'cleanup', measurement: { status: 'unavailable', reason: 'clock_regressed' } },
  ] };
  const options = parseOptions(['--started', NOW, '--outcome', 'failed', '--exit', '5', '--timing', JSON.stringify(timing)]);
  const run = buildRun({ planText: '', options, now: NOW });
  assert.equal(run.format_version, 4);
  assert.deepEqual(run.timing, timing);
  assert.deepEqual(validateRun(run), []);
  assert.notDeepEqual(validateRun({ ...run, timing: undefined }), []);
  const { timing: _timing, ...legacy } = run;
  legacy.format_version = 3;
  const before = JSON.stringify(legacy);
  assert.deepEqual(validateRun(legacy), []);
  assert.equal(JSON.stringify(legacy), before);
  assert.equal('timing' in legacy, false);
  assert.notDeepEqual(validateRun({ ...legacy, timing }), []);
  for (const total of [null, { status: 'available', duration_ms: -10 }, { status: 'available', duration_ms: 1 },
    { status: 'unavailable', reason: 'clock_malformed', duration_ms: 0 }, { status: 'unavailable', reason: 'private input' }]) {
    assert.notDeepEqual(validateTiming({ ...timing, total }), []);
  }
  for (const intervals of [[null], [...timing.intervals, ...timing.intervals],
    [{ id: '../unsafe input', measurement: timing.total }], [{ id: 'cleanup', measurement: timing.total, extra: true }]]) {
    assert.notDeepEqual(validateTiming({ ...timing, intervals }), []);
  }
});

test('the package count is recorded only when given', () => {
  const operations = operationsOf(text);
  const base = { operations, status: 'running', current: 'install_packages', completed: [], now: NOW };
  assert.equal('packages_installed' in buildState(base), false);
  assert.equal(buildState({ ...base, packages: 42 }).packages_installed, 42);
});

test('a failed run keeps the original status, the child command, and the completed and not started operations', () => {
  const options = parseOptions([
    '--started', NOW, '--outcome', 'failed', '--exit', '5', '--digest', 'd'.repeat(64),
    '--commit', 'a'.repeat(40), '--dirty', 'false',
    '--completed', 'wipe_disk_signatures,create_partition_table', '--failed-operation', 'create_partitions',
    '--failed-arg', 'sfdisk', '--failed-arg', '/dev/vda', '--child-status', '7',
    '--reason-code', 'stage_failed', '--reason-operation', 'create_partitions', '--reason-message', 'failed', '--reason-next-step', 'retry',
  ]);
  const run = buildRun({ planText: text, options, now: NOW });
  assert.deepEqual(validateRun(run), []);
  assert.deepEqual(run.failed_operation, { id: 'create_partitions', command: ['sfdisk', '/dev/vda'], child_exit_status: 7 });
  assert.equal(run.reasons[0].child_exit_status, 7);
  assert.equal(run.completed.length, 2);
  assert.equal(run.not_started.length, 17 - 3);
  assert.equal(run.not_started.includes('create_partitions'), false);
  assert.equal(run.storage_option, 'ext4-systemd-boot');
});

test('resolved values, mirrors, constants, and cleanup results are recorded', () => {
  const options = parseOptions([
    '--started', NOW, '--outcome', 'installed', '--exit', '0', '--completed', '',
    '--resolved', 'root_uuid=1111', '--resolved', 'resume_offset=12345',
    '--server', 'Server = https://example.invalid/$repo', '--mirrorlist-sha256', 'e'.repeat(64),
    '--constant', 'configure_snapper.NUMBER_LIMIT=10', '--cleanup', 'umount=ok',
  ]);
  const run = buildRun({ planText: '', options, now: NOW });
  assert.deepEqual(run.resolved, { root_uuid: '1111', resume_offset: 12345 });
  assert.deepEqual(run.mirrors.servers, ['Server = https://example.invalid/$repo']);
  assert.deepEqual(run.constants, { configure_snapper: { NUMBER_LIMIT: '10' } });
  assert.deepEqual(run.cleanup, { umount: 'ok' });
});

test('a run is never valid as installed with a reason, a pending operation, or a non-zero status', () => {
  const installed = { format_version: 3, started_at: NOW, finished_at: NOW, outcome: 'installed', exit_status: 0, reasons: [], completed: [], not_started: [], postconditions: PASSED, configure_outcome: 0 };
  assert.deepEqual(validateRun(installed), []);
  assert.notDeepEqual(validateRun({ ...installed, postconditions: undefined }), []);
  assert.notDeepEqual(validateRun({ ...installed, postconditions: FAILED }), []);
  assert.notDeepEqual(validateRun({ ...installed, format_version: 1 }), []);
  assert.notDeepEqual(validateRun({ ...installed, not_started: ['x'] }), []);
  assert.notDeepEqual(validateRun({ ...installed, exit_status: 5 }), []);
  assert.notDeepEqual(validateRun({ ...installed, outcome: 'failed', exit_status: 0 }), []);
  assert.notDeepEqual(validateRun({ ...installed, outcome: 'unknown' }), []);
});

test('a document with a secret-looking field is never written', () => {
  const directory = mkdtempSync(join(tmpdir(), 'engine-record-'));
  try {
    const run = { format_version: 3, started_at: NOW, finished_at: NOW, outcome: 'failed', exit_status: 5, reasons: [], completed: [], not_started: [], account_password: 'x' };
    assert.throws(() => writeAtomic(join(directory, 'engine-run.json'), run, validateRun), /secret/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('the command line writes both records atomically with private permissions', () => {
  const directory = mkdtempSync(join(tmpdir(), 'engine-record-'));
  try {
    const output = join(directory, 'engine');
    const state = runNode(engineRecordPath, ['state', '--output', output, '--status', 'running', '--current', 'create_partitions', '--completed', 'wipe_disk_signatures,create_partition_table'], text);
    assert.equal(state.status, 0, state.stderr);
    const run = runNode(engineRecordPath, ['run', '--output', output, '--started', NOW, '--outcome', 'blocked', '--exit', '2',
      '--reason-code', 'live_keyring_not_ready', '--reason-message', 'not ready', '--reason-next-step', 'wait', '--completed', ''], text);
    assert.equal(run.status, 0, run.stderr);
    for (const [name, mode] of [['state.json', 0o600], ['engine-run.json', 0o600]]) {
      assert.equal(statSync(join(output, name)).mode & 0o777, mode);
    }
    assert.equal(statSync(output).mode & 0o777, 0o700);
    assert.equal(JSON.parse(readFileSync(join(output, 'engine-run.json'), 'utf8')).reasons[0].code, 'live_keyring_not_ready');
    const bad = runNode(engineRecordPath, ['run', '--output', output, '--started', NOW, '--outcome', 'installed', '--exit', '5'], text);
    assert.equal(bad.status, 6);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('the postconditions phase leaves one final configure unit in the total', () => {
  const operations = operationsOf(text);
  const state = buildState({ operations, status: 'running', current: 'postconditions', completed: operations.map(item => item.id), now: NOW });
  assert.deepEqual(validateState(state), []);
  assert.equal(state.current, 'postconditions');
  assert.equal(state.index, state.total - 1);
  assert.ok(state.operations.every(item => item.status === 'completed'));
  assert.equal(state.format_version, 3);
  assert.deepEqual(validateState(buildState({ operations, status: 'not_verified', completed: operations.map(item => item.id), now: NOW })), []);
});

test('a not_verified run exits 4 with one postcondition_failed reason per failed check and the stored result', () => {
  const operations = operationsOf(text).map(item => item.id);
  const result = {
    format_version: 1,
    status: 'failed',
    checks: [
      { id: 'kernel_installed', status: 'failed', detail: '/boot/vmlinuz-linux is missing' },
      { id: 'mounts_active', status: 'passed' },
      { id: 'zram_configuration', status: 'failed', detail: 'the zram drop-in lacks "zram-size = ram"' },
    ],
    failed_checks: ['kernel_installed', 'zram_configuration'],
  };
  const options = parseOptions([
    '--started', NOW, '--outcome', 'not_verified', '--exit', '4', '--completed', operations.join(','), '--postconditions', JSON.stringify(result),
  ]);
  const run = buildRun({ planText: text, options, now: NOW });
  assert.deepEqual(validateRun(run), []);
  assert.deepEqual(run.postconditions, result);
  assert.deepEqual(run.reasons.map(item => item.code), ['postcondition_failed', 'postcondition_failed']);
  assert.deepEqual(run.reasons.map(item => item.operation), ['postconditions', 'postconditions']);
  assert.match(run.reasons[0].message, /kernel_installed.*vmlinuz-linux is missing/);
  assert.match(run.reasons[1].message, /zram_configuration/);
  assert.deepEqual(run.not_started, []);
  assert.notDeepEqual(validateRun({ ...run, exit_status: 5 }), []);
  assert.notDeepEqual(validateRun({ ...run, outcome: 'failed' }), []);
  assert.notDeepEqual(validateRun({ ...run, reasons: [] }), []);
  assert.notDeepEqual(validateRun({ ...run, postconditions: PASSED }), []);
  assert.notDeepEqual(validateRun({ ...run, not_started: ['configure_zram'] }), []);
});

test('exit 4 belongs to not_verified alone and a stored result must itself be valid', () => {
  const failed = { format_version: 3, started_at: NOW, finished_at: NOW, outcome: 'failed', exit_status: 4, reasons: [], completed: [], not_started: [] };
  assert.notDeepEqual(validateRun(failed), []);
  const installed = { ...failed, outcome: 'installed', exit_status: 0, postconditions: { ...PASSED, checks: [{ id: 'unknown_check', status: 'passed' }] } };
  assert.notDeepEqual(validateRun(installed), []);
  assert.notDeepEqual(validateRun({ ...installed, postconditions: { ...PASSED, checks: [{ id: 'kernel_installed', status: 'passed', detail: 'x' }] } }), []);
});

test('verifyPostconditions accepts only a result that is valid for the plan and agrees with the checker status', () => {
  const plan = JSON.parse(text);
  const checks = applicableChecks(plan).map(id => ({ id, status: 'passed' }));
  const passed = { format_version: 1, status: 'passed', checks, failed_checks: [] };
  const failed = {
    format_version: 1,
    status: 'failed',
    checks: checks.map((check, index) => (index === 0 ? { ...check, status: 'failed', detail: 'missing' } : check)),
    failed_checks: [checks[0].id],
  };
  assert.equal(verifyPostconditions({ planText: text, result: JSON.stringify(passed), exit: '0' }), 'valid:');
  assert.equal(verifyPostconditions({ planText: text, result: JSON.stringify(failed), exit: '4' }), `valid:${checks[0].id}`);
  assert.equal(verifyPostconditions({ planText: text, result: JSON.stringify(passed), exit: '4' }), 'invalid');
  assert.equal(verifyPostconditions({ planText: text, result: JSON.stringify(failed), exit: '0' }), 'invalid');
  assert.equal(verifyPostconditions({ planText: text, result: JSON.stringify({ ...passed, checks: checks.slice(1) }), exit: '0' }), 'invalid');
  assert.equal(verifyPostconditions({ planText: text, result: 'not json', exit: '0' }), 'invalid');
  assert.equal(verifyPostconditions({ planText: text, result: undefined, exit: '0' }), 'invalid');
});

test('the command line verifies a postconditions result without an output directory', () => {
  const plan = JSON.parse(text);
  const checks = applicableChecks(plan).map(id => ({ id, status: 'passed' }));
  const passed = { format_version: 1, status: 'passed', checks, failed_checks: [] };
  const verdict = runNode(engineRecordPath, ['verify-postconditions', '--result', JSON.stringify(passed), '--exit', '0'], text);
  assert.equal(verdict.status, 0, verdict.stderr);
  assert.equal(verdict.stdout, 'valid:');
});
