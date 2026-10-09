import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { PlanContractError } from '../plan/canonical-json.mjs';
import { loadFacts } from '../plan/generate-plan.mjs';
import { loadPlanOverride, loadPlanPolicy } from '../plan/resolve-choices.mjs';
import { EXIT_INTERNAL, EXIT_INVALID_INPUT, EXIT_UPSTREAM_FAILURE, EXIT_VALID, parsePlanText, validatePlan } from '../plan/validate-plan.mjs';
import { reason } from '../discovery/validate-facts.mjs';
import { NEXT_STEP_REGENERATE, compareSafety } from './compare-safety.mjs';
import { applyEdit, parseValue, startingChoices } from './edit-choices.mjs';
import { standardReason, structuredReason } from './outcomes.mjs';
import { confirmationPrompt, deviceName, digestPrefix, formatSize, reviewMarkdown } from './review-content.mjs';
import { RecordContractError } from './validate-records.mjs';
import { buildApprovalRecord, buildRunRecord, writeApplyRecords, writeChoices } from './write-records.mjs';

const [command, ...args] = process.argv.slice(2);

function readPlan(path) {
  let text;
  try {
    text = readFileSync(path, 'utf8');
  } catch {
    return { plan: undefined, reasons: [reason('plan_not_json', 'The plan file cannot be read.', 'Provide a plan produced by operations/install plan.')] };
  }
  return parsePlanText(text);
}

// A plan that fails its validator or its digest is never reviewed.
function loadValidPlan(path) {
  const loaded = readPlan(path);
  if (loaded.plan === undefined) return loaded;
  const problems = validatePlan(loaded.plan);
  return problems.length > 0 ? { plan: undefined, reasons: problems } : loaded;
}

function printReasons(reasons) {
  process.stdout.write(`${JSON.stringify(reasons, null, 2)}\n`);
  for (const item of reasons) process.stderr.write(`MirrorOS install apply: ${item.message}\nNext step: ${item.next_step}\n`);
}

// Every reason that reaches an invalidation tells the user the same next step (AC-5).
function invalidating(reasons) {
  return reasons.map(item => ({ ...item, next_step: NEXT_STEP_REGENERATE }));
}

function compare([codeRoot, planPath, factsPath, baselinePath]) {
  const loaded = loadValidPlan(planPath);
  if (loaded.plan === undefined) return printReasonsAndFail(invalidating(loaded.reasons));
  const fresh = loadFacts(factsPath);
  if (fresh.facts === undefined) return printReasonsAndFail(invalidating(fresh.reasons));
  let baselineFacts;
  if (baselinePath !== undefined && baselinePath !== '') {
    const baseline = loadFacts(baselinePath);
    if (baseline.facts === undefined) return printReasonsAndFail(invalidating(baseline.reasons));
    baselineFacts = baseline.facts;
  }
  const policy = loadPlanPolicy(join(codeRoot, 'install/plan/policy.json'));
  const override = loadPlanOverride(join(codeRoot, 'targets'), loaded.plan.target.target_id);
  if (override.reasons.length > 0) return printReasonsAndFail(invalidating(override.reasons));
  const reasons = compareSafety({
    plan: loaded.plan,
    facts: fresh.facts,
    hashes: { policy_sha256: policy.sha256, override_sha256: override.sha256 },
    baselineFacts,
  });
  if (reasons.length > 0) return printReasonsAndFail(reasons);
  process.stdout.write('[]\n');
  return EXIT_VALID;
}

function printReasonsAndFail(reasons) {
  printReasons(reasons);
  return EXIT_INVALID_INPUT;
}

function review([field, planPath]) {
  const loaded = loadValidPlan(planPath);
  if (loaded.plan === undefined) return printReasonsAndFail(invalidating(loaded.reasons));
  const { plan } = loaded;
  switch (field) {
    case 'markdown':
      process.stdout.write(reviewMarkdown(plan));
      return EXIT_VALID;
    case 'prompt':
      process.stdout.write(`${confirmationPrompt(plan)}\n`);
      return EXIT_VALID;
    case 'digest-prefix':
      process.stdout.write(`${digestPrefix(plan)}\n`);
      return EXIT_VALID;
    case 'target-id':
      process.stdout.write(`${plan.target.target_id}\n`);
      return EXIT_VALID;
    case 'device-name': {
      const name = deviceName(plan);
      if (name === undefined) return printReasonsAndFail([standardReason('device_name_unavailable')]);
      process.stdout.write(`${name}\n`);
      return EXIT_VALID;
    }
    default:
      process.stderr.write(`MirrorOS install apply: unknown review field: ${field}\n`);
      return EXIT_INTERNAL;
  }
}

function writeChoicesFile(path, choices) {
  writeChoices(dirname(path), choices, basename(path));
}

