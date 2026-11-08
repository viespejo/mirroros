// Audio panel: the copied v4.5.0 model as the panel uses it, and the MirrorOS adaptation points in Audio.qml.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const module = { exports: {} };
vm.runInNewContext(readFileSync(new URL('panels/audio/Model.js', shell), 'utf8'), { module });
const Model = module.exports;
const audio = readFileSync(new URL('bar/widgets/Audio.qml', shell), 'utf8');

function body(name) {
  const match = audio.match(new RegExp(`  function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`));
  assert.ok(match, `${name} must remain testable`);
  return match[1];
}

function fn(name, params, context) {
  return vm.runInNewContext(`(function(${params}) {${body(name)}})`, context);
}

test('availability parses the audio-device name<TAB>0|1 listing', () => {
  const parsed = Model.parseSinkAvailability('alsa_output.speaker\t1\nalsa_output.headphones\t0\n\nbluez_output.x\t1\n');
  assert.deepEqual({ ...parsed }, { 'alsa_output.speaker': true, 'alsa_output.headphones': false, 'bluez_output.x': true });
  assert.deepEqual({ ...Model.parseSinkAvailability('') }, {});
});

test('unavailable ports are hidden, unknown and pre-load ports are kept', () => {
  const context = { sinkAvailabilityLoaded: true, sinkAvailability: { 'alsa_output.headphones': false, 'alsa_output.speaker': true },
    sourceAvailabilityLoaded: true, sourceAvailability: { 'alsa_input.headset': false }, String };
  const sinkAvailable = fn('sinkAvailable', 'node', context);
  const sourceAvailable = fn('sourceAvailable', 'node', context);
  assert.equal(sinkAvailable({ name: 'alsa_output.headphones' }), false);
  assert.equal(sinkAvailable({ name: 'alsa_output.speaker' }), true);
  assert.equal(sinkAvailable({ name: 'bluez_output.headset' }), true);
  assert.equal(sourceAvailable({ name: 'alsa_input.headset' }), false);
  assert.equal(sourceAvailable({ name: 'alsa_input.internal' }), true);
  context.sinkAvailabilityLoaded = false;
  assert.equal(fn('sinkAvailable', 'node', context)({ name: 'alsa_output.headphones' }), true);
});

test('the WirePlumber dummy sink is never a device row', () => {
  const listedSink = fn('listedSink', 'node', { String });
  assert.equal(listedSink({ name: 'auto_null', isSink: true, isStream: false }), false);
  assert.equal(listedSink({ name: 'alsa_output.speaker', isSink: true, isStream: false }), true);
  assert.equal(listedSink({ name: 'effects_sink', isSink: true, isStream: false }), true);
  assert.equal(listedSink({ name: 'firefox', isSink: true, isStream: true }), false);
  assert.equal(listedSink({ name: 'alsa_input.mic', isSink: false, isStream: false }), false);
  assert.equal(listedSink(null), false);
});

test('row filters: playback streams, audio sources and primitive snapshots', () => {
  assert.equal(Model.isPlaybackStream({ isStream: true, isSink: true }), true);
  assert.equal(Model.isPlaybackStream({ isStream: true, isSink: false, type: 'Stream/Input/Audio' }), false);
  assert.equal(Model.isPlaybackStream({ isStream: false, isSink: true }), false);
  assert.equal(Model.isAudioSource({ audio: {} }), true);
  assert.equal(Model.isAudioSource({ type: 'Audio/Source' }), true);
  assert.equal(Model.isAudioSource({ type: 'Video/Source' }), true, 'upstream substring match is kept unchanged');
  const rows = Model.rowSnapshot([{ id: 4, name: 'a', audio: {} }, { name: 'no-id' }, null, { id: 9 }]);
  assert.deepEqual(JSON.parse(JSON.stringify(rows)), [{ id: 4, name: 'a' }, { id: 9, name: '' }]);
});

