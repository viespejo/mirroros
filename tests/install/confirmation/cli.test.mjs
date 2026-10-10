import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { validateApprovalRecord, validateRunRecord } from '../../../install/confirmation/validate-records.mjs';
import {
  CANARY, clone, facts, generate, removeDirectory, repository, temporaryDirectory, unqualifiedFacts, withDisk,
} from './helpers.mjs';

const scratch = temporaryDirectory();
after(() => removeDirectory(scratch));

const cli = join(repository, 'install/confirmation/cli.mjs');
const run = (...args) => spawnSync('node', [cli, ...args], { encoding: 'utf8' });
const mode = path => statSync(path).mode & 0o777;

function write(name, document) {
  const path = join(scratch, name);
  writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
  return path;
}

const plan = generate().plan;
const planPath = write('plan.json', plan);
const factsPath = write('facts.json', facts());

test('compare passes when nothing changed', () => {
  const result = run('compare', repository, planPath, factsPath, factsPath);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), []);
});

test('compare passes an unqualified machine that is still unqualified', () => {
  const unqualified = generate({ factsDocument: unqualifiedFacts() }).plan;
  const result = run(
    'compare', repository, write('unqualified-plan.json', unqualified), write('unqualified-facts.json', unqualifiedFacts()),
  );
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), []);
});

test('compare reports a recognized machine that is no longer recognized', () => {
  const result = run('compare', repository, planPath, write('now-unqualified.json', unqualifiedFacts()));
  assert.equal(result.status, 2);
  const codes = JSON.parse(result.stdout).map(item => item.code);
  assert.ok(codes.includes('profile_binding_changed') && codes.includes('machine_identity_changed'), codes.join());
});

test('compare reports a machine that changed its identity', () => {
  const changed = clone(facts());
  changed.layers.detected.firmware.dmi.sys_vendor = 'Other Vendor';
  const result = run('compare', repository, planPath, write('changed-vendor.json', changed));
  assert.equal(result.status, 2);
  assert.ok(JSON.parse(result.stdout).some(item => item.code === 'machine_identity_changed'));
});

test('compare reports a layout change with exit 2 and the next step', () => {
  const changed = write('changed.json', withDisk(facts(), disk => {
    disk.layout.partitions = [];
  }));
  const result = run('compare', repository, planPath, changed);
  assert.equal(result.status, 2);
  assert.equal(JSON.parse(result.stdout)[0].code, 'target_layout_changed');
  assert.match(result.stderr, /Next step: Regenerate and review the installation plan\./);
});

test('compare passes the validator code for a tampered plan', () => {
  const tampered = clone(plan);
  tampered.choices.hostname.value = 'tampered';
  const result = run('compare', repository, write('tampered.json', tampered), factsPath);
  assert.equal(result.status, 2);
  assert.ok(JSON.parse(result.stdout).some(item => item.code === 'digest_mismatch'));
});

test('compare and review give every invalidating reason the same next step', () => {
  const tampered = write('tampered-next-step.json', (() => {
    const copy = clone(plan);
    copy.choices.hostname.value = 'tampered';
    return copy;
  })());
  for (const result of [run('compare', repository, tampered, factsPath), run('review', 'markdown', tampered)]) {
    assert.equal(result.status, 2);
    for (const item of JSON.parse(result.stdout)) assert.equal(item.next_step, 'Regenerate and review the installation plan.');
  }
});

test('compare reports an unreadable plan and invalid facts', () => {
  assert.equal(JSON.parse(run('compare', repository, join(scratch, 'missing.json'), factsPath).stdout)[0].code, 'plan_not_json');
  const earlier = write('earlier-facts.json', { format_version: 1 });
  assert.equal(JSON.parse(run('compare', repository, planPath, earlier).stdout)[0].code, 'facts_format_unknown');
  const invalid = write('invalid-facts.json', { format_version: 2 });
  assert.equal(JSON.parse(run('compare', repository, planPath, invalid).stdout)[0].code, 'facts_invalid');
});

