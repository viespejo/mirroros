import { chmodSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';

import { validateResult } from '../postconditions/evaluate.mjs';

export const ENGINE_RUN_FORMAT_VERSION = 2;
export const ENGINE_STATE_FORMAT_VERSION = 2;
export const POSTCONDITIONS_OPERATION = 'postconditions';
export const STATE_STATUSES = ['running', 'installed', 'not_verified', 'failed', 'blocked', 'invalidated'];
export const RUN_OUTCOMES = ['installed', 'not_verified', 'blocked', 'invalidated', 'failed'];
export const OPERATION_STATUSES = ['pending', 'running', 'completed', 'failed'];

const SECRET_KEY = /password|passphrase|secret|token/i;
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);

function assertNoSecretKeys(value, path = 'document') {
  if (Array.isArray(value)) value.forEach((item, index) => assertNoSecretKeys(item, `${path}[${index}]`));
  else if (isRecord(value)) {
    for (const [key, inner] of Object.entries(value)) {
      if (SECRET_KEY.test(key)) throw new Error(`${path}.${key} looks like a secret field`);
      assertNoSecretKeys(inner, `${path}.${key}`);
    }
  }
}

export function validateState(state) {
  const errors = [];
  if (state.format_version !== ENGINE_STATE_FORMAT_VERSION) errors.push('format_version must be 2');
  if (!STATE_STATUSES.includes(state.status)) errors.push('status is not allowed');
  if (!Number.isInteger(state.index) || state.index < 0) errors.push('index must be a non-negative integer');
  if (!Number.isInteger(state.total) || state.total < 0) errors.push('total must be a non-negative integer');
  if (!Array.isArray(state.operations) || state.operations.length !== state.total) errors.push('operations must list every operation');
  else {
    for (const operation of state.operations) {
      if (typeof operation.id !== 'string' || typeof operation.description !== 'string'
        || !OPERATION_STATUSES.includes(operation.status)) errors.push(`operation ${operation.id} is malformed`);
    }
  }
  if (state.packages_installed !== undefined && !(Number.isInteger(state.packages_installed) && state.packages_installed >= 0)) {
    errors.push('packages_installed must be a non-negative integer');
  }
  if (typeof state.updated_at !== 'string') errors.push('updated_at is missing');
  return errors;
}

export function validateRun(run) {
  const errors = [];
  if (run.format_version !== ENGINE_RUN_FORMAT_VERSION) errors.push('format_version must be 2');
  if (!RUN_OUTCOMES.includes(run.outcome)) errors.push('outcome is not allowed');
  if (!Number.isInteger(run.exit_status) || run.exit_status < 0 || run.exit_status > 255) errors.push('exit_status must be 0..255');
  for (const key of ['started_at', 'finished_at']) if (typeof run[key] !== 'string') errors.push(`${key} is missing`);
  for (const key of ['reasons', 'completed', 'not_started']) if (!Array.isArray(run[key])) errors.push(`${key} must be a list`);
  if (run.outcome === 'installed' && (run.exit_status !== 0 || run.reasons.length > 0 || run.not_started.length > 0)) {
    errors.push('an installed run has status 0, no reasons, and no pending operation');
  }
  if (run.outcome === 'installed' && run.postconditions?.status !== 'passed') errors.push('an installed run has passed postconditions');
  if (run.outcome === 'not_verified') {
    if (run.exit_status !== 4) errors.push('a not_verified run exits 4');
    if (run.postconditions?.status !== 'failed') errors.push('a not_verified run has failed postconditions');
    if (!Array.isArray(run.not_started) || run.not_started.length > 0) errors.push('a not_verified run has no pending operation');
    if (!Array.isArray(run.reasons) || run.reasons.length === 0 || !run.reasons.every(item => item.code === 'postcondition_failed')) {
      errors.push('a not_verified run has one postcondition_failed reason per failed check');
    }
  }
  if (run.exit_status === 4 && run.outcome !== 'not_verified') errors.push('only a not_verified run exits 4');
  if (run.postconditions !== undefined) {
    for (const problem of validateResult(run.postconditions)) errors.push(`postconditions: ${problem}`);
  }
  if (run.outcome !== 'installed' && run.exit_status === 0) errors.push('only an installed run exits 0');
  for (const item of run.reasons ?? []) {
    for (const key of ['code', 'stage', 'message', 'next_step']) if (typeof item[key] !== 'string') errors.push(`a reason lacks ${key}`);
  }
  return errors;
}

