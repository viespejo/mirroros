import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { RULES, evaluateRules, evaluateValues } from '../../hardware/rules/evaluate-rules.mjs';
import { repository } from '../install/discovery/helpers.mjs';

// Simulated effective views: the rules read only `effective[<fact>].value`, so cases that the reference VM cannot
// produce (NVIDIA, Intel, a battery) are proved without a machine.
function effective(values) {
  return { effective: Object.fromEntries(Object.entries(values).map(([fact, value]) => [fact, { value }])) };
}

const baseline = {
  'hardware.graphics': [{ vendor: 'amd' }],
  'hardware.cpu.vendor': 'AuthenticAMD',
  'hardware.battery_present': true,
  'hardware.virtualization': 'none',
};

function evaluate(overrides = {}, removed = []) {
  const values = { ...baseline, ...overrides };
  for (const fact of removed) delete values[fact];
  return evaluateRules(effective(values));
}

const outcomeOf = (result, rule) => result.rule_outcomes.find(entry => entry.rule === rule);
const warningCodes = result => result.warnings.map(item => item.code);

test('the fixed rule set is evaluated in the plan order with one entry per rule', () => {
  assert.deepEqual(RULES.map(rule => rule.id), ['graphics', 'cpu-microcode', 'battery', 'virtualization']);
  const result = evaluate();
  assert.deepEqual(result.rule_outcomes.map(entry => entry.rule), ['graphics', 'cpu-microcode', 'battery', 'virtualization']);
  assert.deepEqual(result.rule_outcomes.map(entry => entry.fact), [
    'hardware.graphics', 'hardware.cpu.vendor', 'hardware.battery_present', 'hardware.virtualization',
  ]);
  for (const entry of result.rule_outcomes) {
    assert.deepEqual(Object.keys(entry), ['rule', 'fact', 'value', 'outcome', 'explanation']);
    assert.ok(entry.explanation.length > 0);
  }
});

test('graphics: AMD, Intel, and QEMU virtual use the kernel driver with no warning', () => {
  for (const vendor of ['amd', 'intel', 'qemu_virtual']) {
    const result = evaluate({ 'hardware.graphics': [{ vendor }] });
    assert.equal(outcomeOf(result, 'graphics').outcome, 'kernel_driver_only', vendor);
    assert.deepEqual(outcomeOf(result, 'graphics').value, [vendor]);
    assert.deepEqual(warningCodes(result), []);
    assert.deepEqual(result.rule_packages.filter(entry => entry.rule === 'graphics'), []);
  }
});

test('graphics: NVIDIA falls back to nouveau with a warning, selects no driver, and never blocks', () => {
  const result = evaluate({ 'hardware.graphics': [{ vendor: 'nvidia' }] });
  assert.equal(outcomeOf(result, 'graphics').outcome, 'nvidia_nouveau_fallback');
  assert.deepEqual(warningCodes(result), ['graphics_nvidia_nouveau']);
  assert.match(result.warnings[0].message, /nouveau/);
  assert.match(result.warnings[0].next_step, /does not blacklist nouveau/);
  assert.deepEqual(result.rule_packages.filter(entry => entry.rule === 'graphics'), []);
  assert.doesNotMatch(JSON.stringify(result), /nvidia-|mesa|vulkan|blacklist\s*=|modprobe/i);
});

test('graphics: an unknown vendor, no device, or no fact is not recognized and warns', () => {
  const cases = [
    evaluate({ 'hardware.graphics': [{ vendor: 'unknown' }] }),
    evaluate({ 'hardware.graphics': [{ vendor: 'amd' }, { vendor: 'unknown' }] }),
    evaluate({ 'hardware.graphics': [] }),
    evaluate({}, ['hardware.graphics']),
  ];
  for (const result of cases) {
    assert.equal(outcomeOf(result, 'graphics').outcome, 'vendor_not_recognized');
    assert.deepEqual(warningCodes(result), ['graphics_vendor_unknown']);
    assert.deepEqual(result.rule_packages.filter(entry => entry.rule === 'graphics'), []);
  }
  assert.equal(outcomeOf(cases[3], 'graphics').value, 'unknown');
});