test('mixer labels use PipeWire names without MPRIS and player names when they match', () => {
  const stream = (name, extra = {}) => ({ name, ready: true, properties: { 'application.name': name, ...extra } });
  const firefox = stream('Firefox');
  const generic = stream('audio-src');
  assert.equal(Model.streamLabel(firefox, [], [firefox]), 'Firefox');
  assert.equal(Model.streamLabel(generic, [], [generic]), 'audio-src');
  const spotify = { identity: 'Spotify', isPlaying: true, canPlay: true, dbusName: 'org.mpris.MediaPlayer2.spotify' };
  assert.equal(Model.streamLabel(generic, [spotify], [generic]), 'Spotify');
  const chromium = { identity: 'Chromium', desktopEntry: 'chromium', isPlaying: true, canPlay: true };
  assert.equal(Model.streamLabel(stream('Chromium input'), [chromium], []), 'Chromium');
  assert.equal(Model.streamLabel(null, [], []), 'Stream');
});

test('default selection passes the node name, never the id, and ignores repeats while pending', () => {
  const calls = [];
  const proc = { running: false, command: null };
  const context = { Pipewire: {}, outputDefaultProc: proc, audioDevice: '/usr/share/mirroros/hardware/audio-device',
    pendingSinkName: '', String };
  const run = node => vm.runInNewContext(`(function(node) {${body('setDefaultSink')}})`, context)(node);
  Object.defineProperty(proc, 'running', { get() { return this._r || false; }, set(v) { this._r = v; if (v) calls.push(this.command); } });
  run({ id: 57, name: 'alsa_output.headphones' });
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [['/usr/share/mirroros/hardware/audio-device', 'default', 'output', 'alsa_output.headphones']]);
  assert.equal(context.pendingSinkName, 'alsa_output.headphones');
  assert.equal(context.Pipewire.preferredDefaultAudioSink.id, 57);
  run({ id: 58, name: 'alsa_output.speaker' });
  assert.equal(calls.length, 1, 'a second activation while pending is ignored');
  assert.doesNotMatch(audio, /"default", "(output|input)", String\(node\.id\)/);
  assert.match(audio, /inputDefaultProc\.command = \[audioDevice, "default", "input", pendingSourceName\]/);
  assert.match(audio, /onRunningChanged: if \(!running\) root\.pendingSinkName = ""/);
  assert.match(audio, /onRunningChanged: if \(!running\) root\.pendingSourceName = ""/);
});

test('panel contract: owned commands, open-only probes, advanced tool and no Omarchy runtime coupling', () => {
  assert.match(audio, /manageIpc: false/);
  assert.match(audio, /command: \[root\.audioDevice, "availability", "output"\]/);
  assert.match(audio, /command: \[root\.audioDevice, "availability", "input"\]/);
  assert.match(audio, /interval: 5000\n\s+running: root\.opened/);
  assert.match(audio, /enabled: root\.opened && !!root\.inputPeakNode/);
  assert.match(audio, /Quickshell\.execDetached\(\["uwsm", "app", "--", "pavucontrol"\]\)/);
  assert.match(audio, /text: "Advanced…"/);
  const code = audio.split('\n').filter(line => !/^\s*\/\//.test(line)).join('\n');
  assert.doesNotMatch(code, /omarchy-audio|omarchy\.media|easyeffects|UntypedInput|AudioNodes|activeMediaPlayer|ipcTarget/);
});

test('without an output the panel shows a reason and no slider or level', () => {
  assert.match(audio, /visible: !root\.hasOutput\n\s+width: parent\.width\n\s+textFormat: Text\.PlainText\n\s+text: root\.unavailableReason\(\)/);
  assert.match(audio, /if \(section === "output"\) return hasOutput/);
  assert.match(audio, /displayAudioSinks = hasOutput \? rowSnapshot\(audioSinks\) : \[\]/);
  assert.match(audio, /readonly property var inputPeakNode: hasInput \? source : null/);
});