// Writes the document to a temporary file of the same directory, re-reads and validates it, and renames it.
export function writeAtomic(path, document, validate) {
  assertNoSecretKeys(document);
  const errors = validate(document);
  if (errors.length > 0) throw new Error(`${path}: ${errors.join('; ')}`);
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const temporary = `${path}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
  chmodSync(temporary, 0o600);
  const reread = JSON.parse(readFileSync(temporary, 'utf8'));
  const problems = validate(reread);
  if (problems.length > 0) throw new Error(`${path}: ${problems.join('; ')}`);
  renameSync(temporary, path);
}

export function operationsOf(planText) {
  if (planText.trim() === '') return [];
  return JSON.parse(planText).operations.map(({ id, description }) => ({ id, description }));
}

function list(value) {
  return value === undefined || value === '' ? [] : value.split(',');
}

export function buildState({ operations, status, current, completed, failed, packages, now }) {
  const done = new Set(completed);
  const states = operations.map(operation => {
    let operationStatus = 'pending';
    if (done.has(operation.id)) operationStatus = 'completed';
    else if (operation.id === failed) operationStatus = 'failed';
    else if (operation.id === current) operationStatus = 'running';
    return { id: operation.id, description: operation.description, status: operationStatus };
  });
  const position = current === undefined ? -1 : operations.findIndex(operation => operation.id === current);
  const state = {
    format_version: ENGINE_STATE_FORMAT_VERSION,
    status,
    ...(current === undefined ? {} : { current }),
    index: current === POSTCONDITIONS_OPERATION ? operations.length : position === -1 ? done.size : position + 1,
    total: operations.length,
    operations: states,
    ...(packages === undefined ? {} : { packages_installed: packages }),
    updated_at: now,
  };
  return state;
}

function pairs(values, label) {
  const result = {};
  for (const item of values ?? []) {
    const separator = item.indexOf('=');
    if (separator < 1) throw new Error(`${label} needs key=value: ${item}`);
    result[item.slice(0, separator)] = item.slice(separator + 1);
  }
  return result;
}

function nested(values, label) {
  const result = {};
  for (const [path, value] of Object.entries(pairs(values, label))) {
    const [group, ...rest] = path.split('.');
    if (rest.length === 0) result[group] = value;
    else (result[group] ??= {})[rest.join('.')] = value;
  }
  return result;
}

// One reason per failed check, in suite order; the detail is non-secret by the postconditions contract.
function postconditionReasons(postconditions) {
  return postconditions.checks.filter(check => check.status === 'failed').map(check => ({
    code: 'postcondition_failed',
    stage: 'engine',
    operation: POSTCONDITIONS_OPERATION,
    message: `The check ${check.id} failed: ${check.detail}`,
    next_step: 'Do not rely on the installed system; the full result is in the run directory, and a new installation attempt is a new run with a new plan and confirmation.',
  }));
}

// The engine's validation of the checker's answer: a valid document for this plan whose status agrees with the
// checker's exit status (0 passed, 4 failed). Answers `valid:<failed check ids>` or `invalid`.
export function verifyPostconditions({ planText, result, exit }) {
  let document;
  try {
    document = JSON.parse(result);
  } catch {
    return 'invalid';
  }
  const agrees = (exit === '0' && document?.status === 'passed') || (exit === '4' && document?.status === 'failed');
  if (!agrees || validateResult(document, JSON.parse(planText)).length > 0) return 'invalid';
  return `valid:${document.failed_checks.join(',')}`;
}

export function buildRun({ planText, options, now }) {
  const operations = operationsOf(planText);
  const completed = list(options.completed?.[0]);
  const failedId = options['failed-operation']?.[0];
  const childStatus = options['child-status']?.[0];
  const run = {
    format_version: ENGINE_RUN_FORMAT_VERSION,
    started_at: options.started?.[0],
    finished_at: now,
  };
  if (options.digest?.[0] !== undefined) run.plan_digest = options.digest[0];
  if (options.commit?.[0] !== undefined) run.code_identity = { commit: options.commit[0], dirty: options.dirty?.[0] === 'true' };
  if (planText.trim() !== '') {
    const plan = JSON.parse(planText);
    run.storage_option = plan.choices.storage_option.value;
    run.hibernation = plan.choices.hibernation.value;
  }
  run.outcome = options.outcome?.[0];
  run.exit_status = Number(options.exit?.[0]);
  const postconditions = options.postconditions === undefined ? undefined : JSON.parse(options.postconditions[0]);
  run.reasons = postconditions !== undefined && run.outcome === 'not_verified' ? postconditionReasons(postconditions) : options['reason-code'] === undefined ? [] : [{
    code: options['reason-code'][0],
    stage: 'engine',
    operation: options['reason-operation']?.[0] ?? 'precheck',
    message: options['reason-message']?.[0] ?? '',
    next_step: options['reason-next-step']?.[0] ?? '',
    ...(childStatus === undefined ? {} : { child_exit_status: Number(childStatus) }),
  }];
  run.completed = completed;
  run.not_started = operations.map(operation => operation.id).filter(id => !completed.includes(id) && id !== failedId);
  if (failedId !== undefined) {
    run.failed_operation = {
      id: failedId,
      command: options['failed-arg'] ?? [],
      ...(childStatus === undefined ? {} : { child_exit_status: Number(childStatus) }),
    };
  }
  if (postconditions !== undefined) run.postconditions = postconditions;
  const resolved = pairs(options.resolved, 'resolved');
  if (Object.keys(resolved).length > 0) {
    if (resolved.resume_offset !== undefined) resolved.resume_offset = Number(resolved.resume_offset);
    run.resolved = resolved;
  }
  if (options.server !== undefined || options['mirrorlist-sha256'] !== undefined) {
    run.mirrors = { servers: options.server ?? [], mirrorlist_sha256: options['mirrorlist-sha256']?.[0] };
  }
  const constants = nested(options.constant, 'constant');
  if (Object.keys(constants).length > 0) run.constants = constants;
  const cleanup = pairs(options.cleanup, 'cleanup');
  if (Object.keys(cleanup).length > 0) run.cleanup = cleanup;
  return run;
}

export function parseOptions(args) {
  const options = {};
  for (let index = 0; index < args.length; index += 2) {
    const name = args[index];
    if (!name.startsWith('--') || index + 1 >= args.length) throw new Error(`bad option: ${name}`);
    (options[name.slice(2)] ??= []).push(args[index + 1]);
  }
  return options;
}

function main(args) {
  const [mode, ...rest] = args;
  const options = parseOptions(rest);
  const output = options.output?.[0];
  const planText = readFileSync(0, 'utf8');
  const now = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  if (mode === 'verify-postconditions') {
    process.stdout.write(verifyPostconditions({ planText, result: options.result?.[0], exit: options.exit?.[0] }));
    return;
  }
  if (output === undefined) throw new Error('--output is required');
  if (mode === 'state') {
    const state = buildState({
      operations: operationsOf(planText),
      status: options.status?.[0],
      current: options.current?.[0],
      completed: list(options.completed?.[0]),
      failed: options.failed?.[0],
      packages: options.packages === undefined ? undefined : Number(options.packages[0]),
      now,
    });
    writeAtomic(join(output, 'state.json'), state, validateState);
  } else if (mode === 'run') {
    writeAtomic(join(output, 'engine-run.json'), buildRun({ planText, options, now }), validateRun);
  } else {
    throw new Error(`unknown mode: ${mode}`);
  }
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`The engine record writer failed: ${error.message}\n`);
    process.exitCode = 6;
  }
}