test('graphics: several devices give the most restrictive outcome', () => {
  assert.equal(outcomeOf(evaluate({ 'hardware.graphics': [{ vendor: 'intel' }, { vendor: 'nvidia' }] }), 'graphics').outcome, 'nvidia_nouveau_fallback');
  const mixed = evaluate({ 'hardware.graphics': [{ vendor: 'nvidia' }, { vendor: 'unknown' }] });
  assert.equal(outcomeOf(mixed, 'graphics').outcome, 'vendor_not_recognized');
  assert.deepEqual(warningCodes(mixed), ['graphics_vendor_unknown']);
});

test('cpu-microcode: AMD and Intel select exactly their package with the hardware labels', () => {
  const amd = evaluate({ 'hardware.cpu.vendor': 'AuthenticAMD' });
  assert.equal(outcomeOf(amd, 'cpu-microcode').outcome, 'amd_microcode');
  assert.deepEqual(amd.rule_packages, [{ name: 'amd-ucode', rule: 'cpu-microcode', provenance: 'hardware_detection', source: 'detected', editable: false }]);
  const intel = evaluate({ 'hardware.cpu.vendor': 'GenuineIntel' });
  assert.equal(outcomeOf(intel, 'cpu-microcode').outcome, 'intel_microcode');
  assert.deepEqual(intel.rule_packages.map(entry => entry.name), ['intel-ucode']);
  assert.deepEqual(warningCodes(amd), []);
  assert.deepEqual(warningCodes(intel), []);
});

test('cpu-microcode: another or missing vendor selects nothing, warns, and guesses nothing', () => {
  for (const result of [evaluate({ 'hardware.cpu.vendor': 'HygonGenuine' }), evaluate({}, ['hardware.cpu.vendor']), evaluate({ 'hardware.cpu.vendor': 'authenticamd' })]) {
    assert.equal(outcomeOf(result, 'cpu-microcode').outcome, 'vendor_not_recognized');
    assert.deepEqual(result.rule_packages, []);
    assert.deepEqual(warningCodes(result), ['cpu_vendor_unknown']);
  }
  assert.equal(outcomeOf(evaluate({}, ['hardware.cpu.vendor']), 'cpu-microcode').value, 'unknown');
});

test('battery: present, absent, and not observed are informational', () => {
  const expected = [[true, 'battery_present'], [false, 'battery_absent']];
  for (const [value, outcome] of expected) {
    const result = evaluate({ 'hardware.battery_present': value });
    assert.equal(outcomeOf(result, 'battery').outcome, outcome);
    assert.equal(outcomeOf(result, 'battery').value, value);
    assert.deepEqual(result.rule_packages.filter(entry => entry.rule === 'battery'), []);
    assert.deepEqual(warningCodes(result), []);
  }
  const missing = evaluate({}, ['hardware.battery_present']);
  assert.equal(outcomeOf(missing, 'battery').outcome, 'not_observed');
  assert.equal(outcomeOf(missing, 'battery').value, 'unknown');
});

test('virtualization: a virtual machine, a physical machine, and not observed are informational', () => {
  for (const [value, outcome] of [['kvm', 'virtual_machine'], ['none', 'physical_machine']]) {
    const result = evaluate({ 'hardware.virtualization': value });
    assert.equal(outcomeOf(result, 'virtualization').outcome, outcome);
    assert.equal(outcomeOf(result, 'virtualization').value, value);
    assert.deepEqual(result.rule_packages.filter(entry => entry.rule === 'virtualization'), []);
    assert.deepEqual(warningCodes(result), []);
  }
  assert.equal(outcomeOf(evaluate({}, ['hardware.virtualization']), 'virtualization').outcome, 'not_observed');
});

