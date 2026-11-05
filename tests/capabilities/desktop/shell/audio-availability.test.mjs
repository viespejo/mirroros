import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const osd = readFileSync(new URL('../../../../capabilities/desktop/shell/osd/Osd.qml', import.meta.url), 'utf8');
const audio = readFileSync(new URL('../../../../capabilities/desktop/shell/bar/widgets/Audio.qml', import.meta.url), 'utf8');

function body(source, name) {
  const match = source.match(new RegExp(`  function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`));
  assert.ok(match, `${name} must remain testable`);
  return match[1];
}

function property(name, context) {
  const match = audio.match(new RegExp(`readonly property bool ${name}: (.+)`));
  assert.ok(match, `${name} must remain declared`);
  return vm.runInNewContext(match[1], context);
}

function sourceState(output, ready = true) {
  return vm.runInNewContext(`(function(name) {${body(osd, 'sourceState')}})('volume')`, {
    output, Pipewire: { ready },
  });
}

function barState(sink, ready = true, settled = true) {
  const context = { volumeSink: sink, sink, Pipewire: { ready }, providerSettled: settled };
  return { hasOutput: property('hasOutput', context), unavailable: property('unavailable', context) };
}

test('WirePlumber fallback is unavailable without a fabricated OSD level', () => {
  const sink = { name: 'auto_null', audio: { volume: 1, muted: false } };
  const state = sourceState(sink);
  assert.equal(state.available, false);
  assert.match(state.reason, /No audio output/);
  assert.equal('value' in state, false);
  assert.equal('max' in state, false);
  assert.deepEqual(barState(sink), { hasOutput: false, unavailable: true });
});

test('ordinary, Bluetooth and non-fallback virtual sinks retain measured volume', () => {
  for (const name of ['alsa_output.test', 'bluez_output.test', 'effects_sink', 'network_sink']) {
    const sink = { name, properties: { 'node.virtual': true }, audio: { volume: 0.37, muted: true } };
    const state = sourceState(sink);
    assert.equal(state.available, true, name);
    assert.equal(state.value, 37, name);
    assert.equal(state.muted, true, name);
    assert.deepEqual(barState(sink), { hasOutput: true, unavailable: false });
  }
});

test('missing sinks and unavailable providers keep their existing distinct states', () => {
  assert.match(sourceState(null).reason, /No audio output/);
  assert.equal(sourceState({ name: 'pending' }).available, false);
  assert.match(sourceState(null, false).reason, /PipeWire unavailable/);
  assert.deepEqual(barState(null), { hasOutput: false, unavailable: false });
  assert.equal(barState(null, false, false).unavailable, false);
  assert.equal(barState(null, false, true).unavailable, true);
});

test('bar volume controls cannot write to the fallback sink', () => {
  const sink = { name: 'auto_null', audio: { volume: 1, muted: false } };
  const hasOutput = barState(sink).hasOutput;
  const value = vm.runInNewContext(`(function(v) {${body(audio, 'setOutputVolume')}})(0.5)`, {
    volumeSink: sink, hasOutput, outputVolume: 0, Math,
  });
  assert.equal(value, 0);
  assert.equal(sink.audio.volume, 1);
  assert.match(audio, /if \(!Pipewire\.ready \|\| !root\.hasOutput\) return/);
});

test('usable sinks keep volume clamping and measured updates', () => {
  const sink = { name: 'alsa_output.test', audio: { volume: 0.37, muted: false } };
  const value = vm.runInNewContext(`(function(v) {${body(audio, 'setOutputVolume')}})(2)`, {
    volumeSink: sink, hasOutput: true, outputVolume: 0.37, Math,
  });
  assert.equal(value, 1);
  assert.equal(sink.audio.volume, 1);
});
