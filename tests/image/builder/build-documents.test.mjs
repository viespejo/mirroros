import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import {
  buildArtifactMetadata,
  buildExecutionResult,
  buildLiminePackageManifest,
  limineBuildArguments,
  validateArtifactMetadata,
  validateBundle,
  validateExecutionResult,
  validateLimineRecipe,
} from '../../../image/builder/lib/build-documents-core.mjs';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const cli = join(repository, 'image/builder/build-documents.mjs');

function validMetadata() {
  return {
    schema_version: 1,
    execution: {
      run_id: '20261005T120000Z-11111111-2222-4333-8444-555555555555',
      commit: 'a'.repeat(40),
      dirty: false,
      profile_identity: 'b'.repeat(40),
      dirty_paths: [],
    },
    embedded_code: {
      iso_path: '/usr/local/lib/mirroros',
      subtrees: [
        { path: 'install', identity: '1'.repeat(40) },
        { path: 'operations/install', identity: '2'.repeat(40) },
      ],
      dirty_paths: [],
    },
    construction: {
      architecture: 'x86_64',
      image_digest: `sha256:${'c'.repeat(64)}`,
      archiso_version: '91-1',
      source_date_epoch: 1791201600,
      tool_versions: { docker: '29.0.0', cosign: '2.5.0', gitleaks: '8.28.0', git: '2.50.0', node: '24.15.0' },
      cosign: { identity: 'https://example.invalid/identity', issuer: 'https://example.invalid/issuer' },
    },
    repository_configuration: {
      pacman_conf: 'image/archiso/pacman.conf',
      mirrorlist: { path: 'mirrorlist', sha256: 'd'.repeat(64) },
    },
    artifact: {
      iso: { name: 'mirroros.iso', size_bytes: 1234, sha256: 'e'.repeat(64) },
      package_manifest: { name: 'pkglist.x86_64.txt', sha256: 'f'.repeat(64) },
    },
    prebuilt_packages: {
      manifest_path: '/usr/local/lib/mirroros/packages/packages.json',
      manifest_sha256: '9'.repeat(64),
      packages: [
        {
          name: 'limine-snapper-sync',
          version: '1.32.1-1',
          file: 'limine-snapper-sync-1.32.1-1-x86_64.pkg.tar.zst',
          sha256: '8'.repeat(64),
          aur_commit: '7'.repeat(40),
          upstream_commit: '6'.repeat(40),
        },
      ],
    },
    controls: {
      secret_scan_scope: 'mirroros-created-content',
      outcomes: {
        signature_verification: 'passed',
        archiso_version: 'passed',
        profile_secret_scan: 'passed',
        evidence_secret_scan: 'passed',
        bundle_validation: 'passed',
      },
    },
    traceability_limitations: ['Rolling repositories may resolve different package versions on later runs.'],
    boot_qualification: 'not_performed',
  };
}

