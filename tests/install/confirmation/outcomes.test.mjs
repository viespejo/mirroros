import test from 'node:test';
import assert from 'node:assert/strict';
import {
  OUTCOMES,
  SIGINT,
  mapGumStatus,
  mapSignal,
  mapStageStatus,
  resultFor,
  standardReason,
  structuredReason,
} from '../../../install/confirmation/outcomes.mjs';

test('Gum statuses map per phase', () => {
  const table = [
    [0, 'menu', { action: 'proceed' }],
    [0, 'edit', { action: 'proceed' }],
    [1, 'menu', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [1, 'confirm', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [1, 'name', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [1, 'edit', { action: 'back' }],
    [1, 'step', { action: 'back' }],
    [1, 'review', { action: 'back' }],
    [1, 'password', { action: 'back' }],
    [1, 'pager', { action: 'back' }],
    [130, 'step', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'review', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'password', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'pager', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [2, 'step', { action: 'stop', exit_status: 5, outcome: 'failed' }],
    [130, 'menu', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'edit', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'confirm', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [130, 'name', { action: 'stop', exit_status: 3, outcome: 'cancelled' }],
    [2, 'menu', { action: 'stop', exit_status: 5, outcome: 'failed' }],
    [127, 'edit', { action: 'stop', exit_status: 5, outcome: 'failed' }],
  ];
  for (const [status, phase, expected] of table) {
    assert.deepEqual(mapGumStatus(status, phase), expected, `${status} in ${phase}`);
  }
});

test('Esc at an authorization prompt cancels and never goes back', () => {
  for (const phase of ['confirm', 'name']) {
    assert.deepEqual(mapGumStatus(1, phase), { action: 'stop', exit_status: 3, outcome: 'cancelled' }, phase);
  }
});

test('Gum 130 outside the interactive phase keeps its status', () => {
  assert.deepEqual(mapGumStatus(130, 'menu', { interactive: false }), { action: 'stop', exit_status: 130, outcome: null });
});

test('SIGINT cancels only inside the interactive phase', () => {
  assert.deepEqual(mapSignal(SIGINT, { interactive: true }), { action: 'stop', exit_status: 3, outcome: 'cancelled' });
  assert.deepEqual(mapSignal(SIGINT, { interactive: false }), { action: 'stop', exit_status: 130, outcome: null });
});

test('other signals keep 128+n in every phase', () => {
  for (const [signal, status] of [[1, 129], [15, 143]]) {
    for (const interactive of [true, false]) {
      assert.deepEqual(mapSignal(signal, { interactive }), { action: 'stop', exit_status: status, outcome: null });
    }
  }
});

test('stage statuses map to blocked, invalidated, or failed', () => {
  assert.deepEqual(mapStageStatus(0, { invalidating: false }), { action: 'proceed' });
  assert.deepEqual(mapStageStatus(2, { invalidating: false }), { action: 'stop', exit_status: 2, outcome: 'blocked' });
  assert.deepEqual(mapStageStatus(2, { invalidating: true }), { action: 'stop', exit_status: 2, outcome: 'invalidated' });
  assert.deepEqual(mapStageStatus(5, { invalidating: true }), { action: 'stop', exit_status: 5, outcome: 'failed' });
  assert.deepEqual(mapStageStatus(6, { invalidating: false }), { action: 'stop', exit_status: 6, outcome: 'failed' });
  assert.deepEqual(mapStageStatus(77, { invalidating: false }), { action: 'stop', exit_status: 5, outcome: 'failed' });
});

test('the outcome table matches the contract and allows 0 only for installed', () => {
  assert.deepEqual(Object.keys(OUTCOMES), ['installed', 'cancelled', 'invalidated', 'blocked', 'failed']);
  assert.deepEqual(OUTCOMES.installed, [0]);
  assert.deepEqual([OUTCOMES.cancelled, OUTCOMES.invalidated, OUTCOMES.blocked], [[3], [2], [2]]);
  assert.ok(!('approved' in OUTCOMES));
  // failed: 5, 6, and 128+n for a signal during the engine (129 to 255).
  assert.deepEqual(OUTCOMES.failed.slice(0, 3), [5, 6, 129]);
  assert.equal(OUTCOMES.failed.at(-1), 255);
  assert.ok(OUTCOMES.failed.includes(143) && !OUTCOMES.failed.includes(128));
  for (const [outcome, statuses] of Object.entries(OUTCOMES)) {
    if (outcome !== 'installed') assert.ok(!statuses.includes(0), outcome);
  }
});

test('resultFor defaults to the first exit and rejects a mismatch', () => {
  assert.deepEqual(resultFor('installed'), { exit_status: 0, outcome: 'installed', reasons: [] });
  assert.deepEqual(resultFor('failed', { exitStatus: 6 }).exit_status, 6);
  assert.deepEqual(resultFor('failed', { exitStatus: 143 }).exit_status, 143);
  assert.throws(() => resultFor('installed', { exitStatus: 2 }));
  assert.throws(() => resultFor('blocked', { exitStatus: 0 }));
  assert.throws(() => resultFor('cancelled', { exitStatus: 2 }));
  assert.throws(() => resultFor('approved'));
  assert.throws(() => resultFor('unknown'));
});

test('standard reasons exist for every codified case', () => {
  for (const code of ['confirmation_mismatch', 'engine_version_mismatch', 'gum_not_qualified', 'device_name_unavailable']) {
    const item = standardReason(code);
    assert.equal(item.code, code);
    assert.ok(item.message.length > 0 && item.next_step.length > 0);
  }
  assert.throws(() => standardReason('nope'));
  assert.throws(() => standardReason('engine_not_available'));
});

test('structured reasons use the architecture shape', () => {
  const shaped = structuredReason({ code: 'policy_changed', message: 'm', next_step: 'n' }, { operation: 'final_check' });
  assert.deepEqual(shaped, { code: 'policy_changed', stage: 'install', operation: 'final_check', message: 'm', next_step: 'n' });
  assert.equal(structuredReason({ code: 'c', message: 'm', next_step: 'n' }, { operation: 'discover', childExitStatus: 5 }).child_exit_status, 5);
});
