import { join } from 'node:path';
import { reason } from '../discovery/validate-facts.mjs';
import { PlanContractError } from './canonical-json.mjs';
import { loadConfigurationAssets } from './configuration-assets.mjs';
import { detectedMemoryBytes, generatePlan, loadFacts } from './generate-plan.mjs';
import { previewChoices, validateChoice } from './preview-choices.mjs';
import { renderSummary } from './render-plan.mjs';
import { loadChoices, loadPlanOverride, loadPlanPolicy, loadProfileDefinition } from './resolve-choices.mjs';
import { EXIT_INTERNAL, EXIT_INVALID_INPUT, EXIT_UPSTREAM_FAILURE, EXIT_VALID } from './validate-plan.mjs';
import {
  defaultOutputDirectory,
  newRunId,
  outputExistsReason,
  outputHoldsPlan,
  rfc3339,
  writePlan,
  writeRejectedRun,
} from './write-plan.mjs';

const [mode, codeRoot, factsPath, choicesPath, outputPath, choiceKey, choiceValue] = process.argv.slice(2);

function report(items, stream = process.stderr) {
  for (const item of items) {
    stream.write(`MirrorOS install plan: ${item.message}\n`);
    stream.write(`Next step: ${item.next_step}\n`);
  }
}

// Loads the inputs every mode shares: the policy, its configuration assets, the facts, the optional choices
// file, and, for a matched profile, its override and definition hash. Returns { reasons } when an input is
// invalid. A missing or damaged asset is a contract failure (exit 6), not an input problem.
function prepare() {
  const policy = loadPlanPolicy(join(codeRoot, 'install/plan/policy.json'));
  const assets = loadConfigurationAssets(codeRoot, policy);
  const loaded = loadFacts(factsPath);
  if (loaded.facts === undefined) return { reasons: loaded.reasons };
  const { facts } = loaded;
  const reasons = [];
  let choices = { values: {} };
  if (choicesPath !== '') {
    choices = loadChoices(choicesPath, {
      policy: policy.policy,
      storageOptions: policy.storageOptions,
      memoryTotalBytes: detectedMemoryBytes(facts),
    });
    reasons.push(...choices.reasons);
  }
  let override = { values: {} };
  let profileDefinition;
  if (facts.profile.status === 'matched') {
    override = loadPlanOverride(join(codeRoot, 'targets'), facts.profile.profile_id);
    reasons.push(...override.reasons);
    profileDefinition = loadProfileDefinition(join(codeRoot, 'targets'), facts.profile.profile_id);
    reasons.push(...profileDefinition.reasons);
  }
  if (reasons.length > 0) return { reasons };
  return { reasons, policy, assets, facts, choices, override, profileDefinition };
}

function runPlan() {
  const runId = newRunId();
  const timestamp = rfc3339();
  const directory = outputPath === '' ? defaultOutputDirectory(runId) : outputPath;
  const inputs = { facts: factsPath };
  if (choicesPath !== '') inputs.choices = choicesPath;

  if (outputPath !== '' && outputHoldsPlan(directory)) {
    report([outputExistsReason()]);
    return EXIT_INVALID_INPUT;
  }

  const rejected = reasons => {
    writeRejectedRun({ directory, runId, timestamp, inputs, exitStatus: EXIT_INVALID_INPUT, reasons });
    report(reasons);
    return EXIT_INVALID_INPUT;
  };

  const prepared = prepare();
  if (prepared.reasons.length > 0) return rejected(prepared.reasons);
  const { policy, assets, facts, choices, override, profileDefinition } = prepared;

  const generated = generatePlan({ facts, policy, choices, override, profileDefinition, assets });
  if (generated.plan === undefined) return rejected(generated.reasons);

  const paths = writePlan({ plan: generated.plan, facts, directory, runId, timestamp, inputs });
  report(generated.plan.warnings.map(item => reason(item.code, `Warning: ${item.message}`, item.next_step)));
  process.stdout.write(renderSummary(generated.plan, paths.plan));
  return EXIT_VALID;
}

function runPreview() {
  const prepared = prepare();
  if (prepared.reasons.length > 0) {
    report(prepared.reasons);
    return EXIT_INVALID_INPUT;
  }
  const { policy, facts, choices, override } = prepared;
  const preview = previewChoices({ facts, policy, choices, override });
  if (preview.document === undefined) {
    report(preview.reasons);
    return EXIT_INVALID_INPUT;
  }
  process.stdout.write(`${JSON.stringify(preview.document, null, 2)}\n`);
  return EXIT_VALID;
}

function runValidateChoice() {
  const prepared = prepare();
  if (prepared.reasons.length > 0) {
    report(prepared.reasons);
    return EXIT_INVALID_INPUT;
  }
  const { policy, facts, choices, override } = prepared;
  const result = validateChoice({ facts, policy, choices, override, key: choiceKey, value: choiceValue });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result.valid ? EXIT_VALID : EXIT_INVALID_INPUT;
}

const MODES = { plan: runPlan, 'preview-choices': runPreview, 'validate-choice': runValidateChoice };

try {
  process.exitCode = MODES[mode]();
} catch (error) {
  if (error instanceof PlanContractError) {
    process.stderr.write(`MirrorOS install plan: an internal contract check failed: ${error.message}\n`);
    process.stderr.write('Next step: rebuild or re-clone the installation medium and rerun plan.\n');
    process.exitCode = EXIT_INTERNAL;
  } else {
    process.stderr.write(`MirrorOS install plan: an unexpected failure occurred (${error.code ?? error.name}).\n`);
    process.stderr.write('Next step: check the output location and the installed Node.js, then rerun plan.\n');
    process.exitCode = EXIT_UPSTREAM_FAILURE;
  }
}