test('review prints the fields the orchestrator needs', () => {
  const compact = run('review', 'compact', planPath).stdout.trimEnd().split('\n').map(line => line.split('\t'));
  assert.deepEqual(compact[0], ['Machine', 'Recognized (reference-vm)']);
  assert.deepEqual(compact.at(-1), ['Plan reference', plan.digest.value.slice(0, 12)]);
  assert.match(run('review', 'confirmation', planPath).stdout, /^Disk: \/dev\/vda 32\.0 GiB\n[\s\S]*Plan reference: [0-9a-f]{12}\n$/);
  assert.match(run('review', 'complete', planPath).stdout, /^MirrorOS installation plan \(format 2\)\n[\s\S]*Plan reference: [0-9a-f]{12} /);
  assert.equal(run('review', 'machine', planPath).stdout, 'Recognized (reference-vm)\n');
  assert.equal(run('review', 'device-name', planPath).stdout, 'vda\n');
  assert.equal(run('review', 'digest-prefix', planPath).stdout, `${plan.digest.value.slice(0, 12)}\n`);
  assert.match(run('review', 'prompt', planPath).stdout, /^Erase \/dev\/vda 32\.0 GiB and apply plan [0-9a-f]{12}\?\n$/);
});

test('review refuses an invalid plan and an unknown field', () => {
  const tampered = clone(plan);
  tampered.approved = true;
  const result = run('review', 'compact', write('approved.json', tampered));
  assert.equal(result.status, 2);
  assert.ok(JSON.parse(result.stdout).some(item => item.code === 'plan_unknown_field'));
  assert.equal(run('review', 'nonsense', planPath).status, 6);
});

test('edit start and set write accumulating private choices files', () => {
  const first = join(scratch, 'choices-1.json');
  const second = join(scratch, 'choices-2.json');
  assert.equal(run('edit', 'start', planPath, first).status, 0);
  assert.equal(run('edit', 'set', first, 'hostname', 'laptop', second).status, 0);
  const third = join(scratch, 'choices-3.json');
  assert.equal(run('edit', 'set', second, 'regional_format', 'es_ES.UTF-8', third).status, 0);
  assert.deepEqual(JSON.parse(readFileSync(third, 'utf8')), {
    format_version: 2, hostname: 'laptop', regional_format: 'es_ES.UTF-8',
  });
  assert.equal(mode(third), 0o600);
});

test('edit set rejects a derived locale list without writing', () => {
  const out = join(scratch, 'derived-out.json');
  const result = run('edit', 'set', join(scratch, 'choices-1.json'), 'locales', 'en_US.UTF-8', out);
  assert.equal(result.status, 2);
  assert.equal(JSON.parse(result.stdout)[0].code, 'choices_not_editable');
  assert.throws(() => readFileSync(out));
});

test('edit set rejects a secret key without writing', () => {
  const out = join(scratch, 'secret-out.json');
  const result = run('edit', 'set', join(scratch, 'choices-1.json'), 'user_password', CANARY, out);
  assert.equal(result.status, 2);
  assert.ok(!result.stdout.includes(CANARY) && !result.stderr.includes(CANARY));
  assert.throws(() => readFileSync(out));
});

test('options list eligible disks and storage tiers', () => {
  assert.equal(run('options', 'disks', factsPath).stdout, 'virtio-SYNTH-VDA-0001 (32.0 GiB)\n');
  const storage = run('options', 'storage', repository).stdout.trim().split('\n');
  assert.deepEqual(storage, ['ext4-systemd-boot (default)', 'btrfs-rescue (supported)', 'btrfs-limine (experimental)']);
});

