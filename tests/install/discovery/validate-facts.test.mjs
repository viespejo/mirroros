import test from 'node:test';
import assert from 'node:assert/strict';
import { validateDocument } from '../../../install/discovery/validate-facts.mjs';
import { discover } from './helpers.mjs';

function mutated(change) {
  const document = structuredClone(discover('reference-vm-empty'));
  change(document);
  return validateDocument(document);
}

test('a produced document is accepted', () => {
  assert.deepEqual(validateDocument(discover('reference-vm-layout')), []);
});

test('unknown fields are rejected at every level', () => {
  assert.match(mutated(d => { d.extra = 1; }).join('\n'), /target-facts\.extra is not an allowed field/);
  assert.match(mutated(d => { d.source.hostname = 'x'; }).join('\n'), /source\.hostname/);
  assert.match(mutated(d => { d.layers.detected.firmware.product_serial = 'x'; }).join('\n'), /firmware\.product_serial/);
  assert.match(mutated(d => { d.layers.detected.firmware.dmi.product_serial = 'x'; }).join('\n'), /dmi\.product_serial/);
  assert.match(mutated(d => { d.layers.detected.storage.disks[0].identity.mac = 'x'; }).join('\n'), /identity\.mac/);
  assert.match(mutated(d => { d.layers.detected.network.interfaces[0].address = 'x'; }).join('\n'), /interfaces\[0\]\.address/);
  assert.match(mutated(d => { d.validation.reasons.push({ code: 'c', message: 'm', next_step: 'n', extra: 1 }); }).join('\n'), /reasons\[0\]\.extra/);
});

test('format version and required sections are enforced', () => {
  assert.match(mutated(d => { d.format_version = 1; }).join('\n'), /format_version must be one of: 2/);
  assert.match(mutated(d => { delete d.profile; }).join('\n'), /profile is required/);
  assert.match(mutated(d => { delete d.layers.runtime_private; }).join('\n'), /runtime_private is required/);
  assert.match(mutated(d => { delete d.validation; }).join('\n'), /validation is required/);
});

test('the profile classification is consistent with its identifier', () => {
  assert.deepEqual(mutated(d => { d.profile = { status: 'matched', profile_id: 'reference-vm' }; }), []);
  assert.match(mutated(d => { d.profile = { status: 'matched' }; }).join('\n'), /profile_id is required for a matched profile/);
  assert.match(mutated(d => { d.profile = { status: 'unqualified', profile_id: 'reference-vm' }; }).join('\n'), /must be omitted for an unqualified machine/);
  assert.match(mutated(d => { d.profile = { status: 'generic' }; }).join('\n'), /profile\.status must be one of/);
  assert.match(mutated(d => { d.profile = { status: 'unqualified', name: 'x' }; }).join('\n'), /profile\.name is not an allowed field/);
  assert.match(mutated(d => { d.source.requested_profile_id = '../x'; }).join('\n'), /not a valid profile id/);
  assert.match(mutated(d => {
    d.source.requested_profile_id = 'framework-13-pro-amd';
    d.profile = { status: 'matched', profile_id: 'reference-vm' };
  }).join('\n'), /must equal source\.requested_profile_id/);
  assert.match(mutated(d => { d.source.target_id = 'reference-vm'; }).join('\n'), /source\.target_id is not an allowed field/);
});

test('status must agree with the reasons', () => {
  assert.match(mutated(d => { d.validation.status = 'invalid'; }).join('\n'), /exactly when there are no reasons/);
  assert.match(mutated(d => {
    d.validation.reasons.push({ code: 'c', message: 'm', next_step: 'n' });
  }).join('\n'), /exactly when there are no reasons/);
});

test('runtime entries never carry a value', () => {
  assert.match(mutated(d => { d.effective['runtime.x'] = { source: 'runtime', value: 'secret' }; }).join('\n'), /must not carry a runtime private value/);
});

test('disk eligibility must match its reasons', () => {
  assert.match(mutated(d => { d.layers.detected.storage.disks[0].eligible = false; }).join('\n'), /eligibility must match its reasons/);
  assert.match(mutated(d => { d.layers.detected.storage.disks[0].ineligible_reasons = ['selected']; }).join('\n'), /must be one of/);
});