function validResult() {
  return {
    schema_version: 1,
    run_id: '20261005T120000Z-11111111-2222-4333-8444-555555555555',
    references: {
      sources: ['commit:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'profile:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'],
      artifacts: ['dist/run-id/artifact-metadata.json', 'dist/run-id/mirroros.iso'],
    },
    started_at: '2026-10-05T12:00:00.000Z',
    ended_at: '2026-10-05T12:00:02.000Z',
    duration_seconds: 2,
    outcome: 'success',
    exit_status: 0,
    failed_stage: null,
    original_tool_statuses: { git: 0, gitleaks: 0 },
    validations: { profile_scan: 'passed', bundle_validation: 'passed' },
    diagnostic_references: ['evidence/archiso-build/run-id/logs/build.log'],
    published: true,
    cleanup: { outcome: 'success', leftover_resources: [], recovery_guidance: null },
  };
}

function setPath(object, path, value) {
  const parts = path.split('.');
  const final = parts.pop();
  const parent = parts.reduce((current, part) => current[part], object);
  parent[final] = value;
}

function deletePath(object, path) {
  const parts = path.split('.');
  const final = parts.pop();
  const parent = parts.reduce((current, part) => current[part], object);
  delete parent[final];
}

function withFixture(callback) {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-build-documents-'));
  chmodSync(root, 0o700);
  try {
    return callback(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function hash(contents) {
  return createHash('sha256').update(contents).digest('hex');
}

function validBundleFixture() {
  const metadata = validMetadata();
  const isoBytes = Buffer.from('synthetic ISO bytes');
  const manifestBytes = Buffer.from('bash 5.3-1\n');
  metadata.artifact.iso.size_bytes = isoBytes.length;
  metadata.artifact.iso.sha256 = hash(isoBytes);
  metadata.artifact.package_manifest.sha256 = hash(manifestBytes);
  const metadataBytes = Buffer.from(`${JSON.stringify(metadata, null, 2)}\n`);
  const files = {
    iso: { name: metadata.artifact.iso.name, size_bytes: isoBytes.length, sha256: hash(isoBytes) },
    metadata: { name: 'artifact-metadata.json', sha256: hash(metadataBytes) },
    package_manifest: { name: metadata.artifact.package_manifest.name, sha256: hash(manifestBytes) },
  };
  files.sha256sums = [
    `${files.iso.sha256}  ${files.iso.name}`,
    `${files.metadata.sha256}  ${files.metadata.name}`,
    `${files.package_manifest.sha256}  ${files.package_manifest.name}`,
  ].join('\n') + '\n';
  return { metadata, files, metadataBytes, isoBytes, manifestBytes };
}

test('builds valid artifact metadata and execution results', () => {
  assert.equal(buildArtifactMetadata(validMetadata()).schema_version, 1);
  assert.equal(buildExecutionResult(validResult()).outcome, 'success');
  assert.deepEqual(validateArtifactMetadata(validMetadata()), []);
  assert.deepEqual(validateExecutionResult(validResult()), []);
});

const metadataMissingPaths = [
  'schema_version',
  'execution', 'execution.run_id', 'execution.commit', 'execution.dirty', 'execution.profile_identity', 'execution.dirty_paths',
  'embedded_code', 'embedded_code.iso_path', 'embedded_code.subtrees', 'embedded_code.dirty_paths',
  'construction', 'construction.architecture', 'construction.image_digest', 'construction.archiso_version',
  'construction.source_date_epoch', 'construction.tool_versions', 'construction.cosign',
  'construction.cosign.identity', 'construction.cosign.issuer',
  'repository_configuration', 'repository_configuration.pacman_conf', 'repository_configuration.mirrorlist',
  'repository_configuration.mirrorlist.path', 'repository_configuration.mirrorlist.sha256',
  'artifact', 'artifact.iso', 'artifact.iso.name', 'artifact.iso.size_bytes', 'artifact.iso.sha256',
  'artifact.package_manifest', 'artifact.package_manifest.name', 'artifact.package_manifest.sha256',
  'prebuilt_packages', 'prebuilt_packages.manifest_path', 'prebuilt_packages.manifest_sha256', 'prebuilt_packages.packages',
  'controls', 'controls.secret_scan_scope', 'controls.outcomes',
  'controls.outcomes.signature_verification', 'controls.outcomes.archiso_version',
  'controls.outcomes.profile_secret_scan', 'controls.outcomes.evidence_secret_scan', 'controls.outcomes.bundle_validation',
  'traceability_limitations', 'boot_qualification',
];

test('rejects every missing artifact metadata field', () => {
  for (const path of metadataMissingPaths) {
    const document = validMetadata();
    deletePath(document, path);
    assert.ok(validateArtifactMetadata(document).length > 0, `Expected missing ${path} to be rejected`);
  }
});

const metadataWrongTypes = [
  ['schema_version', '1'],
  ['execution', []], ['execution.run_id', 1], ['execution.commit', 'bad'], ['execution.dirty', 'false'],
  ['execution.profile_identity', 1], ['execution.dirty_paths', 'image/archiso/file'],
  ['embedded_code', []], ['embedded_code.iso_path', 1], ['embedded_code.subtrees', []],
  ['embedded_code.dirty_paths', 'install/file'],
  ['construction', []], ['construction.architecture', 1], ['construction.image_digest', 1],
  ['construction.archiso_version', 91], ['construction.source_date_epoch', '1791201600'],
  ['construction.tool_versions', []], ['construction.cosign', []], ['construction.cosign.identity', 1],
  ['construction.cosign.issuer', 1],
  ['repository_configuration', []], ['repository_configuration.pacman_conf', 1],
  ['repository_configuration.mirrorlist', []], ['repository_configuration.mirrorlist.path', 1],
  ['repository_configuration.mirrorlist.sha256', 'invalid'],
  ['artifact', []], ['artifact.iso', []], ['artifact.iso.name', 1], ['artifact.iso.size_bytes', '1234'],
  ['artifact.iso.sha256', 'invalid'], ['artifact.package_manifest', []], ['artifact.package_manifest.name', 1],
  ['artifact.package_manifest.sha256', 'invalid'],
  ['prebuilt_packages', []], ['prebuilt_packages.manifest_path', 1], ['prebuilt_packages.manifest_sha256', 'invalid'],
  ['prebuilt_packages.packages', []], ['prebuilt_packages.packages', ['limine-snapper-sync']],
  ['prebuilt_packages.packages.0.sha256', 'invalid'], ['prebuilt_packages.packages.0.aur_commit', 'v1.32.1'],
  ['prebuilt_packages.packages.0.upstream_commit', 'main'], ['prebuilt_packages.packages.0.file', '../escape.pkg.tar.zst'],
  ['controls', []], ['controls.secret_scan_scope', 'all-content'], ['controls.outcomes', []],
  ['controls.outcomes.signature_verification', 'unknown'], ['controls.outcomes.archiso_version', 'unknown'],
  ['controls.outcomes.profile_secret_scan', 'unknown'], ['controls.outcomes.evidence_secret_scan', 'unknown'],
  ['controls.outcomes.bundle_validation', 'unknown'], ['traceability_limitations', 'none'],
  ['boot_qualification', true],
];

test('rejects every incorrectly typed or invalid artifact metadata field', () => {
  for (const [path, value] of metadataWrongTypes) {
    const document = validMetadata();
    setPath(document, path, value);
    assert.ok(validateArtifactMetadata(document).length > 0, `Expected invalid ${path} to be rejected`);
  }
});

test('dirty metadata requires the dirty-path identity and a traceability limitation', () => {
  const document = validMetadata();
  document.execution.dirty = true;
  document.execution.profile_identity = 'dirty-path-list';
  document.execution.dirty_paths = [];
  document.traceability_limitations = [];
  const errors = validateArtifactMetadata(document);
  assert.ok(errors.some(error => error.includes('traceability limitation')));
  document.traceability_limitations = ['Dirty source content is not identified by a content hash.'];
  document.execution.profile_identity = 'b'.repeat(40);
  assert.ok(validateArtifactMetadata(document).some(error => error.includes('dirty-path-list')));
});

test('embedded code identities must match the clean or dirty execution state', () => {
  const invalidSubtrees = [
    [{ path: 'install', identity: 'dirty-path-list' }],
    [{ path: 'install', identity: 'bad' }],
    [{ identity: '1'.repeat(40) }],
    ['install'],
  ];
  for (const subtrees of invalidSubtrees) {
    const document = validMetadata();
    document.embedded_code.subtrees = subtrees;
    assert.ok(validateArtifactMetadata(document).length > 0, `Expected ${JSON.stringify(subtrees)} to be rejected`);
  }

  const clean = validMetadata();
  clean.embedded_code.dirty_paths = ['install/file'];
  assert.ok(validateArtifactMetadata(clean).some(error => error.includes('clean embedded_code.dirty_paths')));

  const dirty = validMetadata();
  dirty.execution.dirty = true;
  dirty.execution.profile_identity = 'dirty-path-list';
  dirty.traceability_limitations = ['Dirty source content is not identified by a content hash.'];
  assert.ok(validateArtifactMetadata(dirty).some(error => error.includes('dirty-path-list for a dirty execution')));
  dirty.embedded_code.subtrees = dirty.embedded_code.subtrees.map(subtree => ({ ...subtree, identity: 'dirty-path-list' }));
  dirty.embedded_code.dirty_paths = ['install/file'];
  assert.deepEqual(validateArtifactMetadata(dirty), []);
});

const resultMissingPaths = [
  'schema_version', 'run_id', 'references', 'references.sources', 'references.artifacts',
  'started_at', 'ended_at', 'duration_seconds', 'outcome', 'exit_status', 'failed_stage',
  'original_tool_statuses', 'validations', 'diagnostic_references', 'published',
  'cleanup', 'cleanup.outcome', 'cleanup.leftover_resources', 'cleanup.recovery_guidance',
];

test('rejects every missing execution result field', () => {
  for (const path of resultMissingPaths) {
    const document = validResult();
    deletePath(document, path);
    assert.ok(validateExecutionResult(document).length > 0, `Expected missing ${path} to be rejected`);
  }
});

const resultWrongTypes = [
  ['schema_version', '1'], ['run_id', 1], ['references', []], ['references.sources', 'commit'],
  ['references.artifacts', 'bundle'], ['started_at', 'unknown'], ['ended_at', 1],
  ['duration_seconds', '2'], ['outcome', 'passed'], ['exit_status', '0'], ['failed_stage', true],
  ['original_tool_statuses', []], ['validations', []], ['diagnostic_references', 'log'],
  ['published', 'true'], ['cleanup', []], ['cleanup.outcome', 'passed'],
  ['cleanup.leftover_resources', 'container'], ['cleanup.recovery_guidance', false],
];

test('rejects every incorrectly typed or invalid execution result field', () => {
  for (const [path, value] of resultWrongTypes) {
    const document = validResult();
    setPath(document, path, value);
    assert.ok(validateExecutionResult(document).length > 0, `Expected invalid ${path} to be rejected`);
  }
});

test('unknown observations remain unknown and cannot be reported as success', () => {
  const unknown = validResult();
  unknown.outcome = 'unknown';
  unknown.exit_status = null;
  unknown.ended_at = null;
  unknown.duration_seconds = null;
  unknown.validations = { source_scan: 'unknown', construction: 'not_run' };
  unknown.original_tool_statuses = { gitleaks: null };
  unknown.published = null;
  unknown.cleanup = { outcome: 'unknown', leftover_resources: [], recovery_guidance: null };
  const result = buildExecutionResult(unknown);
  assert.equal(result.outcome, 'unknown');
  assert.equal(result.validations.source_scan, 'unknown');

  const falselySuccessful = { ...result, outcome: 'success', exit_status: 0, ended_at: '2026-10-05T12:00:02.000Z', duration_seconds: 2, published: true };
  falselySuccessful.cleanup = { outcome: 'success', leftover_resources: [], recovery_guidance: null };
  assert.ok(validateExecutionResult(falselySuccessful).some(error => error.includes('every validation')));
  assert.throws(() => buildExecutionResult(falselySuccessful));
});

test('validates bundle references and SHA-256 coverage', () => {
  const { metadata, files } = validBundleFixture();
  assert.deepEqual(validateBundle(metadata, files), []);

  const badMetadata = structuredClone(metadata);
  badMetadata.artifact.iso.sha256 = '0'.repeat(64);
  const mismatchErrors = validateBundle(badMetadata, files);
  assert.ok(mismatchErrors.some(error => error.includes('metadata ISO SHA-256')));

  const badChecksums = { ...files, sha256sums: files.sha256sums.replace(files.iso.sha256, '0'.repeat(64)) };
  assert.ok(validateBundle(metadata, badChecksums).some(error => error.includes('SHA256SUMS digest')));
});

test('CLI writes metadata and execution results with mode 0600', () => withFixture(root => {
  const metadataInput = join(root, 'metadata-input.json');
  const resultInput = join(root, 'result-input.json');
  const metadataOutput = join(root, 'artifact-metadata.json');
  const resultOutput = join(root, 'execution-result.json');
  writeFileSync(metadataInput, JSON.stringify(validMetadata()), { mode: 0o600 });
  writeFileSync(resultInput, JSON.stringify(validResult()), { mode: 0o600 });

  for (const [command, input, output] of [
    ['write-metadata', metadataInput, metadataOutput],
    ['write-result', resultInput, resultOutput],
  ]) {
    const child = spawnSync(process.execPath, [cli, command, '--input', input, '--output', output], { encoding: 'utf8' });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(statSync(output).mode & 0o777, 0o600);
    assert.equal(JSON.parse(readFileSync(output, 'utf8')).schema_version, 1);
  }
}));

test('CLI validates a complete bundle', () => withFixture(root => {
  const { metadata, files, metadataBytes, isoBytes, manifestBytes } = validBundleFixture();
  const metadataPath = join(root, 'artifact-metadata.json');
  const isoPath = join(root, files.iso.name);
  const manifestPath = join(root, files.package_manifest.name);
  const checksumsPath = join(root, 'SHA256SUMS');
  writeFileSync(metadataPath, metadataBytes, { mode: 0o600 });
  writeFileSync(isoPath, isoBytes, { mode: 0o600 });
  writeFileSync(manifestPath, manifestBytes, { mode: 0o600 });
  writeFileSync(checksumsPath, files.sha256sums, { mode: 0o600 });
  const child = spawnSync(process.execPath, [
    cli, 'validate-bundle', '--metadata', metadataPath, '--iso', isoPath,
    '--manifest', manifestPath, '--checksums', checksumsPath,
  ], { encoding: 'utf8' });
  assert.equal(child.status, 0, child.stderr);
  assert.match(child.stdout, /Bundle contract valid/);
}));

test('CLI reports invalid contracts to stderr with status 6', () => withFixture(root => {
  const input = join(root, 'invalid.json');
  const output = join(root, 'output.json');
  writeFileSync(input, JSON.stringify({}), { mode: 0o600 });
  const child = spawnSync(process.execPath, [cli, 'write-metadata', '--input', input, '--output', output], { encoding: 'utf8' });
  assert.equal(child.status, 6);
  assert.match(child.stderr, /build-documents:/);
}));

function validRecipe() {
  return JSON.parse(readFileSync(join(repository, 'image/builder/aur/limine-tools.json'), 'utf8'));
}

test('the committed Limine recipe is valid and pins both tools twice', () => {
  const recipe = validRecipe();
  assert.deepEqual(validateLimineRecipe(recipe), []);
  assert.deepEqual(recipe.packages.map(entry => entry.name), ['limine-mkinitcpio-hook', 'limine-snapper-sync']);
  assert.ok(recipe.makedepends.includes('gradle'));
  const [dependencies, ...entries] = limineBuildArguments(recipe);
  assert.equal(dependencies, recipe.makedepends.join(','));
  assert.equal(entries.length, 2);
  for (const entry of entries) assert.match(entry, /^[a-z0-9@._+-]+:[a-f0-9]{40}:[a-f0-9]{40}$/);
});

test('rejects Limine recipes with movable or malformed pins', () => {
  for (const mutate of [
    recipe => { recipe.packages[0].upstream_commit = '1.40.0'; },
    recipe => { recipe.packages[0].aur_commit = 'master'; },
    recipe => { recipe.packages[1].name = recipe.packages[0].name; },
    recipe => { recipe.packages = []; },
    recipe => { recipe.makedepends = ['base-devel', 'gradle; rm -rf /']; },
    recipe => { recipe.schema_version = 2; },
  ]) {
    const recipe = validRecipe();
    mutate(recipe);
    assert.ok(validateLimineRecipe(recipe).length > 0);
    assert.throws(() => limineBuildArguments(recipe));
  }
});

function builtRows(recipe) {
  return recipe.packages.map(entry => [
    entry.name, '1.0-1', `${entry.name}-1.0-1-x86_64.pkg.tar.zst`, entry.aur_commit, entry.upstream_commit,
  ]);
}

test('builds the Limine package manifest only from records matching the recipe', () => {
  const recipe = validRecipe();
  const rows = builtRows(recipe);
  const hashes = Object.fromEntries(rows.map(row => [row[2], hash(row[2])]));
  const manifest = buildLiminePackageManifest(recipe, rows, hashes);
  assert.equal(manifest.schema_version, 1);
  assert.deepEqual(manifest.packages.map(entry => entry.name), recipe.packages.map(entry => entry.name));
  assert.equal(manifest.packages[0].sha256, hashes[rows[0][2]]);

  assert.throws(() => buildLiminePackageManifest(recipe, rows.slice(1), hashes));
  const wrongPin = structuredClone(rows);
  wrongPin[0][4] = 'f'.repeat(40);
  assert.throws(() => buildLiminePackageManifest(recipe, wrongPin, hashes));
  assert.throws(() => buildLiminePackageManifest(recipe, rows, {}));
});

test('CLI emits NUL-delimited recipe arguments and writes a host-hashed package manifest', () => withFixture(root => {
  const recipePath = join(repository, 'image/builder/aur/limine-tools.json');
  const recipe = validRecipe();
  const child = spawnSync(process.execPath, [cli, 'read-recipe', '--input', recipePath], { encoding: 'utf8' });
  assert.equal(child.status, 0, child.stderr);
  assert.deepEqual(child.stdout.split('\0').slice(0, -1), limineBuildArguments(recipe));

  const directory = join(root, 'packages');
  mkdirSync(directory, { mode: 0o700 });
  const rows = builtRows(recipe);
  for (const row of rows) writeFileSync(join(directory, row[2]), `package ${row[0]}\n`, { mode: 0o600 });
  writeFileSync(join(directory, 'packages.tsv'), `${rows.map(row => row.join('\t')).join('\n')}\n`, { mode: 0o600 });
  const output = join(directory, 'packages.json');
  const writer = spawnSync(process.execPath, [
    cli, 'write-package-manifest', '--recipe', recipePath, '--directory', directory, '--output', output,
  ], { encoding: 'utf8' });
  assert.equal(writer.status, 0, writer.stderr);
  assert.equal(statSync(output).mode & 0o777, 0o600);
  const manifest = JSON.parse(readFileSync(output, 'utf8'));
  assert.equal(manifest.packages[0].sha256, hash(`package ${rows[0][0]}\n`));

  writeFileSync(join(directory, 'packages.tsv'), `${rows[0].join('\t')}\n`, { mode: 0o600 });
  const mismatch = spawnSync(process.execPath, [
    cli, 'write-package-manifest', '--recipe', recipePath, '--directory', directory, '--output', join(root, 'other.json'),
  ], { encoding: 'utf8' });
  assert.equal(mismatch.status, 6);
}));
