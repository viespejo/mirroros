import { CHOICES_FORMAT_VERSION, PROFILE_STATUSES } from '../plan/validate-plan.mjs';
import { OUTCOMES } from './outcomes.mjs';
import { validateTiming } from '../engine/engine-record.mjs';

export const RECORD_FORMAT_VERSION = 7;
export const ENTRIES = ['guided', 'plan_file'];
export const STAGES = ['preparation', 'discovery_initial', 'plan', 'review', 'confirmation', 'password', 'discovery_final', 'engine'];

export class RecordContractError extends Error {
  constructor(errors) {
    super(Array.isArray(errors) ? errors.join('\n') : String(errors));
    this.name = 'RecordContractError';
    this.errors = Array.isArray(errors) ? errors : [String(errors)];
  }
}

const SECRET_LIKE_KEY = /password|passphrase|secret|token/i;
const HEX_64 = /^[0-9a-f]{64}$/;
const RFC_3339 = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const DISK_KEYS = ['path', 'by_id', 'wwn', 'serial', 'model', 'size_bytes'];
const MACHINE_DMI_KEYS = ['sys_vendor', 'product_name'];
const REASON_REQUIRED = ['code', 'stage', 'operation', 'message', 'next_step'];
const REASON_OPTIONAL = ['child_exit_status'];

const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const isText = value => typeof value === 'string' && value !== '';

function secretKeys(value, path, problems) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => secretKeys(item, `${path}[${index}]`, problems));
  } else if (isRecord(value)) {
    for (const [key, item] of Object.entries(value)) {
      if (SECRET_LIKE_KEY.test(key)) problems.push(`${path}.${key} is a secret-like key`);
      secretKeys(item, `${path}.${key}`, problems);
    }
  }
}

function checkFields(value, path, required, optional, problems) {
  if (!isRecord(value)) {
    problems.push(`${path} must be an object`);
    return false;
  }
  for (const key of required) if (!(key in value)) problems.push(`${path}.${key} is required`);
  for (const key of Object.keys(value)) {
    if (!required.includes(key) && !optional.includes(key)) problems.push(`${path}.${key} is not a known field`);
  }
  return true;
}

function checkMachine(machine, path, problems) {
  if (!checkFields(machine, path, ['architecture'], ['memory_total_bytes', 'virtualization', 'dmi'], problems)) return;
  if (!isText(machine.architecture)) problems.push(`${path}.architecture must be a non-empty string`);
  if ('memory_total_bytes' in machine && !(Number.isSafeInteger(machine.memory_total_bytes) && machine.memory_total_bytes > 0)) {
    problems.push(`${path}.memory_total_bytes must be a positive integer`);
  }
  if ('virtualization' in machine && !isText(machine.virtualization)) problems.push(`${path}.virtualization must be a non-empty string`);
  if ('dmi' in machine && checkFields(machine.dmi, `${path}.dmi`, [], MACHINE_DMI_KEYS, problems)) {
    if (Object.keys(machine.dmi).length === 0) problems.push(`${path}.dmi must not be empty`);
    for (const key of MACHINE_DMI_KEYS) {
      if (key in machine.dmi && !isText(machine.dmi[key])) problems.push(`${path}.dmi.${key} must be a non-empty string`);
    }
  }
}

function checkProfile(profile, path, problems) {
  if (!checkFields(profile, path, ['status'], ['profile_id'], problems)) return;
  if (!PROFILE_STATUSES.includes(profile.status)) {
    problems.push(`${path}.status must be one of ${PROFILE_STATUSES.join(', ')}`);
  } else if (profile.status === 'matched') {
    if (!isText(profile.profile_id)) problems.push(`${path}.profile_id is required for a matched profile`);
  } else if ('profile_id' in profile) {
    problems.push(`${path}.profile_id is only allowed for a matched profile`);
  }
}

function checkCommon(document, path, problems) {
  if (![6, RECORD_FORMAT_VERSION].includes(document.format_version)) problems.push(`${path}.format_version must be 6 or ${RECORD_FORMAT_VERSION}`);
  if (!isText(document.run_id)) problems.push(`${path}.run_id must be a non-empty string`);
  if (typeof document.timestamp !== 'string' || !RFC_3339.test(document.timestamp)) problems.push(`${path}.timestamp must be RFC 3339 UTC`);
  if ('gum_version' in document && !isText(document.gum_version)) problems.push(`${path}.gum_version must be a non-empty string`);
  if (!(document.outcome in OUTCOMES)) problems.push(`${path}.outcome is not a known outcome`);
  if ('machine' in document) checkMachine(document.machine, `${path}.machine`, problems);
  if ('profile' in document) checkProfile(document.profile, `${path}.profile`, problems);
}

function checkReason(item, path, problems) {
  if (!checkFields(item, path, REASON_REQUIRED, REASON_OPTIONAL, problems)) return;
  for (const key of REASON_REQUIRED) if (!isText(item[key])) problems.push(`${path}.${key} must be a non-empty string`);
  if (item.stage !== 'install') problems.push(`${path}.stage must be install`);
  if ('child_exit_status' in item && !Number.isInteger(item.child_exit_status)) problems.push(`${path}.child_exit_status must be an integer`);
}

