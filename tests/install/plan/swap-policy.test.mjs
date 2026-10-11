import test from 'node:test';
import assert from 'node:assert/strict';
import {
  GIBIBYTE,
  MEBIBYTE,
  SWAPFILE_MINIMUM_MIB,
  checkSwapfileSize,
  hasResumeParameters,
  isMemoryBytes,
  isSwapfileBelowRam,
  isSwapfileSizeInRange,
  kernelCommandLine,
  requiredDiskBytes,
  swapfileMaximumMib,
  swapfileRange,
} from '../../../install/plan/swap-policy.mjs';

test('detected memory is a positive safe integer and nothing else', () => {
  for (const value of [1, 4294967296, Number.MAX_SAFE_INTEGER]) assert.equal(isMemoryBytes(value), true, String(value));
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, Infinity, NaN, '4096', null, undefined, true]) {
    assert.equal(isMemoryBytes(value), false, String(value));
  }
});

test('the maximum is the memory rounded up to whole GiB, in MiB', () => {
  assert.equal(swapfileMaximumMib(1), 1024);
  assert.equal(swapfileMaximumMib(GIBIBYTE - 1), 1024);
  assert.equal(swapfileMaximumMib(GIBIBYTE), 1024);
  assert.equal(swapfileMaximumMib(GIBIBYTE + 1), 2048);
  assert.equal(swapfileMaximumMib(4090589184), 4096);
  assert.equal(swapfileMaximumMib(4 * GIBIBYTE), 4096);
  assert.equal(swapfileMaximumMib(4 * GIBIBYTE + 1), 5120);
  assert.equal(swapfileMaximumMib(96 * GIBIBYTE), 98304);
  assert.equal(swapfileMaximumMib(1024 * GIBIBYTE), 1048576);
  for (const value of [0, -5, 1.5, undefined, Number.MAX_SAFE_INTEGER + 1]) assert.equal(swapfileMaximumMib(value), undefined, String(value));
  assert.ok(Number.isSafeInteger(swapfileMaximumMib(Number.MAX_SAFE_INTEGER)));
});

test('the range has a fixed minimum, the maximum as default, and the memory it came from', () => {
  assert.deepEqual(swapfileRange(4 * GIBIBYTE), {
    minimum: 512, maximum: 4096, default: 4096, unit: 'MiB', memory_total_bytes: 4 * GIBIBYTE,
  });
  assert.equal(SWAPFILE_MINIMUM_MIB, 512);
  assert.equal(swapfileRange(0), undefined);
  assert.equal(swapfileRange(536870912).minimum, 512);
  assert.equal(swapfileRange(536870912).maximum, 1024);
});

test('a size is valid from 512 MiB up to and including the maximum', () => {
  const memory = 4 * GIBIBYTE;
  for (const size of [512, 513, 2048, 4095, 4096]) assert.equal(isSwapfileSizeInRange(size, memory), true, String(size));
  for (const size of [511, 0, -1, 4097, 1.5, '2048', null, NaN, Number.MAX_SAFE_INTEGER]) {
    assert.equal(isSwapfileSizeInRange(size, memory), false, String(size));
  }
  assert.equal(isSwapfileSizeInRange(512, undefined), false);
  assert.equal(checkSwapfileSize(2048, memory), undefined);
  assert.match(checkSwapfileSize(4097, memory), /512 to 4096 MiB/);
  assert.match(checkSwapfileSize(100, memory), /from 512 MiB/);
  assert.match(checkSwapfileSize(1.5, memory), /integer/);
  assert.doesNotMatch(String(checkSwapfileSize(99999, memory)), /99999/);
  // Without memory only the integer and minimum checks apply.
  assert.equal(checkSwapfileSize(99999, undefined), undefined);
});

test('a size below the raw memory warns and an equal size does not', () => {
  assert.equal(isSwapfileBelowRam(4095, 4 * GIBIBYTE), true);
  assert.equal(isSwapfileBelowRam(4096, 4 * GIBIBYTE), false);
  assert.equal(isSwapfileBelowRam(4096, 4 * GIBIBYTE + 1), true);
  assert.equal(isSwapfileBelowRam(4096, 4 * GIBIBYTE - 1), false);
  assert.equal(isSwapfileBelowRam(5120, 4 * GIBIBYTE + 1), false);
  assert.equal(isSwapfileBelowRam(512, 4090589184), true);
  // 4090589184 bytes are 3901.1 MiB: 3901 MiB is still below, 3902 MiB is above.
  assert.equal(isSwapfileBelowRam(3901, 4090589184), true);
  assert.equal(isSwapfileBelowRam(3902, 4090589184), false);
  assert.equal(isSwapfileBelowRam(1.5, 4 * GIBIBYTE), false);
  assert.equal(isSwapfileBelowRam(512, 0), false);
});

test('the disk requirement adds the swapfile only when present and refuses unsafe sums', () => {
  const base = { espBytes: GIBIBYTE, rootMinimumBytes: 15 * GIBIBYTE };
  assert.equal(requiredDiskBytes(base), 16 * GIBIBYTE);
  assert.equal(requiredDiskBytes({ ...base, swapfileMib: 4096 }), 20 * GIBIBYTE);
  assert.equal(requiredDiskBytes({ ...base, swapfileMib: 512 }), 16 * GIBIBYTE + 512 * MEBIBYTE);
  assert.equal(requiredDiskBytes({ ...base, swapfileMib: Number.MAX_SAFE_INTEGER }), undefined);
  assert.equal(requiredDiskBytes({ espBytes: Number.MAX_SAFE_INTEGER, rootMinimumBytes: 1 }), undefined);
});

test('disabling hibernation removes exactly the resume parameters from the command line', () => {
  const policy = 'root=UUID=<root> rw zswap.enabled=0 resume=UUID=<root> resume_offset=<resume_offset>';
  assert.equal(kernelCommandLine(policy, true), policy);
  assert.equal(kernelCommandLine(policy, false), 'root=UUID=<root> rw zswap.enabled=0');
  assert.deepEqual(hasResumeParameters(policy), [true, true]);
  assert.deepEqual(hasResumeParameters('root=UUID=<root> rw zswap.enabled=0'), [false, false]);
  assert.deepEqual(hasResumeParameters('root=UUID=<root> resume=UUID=<root>'), [true, false]);
  assert.equal(kernelCommandLine('rw quiet', false), 'rw quiet');
});
