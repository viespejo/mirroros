import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { validateApprovalRecord, validateRunRecord } from '../../../install/confirmation/validate-records.mjs';
import {
  CANARY, clone, facts, generate, removeDirectory, repository, temporaryDirectory, unqualifiedFacts, withDisk, withMemory,
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

// A copy of what compare reads from the code root: the policy, its configuration assets, and the targets.
function codeRootCopy(name) {
  const root = join(scratch, name);
  mkdirSync(join(root, 'install/plan'), { recursive: true });
  cpSync(join(repository, 'install/plan/policy.json'), join(root, 'install/plan/policy.json'));
  cpSync(join(repository, 'install/plan/assets'), join(root, 'install/plan/assets'), { recursive: true });
  cpSync(join(repository, 'targets'), join(root, 'targets'), { recursive: true });
  return root;
}

const ZRAM_ASSET = 'install/plan/assets/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf';
const SYSCTL_ASSET = 'install/plan/assets/usr/lib/sysctl.d/60-mirroros-memory.conf';

test('compare passes with a copy of the code root and invalidates a changed, missing, or damaged asset', () => {
  const root = codeRootCopy('assets-unchanged');
  assert.equal(run('compare', root, planPath, factsPath).status, 0);
  const changed = codeRootCopy('assets-changed');
  writeFileSync(join(changed, ZRAM_ASSET), `${readFileSync(join(changed, ZRAM_ASSET), 'utf8')}# edited\n`);
  const missing = codeRootCopy('assets-missing');
  rmSync(join(missing, SYSCTL_ASSET));
  const damaged = codeRootCopy('assets-damaged');
  writeFileSync(join(damaged, ZRAM_ASSET), 'not a configuration\n');
  const diverged = codeRootCopy('assets-diverged');
  writeFileSync(join(diverged, ZRAM_ASSET), readFileSync(join(diverged, ZRAM_ASSET), 'utf8').replace('= 100', '= 10'));
  for (const [name, directory] of Object.entries({ changed, missing, damaged, diverged })) {
    const result = run('compare', directory, planPath, factsPath);
    assert.equal(result.status, 2, `${name}: ${result.stderr}`);
    assert.deepEqual(JSON.parse(result.stdout).map(item => item.code), ['configuration_assets_changed'], name);
    assert.match(result.stderr, /Next step: Regenerate and review the installation plan\./, name);
  }
});

test('compare invalidates changed or missing memory with and without hibernation', () => {
  for (const hibernation of [true, false]) {
    const subject = write(`memory-plan-${hibernation}.json`, generate({ choices: { hibernation } }).plan);
    assert.equal(run('compare', repository, subject, factsPath).status, 0);
    for (const bytes of [8589934592, undefined]) {
      const result = run('compare', repository, subject, write(`memory-${hibernation}-${bytes}.json`, withMemory(facts(), bytes)));
      assert.equal(result.status, 2, `${hibernation} ${bytes}`);
      assert.deepEqual(JSON.parse(result.stdout).map(item => item.code), ['machine_identity_changed'], `${hibernation} ${bytes}`);
    }
  }
});

test('compare and review reject a plan of an earlier version with regeneration guidance', () => {
  for (const version of [1, 2]) {
    const earlier = write(`earlier-plan-${version}.json`, { ...clone(plan), format_version: version });
    for (const result of [run('compare', repository, earlier, factsPath), run('review', 'compact', earlier)]) {
      assert.equal(result.status, 2);
      const [first] = JSON.parse(result.stdout);
      assert.equal(first.code, 'plan_format_unsupported');
      assert.equal(first.next_step, 'Regenerate and review the installation plan.');
    }
  }
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
  assert.deepEqual(compact.find(([label]) => label === 'Hibernation'), ['Hibernation', 'Enabled (swapfile 4096 MiB)']);
  assert.equal(compact.some(([label]) => label === 'Swapfile'), false);
  assert.deepEqual(compact.at(-1), ['Plan reference', plan.digest.value.slice(0, 12)]);
  assert.match(run('review', 'confirmation', planPath).stdout, /^Disk: \/dev\/vda 32\.0 GiB\n[\s\S]*Plan reference: [0-9a-f]{12}\n$/);
  assert.match(run('review', 'complete', planPath).stdout, /^MirrorOS installation plan \(format 4\)\n[\s\S]*Plan reference: [0-9a-f]{12} /);
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
    format_version: 3, hostname: 'laptop', regional_format: 'es_ES.UTF-8',
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
  assert.deepEqual(storage, ['ext4-systemd-boot (supported)', 'btrfs-rescue (supported)', 'btrfs-limine (default)']);
});

test('reasons prints standard reasons and extracts them from run files', () => {
  assert.equal(JSON.parse(run('reasons', 'standard', 'engine_version_mismatch').stdout)[0].code, 'engine_version_mismatch');
  assert.equal(run('reasons', 'standard', 'engine_not_available').status, 5);
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
  const timing = {
    total: { status: 'available', duration_ms: 1000 },
    intervals: ['preparation', 'discovery_initial', 'plan', 'review', 'confirmation'].map(id => ({
      id,
      classification: id === 'preparation' ? 'mixed' : ['review', 'confirmation'].includes(id) ? 'interactive' : 'automated',
      measurement: { status: 'available', duration_ms: 100 },
    })),
  };
  const result = run(
    'record', directory, 'run-1', '2026-10-08T12:00:00Z', 'guided', 'gum version 2.0.2', '3', 'cancelled', 'confirm', reasons,
    'preparation,discovery_initial,plan,review,confirmation', JSON.stringify(timing),
  );
  assert.equal(result.status, 0, result.stderr);
  const runRecord = JSON.parse(readFileSync(join(directory, 'install-run.json'), 'utf8'));
  const approval = JSON.parse(readFileSync(join(directory, 'approval-record.json'), 'utf8'));
  assert.deepEqual(validateRunRecord(runRecord), []);
  assert.deepEqual(validateApprovalRecord(approval), []);
  assert.equal(runRecord.format_version, 7);
  assert.deepEqual(runRecord.timing, timing);
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
  assert.deepEqual(runRecord.timing.total, { status: 'unavailable', reason: 'not_sampled' });
  assert.deepEqual(runRecord.timing.intervals, [{ id: 'plan', classification: 'automated',
    measurement: { status: 'unavailable', reason: 'not_sampled' } }]);
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
  const result = run('record', join(scratch, 'record-bad'), 'run-3', '2026-10-08T12:00:00Z', 'guided', '', '2', 'installed', 'x', '', '');
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
  const list = write('text.json', JSON.parse(run('reasons', 'standard', 'engine_version_mismatch').stdout));
  const result = run('reasons', 'text', list);
  assert.equal(result.status, 0);
  assert.match(result.stderr, /^MirrorOS install: The plan was generated by a different MirrorOS code identity/);
  assert.match(result.stderr, /Next step: Generate a new plan with this artifact; the disk was not touched\./);
});

test('an unknown helper command exits 6', () => {
  assert.equal(run('frobnicate').status, 6);
});

test('identity accepts a plan of the running artifact and blocks any other code identity', () => {
  const root = join(scratch, 'identity-root');
  mkdirSync(root, { recursive: true });
  const identity = (commit, dirty) => writeFileSync(join(root, 'identity.json'), JSON.stringify({ commit, dirty }));
  identity(plan.facts_binding.commit, plan.facts_binding.dirty);
  assert.equal(run('identity', root, planPath).status, 0);
  identity('b'.repeat(40), plan.facts_binding.dirty);
  const commit = run('identity', root, planPath);
  assert.equal(commit.status, 2);
  assert.equal(JSON.parse(commit.stdout)[0].code, 'engine_version_mismatch');
  assert.match(commit.stderr, /Generate a new plan with this artifact/);
  identity(plan.facts_binding.commit, !plan.facts_binding.dirty);
  assert.equal(run('identity', root, planPath).status, 2);
  rmSync(join(root, 'identity.json'));
  assert.equal(run('identity', root, planPath).status, 0);
  writeFileSync(join(root, 'identity.json'), 'not json');
  assert.equal(run('identity', root, planPath).status, 6);
  identity(plan.facts_binding.commit, plan.facts_binding.dirty);
  assert.equal(run('identity', root, write('tampered-identity-plan.json', { ...plan, hostname: 'x' })).status, 2);
});

test('engine-result prints the reasons of a valid record and rejects a missing, invalid, or disagreeing one', () => {
  const record = {
    format_version: 3, started_at: '2026-10-12T12:00:00Z', finished_at: '2026-10-12T12:05:00Z', outcome: 'failed', exit_status: 5,
    reasons: [{ code: 'stage_failed', stage: 'engine', operation: 'install_packages', message: 'm', next_step: 'n', child_exit_status: 1 }],
    completed: ['wipe_disk_signatures'], not_started: ['configure_zram'],
  };
  const path = write('engine-run.json', record);
  const result = run('engine-result', path, '5');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout)[0].code, 'stage_failed');
  assert.equal(run('engine-result', path, '6').status, 1);
  assert.equal(run('engine-result', join(scratch, 'no-engine-run.json'), '5').status, 1);
  assert.equal(run('engine-result', write('engine-run-invalid.json', { ...record, outcome: 'approved' }), '5').status, 1);
  const passed = { format_version: 1, status: 'passed', checks: [{ id: 'kernel_installed', status: 'passed' }], failed_checks: [] };
  const installed = write('engine-run-installed.json', { ...record, outcome: 'installed', exit_status: 0, reasons: [], not_started: [], postconditions: passed, configure_outcome: 0 });
  assert.deepEqual(JSON.parse(run('engine-result', installed, '0').stdout), []);
  const unconfigured = write('engine-run-not-configured.json', {
    ...record, outcome: 'not_configured', exit_status: 4, not_started: [], postconditions: passed,
    configure_outcome: 5, configure_failed_step: 'desktop/compositor/providers/hyprland',
    configure_evidence: '/var/log/mirroros/configure/run',
  });
  assert.equal(run('engine-result', unconfigured, '4').status, 0);
  assert.equal(run('engine-result', unconfigured, '0').status, 1);
  const failed = { format_version: 1, status: 'failed', checks: [{ id: 'kernel_installed', status: 'failed', detail: 'missing' }], failed_checks: ['kernel_installed'] };
  const unverified = write('engine-run-not-verified.json', {
    ...record,
    outcome: 'not_verified',
    exit_status: 4,
    reasons: [{ code: 'postcondition_failed', stage: 'engine', operation: 'postconditions', message: 'The check kernel_installed failed: missing', next_step: 'n' }],
    not_started: [],
    postconditions: failed,
  });
  assert.equal(JSON.parse(run('engine-result', unverified, '4').stdout)[0].code, 'postcondition_failed');
  assert.equal(run('engine-result', unverified, '5').status, 1);
});