// The stages reached are listed in flow order, each at most once.
function checkStages(stages, path, problems) {
  if (!Array.isArray(stages) || !stages.every(stage => STAGES.includes(stage))) {
    problems.push(`${path} must be a list of known stages`);
    return;
  }
  const positions = stages.map(stage => STAGES.indexOf(stage));
  if (!positions.every((position, index) => index === 0 || position > positions[index - 1])) {
    problems.push(`${path} must list each stage once, in flow order`);
  }
}

export function validateRunRecord(document) {
  const problems = [];
  const required = ['format_version', 'run_id', 'timestamp', 'entry', 'stages', 'digests', 'exit_status', 'outcome', 'reasons'];
  if (!checkFields(document, 'run', required, ['machine', 'profile', 'gum_version', 'final_digest', 'timing'], problems)) return problems;
  if (document.format_version === RECORD_FORMAT_VERSION) {
    problems.push(...validateTiming(document.timing));
    const classes = { preparation: 'mixed', review: 'interactive', confirmation: 'interactive', password: 'interactive' };
    if (Array.isArray(document.timing?.intervals) && Array.isArray(document.stages)) {
      for (const item of document.timing.intervals) {
        if (!document.stages.includes(item?.id) || item?.classification !== (classes[item?.id] ?? 'automated')) {
          problems.push('timing interval must identify a reached stage with its classification');
        }
      }
      for (const stage of document.stages) {
        if (!document.timing.intervals.some(item => item?.id === stage)) problems.push(`timing is missing reached stage ${stage}`);
      }
    }
  } else if (document.timing !== undefined) problems.push('legacy runs have no timing');
  secretKeys(document, 'run', problems);
  checkCommon(document, 'run', problems);
  if (!ENTRIES.includes(document.entry)) problems.push(`run.entry must be one of ${ENTRIES.join(', ')}`);
  checkStages(document.stages, 'run.stages', problems);
  if (!Array.isArray(document.digests) || !document.digests.every(value => HEX_64.test(value))) {
    problems.push('run.digests must be a list of SHA-256 hex digests');
  }
  if ('final_digest' in document) {
    if (!HEX_64.test(document.final_digest)) problems.push('run.final_digest must be a SHA-256 hex digest');
    else if (Array.isArray(document.digests) && document.digests.at(-1) !== document.final_digest) problems.push('run.final_digest must be the last of run.digests');
  } else if (Array.isArray(document.digests) && document.digests.length > 0) {
    problems.push('run.final_digest is required when a plan exists');
  }
  if (!Number.isInteger(document.exit_status)) problems.push('run.exit_status must be an integer');
  else if (document.outcome in OUTCOMES && !OUTCOMES[document.outcome].includes(document.exit_status)) {
    problems.push(`run.exit_status ${document.exit_status} is not valid for outcome ${document.outcome}`);
  }
  if (!Array.isArray(document.reasons)) problems.push('run.reasons must be a list');
  else document.reasons.forEach((item, index) => checkReason(item, `run.reasons[${index}]`, problems));
  return problems;
}

// The approval record is evidence only: nothing reads it as permission, and it holds no field that could grant one.
export function validateApprovalRecord(document) {
  const problems = [];
  const required = ['format_version', 'run_id', 'timestamp', 'outcome'];
  const optional = ['digest', 'machine', 'profile', 'disk', 'gum_version', 'reason'];
  if (!checkFields(document, 'approval', required, optional, problems)) return problems;
  secretKeys(document, 'approval', problems);
  checkCommon(document, 'approval', problems);
  if ('digest' in document && !HEX_64.test(document.digest)) problems.push('approval.digest must be a SHA-256 hex digest');
  if ('reason' in document && !isText(document.reason)) problems.push('approval.reason must be a non-empty string');
  if ('disk' in document && checkFields(document.disk, 'approval.disk', [], DISK_KEYS, problems)) {
    const { disk } = document;
    if (disk.by_id === undefined && disk.path === undefined) problems.push('approval.disk needs by_id or path');
    for (const key of DISK_KEYS.filter(name => name !== 'size_bytes')) {
      if (key in disk && !isText(disk[key])) problems.push(`approval.disk.${key} must be a non-empty string`);
    }
    if ('size_bytes' in disk && !Number.isSafeInteger(disk.size_bytes)) problems.push('approval.disk.size_bytes must be an integer');
  }
  return problems;
}

export function validateChoicesRecord(document) {
  const problems = [];
  if (!isRecord(document) || document.format_version !== CHOICES_FORMAT_VERSION) {
    problems.push(`choices must be an object with format_version ${CHOICES_FORMAT_VERSION}`);
    return problems;
  }
  secretKeys(document, 'choices', problems);
  return problems;
}
