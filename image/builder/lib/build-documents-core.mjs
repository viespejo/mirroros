const SECRET_SCAN_SCOPE = 'mirroros-created-content';
const CONTROL_OUTCOMES = [
  'signature_verification',
  'archiso_version',
  'profile_secret_scan',
  'evidence_secret_scan',
  'bundle_validation',
];
const VALIDATION_STATES = ['passed', 'failed', 'not_run', 'unknown'];
const RESULT_OUTCOMES = ['success', 'failure', 'interrupted', 'unknown'];
const CLEANUP_OUTCOMES = ['success', 'failure', 'pending', 'unknown'];
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const GIT_TREE_PATTERN = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i;

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

function objectAt(parent, key, path, errors) {
  const value = parent?.[key];
  if (!isRecord(value)) {
    errors.push(`${path} must be an object`);
    return {};
  }
  return value;
}

function nonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function stringField(object, key, path, errors) {
  if (!nonEmptyString(object?.[key])) errors.push(`${path} must be a non-empty string`);
}

function nullableStringField(object, key, path, errors) {
  const value = object?.[key];
  if (value !== null && typeof value !== 'string') errors.push(`${path} must be a string or null`);
  if (typeof value === 'string' && value.length === 0) errors.push(`${path} must be non-empty or null`);
}

function stringArrayField(object, key, path, errors) {
  const value = object?.[key];
  if (!Array.isArray(value) || value.some(item => !nonEmptyString(item))) {
    errors.push(`${path} must be an array of non-empty strings`);
  }
}

function safeFilename(value) {
  return nonEmptyString(value)
    && value !== '.'
    && value !== '..'
    && !/[\\/\u0000-\u001f\u007f]/.test(value);
}

function validateHash(value, path, errors) {
  if (typeof value !== 'string' || !SHA256_PATTERN.test(value)) {
    errors.push(`${path} must be a lowercase SHA-256 digest`);
  }
}

export function validateArtifactMetadata(metadata) {
  const errors = [];
  if (!isRecord(metadata)) return ['metadata must be an object'];
  if (metadata.schema_version !== 1) errors.push('schema_version must be 1');

  const execution = objectAt(metadata, 'execution', 'execution', errors);
  stringField(execution, 'run_id', 'execution.run_id', errors);
  if (typeof execution.commit !== 'string' || !GIT_TREE_PATTERN.test(execution.commit)) {
    errors.push('execution.commit must be a 40- or 64-character Git object ID');
  }
  if (typeof execution.dirty !== 'boolean') errors.push('execution.dirty must be a boolean');
  stringField(execution, 'profile_identity', 'execution.profile_identity', errors);
  stringArrayField(execution, 'dirty_paths', 'execution.dirty_paths', errors);

  const construction = objectAt(metadata, 'construction', 'construction', errors);
  stringField(construction, 'architecture', 'construction.architecture', errors);
  if (typeof construction.image_digest !== 'string' || !/^sha256:[a-f0-9]{64}$/.test(construction.image_digest)) {
    errors.push('construction.image_digest must be a sha256 digest');
  }
  stringField(construction, 'archiso_version', 'construction.archiso_version', errors);
  if (!Number.isSafeInteger(construction.source_date_epoch) || construction.source_date_epoch < 0) {
    errors.push('construction.source_date_epoch must be a non-negative safe integer');
  }
  if (!isRecord(construction.tool_versions) || Object.keys(construction.tool_versions).length === 0) {
    errors.push('construction.tool_versions must be a non-empty object');
  } else {
    for (const [tool, version] of Object.entries(construction.tool_versions)) {
      if (!nonEmptyString(tool) || !nonEmptyString(version)) errors.push('construction.tool_versions values must be non-empty strings');
    }
  }
  const cosign = objectAt(construction, 'cosign', 'construction.cosign', errors);
  stringField(cosign, 'identity', 'construction.cosign.identity', errors);
  stringField(cosign, 'issuer', 'construction.cosign.issuer', errors);

  const repository = objectAt(metadata, 'repository_configuration', 'repository_configuration', errors);
  stringField(repository, 'pacman_conf', 'repository_configuration.pacman_conf', errors);
  const mirrorlist = objectAt(repository, 'mirrorlist', 'repository_configuration.mirrorlist', errors);
  stringField(mirrorlist, 'path', 'repository_configuration.mirrorlist.path', errors);
  validateHash(mirrorlist.sha256, 'repository_configuration.mirrorlist.sha256', errors);

  const artifact = objectAt(metadata, 'artifact', 'artifact', errors);
  const iso = objectAt(artifact, 'iso', 'artifact.iso', errors);
  if (!safeFilename(iso.name)) errors.push('artifact.iso.name must be a safe filename');
  if (!Number.isSafeInteger(iso.size_bytes) || iso.size_bytes <= 0) errors.push('artifact.iso.size_bytes must be a positive safe integer');
  validateHash(iso.sha256, 'artifact.iso.sha256', errors);
  const manifest = objectAt(artifact, 'package_manifest', 'artifact.package_manifest', errors);
  if (!safeFilename(manifest.name)) errors.push('artifact.package_manifest.name must be a safe filename');
  validateHash(manifest.sha256, 'artifact.package_manifest.sha256', errors);

  const controls = objectAt(metadata, 'controls', 'controls', errors);
  if (controls.secret_scan_scope !== SECRET_SCAN_SCOPE) errors.push(`controls.secret_scan_scope must be ${SECRET_SCAN_SCOPE}`);
  const outcomes = objectAt(controls, 'outcomes', 'controls.outcomes', errors);
  for (const control of CONTROL_OUTCOMES) {
    if (outcomes[control] !== 'passed') errors.push(`controls.outcomes.${control} must be passed`);
  }
  for (const [control, outcome] of Object.entries(outcomes)) {
    if (!nonEmptyString(control) || outcome !== 'passed') errors.push('all controls.outcomes values must be passed');
  }

  stringArrayField(metadata, 'traceability_limitations', 'traceability_limitations', errors);
  if (metadata.boot_qualification !== 'not_performed') errors.push('boot_qualification must be not_performed');

  if (typeof execution.dirty === 'boolean' && Array.isArray(execution.dirty_paths)) {
    if (execution.dirty && execution.profile_identity !== 'dirty-path-list') {
      errors.push('dirty execution.profile_identity must be dirty-path-list');
    }
    if (execution.dirty && Array.isArray(metadata.traceability_limitations) && metadata.traceability_limitations.length === 0) {
      errors.push('dirty metadata must include a traceability limitation');
    }
    if (!execution.dirty && !GIT_TREE_PATTERN.test(execution.profile_identity)) {
      errors.push('clean execution.profile_identity must be a Git tree hash');
    }
    if (!execution.dirty && execution.dirty_paths.length > 0) {
      errors.push('clean execution.dirty_paths must be empty');
    }
  }
  return errors;
}

