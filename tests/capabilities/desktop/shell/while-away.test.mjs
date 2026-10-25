// Contracts for the conditional while-away count model (DEC-021/022).
// The model is not wired into the runtime until the guest proof passes.
// Usage: node --test tests/capabilities/desktop/shell/while-away.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const shellDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const W = createRequire(import.meta.url)(path.join(shellDir, 'notifications/WhileAway.js'));

test('arrivals count only while locked', () => {
  let s = W.notified(W.initial());
  assert.equal(s.count, 0);
  s = W.notified(W.notified(W.lock(s)));
  assert.equal(s.count, 2);
});

test('the count is visible only on return and survives unlock', () => {
  let s = W.notified(W.lock(W.initial()));
  assert.equal(W.visibleCount(s), 0);
  s = W.unlock(s);
  assert.equal(W.visibleCount(s), 1);
});

test('opening history clears the count; a later lock accumulates afresh', () => {
  let s = W.unlock(W.notified(W.lock(W.initial())));
  s = W.unlock(W.notified(W.lock(s)));
  assert.equal(s.count, 2);
  s = W.historyOpened(s);
  assert.equal(W.visibleCount(s), 0);
  assert.equal(W.visibleCount(W.unlock(W.notified(W.lock(s)))), 1);
});

test('reconciliation trusts the observed lock state and keeps a valid count', () => {
  const persisted = W.serialize(W.notified(W.lock(W.initial())));
  assert.deepEqual(W.reconcile(W.parse(persisted), true), { version: 1, locked: true, count: 1 });
  assert.deepEqual(W.reconcile(W.parse(persisted), false), { version: 1, locked: false, count: 1 });
  assert.deepEqual(W.reconcile(W.parse(''), true), { version: 1, locked: true, count: 0 });
});

test('malformed or hostile state starts from zero and stores no content', () => {
  for (const text of ['{', '[]', 'null', '{"version":2,"count":5}', '{"version":1,"count":-3}',
    '{"version":1,"count":"7"}', '{"version":1,"count":1.5}']) {
    assert.equal(W.parse(text).count, 0, text);
  }
  const s = W.parse('{"version":1,"locked":true,"count":2,"summary":"secret","__proto__":{"x":1}}');
  assert.deepEqual(Object.keys(s), ['version', 'locked', 'count']);
  assert.equal(W.serialize(s).includes('secret'), false);
  assert.equal({}.x, undefined);
});

test('the count is bounded', () => {
  let s = W.lock({ version: 1, locked: true, count: W.MAX_COUNT });
  s = W.notified(s);
  assert.equal(s.count, W.MAX_COUNT);
});
