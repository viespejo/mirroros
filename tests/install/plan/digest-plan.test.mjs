import test from 'node:test';
import assert from 'node:assert/strict';
import { computeDigest, sha256Canonical, verifyDigest, withDigest } from '../../../install/plan/digest-plan.mjs';
import { buildValidPlan } from './build-fixtures.mjs';

test('the digest is SHA-256 hex over the canonical content', () => {
  assert.equal(sha256Canonical({ a: 1 }), '015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862');
  assert.equal(sha256Canonical({ a: 1, b: 2 }), sha256Canonical({ b: 2, a: 1 }));
  assert.notEqual(sha256Canonical({ a: 1 }), sha256Canonical({ a: 2 }));
});

test('the digest excludes the digest field itself', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  const { digest: _digest, ...content } = plan;
  assert.equal(computeDigest(plan), computeDigest(content));
  assert.equal(computeDigest({ ...plan, digest: { algorithm: 'sha256', value: 'x' } }), computeDigest(plan));
});

test('withDigest produces a verifiable plan and is idempotent', () => {
  const plan = buildValidPlan('btrfs-rescue', 'password');
  assert.equal(plan.digest.algorithm, 'sha256');
  assert.equal(verifyDigest(plan), true);
  assert.deepEqual(withDigest(plan), plan);
});

test('identical content yields an identical digest on every run', () => {
  assert.equal(buildValidPlan('ext4-systemd-boot', 'locked').digest.value, buildValidPlan('ext4-systemd-boot', 'locked').digest.value);
});

test('any content change changes the digest', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  const edited = structuredClone(plan);
  edited.choices.hostname.value = 'other';
  assert.notEqual(computeDigest(edited), plan.digest.value);
  assert.equal(verifyDigest(edited), false);
  const rebound = structuredClone(plan);
  rebound.policy_binding.policy_sha256 = 'f'.repeat(64);
  assert.notEqual(computeDigest(rebound), plan.digest.value);
  const refacted = structuredClone(plan);
  refacted.facts_binding.facts_sha256 = 'f'.repeat(64);
  assert.notEqual(computeDigest(refacted), plan.digest.value);
});

test('tampered or malformed digest fields fail verification', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  assert.equal(verifyDigest({ ...plan, digest: { algorithm: 'md5', value: plan.digest.value } }), false);
  assert.equal(verifyDigest({ ...plan, digest: undefined }), false);
  assert.equal(verifyDigest({ ...plan, digest: null }), false);
});

test('the signed content carries no timestamp and no plan run id', () => {
  const plan = buildValidPlan('ext4-systemd-boot', 'locked');
  assert.equal(plan.run_id, undefined);
  assert.doesNotMatch(JSON.stringify(plan), /"(timestamp|generated_at|created_at)"/);
});
