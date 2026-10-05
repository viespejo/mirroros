export const CHECK_IDS = [
  'uefi_mode',
  'root_shell',
  'native_install_tools',
  'ipv4_address',
  'default_route',
  'dns_resolution',
  'https_request',
];
export const BUNDLE_CHECKSUM_FILE = 'SHA256SUMS';
export const BUNDLE_METADATA_FILE = 'artifact-metadata.json';
export const NOCLOUD_NOTE = 'An auxiliary NoCloud medium was attached to the guest to deliver the checks; the ISO was not modified.';

const RUN_ID_PATTERN = /^\d{8}T\d{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const GIT_ID_PATTERN = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i;
const IPV4_PATTERN = /^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$/;
const CHECK_STATUSES = ['passed', 'failed'];
const SCAN_STATES = ['passed', 'findings', 'failed', 'not_run'];
const CLEANUP_OUTCOMES = ['success', 'failure', 'preserved', 'pending'];
const RESULT_STATUSES = [0, 2, 4, 5, 6, 130, 143];

export class ContractError extends Error {
  constructor(errors) {
    super(Array.isArray(errors) ? errors.join('\n') : String(errors));
    this.name = 'ContractError';
    this.errors = Array.isArray(errors) ? errors : [String(errors)];
  }
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function nonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function safeFilename(value) {
  return nonEmptyString(value)
    && value !== '.'
    && value !== '..'
    && !/[\\/\u0000-\u001f\u007f]/.test(value);
}

export function isRunId(value) {
  return typeof value === 'string' && RUN_ID_PATTERN.test(value);
}

function parseChecksums(text, errors) {
  const entries = new Map();
  if (typeof text !== 'string' || text.length === 0) {
    errors.push('SHA256SUMS must be non-empty text');
    return entries;
  }
  for (const line of text.trimEnd().split(/\r?\n/)) {
    const match = /^([a-f0-9]{64})  ([^\r\n]+)$/.exec(line);
    if (!match) {
      errors.push('SHA256SUMS contains an invalid sha256sum entry');
      continue;
    }
    if (entries.has(match[2])) errors.push(`SHA256SUMS contains duplicate entry ${match[2]}`);
    entries.set(match[2], match[1]);
  }
  return entries;
}

// Bundle admission: returns a list of errors; an empty list means admissible.
// `files` carries observed facts: { entries, iso, metadata, package_manifest, sha256sums }.
export function validateBundleAdmission(metadata, files) {
  const errors = [];
  if (!isRecord(files)) return ['bundle files must be an object'];
  const { iso, metadata: metadataFile, package_manifest: manifest } = files;
  if (!isRecord(iso) || !isRecord(metadataFile) || !isRecord(manifest)) {
    return ['bundle iso, metadata, and package_manifest observations must be objects'];
  }
  if (!isRecord(metadata)) return ['artifact metadata must be a JSON object'];

  const artifact = isRecord(metadata.artifact) ? metadata.artifact : {};
  const metaIso = isRecord(artifact.iso) ? artifact.iso : {};
  const metaManifest = isRecord(artifact.package_manifest) ? artifact.package_manifest : {};
  const execution = isRecord(metadata.execution) ? metadata.execution : {};

  if (metadata.schema_version !== 1) errors.push('metadata schema_version must be 1');
  if (!nonEmptyString(execution.run_id)) errors.push('metadata execution.run_id must be a non-empty string');
  if (typeof execution.commit !== 'string' || !GIT_ID_PATTERN.test(execution.commit)) {
    errors.push('metadata execution.commit must be a Git object ID');
  }
  if (typeof execution.dirty !== 'boolean') errors.push('metadata execution.dirty must be a boolean');
  if (!safeFilename(metaIso.name)) errors.push('metadata artifact.iso.name must be a safe filename');
  if (!safeFilename(metaManifest.name)) errors.push('metadata artifact.package_manifest.name must be a safe filename');
  if (!SHA256_PATTERN.test(metaIso.sha256 ?? '')) errors.push('metadata artifact.iso.sha256 must be a SHA-256 digest');
  if (!SHA256_PATTERN.test(metaManifest.sha256 ?? '')) errors.push('metadata artifact.package_manifest.sha256 must be a SHA-256 digest');
  if (!Number.isSafeInteger(metaIso.size_bytes) || metaIso.size_bytes <= 0) {
    errors.push('metadata artifact.iso.size_bytes must be a positive integer');
  }
  if (errors.length > 0) return errors;

  const required = [metaIso.name, BUNDLE_CHECKSUM_FILE, BUNDLE_METADATA_FILE, metaManifest.name];
  if (!Array.isArray(files.entries)) return ['bundle entries must be an array'];
  for (const name of required) {
    if (!files.entries.includes(name)) errors.push(`bundle is missing ${name}`);
  }

  if (iso.name !== metaIso.name) errors.push('metadata ISO filename does not match bundle');
  if (iso.size_bytes !== metaIso.size_bytes) errors.push('metadata ISO size does not match bundle');
  if (iso.sha256 !== metaIso.sha256) errors.push('metadata ISO SHA-256 does not match bundle');
  if (manifest.name !== metaManifest.name) errors.push('metadata package manifest filename does not match bundle');
  if (manifest.sha256 !== metaManifest.sha256) errors.push('metadata package manifest SHA-256 does not match bundle');
  if (metadataFile.name !== BUNDLE_METADATA_FILE) errors.push(`metadata file must be named ${BUNDLE_METADATA_FILE}`);

  const sums = parseChecksums(files.sha256sums, errors);
  const expected = new Map([
    [iso.name, iso.sha256],
    [metadataFile.name, metadataFile.sha256],
    [manifest.name, manifest.sha256],
  ]);
  if (sums.size !== expected.size || [...expected.keys()].some(name => !sums.has(name))) {
    errors.push('SHA256SUMS must cover exactly the ISO, artifact metadata, and package manifest');
  }
  for (const [name, digest] of expected) {
    if (sums.has(name) && sums.get(name) !== digest) errors.push(`SHA256SUMS digest does not match ${name}`);
  }
  return errors;
}

// Guest report validation. Returns { errors, passed, failed_checks }.
// A report is accepted as evidence only when `errors` is empty; only then does `passed`
// reflect the checks. No log keywords or absent failures are ever interpreted.
export function validateGuestReport(report, expectedRunId) {
  const errors = [];
  if (!isRecord(report)) return { errors: ['guest report must be an object'], passed: false, failed_checks: [] };
  if (report.schema_version !== 1) errors.push('guest report schema_version must be 1');
  if (!isRunId(expectedRunId)) errors.push('expected run id is not a valid run id');
  if (report.run_id !== expectedRunId) errors.push('guest report run_id does not match the current run');
  if (!isRecord(report.checks)) {
    errors.push('guest report checks must be an object');
    return { errors, passed: false, failed_checks: [] };
  }
  for (const id of Object.keys(report.checks)) {
    if (!CHECK_IDS.includes(id)) errors.push(`guest report contains unknown check ${id}`);
  }
  const failed = [];
  for (const id of CHECK_IDS) {
    const check = report.checks[id];
    if (!isRecord(check)) {
      errors.push(`guest report is missing check ${id}`);
      continue;
    }
    if (!CHECK_STATUSES.includes(check.status)) {
      errors.push(`check ${id} status must be passed or failed`);
      continue;
    }
    if (!nonEmptyString(check.detail)) errors.push(`check ${id} detail must be a non-empty string`);
    if (check.status === 'failed') failed.push(id);
    validateCheckEvidence(id, check, errors);
  }
  if (!CHECK_STATUSES.includes(report.result)) {
    errors.push('guest report result must be passed or failed');
  } else if (report.result !== (failed.length === 0 ? 'passed' : 'failed')) {
    errors.push('guest report result contradicts its checks');
  }
  return { errors, passed: errors.length === 0 && failed.length === 0, failed_checks: failed };
}

function validateCheckEvidence(id, check, errors) {
  const passed = check.status === 'passed';
  if (id === 'ipv4_address') {
    if (passed && !(typeof check.address === 'string' && IPV4_PATTERN.test(check.address))) {
      errors.push('check ipv4_address passed without a valid IPv4 address');
    }
  }
  if (id === 'https_request') {
    if (check.http_status !== null && !Number.isSafeInteger(check.http_status)) {
      errors.push('check https_request http_status must be an integer or null');
    }
    if (typeof check.tls_verified !== 'boolean') {
      errors.push('check https_request tls_verified must be a boolean');
    }
    if (passed && (check.http_status !== 200 || check.tls_verified !== true)) {
      errors.push('check https_request passed without validated TLS and HTTP 200');
    }
    if (!passed && check.http_status === 200 && check.tls_verified === true) {
      errors.push('check https_request failed despite validated TLS and HTTP 200');
    }
  }
}

function validateVm(vm, errors) {
  if (!isRecord(vm)) {
    errors.push('vm_configuration must be an object');
    return;
  }
  if (Object.keys(vm).length === 0) errors.push('vm_configuration must not be empty');
}

function validateStateMap(map, name, states, errors) {
  if (!isRecord(map) || Object.keys(map).length === 0) {
    errors.push(`${name} must be a non-empty object`);
    return;
  }
  for (const [key, state] of Object.entries(map)) {
    if (!nonEmptyString(key) || !states.includes(state)) {
      errors.push(`${name} values must be one of ${states.join(', ')}`);
    }
  }
}

export function validateResultDocument(result) {
  const errors = [];
  if (!isRecord(result)) return ['result must be an object'];
  if (result.schema_version !== 1) errors.push('schema_version must be 1');
  if (!isRunId(result.run_id)) errors.push('run_id must be a valid run id');

  const artifact = isRecord(result.artifact) ? result.artifact : null;
  if (!artifact) {
    errors.push('artifact must be an object');
  } else {
    if (!safeFilename(artifact.iso_name)) errors.push('artifact.iso_name must be a safe filename');
    if (!SHA256_PATTERN.test(artifact.iso_sha256 ?? '')) errors.push('artifact.iso_sha256 must be a SHA-256 digest');
    if (!GIT_ID_PATTERN.test(artifact.build_commit ?? '')) errors.push('artifact.build_commit must be a Git object ID');
    if (!nonEmptyString(artifact.build_run_id)) errors.push('artifact.build_run_id must be a non-empty string');
  }
  const code = isRecord(result.test_code) ? result.test_code : null;
  if (!code) {
    errors.push('test_code must be an object');
  } else {
    if (!GIT_ID_PATTERN.test(code.commit ?? '')) errors.push('test_code.commit must be a Git object ID');
    if (typeof code.dirty !== 'boolean') errors.push('test_code.dirty must be a boolean');
  }
  validateVm(result.vm_configuration, errors);
  if (!isRecord(result.versions) || !nonEmptyString(result.versions.qemu) || !nonEmptyString(result.versions.ovmf)) {
    errors.push('versions.qemu and versions.ovmf must be non-empty strings');
  }

  if (!isRecord(result.checks)) {
    errors.push('checks must be an object');
  } else {
    for (const id of CHECK_IDS) {
      const state = result.checks[id];
      if (!['passed', 'failed', 'not_run'].includes(state)) errors.push(`checks.${id} must be passed, failed, or not_run`);
    }
    for (const id of Object.keys(result.checks)) {
      if (!CHECK_IDS.includes(id)) errors.push(`checks contains unknown check ${id}`);
    }
  }
  if (typeof result.duration_seconds !== 'number' || !Number.isFinite(result.duration_seconds) || result.duration_seconds < 0) {
    errors.push('duration_seconds must be a non-negative finite number');
  }
  if (result.failed_stage !== null && !nonEmptyString(result.failed_stage)) errors.push('failed_stage must be a non-empty string or null');
  if (result.next_action !== null && !nonEmptyString(result.next_action)) errors.push('next_action must be a non-empty string or null');
  if (!RESULT_STATUSES.includes(result.status)) errors.push(`status must be one of ${RESULT_STATUSES.join(', ')}`);
  if (!isRecord(result.original_tool_statuses)) {
    errors.push('original_tool_statuses must be an object');
  } else {
    for (const status of Object.values(result.original_tool_statuses)) {
      if (status !== null && !Number.isSafeInteger(status)) errors.push('original_tool_statuses values must be integers or null');
    }
  }
  validateStateMap(result.scans, 'scans', SCAN_STATES, errors);

  const cleanup = isRecord(result.cleanup) ? result.cleanup : null;
  if (!cleanup) {
    errors.push('cleanup must be an object');
  } else {
    if (!CLEANUP_OUTCOMES.includes(cleanup.outcome)) errors.push(`cleanup.outcome must be one of ${CLEANUP_OUTCOMES.join(', ')}`);
    if (!Array.isArray(cleanup.leftover_resources) || cleanup.leftover_resources.some(item => !nonEmptyString(item))) {
      errors.push('cleanup.leftover_resources must be an array of non-empty strings');
    }
    if (cleanup.recovery_guidance !== null && !nonEmptyString(cleanup.recovery_guidance)) {
      errors.push('cleanup.recovery_guidance must be a non-empty string or null');
    }
  }
  if (result.nocloud_note !== NOCLOUD_NOTE) errors.push('nocloud_note must state that an auxiliary NoCloud medium was used');

  if (result.status === 0) {
    if (isRecord(result.checks) && CHECK_IDS.some(id => result.checks[id] !== 'passed')) errors.push('status 0 requires every check passed');
    if (isRecord(result.scans) && Object.values(result.scans).some(state => state !== 'passed')) errors.push('status 0 requires every scan passed');
    if (cleanup && cleanup.outcome !== 'success') errors.push('status 0 requires cleanup success');
    if (result.failed_stage !== null) errors.push('status 0 requires failed_stage null');
    if (isRecord(result.original_tool_statuses) && Object.values(result.original_tool_statuses).some(status => status !== 0)) {
      errors.push('status 0 requires every original tool status to be 0');
    }
  } else {
    if (!nonEmptyString(result.failed_stage)) errors.push('non-zero status requires failed_stage');
    if (!nonEmptyString(result.next_action)) errors.push('non-zero status requires next_action');
  }
  if (result.status === 4 && isRecord(result.checks) && !CHECK_IDS.some(id => result.checks[id] === 'failed')) {
    errors.push('status 4 requires at least one failed check');
  }
  return errors;
}

export function buildResultDocument(fields) {
  if (!isRecord(fields)) throw new ContractError('result input must be an object');
  const document = { ...structuredClone(fields), schema_version: 1, nocloud_note: NOCLOUD_NOTE };
  const errors = validateResultDocument(document);
  if (errors.length > 0) throw new ContractError(errors);
  return document;
}

// Terminal summary: derived only from the result document, never from raw guest logs.
export function renderSummary(result) {
  const errors = validateResultDocument(result);
  if (errors.length > 0) throw new ContractError(errors);
  const lines = [
    `Reference VM bootstrap qualification: ${result.status === 0 ? 'PASSED' : 'NOT QUALIFIED'} (exit ${result.status})`,
    `Run: ${result.run_id}`,
    `Artifact: ${result.artifact.iso_name} (sha256 ${result.artifact.iso_sha256})`,
    `Test code: ${result.test_code.commit}${result.test_code.dirty ? ' (dirty)' : ''}`,
    `Duration: ${result.duration_seconds}s`,
    'Checks:',
    ...CHECK_IDS.map(id => `  ${id}: ${result.checks[id]}`),
    'Scans:',
    ...Object.entries(result.scans).map(([name, state]) => `  ${name}: ${state}`),
    `Cleanup: ${result.cleanup.outcome}`,
  ];
  if (result.failed_stage !== null) lines.push(`Failed stage: ${result.failed_stage}`);
  if (result.next_action !== null) lines.push(`Next action: ${result.next_action}`);
  if (result.cleanup.leftover_resources.length > 0) {
    lines.push(`Preserved resources: ${result.cleanup.leftover_resources.join(', ')}`);
  }
  if (result.cleanup.recovery_guidance !== null) lines.push(`Recovery: ${result.cleanup.recovery_guidance}`);
  return `${lines.join('\n')}\n`;
}
