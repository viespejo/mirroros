import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { assertProfile, classifyProfile, matchesIdentity } from '../../../install/discovery/identify-profile.mjs';
import { loadAllTargets } from '../../../install/discovery/resolve-layers.mjs';
import { exitStatusFor, validateDocument } from '../../../install/discovery/validate-facts.mjs';
import { PLANTED_VALUES, codes, discover, fixturesRoot, repository, targetsRoot } from './helpers.mjs';

function temporaryRoot(t) {
  const root = mkdtempSync(join(tmpdir(), 'mirroros-profiles-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}

function copyProfile(root, id, newId = id) {
  cpSync(join(targetsRoot, id), join(root, newId), { recursive: true });
  const definition = JSON.parse(readFileSync(join(targetsRoot, id, 'target.json'), 'utf8'));
  definition.target_id = newId;
  writeFileSync(join(root, newId, 'target.json'), `${JSON.stringify(definition)}\n`);
}

function writeOverride(root, id, content) {
  mkdirSync(join(root, id, 'overrides'), { recursive: true });
  writeFileSync(join(root, id, 'overrides', 'discovery.json'), `${JSON.stringify(content)}\n`);
}

test('the reference VM is recognized without --target and the facts stay valid', () => {
  const document = discover('reference-vm-empty', { targetId: null });
  assert.deepEqual(document.profile, { status: 'matched', profile_id: 'reference-vm' });
  assert.equal(document.source.requested_profile_id, undefined);
  assert.equal(document.validation.status, 'valid');
  assert.deepEqual(validateDocument(document), []);
});

test('a machine that matches no profile is unqualified, valid, and gets no generic profile', () => {
  const document = discover('synthetic-laptop', { targetId: null });
  assert.deepEqual(document.profile, { status: 'unqualified' });
  assert.equal(document.validation.status, 'valid');
  assert.equal(exitStatusFor(document), 0);
  assert.deepEqual(document.layers.target_override.policy, {});
  assert.equal(JSON.stringify(document).includes('generic'), false);
  assert.deepEqual(validateDocument(document), []);
});

test('a defined profile matches only when every declared field is observed and equal', () => {
  const laptop = discover('synthetic-laptop', { targetId: null, root: join(fixturesRoot, 'targets') });
  assert.deepEqual(laptop.profile, { status: 'matched', profile_id: 'synthetic-laptop' });
  const [target] = loadAllTargets(join(fixturesRoot, 'targets'));
  const detected = { firmware: { dmi: { sys_vendor: 'Synthetic Vendor', product_name: 'Synthetic Laptop' } }, hardware: { virtualization: 'none' } };
  assert.equal(matchesIdentity(detected, target), true);
  assert.equal(matchesIdentity({ ...detected, hardware: { virtualization: 'kvm' } }, target), false);
  assert.equal(matchesIdentity({ ...detected, firmware: { dmi: { sys_vendor: 'Synthetic Vendor' } } }, target), false);
  assert.equal(matchesIdentity({ ...detected, firmware: {} }, target), false);
});

test('a missing identity field prevents a match without becoming a missing fact', () => {
  const dropVendor = raw => { delete raw.firmware.dmi.sys_vendor; };
  const automatic = discover('reference-vm-empty', { targetId: null, mutateRaw: dropVendor });
  assert.deepEqual(automatic.profile, { status: 'unqualified' });
  assert.equal(automatic.validation.status, 'valid');
  const asserted = discover('reference-vm-empty', { mutateRaw: dropVendor });
  assert.deepEqual(codes(asserted.validation.reasons), ['target_identity_unobserved']);
  assert.deepEqual(asserted.profile, { status: 'unqualified' });
});

test('a pending identity is never inferred and never enables adjustments', t => {
  const root = temporaryRoot(t);
  mkdirSync(join(root, 'pending-laptop'));
  writeFileSync(join(root, 'pending-laptop', 'target.json'), JSON.stringify({
    format_version: 1,
    target_id: 'pending-laptop',
    identity: { status: 'pending_capture', virtualization: 'none', dmi_fields_pending: ['sys_vendor', 'product_name'] },
  }));
  writeOverride(root, 'pending-laptop', { minimum_disk_bytes: 42949672960 });
  const document = discover('synthetic-laptop', { targetId: null, root });
  assert.deepEqual(document.profile, { status: 'unqualified' });
  assert.equal(document.validation.status, 'valid');
  assert.deepEqual(document.layers.target_override.policy, {});
  assert.equal(document.effective['policy.minimum_disk_bytes'].source, 'baseline');
});

test('two matching profiles are ambiguous: none is selected and no override applies', t => {
  const root = temporaryRoot(t);
  copyProfile(root, 'reference-vm');
  copyProfile(root, 'reference-vm', 'reference-vm-twin');
  writeOverride(root, 'reference-vm', { minimum_disk_bytes: 42949672960 });
  writeOverride(root, 'reference-vm-twin', { minimum_disk_bytes: 42949672960 });
  const document = discover('reference-vm-empty', { targetId: null, root });
  assert.deepEqual(document.profile, { status: 'unqualified' });
  assert.deepEqual(codes(document.validation.reasons), ['profile_ambiguous']);
  assert.match(document.validation.reasons[0].message, /reference-vm, reference-vm-twin/);
  assert.equal(exitStatusFor(document), 2);
  assert.deepEqual(document.layers.target_override.policy, {});
  assert.deepEqual(validateDocument(document), []);
});

test('an override applies only after an unambiguous verified match', t => {
  const root = temporaryRoot(t);
  copyProfile(root, 'reference-vm');
  writeOverride(root, 'reference-vm', { minimum_disk_bytes: 42949672960 });
  const matched = discover('reference-vm-empty', { targetId: null, root });
  assert.deepEqual(matched.layers.target_override.policy, { minimum_disk_bytes: 42949672960 });
  assert.equal(matched.effective['policy.minimum_disk_bytes'].source, 'override');
  const unmatched = discover('synthetic-laptop', { targetId: null, root });
  assert.deepEqual(unmatched.layers.target_override.policy, {});
  assert.equal(unmatched.effective['policy.minimum_disk_bytes'].source, 'baseline');
});

test('an invalid override of a non-matching profile is not read', t => {
  const root = temporaryRoot(t);
  copyProfile(root, 'reference-vm');
  writeOverride(root, 'reference-vm', { unknown_key: 1 });
  const document = discover('synthetic-laptop', { targetId: null, root });
  assert.equal(document.validation.status, 'valid');
});

test('an explicit assertion that is verified records the requested profile', () => {
  const document = discover('reference-vm-empty', { targetId: 'reference-vm' });
  assert.deepEqual(document.profile, { status: 'matched', profile_id: 'reference-vm' });
  assert.equal(document.source.requested_profile_id, 'reference-vm');
  assert.equal(document.validation.status, 'valid');
});

test('an explicit assertion that is contradicted or pending is rejected and keeps its requested id', () => {
  const contradicted = discover('synthetic-laptop');
  assert.deepEqual(codes(contradicted.validation.reasons), ['target_identity_mismatch']);
  assert.deepEqual(contradicted.profile, { status: 'unqualified' });
  assert.equal(contradicted.source.requested_profile_id, 'reference-vm');
  assert.deepEqual(contradicted.layers.target_override.policy, {});

  const pending = discover('synthetic-laptop', { targetId: 'framework-13-pro-amd' });
  assert.deepEqual(codes(pending.validation.reasons), ['target_identity_pending_capture']);
  assert.deepEqual(pending.profile, { status: 'unqualified' });
  assert.equal(pending.source.requested_profile_id, 'framework-13-pro-amd');
});

test('a rejected assertion applies no override', t => {
  const root = temporaryRoot(t);
  copyProfile(root, 'reference-vm');
  writeOverride(root, 'reference-vm', { minimum_disk_bytes: 42949672960 });
  const document = discover('synthetic-laptop', { root });
  assert.deepEqual(codes(document.validation.reasons), ['target_identity_mismatch']);
  assert.deepEqual(document.layers.target_override.policy, {});
});

test('assertProfile reports mismatch, unobserved, and pending reasons separately', () => {
  const [framework] = loadAllTargets(targetsRoot).filter(target => target.target_id === 'framework-13-pro-amd');
  const reasons = assertProfile({ detected: { firmware: {}, hardware: { virtualization: 'kvm' } }, target: framework });
  assert.deepEqual(codes(reasons), ['target_identity_mismatch', 'target_identity_pending_capture']);
  const [reference] = loadAllTargets(targetsRoot).filter(target => target.target_id === 'reference-vm');
  assert.deepEqual(codes(assertProfile({ detected: { firmware: {}, hardware: {} }, target: reference })), ['target_identity_unobserved']);
  assert.deepEqual(classifyProfile({ detected: {}, requested: { target: null, reasons: [] } }).profile, { status: 'unqualified' });
});

test('machine facts are independent of the profile classification', () => {
  const automatic = discover('reference-vm-empty', { targetId: null });
  const asserted = discover('reference-vm-empty', { targetId: 'reference-vm' });
  const unqualified = discover('reference-vm-empty', { targetId: null, mutateRaw: raw => { raw.firmware.dmi.sys_vendor = 'Elsewhere'; } });
  assert.deepEqual(automatic.layers, asserted.layers);
  assert.deepEqual(automatic.effective, asserted.effective);
  const withoutVendor = structuredClone(automatic.layers.detected);
  withoutVendor.firmware.dmi.sys_vendor = 'Elsewhere';
  assert.deepEqual(unqualified.layers.detected, withoutVendor);
});

test('automatic identification keeps sensitive values out of the document', () => {
  const serialized = JSON.stringify(discover('planted-sensitive', { targetId: null }));
  for (const planted of PLANTED_VALUES) assert.equal(serialized.includes(planted), false, `document leaks ${planted}`);
});

test('the shipped repository profiles load for automatic identification', () => {
  assert.deepEqual(loadAllTargets(join(repository, 'targets')).map(target => target.target_id), ['framework-13-pro-amd', 'reference-vm']);
});
