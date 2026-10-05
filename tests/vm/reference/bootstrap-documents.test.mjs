import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, rmSync, statSync, symlinkSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import {
  buildResultDocument,
  CHECK_IDS,
  ContractError,
  NOCLOUD_NOTE,
  renderSummary,
  validateBundleAdmission,
  validateGuestReport,
  validateResultDocument,
} from '../../../vm/reference/lib/bootstrap-documents.mjs';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const cli = join(repository, 'vm/reference/bootstrap-documents.mjs');
const RUN_ID = '20261005T120000Z-11111111-2222-4333-8444-555555555555';
const OTHER_RUN_ID = '20261005T120001Z-11111111-2222-4333-8444-555555555555';

function sha(content) {
  return createHash('sha256').update(content).digest('hex');
}

function makeBundle(directory, { tamper = false } = {}) {
  const iso = 'iso-content';
  const manifest = 'pkg-a\npkg-b\n';
  const metadata = JSON.stringify({
    schema_version: 1,
    execution: { run_id: 'build-run', commit: 'a'.repeat(40), dirty: false },
    artifact: {
      iso: { name: 'test.iso', size_bytes: iso.length, sha256: sha(iso) },
      package_manifest: { name: 'pkglist.x86_64.txt', sha256: sha(manifest) },
    },
  });
  writeFileSync(join(directory, 'test.iso'), tamper ? 'tampered!!!' : iso);
  writeFileSync(join(directory, 'pkglist.x86_64.txt'), manifest);
  writeFileSync(join(directory, 'artifact-metadata.json'), metadata);
  writeFileSync(join(directory, 'SHA256SUMS'), [
    `${sha(iso)}  test.iso`,
    `${sha(metadata)}  artifact-metadata.json`,
    `${sha(manifest)}  pkglist.x86_64.txt`,
  ].join('\n') + '\n');
}

function admissionFixture() {
  const iso = 'iso-content';
  const manifest = 'pkg-a\n';
  const metadata = {
    schema_version: 1,
    execution: { run_id: 'build-run', commit: 'a'.repeat(40), dirty: false },
    artifact: {
      iso: { name: 'test.iso', size_bytes: iso.length, sha256: sha(iso) },
      package_manifest: { name: 'pkg.txt', sha256: sha(manifest) },
    },
  };
  const files = {
    entries: ['test.iso', 'pkg.txt', 'SHA256SUMS', 'artifact-metadata.json'],
    iso: { name: 'test.iso', size_bytes: iso.length, sha256: sha(iso) },
    metadata: { name: 'artifact-metadata.json', sha256: 'e'.repeat(64) },
    package_manifest: { name: 'pkg.txt', sha256: sha(manifest) },
    sha256sums: [
      `${sha(iso)}  test.iso`,
      `${'e'.repeat(64)}  artifact-metadata.json`,
      `${sha(manifest)}  pkg.txt`,
    ].join('\n') + '\n',
  };
  return { metadata, files };
}

function validReport() {
  const checks = {};
  for (const id of CHECK_IDS) checks[id] = { status: 'passed', detail: `${id} ok` };
  checks.ipv4_address.address = '10.0.2.15';
  checks.https_request.http_status = 200;
  checks.https_request.tls_verified = true;
  return { schema_version: 1, run_id: RUN_ID, result: 'passed', checks };
}

function validResult(overrides = {}) {
  return {
    run_id: RUN_ID,
    artifact: { iso_name: 'test.iso', iso_sha256: 'a'.repeat(64), build_commit: 'b'.repeat(40), build_run_id: 'build-run' },
    test_code: { commit: 'c'.repeat(40), dirty: false },
    vm_configuration: { machine: 'q35', memory_mib: 4096 },
    versions: { qemu: 'QEMU emulator version 9.0.0', ovmf: 'edk2-ovmf 202408' },
    checks: Object.fromEntries(CHECK_IDS.map(id => [id, 'passed'])),
    duration_seconds: 93.5,
    failed_stage: null,
    next_action: null,
    status: 0,
    original_tool_statuses: { qemu: 0, gitleaks: 0 },
    scans: { nocloud: 'passed', evidence: 'passed' },
    cleanup: { outcome: 'success', leftover_resources: [], recovery_guidance: null },
    ...overrides,
  };
}

test('bundle admission accepts a coherent bundle', () => {
  const { metadata, files } = admissionFixture();
  assert.deepEqual(validateBundleAdmission(metadata, files), []);
});

