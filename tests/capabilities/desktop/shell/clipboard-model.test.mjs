import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const require = createRequire(import.meta.url);
const model = require('../../../../capabilities/desktop/shell/clipboard/ClipboardHistoryModel.js');
const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const read = file => readFileSync(new URL(file, shell), 'utf8');
const service = read('services/Clipboard.qml');
const picker = read('clipboard/ClipboardPicker.qml');
const entrypoint = read('shell.qml');
const plain = value => JSON.parse(JSON.stringify(value));
const fixture = '19\t<b>Disposable</b>\n18\t[[ binary data 2 KiB png 100x50 ]]\n17\ttext\twith tab\n';

function adapter() {
  const root = { executable: '/usr/share/mirroros/clipboard/clipboard-history',
    history: [], previews: {}, previewQueue: [], requested: {}, generation: 0,
    active: false, loading: false, failed: false, busy: false };
  const processes = { listProcess: { running: false }, actionProcess: { running: false },
    previewProcess: { running: false }, listing: { text: fixture }, previewOutput: { text: '' } };
  Object.assign(root, { listProcess: processes.listProcess, actionProcess: processes.actionProcess,
    previewProcess: processes.previewProcess });
  const context = vm.createContext({ root, ...processes, History: model,
    Quickshell: { env: key => key === 'XDG_RUNTIME_DIR' ? '/run/user/1000' : '' } });
  for (const match of service.matchAll(/^  function (\w+)\(([^)]*)\) \{([\s\S]*?)^  \}/gm))
    root[match[1]] = vm.runInContext(`(function(${match[2]}) {${match[3]}})`, context);
  const exited = name => {
    const block = service.slice(service.indexOf(`property Process ${name}:`));
    const match = block.match(/onExited: function\(code\) \{([\s\S]*?)\n    \}/);
    return vm.runInContext(`(function(code) {${match[1]}})`, context);
  };
  return { root, ...processes, exited };
}

test('TSV parsing keeps opaque numeric ids and plain text, detects images and rejects malformed rows', () => {
  const rows = model.parseHistory(fixture + 'bad\tignored\n19\tduplicate\n-1\tbad\n1;id\tbad\nno tab\n');
  assert.deepEqual(rows, [
    { id: '19', text: '<b>Disposable</b>', image: false },
    { id: '18', text: '[[ binary data 2 KiB png 100x50 ]]', image: true },
    { id: '17', text: 'text\twith tab', image: false },
  ]);
  assert.deepEqual(model.parseHistory(''), []);
  assert.equal(model.parseHistory('9999999999999999999\tlarge id')[0].id, '9999999999999999999');
  assert.equal(model.parseHistory('1\t' + 'x'.repeat(10000))[0].text.length, 8192);
  assert.equal(model.parseHistory('1\tprefix [[ binary data png ]]')[0].image, false);
});

test('filtering, labels, removal and bounded selection are pure', () => {
  const history = model.parseHistory(fixture);
  const before = JSON.stringify(history);
  assert.equal(model.displayRows(history, 'DISPOSABLE')[0].label, '<b>Disposable</b>');
  assert.equal(model.displayRows(history, 'image', 'Image')[0].id, '18');
  assert.equal(model.displayRows(history, 'image', 'Image')[0].label, 'Image');
  assert.equal(model.displayRows(history, 'absent').length, 0);
  assert.equal(model.displayRows(history, '', 'Image')[2].label, 'text with tab');
  assert.equal(model.removeEntry(history, '18').length, 2);
  assert.equal(JSON.stringify(history), before);
  for (const [index, count, delta, absolute, expected] of [
    [0, 0, 1, false, 0], [0, 3, -1, false, 0], [0, 3, 6, false, 2],
    [2, 3, -6, false, 0], [0, 3, 2, true, 2], [2, 1, 0, false, 0],
  ]) assert.equal(model.selection(index, count, delta, absolute), expected);
});

