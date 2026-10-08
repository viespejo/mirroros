import { createHash } from 'node:crypto';
import { canonicalize } from './canonical-json.mjs';

export const DIGEST_ALGORITHM = 'sha256';

export function sha256Canonical(value) {
  return createHash('sha256').update(canonicalize(value), 'utf8').digest('hex');
}

export function computeDigest(plan) {
  const { digest: _digest, ...content } = plan;
  return sha256Canonical(content);
}

export function withDigest(plan) {
  const { digest: _digest, ...content } = plan;
  return { ...content, digest: { algorithm: DIGEST_ALGORITHM, value: computeDigest(content) } };
}

export function verifyDigest(plan) {
  const digest = plan.digest;
  return digest !== null
    && typeof digest === 'object'
    && digest.algorithm === DIGEST_ALGORITHM
    && digest.value === computeDigest(plan);
}
