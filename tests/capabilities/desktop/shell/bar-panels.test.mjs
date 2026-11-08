// Pure panel routing of the adapted bar model (DEC-045 "focused monitor wins") and the bar's static IPC contract.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const model = vm.createContext({});
vm.runInContext(readFileSync(new URL('bar/BarModel.js', shell), 'utf8'), model);
const bar = readFileSync(new URL('bar/Bar.qml', shell), 'utf8');
const shellQml = readFileSync(new URL('shell.qml', shell), 'utf8');

const slot = (name, drawn = true) => ({ name, visible: drawn, width: drawn ? 24 : 0, height: drawn ? 24 : 0 });
const copies = (opened = '', undrawn = []) => ['A', 'B'].map(screen =>
  ({ slot: slot(screen, !undrawn.includes(screen)), screenName: screen, opened: screen === opened }));
const act = (candidates, focused, action) => {
  const step = model.panelAction(candidates, focused, action);
  return step ? `${step.method} ${step.slot.name}` : null;
};

test('every cell of the focused-monitor table acts on the expected copy', () => {
  // Focus is on A; the panel is closed, open on the focused monitor, or open on another monitor.
  const table = {
    open: { closed: 'open A', focused: 'open A', elsewhere: 'open A' },
    close: { closed: null, focused: 'close A', elsewhere: 'close B' },
    toggle: { closed: 'open A', focused: 'close A', elsewhere: 'open A' },
  };
  const states = { closed: '', focused: 'A', elsewhere: 'B' };
  for (const [action, row] of Object.entries(table))
    for (const [state, expected] of Object.entries(row))
      assert.equal(act(copies(states[state]), 'A', action), expected, `${action} when ${state}`);
});

test('a focus change alone moves nothing and routing never mutates its input', () => {
  const candidates = copies('B');
  const snapshot = JSON.stringify(candidates);
  act(candidates, 'A', 'toggle');
  assert.equal(JSON.stringify(candidates), snapshot);
  assert.doesNotMatch(bar, /onFocusedMonitorChanged|target: Hyprland/);
});

test('an undrawn focused copy falls back to a drawn copy, preferring an open one', () => {
  const three = [...copies('', ['A']), { slot: slot('C'), screenName: 'C', opened: false }];
  assert.equal(act(three, 'A', 'open'), 'open B');
  three[2].opened = true;
  assert.equal(act(three, 'A', 'open'), 'open C');
  assert.equal(act(three, 'A', 'toggle'), 'close C');
  assert.equal(act(copies(), '', 'toggle'), 'open A');
  assert.equal(act(copies('', ['A', 'B']), 'A', 'open'), 'open A');
  assert.equal(act([], 'A', 'open'), null);
  assert.equal(act(copies(), 'A', 'unknown'), null);
});

test('center sections navigate as one and other regions stay alone', () => {
  assert.deepEqual([...model.navigationRegions('center')], ['centerBegin', 'center', 'centerEnd']);
  assert.deepEqual([...model.navigationRegions('centerEnd')], ['centerBegin', 'center', 'centerEnd']);
  assert.deepEqual([...model.navigationRegions('right')], ['right']);
  assert.equal(model.pickDrawnSlot([slot('x', false), slot('y')]).name, 'y');
  assert.equal(model.pickDrawnSlot([slot('x', false)]).name, 'x');
});

test('positional panels count drawn panel icons of one monitor and skip non-panel widgets', () => {
  const ids = ['omarchy.tray', 'omarchy.keyboard-layout', 'omarchy.network', 'omarchy.audio', 'omarchy.monitor', 'omarchy.power'];
  const layout = { right: ids.map(id => ({ id })) };
  const slots = [];
  for (const screenName of ['A', 'B'])
    for (const id of ids)
      slots.push({ region: 'right', moduleName: id, screenName,
        panel: !['omarchy.tray', 'omarchy.keyboard-layout'].includes(id),
        drawn: !(screenName === 'B' && id === 'omarchy.network') });
  const names = screen => [...model.panelSlots(['right'], layout, slots, screen)].map(s => s.moduleName);
  assert.deepEqual(names('A'), ['omarchy.network', 'omarchy.audio', 'omarchy.monitor', 'omarchy.power']);
  assert.deepEqual(names('B'), ['omarchy.audio', 'omarchy.monitor', 'omarchy.power']);
  assert.ok(model.panelSlots(['right'], layout, slots, 'A').every(s => s.screenName === 'A'));
  assert.equal(names('').length, 4);
});

test('panel IPC targets are declared once, outside the per-screen bar, with open/close/toggle only', () => {
  const variants = bar.indexOf('  Variants {');
  for (const target of ['audio', 'display', 'power']) {
    const matches = [...bar.matchAll(new RegExp(`target: "${target}"`, 'g'))];
    assert.equal(matches.length, 1, target);
    assert.ok(matches[0].index < variants, target);
    const block = bar.slice(matches[0].index, bar.indexOf('\n  }', matches[0].index));
    assert.deepEqual([...block.matchAll(/function (\w+)\(/g)].map(m => m[1]), ['open', 'close', 'toggle']);
  }
  assert.doesNotMatch(readFileSync(new URL('Ui/Panel.qml', shell), 'utf8'), /^\s*(IpcHandler|ShellIpc)\s*\{/m);
  assert.match(bar, /BarModel\.panelAction\(candidates, focusedScreenName\(\), action\)/);
});

test('the shell registers the panel global shortcuts under the mirroros application id', () => {
  for (const name of ['panel.audio', 'panel.display', 'panel.power', 'panel.notifications'])
    assert.match(shellQml, new RegExp(`appid: "mirroros"\\n\\s+name: "${name.replace('.', '\\.')}"`), name);
  assert.match(shellQml, /model: \[1, 2, 3, 4, 5, 6, 7, 8, 9\][\s\S]*name: "panel-at-" \+ modelData[\s\S]*togglePanelAt\("right", modelData\)/);
  assert.doesNotMatch(shellQml, /appid: "omarchy"|SocketServer|OMARCHY_PATH/);
});