test('reasons prints standard reasons and extracts them from run files', () => {
  assert.equal(JSON.parse(run('reasons', 'standard', 'engine_not_available').stdout)[0].code, 'engine_not_available');
  const planRun = write('plan-run.json', { reasons: [{ code: 'disk_unknown', message: 'm', next_step: 'n' }] });
  assert.equal(JSON.parse(run('reasons', 'plan-run', planRun).stdout)[0].code, 'disk_unknown');
  const bad = write('facts-invalid.json', { validation: { reasons: [{ code: 'target_identity_mismatch', message: 'm', next_step: 'n' }] } });
  assert.equal(JSON.parse(run('reasons', 'facts', bad).stdout)[0].code, 'target_identity_mismatch');
});

test('record writes both records from the run directory', () => {
  const directory = join(scratch, 'record-run');
  mkdirSync(join(directory, 'plans', '01'), { recursive: true });
  mkdirSync(join(directory, 'plans', '02'), { recursive: true });
  mkdirSync(join(directory, 'discovery', 'initial'), { recursive: true });
  const second = generate({ choices: { hostname: 'laptop' } }).plan;
  writeFileSync(join(directory, 'plans', '01', 'installation-plan.json'), JSON.stringify(plan));
  writeFileSync(join(directory, 'plans', '02', 'installation-plan.json'), JSON.stringify(second));
  writeFileSync(join(directory, 'discovery', 'initial', 'target-facts.json'), JSON.stringify(facts()));
  const reasons = write('reasons.json', JSON.parse(run('reasons', 'standard', 'confirmation_mismatch').stdout));
  const result = run(
    'record', directory, 'run-1', '2026-10-08T12:00:00Z', 'guided', 'gum version 2.0.2', '3', 'cancelled', 'confirm', reasons,
    'preparation,discovery_initial,plan,review,confirmation',
  );
  assert.equal(result.status, 0, result.stderr);
  const runRecord = JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8'));
  const approval = JSON.parse(readFileSync(join(directory, 'approval-record.json'), 'utf8'));
  assert.deepEqual(validateRunRecord(runRecord), []);
  assert.deepEqual(validateApprovalRecord(approval), []);
  assert.equal(runRecord.format_version, 2);
  assert.equal(runRecord.entry, 'guided');
  assert.deepEqual(runRecord.stages, ['preparation', 'discovery_initial', 'plan', 'review', 'confirmation']);
  assert.deepEqual(runRecord.machine, plan.target.machine);
  assert.deepEqual(runRecord.profile, { status: 'matched', profile_id: 'reference-vm' });
  assert.deepEqual(approval.machine, runRecord.machine);
  assert.deepEqual(approval.profile, runRecord.profile);
  assert.deepEqual(runRecord.digests, [plan.digest.value, second.digest.value]);
  assert.equal(runRecord.final_digest, second.digest.value);
  assert.equal(runRecord.reasons[0].operation, 'confirm');
  assert.equal(approval.reason, 'confirmation_mismatch');
  assert.equal(approval.disk.path, '/dev/vda');
  assert.ok(!('eligible' in approval.disk) && !('current_layout' in approval.disk) && !('target_id' in approval));
  for (const name of readdirSync(directory)) if (!statSync(join(directory, name)).isDirectory()) assert.equal(mode(join(directory, name)), 0o600);
  assert.ok(!existsSync(join(directory, 'apply-run.json')));
});

test('record takes the machine and profile of the last plan when no facts were kept', () => {
  const directory = join(scratch, 'record-plan-only');
  mkdirSync(join(directory, 'plans', '01'), { recursive: true });
  const unqualified = generate({ factsDocument: unqualifiedFacts() }).plan;
  writeFileSync(join(directory, 'plans', '01', 'installation-plan.json'), JSON.stringify(unqualified));
  const result = run('record', directory, 'run-4', '2026-10-08T12:00:00Z', 'plan_file', '', '2', 'invalidated', 'final_check', '', 'plan');
  assert.equal(result.status, 0, result.stderr);
  const runRecord = JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8'));
  assert.deepEqual(runRecord.profile, { status: 'unqualified' });
  assert.deepEqual(runRecord.machine, unqualified.target.machine);
  assert.equal(runRecord.entry, 'plan_file');
});

