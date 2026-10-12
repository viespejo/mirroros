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
  validateState,
  writeAtomic,
} from '../../../install/engine/engine-record.mjs';
import { engineRecordPath, planText, runNode } from './helpers.mjs';

const NOW = '2026-10-12T10:00:00Z';
const text = planText('valid', 'ext4-systemd-boot--password');

test('the state lists every operation with its status and the position of the current one', () => {
  const operations = operationsOf(text);
  const state = buildState({
    operations, status: 'running', current: 'create_partitions', completed: ['wipe_disk_signatures', 'create_partition_table'], now: NOW,
  });
  assert.deepEqual(validateState(state), []);
  assert.equal(state.index, 3);
  assert.equal(state.total, operations.length);
  assert.deepEqual(state.operations.slice(0, 4).map(item => item.status), ['completed', 'completed', 'running', 'pending']);
  const final = buildState({ operations, status: 'installed', completed: operations.map(item => item.id), now: NOW });
  assert.equal(final.index, operations.length);
  assert.equal(final.current, undefined);
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
  const installed = { format_version: 1, started_at: NOW, finished_at: NOW, outcome: 'installed', exit_status: 0, reasons: [], completed: [], not_started: [] };
  assert.deepEqual(validateRun(installed), []);
  assert.notDeepEqual(validateRun({ ...installed, not_started: ['x'] }), []);
  assert.notDeepEqual(validateRun({ ...installed, exit_status: 5 }), []);
  assert.notDeepEqual(validateRun({ ...installed, outcome: 'failed', exit_status: 0 }), []);
  assert.notDeepEqual(validateRun({ ...installed, outcome: 'unknown' }), []);
});

test('a document with a secret-looking field is never written', () => {
  const directory = mkdtempSync(join(tmpdir(), 'engine-record-'));
  try {
    const run = { format_version: 1, started_at: NOW, finished_at: NOW, outcome: 'failed', exit_status: 5, reasons: [], completed: [], not_started: [], account_password: 'x' };
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