test('bundle admission rejects missing files, mismatches, and incoherent checksums', () => {
  let { metadata, files } = admissionFixture();
  files.entries = files.entries.filter(name => name !== 'SHA256SUMS');
  assert.match(validateBundleAdmission(metadata, files).join('\n'), /missing SHA256SUMS/);

  ({ metadata, files } = admissionFixture());
  files.iso.sha256 = 'f'.repeat(64);
  const errors = validateBundleAdmission(metadata, files).join('\n');
  assert.match(errors, /ISO SHA-256 does not match/);
  assert.match(errors, /SHA256SUMS digest does not match test.iso/);

  ({ metadata, files } = admissionFixture());
  files.sha256sums += `${'1'.repeat(64)}  extra.bin\n`;
  assert.match(validateBundleAdmission(metadata, files).join('\n'), /exactly the ISO/);

  ({ metadata, files } = admissionFixture());
  metadata.artifact.package_manifest.sha256 = '2'.repeat(64);
  assert.match(validateBundleAdmission(metadata, files).join('\n'), /package manifest SHA-256 does not match/);

  ({ metadata, files } = admissionFixture());
  files.sha256sums = 'garbage\n';
  assert.match(validateBundleAdmission(metadata, files).join('\n'), /invalid sha256sum entry/);
});

test('bundle admission rejects unsafe filenames and non-object metadata', () => {
  const { metadata, files } = admissionFixture();
  metadata.artifact.iso.name = '../escape.iso';
  assert.match(validateBundleAdmission(metadata, files).join('\n'), /safe filename/);
  assert.ok(validateBundleAdmission(null, files).length > 0);
  assert.ok(validateBundleAdmission(metadata, null).length > 0);
});

test('guest report acceptance requires a complete, consistent, run-bound report', () => {
  const verdict = validateGuestReport(validReport(), RUN_ID);
  assert.deepEqual(verdict, { errors: [], passed: true, failed_checks: [] });
});

test('guest report from another run or with missing checks is never accepted', () => {
  assert.match(validateGuestReport(validReport(), OTHER_RUN_ID).errors.join('\n'), /does not match the current run/);
  const report = validReport();
  delete report.checks.dns_resolution;
  const verdict = validateGuestReport(report, RUN_ID);
  assert.equal(verdict.passed, false);
  assert.match(verdict.errors.join('\n'), /missing check dns_resolution/);
  assert.equal(validateGuestReport(null, RUN_ID).passed, false);
});

test('guest report with failed checks is valid but not passed', () => {
  const report = validReport();
  report.checks.default_route = { status: 'failed', detail: 'no default route' };
  report.result = 'failed';
  const verdict = validateGuestReport(report, RUN_ID);
  assert.deepEqual(verdict.errors, []);
  assert.equal(verdict.passed, false);
  assert.deepEqual(verdict.failed_checks, ['default_route']);
});

test('guest report contradictions are rejected', () => {
  let report = validReport();
  report.checks.dns_resolution.status = 'failed';
  assert.match(validateGuestReport(report, RUN_ID).errors.join('\n'), /contradicts its checks/);

  report = validReport();
  report.checks.https_request.http_status = 503;
  assert.match(validateGuestReport(report, RUN_ID).errors.join('\n'), /validated TLS and HTTP 200/);

  report = validReport();
  report.checks.https_request.tls_verified = false;
  assert.match(validateGuestReport(report, RUN_ID).errors.join('\n'), /validated TLS and HTTP 200/);

  report = validReport();
  report.checks.ipv4_address.address = '999.1.1.1';
  assert.match(validateGuestReport(report, RUN_ID).errors.join('\n'), /valid IPv4 address/);

  report = validReport();
  report.checks.extra_check = { status: 'passed', detail: 'x' };
  assert.match(validateGuestReport(report, RUN_ID).errors.join('\n'), /unknown check/);
});

test('success keywords never grant acceptance', () => {
  const report = { schema_version: 1, run_id: RUN_ID, result: 'passed', status: 'success', message: 'ALL CHECKS PASSED', checks: {} };
  const verdict = validateGuestReport(report, RUN_ID);
  assert.equal(verdict.passed, false);
  assert.ok(verdict.errors.length > 0);
});

test('result document builds and validates the success shape', () => {
  const document = buildResultDocument(validResult());
  assert.equal(document.schema_version, 1);
  assert.equal(document.nocloud_note, NOCLOUD_NOTE);
  assert.deepEqual(validateResultDocument(document), []);
});

test('result document enforces outcome consistency', () => {
  const failedCheck = { ...validResult().checks, https_request: 'failed' };
  assert.throws(() => buildResultDocument(validResult({ checks: failedCheck })), ContractError);
  assert.throws(() => buildResultDocument(validResult({ scans: { evidence: 'findings' } })), ContractError);
  assert.throws(() => buildResultDocument(validResult({ cleanup: { outcome: 'failure', leftover_resources: ['disk'], recovery_guidance: 'x' } })), ContractError);
  assert.throws(() => buildResultDocument(validResult({ status: 5 })), /failed_stage/);
  assert.throws(() => buildResultDocument(validResult({ status: 4, failed_stage: 'guest-checks', next_action: 'inspect' })), /failed check/);
  assert.throws(() => buildResultDocument(validResult({ status: 1 })), /status must be one of/);
  assert.throws(() => buildResultDocument(validResult({ original_tool_statuses: { qemu: 1 } })), /original tool status/);
  const failure = buildResultDocument(validResult({
    status: 4,
    failed_stage: 'guest-checks',
    next_action: 'Inspect the redacted serial log.',
    checks: { ...validResult().checks, dns_resolution: 'failed' },
    original_tool_statuses: { qemu: 0 },
  }));
  assert.equal(failure.status, 4);
});

