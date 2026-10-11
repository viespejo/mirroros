import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { PlanContractError } from '../../../install/plan/canonical-json.mjs';
import { renderPlan } from '../../../install/plan/render-plan.mjs';
import {
  PLAN_FILE,
  RUN_FILE,
  TEXT_FILE,
  defaultOutputDirectory,
  newRunId,
  outputExistsReason,
  outputHoldsPlan,
  rfc3339,
  writePlan,
  writeRejectedRun,
} from '../../../install/plan/write-plan.mjs';
import { CANARY, facts, generate, removeDirectory, temporaryDirectory } from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));

const mode = path => statSync(path).mode & 0o777;
const inputs = { facts: 'target-facts.json' };

function persist(directory, plan = generate().plan, runId = newRunId()) {
  return writePlan({ plan, facts: facts(), directory, runId, timestamp: rfc3339(), inputs });
}

test('a valid plan is written as JSON, text, and run metadata with private permissions', () => {
  const directory = join(scratch, 'nested', 'run-1');
  const { plan } = generate();
  const paths = persist(directory, plan, 'run-1');
  assert.deepEqual(readdirSync(directory).sort(), [PLAN_FILE, RUN_FILE, TEXT_FILE].sort());
  assert.equal(mode(directory), 0o700);
  assert.equal(mode(join(scratch, 'nested')), 0o700);
  for (const name of [PLAN_FILE, TEXT_FILE, RUN_FILE]) assert.equal(mode(join(directory, name)), 0o600, name);
  assert.deepEqual(JSON.parse(readFileSync(paths.plan, 'utf8')), plan);
  assert.equal(readFileSync(paths.text, 'utf8'), renderPlan(plan));
  const run = JSON.parse(readFileSync(paths.run, 'utf8'));
  assert.deepEqual(Object.keys(run), ['run_id', 'timestamp', 'inputs', 'digest', 'exit_status', 'reasons', 'warnings']);
  assert.equal(run.run_id, 'run-1');
  assert.equal(run.exit_status, 0);
  assert.deepEqual(run.digest, plan.digest);
  assert.match(run.timestamp, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
});

test('the signed plan file holds no timestamp or plan run id', () => {
  const directory = join(scratch, 'signed');
  const paths = persist(directory, generate().plan, 'run-signed');
  const text = readFileSync(paths.plan, 'utf8');
  assert.doesNotMatch(text, /run-signed|"timestamp"/);
});

test('no temporary files remain after a write', () => {
  const directory = join(scratch, 'clean');
  persist(directory);
  assert.deepEqual(readdirSync(directory).filter(name => name.endsWith('.tmp')), []);
});

test('an invalid plan is refused before anything is written', () => {
  const directory = join(scratch, 'invalid');
  const { plan } = generate();
  const edited = structuredClone(plan);
  edited.choices.hostname.value = 'edited-without-digest';
  assert.throws(() => persist(directory, edited), PlanContractError);
  assert.equal(existsSync(join(directory, PLAN_FILE)), false);
  assert.equal(existsSync(join(directory, TEXT_FILE)), false);
  assert.equal(existsSync(join(directory, RUN_FILE)), false);
  const unapproved = structuredClone(plan);
  unapproved.approved = true;
  assert.throws(() => persist(directory, unapproved), PlanContractError);
});

test('a plan that does not match the supplied facts is refused', () => {
  const directory = join(scratch, 'foreign');
  const other = facts();
  other.layers.detected.hardware.memory_total_bytes += 1;
  assert.throws(
    () => writePlan({ plan: generate().plan, facts: other, directory, runId: 'x', timestamp: rfc3339(), inputs }),
    PlanContractError,
  );
  assert.equal(existsSync(join(directory, PLAN_FILE)), false);
});

test('a rejected run writes only plan-run.json with the reasons and exit status 2', () => {
  const directory = join(scratch, 'rejected');
  const reasons = generate({ choices: { swapfile_size: 4097 } }).reasons;
  const path = writeRejectedRun({ directory, runId: 'run-rejected', timestamp: rfc3339(), inputs, exitStatus: 2, reasons });
  assert.deepEqual(readdirSync(directory), [RUN_FILE]);
  assert.equal(mode(directory), 0o700);
  assert.equal(mode(path), 0o600);
  const run = JSON.parse(readFileSync(path, 'utf8'));
  assert.equal(run.exit_status, 2);
  assert.equal(run.digest, undefined);
  assert.deepEqual(run.reasons.map(item => item.code), ['choices_invalid_value']);
  assert.deepEqual(run.reasons[0], reasons[0]);
});

test('an output directory that holds a plan is detected', () => {
  const directory = join(scratch, 'occupied');
  assert.equal(outputHoldsPlan(directory), false);
  writeRejectedRun({ directory, runId: 'r', timestamp: rfc3339(), inputs, exitStatus: 2, reasons: [] });
  assert.equal(outputHoldsPlan(directory), false);
  persist(directory);
  assert.equal(outputHoldsPlan(directory), true);
  assert.equal(outputExistsReason().code, 'output_exists');
});

test('regeneration with an edit is a new run that leaves the original byte-identical', () => {
  const first = join(scratch, 'regen', 'first');
  const second = join(scratch, 'regen', 'second');
  const original = persist(first);
  const before = { json: readFileSync(original.plan), text: readFileSync(original.text), run: readFileSync(original.run) };
  const edited = generate({ choices: { hostname: 'edited', storage_option: 'btrfs-rescue' } }).plan;
  const regenerated = persist(second, edited);
  assert.deepEqual(readFileSync(original.plan), before.json);
  assert.deepEqual(readFileSync(original.text), before.text);
  assert.deepEqual(readFileSync(original.run), before.run);
  const digests = [original.plan, regenerated.plan].map(path => JSON.parse(readFileSync(path, 'utf8')).digest.value);
  assert.notEqual(digests[0], digests[1]);
  assert.match(readFileSync(regenerated.text, 'utf8'), /hostname: edited/);
  assert.doesNotMatch(readFileSync(original.text, 'utf8'), /hostname: edited/);
});

test('a write into an unwritable directory fails without leaving a partial plan', () => {
  const directory = join(scratch, 'locked');
  persist(directory);
  const other = join(directory, 'inner');
  chmodSync(directory, 0o500);
  try {
    if (process.getuid?.() === 0) return;
    assert.throws(() => persist(other));
    assert.equal(existsSync(other), false);
  } finally {
    chmodSync(directory, 0o700);
  }
});

test('run ids and timestamps have the documented shape and are unique', () => {
  const ids = new Set([newRunId(), newRunId(), newRunId()]);
  assert.equal(ids.size, 3);
  for (const id of ids) assert.match(id, /^\d{8}T\d{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
  assert.equal(newRunId(new Date('2026-10-08T12:34:56.789Z'), 'u'), '20261008T123456Z-u');
  assert.equal(rfc3339(new Date('2026-10-08T12:34:56.789Z')), '2026-10-08T12:34:56Z');
  assert.equal(defaultOutputDirectory('abc'), join('evidence', 'install', 'abc'));
});

test('a planted canary never appears in any file of a run', () => {
  const directory = join(scratch, 'canary');
  persist(directory, generate({ choices: { root_account: 'password' } }).plan);
  for (const name of readdirSync(directory)) assert.doesNotMatch(readFileSync(join(directory, name), 'utf8'), new RegExp(CANARY), name);
});