test('record without a plan or Gum writes a blocked pair', () => {
  const directory = join(scratch, 'record-blocked');
  const result = run('record', directory, 'run-2', '2026-10-08T12:00:00Z', 'guided', '', '6', 'failed', 'gum_check', '', '');
  assert.equal(result.status, 0, result.stderr);
  const runRecord = JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8'));
  assert.deepEqual(runRecord.digests, []);
  assert.deepEqual(runRecord.stages, []);
  assert.ok(!('machine' in runRecord) && !('profile' in runRecord) && !('gum_version' in runRecord) && !('final_digest' in runRecord));
});

test('record ignores facts that are not valid instead of recording a machine', () => {
  const directory = join(scratch, 'record-invalid-facts');
  mkdirSync(join(directory, 'discovery', 'initial'), { recursive: true });
  const invalid = clone(facts());
  invalid.validation = { status: 'invalid', reasons: [{ code: 'profile_ambiguous', message: 'm', next_step: 'n' }] };
  writeFileSync(join(directory, 'discovery', 'initial', 'target-facts.json'), JSON.stringify(invalid));
  const result = run('record', directory, 'run-5', '2026-10-08T12:00:00Z', 'guided', '', '2', 'blocked', 'discover', '', 'preparation');
  assert.equal(result.status, 0, result.stderr);
  const runRecord = JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8'));
  assert.ok(!('machine' in runRecord) && !('profile' in runRecord));
});

test('record never writes a secret value that travels with a reason', () => {
  const directory = join(scratch, 'record-canary');
  const leaking = write('leaking-reasons.json', [{
    code: 'stage_failed', message: 'm', next_step: 'n', user_password: CANARY, child_exit_status: 5,
  }]);
  const result = run('record', directory, 'run-6', '2026-10-08T12:00:00Z', 'guided', '', '5', 'failed', 'discover', leaking, '');
  assert.equal(result.status, 0, result.stderr);
  for (const name of readdirSync(directory)) assert.ok(!readFileSync(join(directory, name), 'utf8').includes(CANARY), name);
  assert.equal(JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8')).reasons[0].child_exit_status, 5);
});

test('record rejects an exit status that contradicts the outcome with exit 6', () => {
  const result = run('record', join(scratch, 'record-bad'), 'run-3', '2026-10-08T12:00:00Z', 'guided', '', '0', 'approved', 'x', '', '');
  assert.equal(result.status, 6);
});

test('record rejects an unknown entry or stage with exit 6', () => {
  const entry = run('record', join(scratch, 'record-bad-entry'), 'run-7', '2026-10-08T12:00:00Z', 'apply', '', '2', 'blocked', 'x', '', '');
  assert.equal(entry.status, 6);
  const stage = run('record', join(scratch, 'record-bad-stage'), 'run-8', '2026-10-08T12:00:00Z', 'guided', '', '2', 'blocked', 'x', '', 'apply');
  assert.equal(stage.status, 6);
});

test('options locales read the plan', () => {
  assert.equal(run('options', 'locales', planPath).stdout, 'en_US.UTF-8\n');
  assert.equal(run('options', 'locales', join(scratch, 'missing.json')).status, 2);
});

test('reasons wraps a child error document and prints reasons as text', () => {
  const error = write('error.json', {
    code: 'child_failed', stage: 'discover', operation: 'storage', message: 'm', next_step: 'n', child_exit_status: 1,
  });
  assert.equal(JSON.parse(run('reasons', 'error', error).stdout)[0].code, 'child_failed');
  const list = write('text.json', JSON.parse(run('reasons', 'standard', 'engine_not_available').stdout));
  const result = run('reasons', 'text', list);
  assert.equal(result.status, 0);
  assert.match(result.stderr, /^MirrorOS install: The installation engine is not part of this MirrorOS version/);
  assert.match(result.stderr, /Next step: Installation becomes available with Story 2\.5\./);
});

test('an unknown helper command exits 6', () => {
  assert.equal(run('frobnicate').status, 6);
});
