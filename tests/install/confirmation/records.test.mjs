import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { RecordContractError, validateApprovalRecord, validateRunRecord } from '../../../install/confirmation/validate-records.mjs';
import {
  APPROVAL_RECORD_FILE,
  RUN_RECORD_FILE,
  buildApprovalRecord,
  buildRunRecord,
  writeApplyRecords,
  writeChoices,
} from '../../../install/confirmation/write-records.mjs';
import { CANARY, clone, recordFixture, removeDirectory, temporaryDirectory } from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));

const fixture = name => JSON.parse(readFileSync(recordFixture(name), 'utf8'));
const mode = path => statSync(path).mode & 0o777;
const secretKeyApproval = () => ({ ...fixture('valid-approval.json'), root_password: CANARY });

test('the valid fixtures pass', () => {
  assert.deepEqual(validateRunRecord(fixture('valid-run.json')), []);
  assert.deepEqual(validateApprovalRecord(fixture('valid-approval.json')), []);
});

test('unknown fields are rejected', () => {
  assert.ok(validateRunRecord(fixture('invalid-run-unknown-field.json')).some(item => item.includes('approved')));
  const approval = { ...fixture('valid-approval.json'), approved: true };
  assert.ok(validateApprovalRecord(approval).some(item => item.includes('approved')));
});

test('secret-like keys are rejected at any depth', () => {
  assert.ok(validateApprovalRecord(secretKeyApproval()).some(item => item.includes('secret-like')));
  const nested = fixture('valid-approval.json');
  nested.disk.user_password = CANARY;
  assert.ok(validateApprovalRecord(nested).some(item => item.includes('secret-like')));
  const run = fixture('valid-run.json');
  run.reasons[0].passphrase = CANARY;
  assert.ok(validateRunRecord(run).some(item => item.includes('secret-like')));
});

test('exit status must agree with the outcome and 0 is never valid', () => {
  assert.ok(validateRunRecord(fixture('invalid-run-exit-status.json')).length > 0);
  const table = { approved: 2, cancelled: 3, invalidated: 2, blocked: 2 };
  for (const [outcome, status] of Object.entries(table)) {
    const run = { ...fixture('valid-run.json'), outcome, exit_status: status };
    assert.deepEqual(validateRunRecord(run), [], outcome);
    assert.ok(validateRunRecord({ ...run, exit_status: status === 2 ? 3 : 2 }).length > 0, outcome);
  }
  for (const status of [5, 6]) {
    assert.deepEqual(validateRunRecord({ ...fixture('valid-run.json'), outcome: 'failed', exit_status: status }), []);
  }
});

test('required fields, formats, and the final digest are checked', () => {
  const run = fixture('valid-run.json');
  for (const key of ['run_id', 'timestamp', 'digests', 'exit_status', 'outcome', 'reasons', 'format_version']) {
    const copy = clone(run);
    delete copy[key];
    assert.ok(validateRunRecord(copy).length > 0, key);
  }
  assert.ok(validateRunRecord({ ...run, timestamp: 'yesterday' }).length > 0);
  assert.ok(validateRunRecord({ ...run, final_digest: 'a'.repeat(64) }).length > 0);
  assert.ok(validateRunRecord({ ...run, digests: ['xyz'] }).length > 0);
  const noFinal = clone(run);
  delete noFinal.final_digest;
  assert.ok(validateRunRecord(noFinal).length > 0);
  const badReason = clone(run);
  badReason.reasons[0].stage = 'build';
  assert.ok(validateRunRecord(badReason).length > 0);
});

test('a run without a plan has no digest and no disk', () => {
  const run = buildRunRecord({
    runId: 'r', timestamp: '2026-10-08T12:00:00Z', digests: [], exitStatus: 2, outcome: 'blocked', reasons: [],
  });
  assert.deepEqual(validateRunRecord(run), []);
  assert.ok(!('final_digest' in run) && !('target_id' in run));
  const approval = buildApprovalRecord({ runId: 'r', timestamp: '2026-10-08T12:00:00Z', outcome: 'blocked' });
  assert.deepEqual(validateApprovalRecord(approval), []);
  assert.deepEqual(Object.keys(approval), ['format_version', 'run_id', 'timestamp', 'outcome']);
});

test('the disk of an approval record needs an identifier and typed fields', () => {
  const approval = fixture('valid-approval.json');
  assert.ok(validateApprovalRecord({ ...approval, disk: { size_bytes: 1 } }).length > 0);
  assert.ok(validateApprovalRecord({ ...approval, disk: { path: '/dev/vda', size_bytes: 1.5 } }).length > 0);
  assert.ok(validateApprovalRecord({ ...approval, disk: { path: '/dev/vda', eligible: true } }).length > 0);
});

test('records are written with private permissions through validation', () => {
  const directory = join(scratch, 'run');
  const written = writeApplyRecords({ directory, run: fixture('valid-run.json'), approval: fixture('valid-approval.json') });
  assert.equal(mode(directory), 0o700);
  assert.equal(mode(written.run), 0o600);
  assert.equal(mode(written.approval), 0o600);
  assert.deepEqual(JSON.parse(readFileSync(join(directory, RUN_RECORD_FILE), 'utf8')), fixture('valid-run.json'));
  assert.deepEqual(readdirSync(directory).sort(), [APPROVAL_RECORD_FILE, RUN_RECORD_FILE].sort());
});

test('an invalid pair writes nothing', () => {
  const directory = join(scratch, 'rejected');
  assert.throws(
    () => writeApplyRecords({ directory, run: fixture('valid-run.json'), approval: secretKeyApproval() }),
    RecordContractError,
  );
  assert.ok(!existsSync(directory));
});

test('the canary never reaches disk through the records', () => {
  const directory = join(scratch, 'canary');
  const approval = { ...fixture('valid-approval.json'), reason: 'confirmation_mismatch' };
  writeApplyRecords({ directory, run: fixture('valid-run.json'), approval });
  assert.throws(() => writeApplyRecords({
    directory: join(scratch, 'canary-2'),
    run: { ...fixture('valid-run.json'), user_password: CANARY },
    approval,
  }), RecordContractError);
  assert.ok(!existsSync(join(scratch, 'canary-2')));
  for (const name of readdirSync(directory)) assert.ok(!readFileSync(join(directory, name), 'utf8').includes(CANARY));
});

test('choices files are written 0600 and reject secret keys', () => {
  const directory = join(scratch, 'plans', '01');
  const path = writeChoices(directory, { format_version: 1, hostname: 'laptop' });
  assert.equal(mode(path), 0o600);
  assert.throws(() => writeChoices(directory, { format_version: 1, user_password: CANARY }, 'bad.json'), RecordContractError);
  assert.ok(!existsSync(join(directory, 'bad.json')));
});