test('every package is justified by exactly one outcome and no outcome names an absent package', () => {
  for (const vendor of ['AuthenticAMD', 'GenuineIntel', 'Other']) {
    const result = evaluate({ 'hardware.cpu.vendor': vendor });
    for (const entry of result.rule_packages) {
      assert.equal(result.rule_outcomes.filter(outcome => outcome.rule === entry.rule).length, 1);
      assert.match(outcomeOf(result, entry.rule).explanation, new RegExp(entry.name));
    }
    for (const outcome of result.rule_outcomes) {
      const named = result.rule_packages.some(entry => entry.rule === outcome.rule);
      assert.equal(/-ucode package is installed/.test(outcome.explanation), named, outcome.rule);
    }
  }
});

test('the validator derivation gives the same result from the recorded values as the facts derivation', () => {
  const facts = effective({ ...baseline, 'hardware.graphics': [{ vendor: 'nvidia' }], 'hardware.cpu.vendor': 'GenuineIntel' });
  const fromFacts = evaluateRules(facts);
  const values = Object.fromEntries(fromFacts.rule_outcomes.map(entry => [entry.rule, entry.value]));
  assert.deepEqual(evaluateValues(values), fromFacts);
});

test('evaluation is pure: it does not modify the facts and gives identical results', () => {
  const facts = effective(baseline);
  const before = JSON.stringify(facts);
  assert.deepEqual(evaluateRules(facts), evaluateRules(facts));
  assert.equal(JSON.stringify(facts), before);
});

test('adding a rule module needs no change to the evaluator, the other rules, or the policy', () => {
  const fixtureRule = {
    id: 'fixture-sensor',
    fact: 'hardware.fixture_sensor',
    observe: raw => (typeof raw === 'string' ? raw : 'unknown'),
    evaluate: value => (value === 'present'
      ? { outcome: 'sensor_present', explanation: 'A sensor was detected.', packages: ['fixture-tools'], warnings: [] }
      : { outcome: 'sensor_absent', explanation: 'No sensor was detected.', packages: [], warnings: [{ code: 'fixture_warning', message: 'm', next_step: 'n' }] }),
  };
  const rules = [...RULES, fixtureRule];
  const withFact = evaluateRules(effective({ ...baseline, 'hardware.fixture_sensor': 'present' }), { rules });
  assert.deepEqual(withFact.rule_outcomes.slice(0, 4), evaluate().rule_outcomes);
  assert.deepEqual(withFact.rule_outcomes[4], {
    rule: 'fixture-sensor', fact: 'hardware.fixture_sensor', value: 'present', outcome: 'sensor_present', explanation: 'A sensor was detected.',
  });
  assert.deepEqual(withFact.rule_packages.map(entry => entry.name), ['amd-ucode', 'fixture-tools']);
  const without = evaluateRules(effective(baseline), { rules });
  assert.deepEqual(warningCodes(without), ['fixture_warning']);
  assert.deepEqual(without.rule_outcomes.slice(0, 4), evaluate().rule_outcomes);
  assert.deepEqual(evaluateValues({ 'fixture-sensor': 'present' }, { rules: [fixtureRule] }).rule_packages.map(entry => entry.name), ['fixture-tools']);
});

test('a rule module reads no file and writes nothing, and no rule mentions the policy or an override', () => {
  for (const rule of RULES) {
    const source = readFileSync(join(repository, 'hardware/rules', rule.id, 'rule.mjs'), 'utf8');
    assert.doesNotMatch(source, /node:fs|node:child_process|import\s+.*from\s+'\.\.\//, rule.id);
    assert.doesNotMatch(source, /policy\.json|overrides?\b|targets\//, rule.id);
    assert.deepEqual(Object.keys(rule).sort(), ['evaluate', 'fact', 'id', 'observe']);
  }
});
