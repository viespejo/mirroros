import test from 'node:test';
import assert from 'node:assert/strict';
import { canonicalize, PlanContractError } from '../../../install/plan/canonical-json.mjs';

test('keys are sorted and independent of insertion order', () => {
  assert.equal(canonicalize({ b: 1, a: 2, c: { z: 1, y: 2 } }), '{"a":2,"b":1,"c":{"y":2,"z":1}}');
  assert.equal(canonicalize({ c: { y: 2, z: 1 }, a: 2, b: 1 }), canonicalize({ b: 1, a: 2, c: { z: 1, y: 2 } }));
});

test('keys sort by code point, not by UTF-16 code unit', () => {
  const astral = '\u{10000}';
  const bmp = '\uffff';
  assert.equal(canonicalize({ [astral]: 1, [bmp]: 2 }), `{"${bmp}":2,"${astral}":1}`);
});

test('there is no whitespace and arrays keep their order', () => {
  assert.equal(canonicalize({ list: [3, 1, 2], flag: true, none: null, text: 'a b' }), '{"flag":true,"list":[3,1,2],"none":null,"text":"a b"}');
});

test('non-ASCII text is kept as UTF-8, not escaped', () => {
  assert.equal(canonicalize({ name: 'señal' }), '{"name":"señal"}');
});

test('integers are written plainly, including negative values and zero', () => {
  assert.equal(canonicalize([0, -5, 34359738368]), '[0,-5,34359738368]');
});

test('values that cannot be canonicalized are contract errors', () => {
  for (const value of [undefined, 1.5, Number.NaN, Infinity, 2 ** 60, () => 1, 10n, Symbol('x'), new Date(0), new Map()]) {
    assert.throws(() => canonicalize({ value }), PlanContractError);
  }
  assert.throws(() => canonicalize([undefined]), PlanContractError);
});

test('the error names the offending path', () => {
  assert.throws(() => canonicalize({ a: { b: [1, 1.5] } }), /\$\.a\.b\[1\]/);
});
