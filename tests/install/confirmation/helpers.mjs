import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generate, facts, policy, referenceOverride } from '../plan/helpers.mjs';

export { facts, generate, policy, referenceOverride };
export { removeDirectory, repository, temporaryDirectory } from '../plan/helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
export const confirmationFixtures = resolve(here, '../../fixtures/confirmation');
export const CANARY = 'PLANTED-CONFIRMATION-SECRET-0001';

export function recordFixture(name) {
  return join(confirmationFixtures, 'records', name);
}

export function currentHashes() {
  return { policy_sha256: policy.sha256, override_sha256: referenceOverride().sha256 };
}

export function clone(value) {
  return structuredClone(value);
}

export function firstDisk(document) {
  return document.layers.detected.storage.disks[0];
}

// Rewrites the first disk of a facts document and keeps the `effective` view in step.
export function withDisk(document, change) {
  const copy = clone(document);
  change(firstDisk(copy));
  copy.effective['storage.disks'].value = copy.layers.detected.storage.disks;
  return copy;
}

export function withoutById(document) {
  return withDisk(document, disk => {
    delete disk.identity.by_id;
  });
}