export function buildArtifactMetadata(fields) {
  if (!isRecord(fields)) throw new ContractError('metadata input must be an object');
  const document = { ...structuredClone(fields), schema_version: 1 };
  const errors = validateArtifactMetadata(document);
  if (errors.length > 0) throw new ContractError(errors);
  return document;
}

function validTimestamp(value) {
  return typeof value === 'string' && value.trim().length > 0 && Number.isFinite(Date.parse(value));
}

export function validateExecutionResult(result) {
  const errors = [];
  if (!isRecord(result)) return ['execution result must be an object'];
  if (result.schema_version !== 1) errors.push('schema_version must be 1');
  stringField(result, 'run_id', 'run_id', errors);

  const references = objectAt(result, 'references', 'references', errors);
  stringArrayField(references, 'sources', 'references.sources', errors);
  stringArrayField(references, 'artifacts', 'references.artifacts', errors);

  if (!validTimestamp(result.started_at)) errors.push('started_at must be a valid timestamp');
  if (result.ended_at !== null && !validTimestamp(result.ended_at)) errors.push('ended_at must be a valid timestamp or null');
  if (result.duration_seconds !== null && (typeof result.duration_seconds !== 'number' || !Number.isFinite(result.duration_seconds) || result.duration_seconds < 0)) {
    errors.push('duration_seconds must be a non-negative finite number or null');
  }
  if (!RESULT_OUTCOMES.includes(result.outcome)) errors.push(`outcome must be one of ${RESULT_OUTCOMES.join(', ')}`);
  if (result.exit_status !== null && !Number.isSafeInteger(result.exit_status)) errors.push('exit_status must be a safe integer or null');
  nullableStringField(result, 'failed_stage', 'failed_stage', errors);
  if (!isRecord(result.original_tool_statuses)) {
    errors.push('original_tool_statuses must be an object');
  } else {
    for (const [tool, status] of Object.entries(result.original_tool_statuses)) {
      if (!nonEmptyString(tool) || (status !== null && !Number.isSafeInteger(status))) {
        errors.push('original_tool_statuses values must be safe integers or null');
      }
    }
  }

  if (!isRecord(result.validations) || Object.keys(result.validations).length === 0) {
    errors.push('validations must be a non-empty object');
  } else {
    for (const [validation, state] of Object.entries(result.validations)) {
      if (!nonEmptyString(validation) || !VALIDATION_STATES.includes(state)) {
        errors.push('validations values must be passed, failed, not_run, or unknown');
      }
    }
  }
  stringArrayField(result, 'diagnostic_references', 'diagnostic_references', errors);
  if (result.published !== null && typeof result.published !== 'boolean') errors.push('published must be a boolean or null');

  const cleanup = objectAt(result, 'cleanup', 'cleanup', errors);
  if (!CLEANUP_OUTCOMES.includes(cleanup.outcome)) errors.push(`cleanup.outcome must be one of ${CLEANUP_OUTCOMES.join(', ')}`);
  stringArrayField(cleanup, 'leftover_resources', 'cleanup.leftover_resources', errors);
  nullableStringField(cleanup, 'recovery_guidance', 'cleanup.recovery_guidance', errors);

  if (result.outcome === 'success') {
    if (result.exit_status !== 0) errors.push('success requires exit_status 0');
    if (result.published !== true) errors.push('success requires published true');
    if (cleanup.outcome !== 'success') errors.push('success requires cleanup.outcome success');
    if (result.ended_at === null || result.duration_seconds === null) errors.push('success requires known end time and duration');
    if (result.failed_stage !== null) errors.push('success requires failed_stage null');
    if (!isRecord(result.validations) || Object.keys(result.validations).length === 0 || Object.values(result.validations).some(state => state !== 'passed')) {
      errors.push('success requires every validation to be passed');
    }
    if (isRecord(result.original_tool_statuses) && Object.values(result.original_tool_statuses).some(status => status !== 0)) {
      errors.push('success cannot contain unknown or non-zero original tool statuses');
    }
  }
  if (result.outcome === 'failure' && (result.exit_status === null || result.exit_status === 0)) {
    errors.push('failure requires a non-zero exit_status');
  }
  if (result.outcome === 'failure' && !nonEmptyString(result.failed_stage)) {
    errors.push('failure requires failed_stage');
  }
  if (result.outcome === 'interrupted' && ![130, 143].includes(result.exit_status)) {
    errors.push('interrupted requires exit_status 130 or 143');
  }
  if (result.outcome === 'unknown' && result.exit_status !== null) {
    errors.push('unknown outcome requires exit_status null');
  }
  return errors;
}