function edit([action, ...rest]) {
  if (action === 'start') {
    const [planPath, outPath] = rest;
    const loaded = loadValidPlan(planPath);
    if (loaded.plan === undefined) return printReasonsAndFail(loaded.reasons);
    writeChoicesFile(outPath, startingChoices(loaded.plan));
    return EXIT_VALID;
  }
  if (action === 'set') {
    const [inPath, key, value, outPath] = rest;
    const current = JSON.parse(readFileSync(inPath, 'utf8'));
    const edited = applyEdit(current, key, parseValue(key, value));
    if (edited.reason !== undefined) return printReasonsAndFail([edited.reason]);
    writeChoicesFile(outPath, edited.choices);
    return EXIT_VALID;
  }
  process.stderr.write(`MirrorOS install apply: unknown edit action: ${action}\n`);
  return EXIT_INTERNAL;
}

function options([kind, source]) {
  if (kind === 'disks') {
    const loaded = loadFacts(source);
    if (loaded.facts === undefined) return printReasonsAndFail(loaded.reasons);
    for (const disk of loaded.facts.layers.detected.storage.disks.filter(item => item.eligible === true)) {
      const { identity } = disk;
      const detail = [formatSize(identity.size_bytes), identity.model].filter(item => item !== undefined).join(', ');
      process.stdout.write(`${identity.by_id ?? identity.path} (${detail})\n`);
    }
    return EXIT_VALID;
  }
  if (kind === 'storage') {
    const policy = loadPlanPolicy(join(source, 'install/plan/policy.json'));
    for (const [name, option] of Object.entries(policy.storageOptions)) process.stdout.write(`${name} (${option.tier})\n`);
    return EXIT_VALID;
  }
  if (kind === 'locales') {
    const loaded = loadValidPlan(source);
    if (loaded.plan === undefined) return printReasonsAndFail(loaded.reasons);
    for (const locale of loaded.plan.choices.locales.value) process.stdout.write(`${locale}\n`);
    return EXIT_VALID;
  }
  process.stderr.write(`MirrorOS install apply: unknown options kind: ${kind}\n`);
  return EXIT_INTERNAL;
}

function reasons([kind, source]) {
  if (kind === 'standard') {
    process.stdout.write(`${JSON.stringify([standardReason(source)], null, 2)}\n`);
    return EXIT_VALID;
  }
  const document = JSON.parse(readFileSync(source, 'utf8'));
  if (kind === 'text') {
    for (const item of document) process.stderr.write(`MirrorOS install apply: ${item.message}\nNext step: ${item.next_step}\n`);
    return EXIT_VALID;
  }
  if (kind === 'error') {
    process.stdout.write(`${JSON.stringify([document], null, 2)}\n`);
    return EXIT_VALID;
  }
  const list = kind === 'plan-run' ? document.reasons : document.validation?.reasons;
  process.stdout.write(`${JSON.stringify(list ?? [], null, 2)}\n`);
  return EXIT_VALID;
}

function planDigests(directory) {
  const root = join(directory, 'plans');
  if (!existsSync(root)) return { digests: [], last: undefined };
  const names = readdirSync(root).filter(name => /^[0-9]+$/.test(name)).sort();
  const plans = names
    .map(name => join(root, name, 'installation-plan.json'))
    .filter(path => existsSync(path))
    .map(path => JSON.parse(readFileSync(path, 'utf8')));
  return { digests: plans.map(plan => plan.digest.value), last: plans.at(-1) };
}

function record([directory, runId, timestamp, targetId, gumVersion, exitStatus, outcome, operation, reasonsPath]) {
  const list = reasonsPath === '' ? [] : JSON.parse(readFileSync(reasonsPath, 'utf8'));
  const shaped = list.map(item => structuredReason(item, { operation }));
  const { digests, last } = planDigests(directory);
  const optional = value => (value === '' ? undefined : value);
  let disk;
  if (last !== undefined) {
    const { eligible: _eligible, current_layout: _layout, ...identity } = last.target.disk;
    disk = identity;
  }
  const run = buildRunRecord({
    runId, timestamp, targetId: optional(targetId), gumVersion: optional(gumVersion), digests,
    exitStatus: Number(exitStatus), outcome, reasons: shaped,
  });
  const approval = buildApprovalRecord({
    runId, timestamp, digest: digests.at(-1), targetId: optional(targetId), disk,
    gumVersion: optional(gumVersion), outcome, reason: shaped[0]?.code,
  });
  writeApplyRecords({ directory, run, approval });
  return EXIT_VALID;
}

const COMMANDS = { compare, review, edit, options, reasons, record };

try {
  if (COMMANDS[command] === undefined) {
    process.stderr.write(`MirrorOS install apply: unknown helper command: ${command}\n`);
    process.exitCode = EXIT_INTERNAL;
  } else {
    process.exitCode = COMMANDS[command](args);
  }
} catch (error) {
  if (error instanceof PlanContractError || error instanceof RecordContractError) {
    process.stderr.write(`MirrorOS install apply: an internal contract check failed: ${error.message}\n`);
    process.stderr.write('Next step: rebuild or re-clone the installation medium and rerun apply.\n');
    process.exitCode = EXIT_INTERNAL;
  } else {
    process.stderr.write(`MirrorOS install apply: an unexpected failure occurred (${error.code ?? error.name}).\n`);
    process.stderr.write('Next step: check the output location and the installed Node.js, then rerun apply.\n');
    process.exitCode = EXIT_UPSTREAM_FAILURE;
  }
}