test('one list per opening; stale responses cannot populate a reopened picker', () => {
  const a = adapter();
  a.root.open();
  assert.equal(a.listProcess.running, true);
  assert.equal(a.root.listGeneration, 1);
  a.root.close();
  a.root.open();
  assert.equal(a.root.listGeneration, 1);
  a.listProcess.running = false;
  a.exited('listProcess')(0);
  assert.equal(a.root.listGeneration, 2);
  assert.equal(a.root.history.length, 0);
  a.listProcess.running = false;
  a.exited('listProcess')(0);
  assert.equal(a.root.history.length, 3);
  assert.equal(a.root.loading, false);
  a.root.close();
  assert.equal(a.root.history.length, 0);
});

test('preview requests are restricted to image ids, deduplicated and validated as runtime paths', () => {
  const a = adapter();
  a.root.open();
  a.exited('listProcess')(0);
  for (const id of ['19', 'missing', '../18', '18', '18']) a.root.requestPreview(id);
  assert.equal(a.previewProcess.running, true);
  assert.deepEqual(plain(a.previewProcess.command), [a.root.executable, 'preview', '18']);
  assert.equal(a.root.previewQueue.length, 0);
  a.previewProcess.running = false;
  a.previewOutput.text = '/tmp/18.png\n';
  a.exited('previewProcess')(0);
  assert.deepEqual(plain(a.root.previews), {});
  a.previewOutput.text = '/run/user/1000/mirroros/clipboard/previews/18.png\n';
  a.exited('previewProcess')(0);
  assert.equal(a.root.previews['18'], a.previewOutput.text.trim());
  a.root.generation++;
  a.root.previews = {};
  a.exited('previewProcess')(0);
  assert.deepEqual(plain(a.root.previews), {});
});

test('fixed argv actions update local history only on success and reject invalid or busy requests', () => {
  const a = adapter();
  a.root.open();
  a.exited('listProcess')(0);
  assert.equal(a.root.act('store', '19'), false);
  assert.equal(a.root.act('delete', '../19'), false);
  a.root.busy = true;
  assert.equal(a.root.act('clear', ''), false);
  a.root.busy = false;
  for (const action of ['copy', 'open', 'delete']) {
    assert.equal(a.root.act(action, '19'), true);
    assert.deepEqual(plain(a.actionProcess.command), [a.root.executable, action, '19']);
  }
  a.exited('actionProcess')(1);
  assert.equal(a.root.history.length, 3);
  a.exited('actionProcess')(0);
  assert.equal(a.root.history.length, 2);
  assert.equal(a.root.act('clear', ''), true);
  assert.deepEqual(plain(a.actionProcess.command), [a.root.executable, 'clear']);
  a.exited('actionProcess')(0);
  assert.equal(a.root.history.length, 0);
  assert.equal((service.match(/root\.startList\(\)/g) || []).length, 2);
});

test('picker contracts: no persistence, capture, auto-paste or rich text; confirmation and native IPC', () => {
  assert.doesNotMatch(service + picker, /FileView|Timer\s*\{|wl-paste|wtype|execDetached|bash.*-c/);
  assert.doesNotMatch(picker, /RichText|AutoText|StyledText/);
  assert.equal((picker.match(/\bText\s*\{/g) || []).length,
    (picker.match(/textFormat: Text\.PlainText/g) || []).length);
  assert.match(picker, /FilterInput\s*\{/);
  assert.match(picker, /pointerGate\.moved/);
  assert.match(picker, /clearConfirm\.selectedIndex = 0/);
  assert.match(picker, /onConfirmed:[\s\S]*service\.act\("clear"/);
  assert.match(picker, /Qt\.ShiftModifier \| Qt\.ControlModifier \| Qt\.MetaModifier/);
  assert.match(picker, /root\.activate\(event\.modifiers & Qt\.AltModifier \? "open" : "copy"\)/);
  assert.match(entrypoint, /id === "mirroros.clipboard"/);
  assert.match(entrypoint, /name: "clipboard"[\s\S]*clipboardPicker.toggle/);
  assert.match(entrypoint, /target: "clipboard"[\s\S]*function open\(\)[\s\S]*function toggle\(\)/);
});
