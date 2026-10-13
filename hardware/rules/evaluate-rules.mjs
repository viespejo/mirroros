import graphics from './graphics/rule.mjs';
import cpuMicrocode from './cpu-microcode/rule.mjs';
import battery from './battery/rule.mjs';
import virtualization from './virtualization/rule.mjs';

// The fixed rule set, in the order the plan lists the outcomes. The evaluator knows nothing about any rule: it
// reads each rule's fact, derives the observed value, and collects the result in the one shape every rule shares.
export const RULES = [graphics, cpuMicrocode, battery, virtualization];

const UNKNOWN = 'unknown';

function derive(items) {
  const rule_outcomes = [];
  const rule_packages = [];
  const warnings = [];
  for (const { rule, value } of items) {
    const result = rule.evaluate(value);
    rule_outcomes.push({ rule: rule.id, fact: rule.fact, value, outcome: result.outcome, explanation: result.explanation });
    for (const name of result.packages) {
      rule_packages.push({ name, rule: rule.id, provenance: 'hardware_detection', source: 'detected', editable: false });
    }
    warnings.push(...result.warnings);
  }
  return { rule_outcomes, rule_packages, warnings };
}

// Evaluates the rules against the effective view of valid target facts.
// Returns { rule_outcomes, rule_packages, warnings }.
export function evaluateRules(facts, { rules = RULES } = {}) {
  return derive(rules.map(rule => {
    const raw = facts.effective?.[rule.fact]?.value;
    return { rule, value: raw === undefined ? UNKNOWN : rule.observe(raw) };
  }));
}

// Re-derives the results from detected values already recorded in a plan, without reading any facts.
// `values` maps a rule id to its recorded value; a rule without a recorded value is evaluated as `unknown`.
export function evaluateValues(values, { rules = RULES } = {}) {
  return derive(rules.map(rule => ({ rule, value: Object.hasOwn(values, rule.id) ? values[rule.id] : UNKNOWN })));
}
