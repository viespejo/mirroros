import { join } from 'node:path';
import { reason } from '../discovery/validate-facts.mjs';
import { PlanContractError } from './canonical-json.mjs';
import { generatePlan, loadFacts } from './generate-plan.mjs';
import { renderSummary } from './render-plan.mjs';
import { loadChoices, loadPlanOverride, loadPlanPolicy } from './resolve-choices.mjs';
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

const [codeRoot, factsPath, choicesPath, outputPath] = process.argv.slice(2);

function report(items, stream = process.stderr) {
  for (const item of items) {
    stream.write(`MirrorOS install plan: ${item.message}\n`);
    stream.write(`Next step: ${item.next_step}\n`);
  }
}

function main() {
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

  const policy = loadPlanPolicy(join(codeRoot, 'install/plan/policy.json'));
  const loaded = loadFacts(factsPath);
  if (loaded.facts === undefined) return rejected(loaded.reasons);

  const reasons = [];
  let choices = { values: {} };
  if (choicesPath !== '') {
    choices = loadChoices(choicesPath, { policy: policy.policy, storageOptions: policy.storageOptions });
    reasons.push(...choices.reasons);
  }
  const override = loadPlanOverride(join(codeRoot, 'targets'), loaded.facts.source.target_id);
  reasons.push(...override.reasons);
  if (reasons.length > 0) return rejected(reasons);

  const generated = generatePlan({ facts: loaded.facts, policy, choices, override });
  if (generated.plan === undefined) return rejected(generated.reasons);

  const paths = writePlan({ plan: generated.plan, facts: loaded.facts, directory, runId, timestamp, inputs });
  report(generated.plan.warnings.map(item => reason(item.code, `Warning: ${item.message}`, item.next_step)));
  process.stdout.write(renderSummary(generated.plan, paths.plan));
  return EXIT_VALID;
}

try {
  process.exitCode = main();
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
