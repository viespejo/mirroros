// Deterministic native-API doubles for the production Plymouth script's bounded expression subset.
// Only function syntax and comments are adapted to JavaScript; this is not a Plymouth parser or runtime test.
// Native timing, rendering, diagnostics and real boot completion still require separately authorized boots.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../../../capabilities/system/boot-splash/plymouth/mirroros.script', import.meta.url), 'utf8');
const code = source.split('\n').filter(line => !/^\s*#/.test(line)).join('\n');
const adapted = code.replace(/\bfun (\w+)\(([^)]*)\)\s*\{/g,
  'function $1($2) { const local = {};');

function presentation({ width = 1280, height = 800, x = 0, y = 0 } = {}) {
  const window = { width, height, x, y };
  const callbacks = {};
  const backgrounds = [];
  const scales = [];
  const sprite = {
    SetImage(image) { this.image = image; },
    SetX(value) { this.x = value; },
    SetY(value) { this.y = value; },
    SetOpacity(value) { this.opacity = value; },
  };
  const image = {
    GetWidth: () => 320,
    GetHeight: () => 320,
    Scale(width, height) {
      assert.ok(width >= 1 && height >= 1);
      const scaled = { width, height };
      scales.push(scaled);
      return scaled;
    },
  };
  const context = {
    logo: {}, animation: {}, NULL: null,
    Math: { Int: Math.floor, Min: Math.min, Max: Math.max, Cos: Math.cos },
    Image(name) { assert.equal(name, 'mirroros-symbol.png'); return image; },
    Sprite() { return sprite; },
    Window: {
      GetWidth: () => window.width, GetHeight: () => window.height,
      GetX: () => window.x, GetY: () => window.y,
      SetBackgroundTopColor: (...rgb) => backgrounds.push(rgb),
      SetBackgroundBottomColor: (...rgb) => backgrounds.push(rgb),
    },
    Plymouth: {
      SetBootProgressFunction(callback) { callbacks.time = callback; },
      SetRefreshFunction(callback) { callbacks.refresh = callback; },
    },
  };
  context.global = context;
  vm.createContext(context);
  vm.runInContext(adapted, context, { timeout: 1000 });
  return {
    window, sprite, backgrounds, scales, callbacks,
    sample(duration, percentage = 0) {
      callbacks.time(duration, percentage);
      callbacks.refresh();
      return sprite.opacity;
    },
  };
}

function close(actual, expected) {
  assert.ok(Math.abs(actual - expected) < 1e-10, `${actual} differs from ${expected}`);
}

test('the native API surface is bounded and has no blocking or completion callback', () => {
  assert.deepEqual([...code.matchAll(/Plymouth\.(\w+)\(/g)].map(match => match[1]),
    ['SetBootProgressFunction', 'SetRefreshFunction']);
  assert.doesNotMatch(code, /\b(?:while|for|do|Sleep|sleep|exec|system|GetTime)\b/);
  assert.doesNotMatch(code, /SetQuitFunction|SetRootMountedFunction|SetDisplay|SetKeyboard|Image\.Text/);
  assert.equal(code.match(/\bunused_percentage\b/g).length, 1);
  assert.doesNotMatch(code, /\+\+|--|refresh_rate|frame_count/);
  const h = presentation();
  assert.deepEqual(h.backgrounds, [[16 / 255, 19 / 255, 21 / 255], [16 / 255, 19 / 255, 21 / 255]]);
  assert.equal(h.sprite.opacity, 0);
  assert.deepEqual(Object.keys(h.callbacks), ['time', 'refresh']);
});

test('the first duration sample sets the origin and the fade ends at 400 ms', () => {
  const h = presentation();
  for (const [elapsed, opacity] of [[0, 0], [0.1, 0.25], [0.2, 0.5], [0.399, 0.9975], [0.4, 1]])
    close(h.sample(17 + elapsed), opacity);
  close(h.sample(17.400001), 1);
});

test('the pulse is smooth, bounded to 75–100 percent and repeats every two seconds', () => {
  const h = presentation();
  h.sample(0);
  for (const [time, opacity] of [[0.4, 1], [0.9, 0.875], [1.4, 0.75], [1.9, 0.875], [2.4, 1], [3.4, 0.75]])
    close(h.sample(time), opacity);
  // New instances compare absolute times without moving a clock backwards.
  for (const phase of [0, 0.01, 0.1, 0.37, 0.5, 1, 1.71, 1.99]) {
    const a = presentation();
    const b = presentation();
    a.sample(0);
    b.sample(0);
    close(a.sample(0.4 + phase), b.sample(2.4 + phase));
  }
  for (let time = 3.4; time < 20; time += 0.013) {
    const opacity = h.sample(time);
    assert.ok(opacity >= 0.75 && opacity <= 1);
  }
});

test('dropped refreshes do not stretch timing and percentage never affects opacity', () => {
  const a = presentation();
  const b = presentation();
  a.sample(100, 0);
  b.sample(100, 1);
  for (let tick = 1; tick < 140; tick++) a.sample(100 + tick / 100, tick / 200);
  // The second instance sees only two duration samples: it must still reach the same pulse minimum.
  close(a.sample(101.4, 0.99), b.sample(101.4, 0));
  close(b.sprite.opacity, 0.75);
  close(b.sample(101.4, 1), 0.75);
});

test('native active-time pauses freeze opacity and resume without a restarted fade', () => {
  const h = presentation();
  h.sample(10);
  close(h.sample(10.2), 0.5);
  for (let tick = 0; tick < 200; tick++) {
    h.callbacks.refresh();
    close(h.sprite.opacity, 0.5);
  }
  close(h.sample(10.2, 1), 0.5);
  close(h.sample(10.4), 1);
  close(h.sample(11.4), 0.75);
  for (let tick = 0; tick < 100; tick++) close(h.sample(11.4, tick / 100), 0.75);
  close(h.sample(12.4), 1);
});

test('resize preserves centering, square proportions, bounds and no upscaling', () => {
  const h = presentation();
  h.sample(0);
  h.sample(2.4);
  for (const [width, height, x, y] of [[800, 480, 0, 0], [1280, 800, 0, 0], [3840, 2160, 100, 50],
    [240, 1000, -240, 0], [768, 1024, 0, 12]]) {
    Object.assign(h.window, { width, height, x, y });
    h.callbacks.refresh();
    const scaled = h.sprite.image;
    assert.equal(scaled.width, scaled.height);
    assert.ok(scaled.width <= Math.min(320, width * 0.42, height * 0.22));
    assert.equal(h.sprite.x, x + Math.floor((width - scaled.width) / 2));
    assert.equal(h.sprite.y, y + Math.floor((height - scaled.height) / 2));
    close(h.sprite.opacity, 1);
  }
  const count = h.scales.length;
  for (let tick = 0; tick < 100; tick++) h.callbacks.refresh();
  assert.equal(h.scales.length, count, 'unchanged dimensions must not rescale each frame');
  h.window.x += 100;
  const beforeX = h.sprite.x;
  h.callbacks.refresh();
  assert.equal(h.sprite.x, beforeX + 100);
  assert.equal(h.scales.length, count);
  Object.assign(h.window, { width: 1, height: 1 });
  h.callbacks.refresh();
  assert.equal(h.sprite.opacity, 0);
  assert.equal(h.scales.length, count, 'do not request a zero-size native image');
  Object.assign(h.window, { width: 1280, height: 800 });
  h.callbacks.refresh();
  close(h.sprite.opacity, 1);
});