export function buildExecutionResult(fields) {
  if (!isRecord(fields)) throw new ContractError('execution result input must be an object');
  const document = { ...structuredClone(fields), schema_version: 1 };
  const errors = validateExecutionResult(document);
  if (errors.length > 0) throw new ContractError(errors);
  return document;
}

function parseChecksums(text, errors) {
  if (typeof text !== 'string' || text.length === 0) {
    errors.push('SHA256SUMS must be non-empty text');
    return new Map();
  }
  const entries = new Map();
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

export function validateBundle(metadata, files) {
  const errors = validateArtifactMetadata(metadata);
  if (!isRecord(files)) return [...errors, 'bundle files must be an object'];
  if (!isRecord(metadata)) return errors;
  const iso = files.iso;
  const metadataFile = files.metadata;
  const manifest = files.package_manifest;
  for (const [key, file] of [['iso', iso], ['metadata', metadataFile], ['package_manifest', manifest]]) {
    if (!isRecord(file)) errors.push(`bundle ${key} must be an object`);
  }
  if (!isRecord(iso) || !isRecord(metadataFile) || !isRecord(manifest)) return errors;

  if (!safeFilename(iso.name)) errors.push('bundle iso.name must be a safe filename');
  if (!Number.isSafeInteger(iso.size_bytes) || iso.size_bytes <= 0) errors.push('bundle iso.size_bytes must be a positive safe integer');
  validateHash(iso.sha256, 'bundle iso.sha256', errors);
  if (metadataFile.name !== 'artifact-metadata.json') errors.push('bundle metadata.name must be artifact-metadata.json');
  validateHash(metadataFile.sha256, 'bundle metadata.sha256', errors);
  if (!safeFilename(manifest.name)) errors.push('bundle package_manifest.name must be a safe filename');
  validateHash(manifest.sha256, 'bundle package_manifest.sha256', errors);

  if (isRecord(metadata.artifact)) {
    if (metadata.artifact.iso?.name !== iso.name) errors.push('metadata ISO filename does not match bundle');
    if (metadata.artifact.iso?.size_bytes !== iso.size_bytes) errors.push('metadata ISO size does not match bundle');
    if (metadata.artifact.iso?.sha256 !== iso.sha256) errors.push('metadata ISO SHA-256 does not match bundle');
    if (metadata.artifact.package_manifest?.name !== manifest.name) errors.push('metadata package manifest filename does not match bundle');
    if (metadata.artifact.package_manifest?.sha256 !== manifest.sha256) errors.push('metadata package manifest SHA-256 does not match bundle');
  }

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