test('terminal summary derives from the result only', () => {
  const summary = renderSummary(buildResultDocument(validResult()));
  assert.match(summary, /PASSED \(exit 0\)/);
  assert.match(summary, new RegExp(RUN_ID));
  assert.match(summary, /https_request: passed/);
  const failure = renderSummary(buildResultDocument(validResult({
    status: 5,
    failed_stage: 'cleanup',
    next_action: 'Follow the recovery guide.',
    original_tool_statuses: { qemu: 0 },
    cleanup: { outcome: 'preserved', leftover_resources: ['disk.qcow2'], recovery_guidance: 'See docs/procedures/test.md' },
  })));
  assert.match(failure, /NOT QUALIFIED \(exit 5\)/);
  assert.match(failure, /Preserved resources: disk.qcow2/);
  assert.throws(() => renderSummary({}), ContractError);
});

function runCli(arguments_) {
  return spawnSync(process.execPath, [cli, ...arguments_], { encoding: 'utf8' });
}

test('CLI admit-bundle accepts a valid bundle and never modifies it', () => {
  const directory = mkdtempSync(join(tmpdir(), 'bootstrap-docs-'));
  try {
    makeBundle(directory);
    const before = readFileSync(join(directory, 'artifact-metadata.json'), 'utf8');
    const result = runCli(['admit-bundle', '--bundle', directory]);
    assert.equal(result.status, 0, result.stderr);
    const identity = JSON.parse(result.stdout);
    assert.equal(identity.iso_name, 'test.iso');
    assert.equal(identity.build_commit, 'a'.repeat(40));
    assert.equal(readFileSync(join(directory, 'artifact-metadata.json'), 'utf8'), before);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('CLI admit-bundle exits 2 for tampered, missing, and symlinked inputs', () => {
  const directory = mkdtempSync(join(tmpdir(), 'bootstrap-docs-'));
  try {
    makeBundle(directory, { tamper: true });
    assert.equal(runCli(['admit-bundle', '--bundle', directory]).status, 2);
    assert.equal(runCli(['admit-bundle', '--bundle', join(directory, 'absent')]).status, 2);

    const linked = join(directory, 'linked');
    mkdirSync(linked);
    makeBundle(linked);
    rmSync(join(linked, 'SHA256SUMS'));
    symlinkSync(join(directory, 'SHA256SUMS'), join(linked, 'SHA256SUMS'));
    assert.equal(runCli(['admit-bundle', '--bundle', linked]).status, 2);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('CLI validate-report maps passed, failed, and rejected reports', () => {
  const directory = mkdtempSync(join(tmpdir(), 'bootstrap-docs-'));
  try {
    const path = join(directory, 'report.json');
    writeFileSync(path, JSON.stringify(validReport()));
    assert.equal(runCli(['validate-report', '--report', path, '--run-id', RUN_ID]).status, 0);
    assert.equal(runCli(['validate-report', '--report', path, '--run-id', OTHER_RUN_ID]).status, 5);

    const failing = validReport();
    failing.checks.dns_resolution = { status: 'failed', detail: 'nxdomain' };
    failing.result = 'failed';
    writeFileSync(path, JSON.stringify(failing));
    assert.equal(runCli(['validate-report', '--report', path, '--run-id', RUN_ID]).status, 4);

    assert.equal(runCli(['validate-report', '--report', join(directory, 'absent.json'), '--run-id', RUN_ID]).status, 5);
    writeFileSync(path, 'not json');
    assert.equal(runCli(['validate-report', '--report', path, '--run-id', RUN_ID]).status, 5);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('CLI write-result and render-summary work and keep private permissions', () => {
  const directory = mkdtempSync(join(tmpdir(), 'bootstrap-docs-'));
  try {
    const input = join(directory, 'input.json');
    const output = join(directory, 'result.json');
    writeFileSync(input, JSON.stringify(validResult()));
    assert.equal(runCli(['write-result', '--input', input, '--output', output]).status, 0);
    assert.equal(statSync(output).mode & 0o777, 0o600);
    const summary = runCli(['render-summary', '--result', output]);
    assert.equal(summary.status, 0, summary.stderr);
    assert.match(summary.stdout, /PASSED/);

    writeFileSync(input, JSON.stringify(validResult({ status: 0, scans: { evidence: 'findings' } })));
    assert.equal(runCli(['write-result', '--input', input, '--output', output]).status, 6);
    assert.equal(runCli(['write-result', '--input', input, '--output', input]).status, 6);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('CLI rejects unknown subcommands and malformed options with 6', () => {
  assert.equal(runCli([]).status, 6);
  assert.equal(runCli(['unknown']).status, 6);
  assert.equal(runCli(['admit-bundle']).status, 6);
  assert.equal(runCli(['admit-bundle', '--bundle']).status, 6);
});
