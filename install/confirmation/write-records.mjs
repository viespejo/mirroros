import { readFileSync, renameSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { writePrivateFile } from '../discovery/write-facts.mjs';
import { UNSAMPLED_TIMING } from '../engine/engine-record.mjs';
import {
  RECORD_FORMAT_VERSION,
  RecordContractError,
  validateApprovalRecord,
  validateChoicesRecord,
  validateRunRecord,
} from './validate-records.mjs';

export const RUN_RECORD_FILE = 'install-run.json';
export const APPROVAL_RECORD_FILE = 'approval-record.json';
export const CHOICES_FILE = 'choices.json';

function present(entries) {
  return Object.fromEntries(entries.filter(([, value]) => value !== undefined));
}

export function buildRunRecord({ runId, timestamp, entry, machine, profile, gumVersion, stages, digests, exitStatus, outcome, reasons, timing }) {
  if (timing === undefined) {
    const classes = { preparation: 'mixed', review: 'interactive', confirmation: 'interactive', password: 'interactive' };
    timing = {
      total: structuredClone(UNSAMPLED_TIMING.total),
      intervals: stages.map(id => ({ id, classification: classes[id] ?? 'automated', measurement: structuredClone(UNSAMPLED_TIMING.total) })),
    };
  }
  return present([
    ['format_version', RECORD_FORMAT_VERSION],
    ['run_id', runId],
    ['timestamp', timestamp],
    ['entry', entry],
    ['machine', machine],
    ['profile', profile],
    ['gum_version', gumVersion],
    ['stages', stages],
    ['timing', timing],
    ['digests', digests],
    ['final_digest', digests.at(-1)],
    ['exit_status', exitStatus],
    ['outcome', outcome],
    ['reasons', reasons],
  ]);
}

export function buildApprovalRecord({ runId, timestamp, digest, machine, profile, disk, targetMode, partitions, gumVersion, outcome, reason }) {
  return present([
    ['format_version', RECORD_FORMAT_VERSION],
    ['run_id', runId],
    ['timestamp', timestamp],
    ['digest', digest],
    ['machine', machine],
    ['profile', profile],
    ['disk', disk],
    ['target_mode', targetMode],
    ['partitions', partitions],
    ['gum_version', gumVersion],
    ['outcome', outcome],
    ['reason', reason],
  ]);
}

// Writes a JSON document through a 0600 temporary file that is flushed, re-read, revalidated, and
// renamed. An invalid document is never written.
export function writeJsonAtomically(directory, name, document, validate) {
  const before = validate(document);
  if (before.length > 0) throw new RecordContractError(before);
  const temporary = writePrivateFile(directory, name, `${JSON.stringify(document, null, 2)}\n`);
  try {
    const after = validate(JSON.parse(readFileSync(temporary, 'utf8')));
    if (after.length > 0) throw new RecordContractError(after);
  } catch (error) {
    unlinkSync(temporary);
    throw error;
  }
  const destination = join(directory, name);
  renameSync(temporary, destination);
  return destination;
}

// Both records are validated before either is written, so a rejected pair leaves nothing behind.
export function writeApplyRecords({ directory, run, approval }) {
  const problems = [...validateRunRecord(run), ...validateApprovalRecord(approval)];
  if (problems.length > 0) throw new RecordContractError(problems);
  return {
    approval: writeJsonAtomically(directory, APPROVAL_RECORD_FILE, approval, validateApprovalRecord),
    run: writeJsonAtomically(directory, RUN_RECORD_FILE, run, validateRunRecord),
  };
}

export function writeChoices(directory, choices, name = CHOICES_FILE) {
  return writeJsonAtomically(directory, name, choices, validateChoicesRecord);
}
