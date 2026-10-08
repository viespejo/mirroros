import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync, renameSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { reason } from '../discovery/validate-facts.mjs';
import { ensurePrivateDirectory, writePrivateFile } from '../discovery/write-facts.mjs';
import { PlanContractError } from './canonical-json.mjs';
import { renderPlan } from './render-plan.mjs';
import { EXIT_VALID, validatePlan } from './validate-plan.mjs';

export const PLAN_FILE = 'installation-plan.json';
export const TEXT_FILE = 'installation-plan.txt';
export const RUN_FILE = 'plan-run.json';

export function newRunId(now = new Date(), uuid = randomUUID()) {
  return `${now.toISOString().replace(/[-:]|\.\d{3}/g, '')}-${uuid}`;
}

export function rfc3339(now = new Date()) {
  return now.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export function defaultOutputDirectory(runId) {
  return join('evidence', 'install', runId);
}

export function outputHoldsPlan(directory) {
  return existsSync(join(directory, PLAN_FILE)) || existsSync(join(directory, TEXT_FILE));
}

export function outputExistsReason() {
  return reason(
    'output_exists',
    'The output directory already contains an installation plan; a plan is never overwritten.',
    'Use a new --output directory, or omit --output to create a new run directory.',
  );
}

function stage(directory, name, content, verify) {
  const temporary = writePrivateFile(directory, name, content);
  try {
    verify(readFileSync(temporary, 'utf8'));
  } catch (error) {
    unlinkSync(temporary);
    throw error;
  }
  return { temporary, destination: join(directory, name) };
}

function runDocument({ runId, timestamp, inputs, plan, exitStatus, reasons, warnings }) {
  const document = { run_id: runId, timestamp, inputs };
  if (plan !== undefined) document.digest = plan.digest;
  document.exit_status = exitStatus;
  document.reasons = reasons;
  document.warnings = warnings;
  return `${JSON.stringify(document, null, 2)}\n`;
}

function writeRun(directory, metadata) {
  const staged = stage(directory, RUN_FILE, runDocument(metadata), text => {
    const parsed = JSON.parse(text);
    if (parsed.run_id !== metadata.runId || parsed.exit_status !== metadata.exitStatus) {
      throw new PlanContractError('plan-run.json did not survive its write intact');
    }
  });
  renameSync(staged.temporary, staged.destination);
  return staged.destination;
}

// Persists a valid plan: JSON, rendered text, and run metadata, each through a temporary file that is
// flushed, re-read, and revalidated before it is renamed. Returns the paths written.
export function writePlan({ plan, facts, directory, runId, timestamp, inputs }) {
  const problems = validatePlan(plan, { facts });
  if (problems.length > 0) throw new PlanContractError(problems.map(item => `${item.code}: ${item.message}`));
  ensurePrivateDirectory(directory);
  const written = [];
  const staged = [];
  try {
    staged.push(stage(directory, PLAN_FILE, `${JSON.stringify(plan, null, 2)}\n`, text => {
      const reread = validatePlan(JSON.parse(text), { facts });
      if (reread.length > 0) throw new PlanContractError(reread.map(item => `${item.code}: ${item.message}`));
    }));
    staged.push(stage(directory, TEXT_FILE, renderPlan(plan), text => {
      if (text !== renderPlan(JSON.parse(readFileSync(staged[0].temporary, 'utf8')))) {
        throw new PlanContractError('installation-plan.txt does not match the persisted plan');
      }
    }));
  } catch (error) {
    for (const item of staged) if (existsSync(item.temporary)) unlinkSync(item.temporary);
    throw error;
  }
  try {
    for (const item of staged) {
      renameSync(item.temporary, item.destination);
      written.push(item.destination);
    }
    written.push(writeRun(directory, {
      runId, timestamp, inputs, plan, exitStatus: EXIT_VALID, reasons: [], warnings: plan.warnings,
    }));
  } catch (error) {
    for (const path of written) if (existsSync(path)) unlinkSync(path);
    throw error;
  }
  return { plan: join(directory, PLAN_FILE), text: join(directory, TEXT_FILE), run: join(directory, RUN_FILE) };
}

// Records a run that produced no plan: only plan-run.json is written, with the reasons.
export function writeRejectedRun({ directory, runId, timestamp, inputs, exitStatus, reasons }) {
  ensurePrivateDirectory(directory);
  return writeRun(directory, { runId, timestamp, inputs, exitStatus, reasons, warnings: [] });
}
