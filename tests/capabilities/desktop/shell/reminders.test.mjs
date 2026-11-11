// Static contract of the shell side of quick reminders (plan 02-34): the shared reminders service, the prompt, the
// bar indicator, the `reminders` IPC target, and the Critical-only quiet bypass for the reminder app (DEC-050).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const shellDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const read = file => readFileSync(path.join(shellDir, file), 'utf8');
// Comment lines are ignored: adaptation headers name the upstream helpers they replace.
const code = file => read(file).split('\n').filter(line => !/^\s*(\/\/|\/\*|\*)/.test(line)).join('\n');
const load = file => {
  const context = vm.createContext({});
  vm.runInContext(read(file).replace(/^\.pragma library\n/m, ''), context);
  return context;
};

const service = code('services/Reminders.qml');
const flow = code('reminders/ReminderFlow.qml');
const indicator = code('bar/indicators/Reminder.qml');
const shellQml = code('shell.qml');
const indicators = code('bar/widgets/Indicators.qml');
const Delivery = load('notifications/Delivery.js');
const CRITICAL = 2;
const NORMAL = 1;

test('the reminder shell files carry no Omarchy coupling or inline shell', () => {
  for (const [file, text] of [['reminders/ReminderFlow.qml', flow], ['reminders/ReminderFlowModel.js',
    code('reminders/ReminderFlowModel.js')], ['services/Reminders.qml', service],
  ['bar/indicators/Reminder.qml', indicator]]) {
    assert.doesNotMatch(text, /omarchy-|OMARCHY_PATH|bash -c/, file);
  }
});

test('the reminders service runs only `reminder show --json`, once per refresh, and never polls', () => {
  assert.equal(service.match(/\bProcess\s*\{/g)?.length, 1);
  assert.match(service, /command: \["\/usr\/share\/mirroros\/reminders\/reminder", "show", "--json"\]/);
  assert.match(service, /function refresh\(\) \{\s*if \(!root\.process\.running\) root\.process\.running = true/);
  assert.match(service, /Component\.onCompleted: refresh\(\)/);
  assert.doesNotMatch(service, /\bTimer\b|FileView|execDetached/);
});

test('the indicator reads the shared service and starts no process of its own', () => {
  assert.match(indicator, /firstPartyServiceFor\("mirroros\.reminders"\)/);
  assert.match(indicator, /active: reminderCount > 0/);
  assert.match(indicator, /execDetached\(\["\/usr\/share\/mirroros\/reminders\/reminder", "show"\]\)/);
  assert.match(indicator, /root\.bar\.shell\.openReminders\(\)/);
  assert.doesNotMatch(indicator, /\bProcess\b|indicatorHost|Component\.onCompleted/);
});

test('the shell registers the service, one prompt and the reminders IPC target', () => {
  assert.match(shellQml, /property Reminders remindersService: Reminders \{ \}/);
  assert.match(shellQml, /if \(id === "mirroros\.reminders"\) return remindersService/);
  assert.equal(shellQml.match(/\bReminderFlow\s*\{/g)?.length, 1);
  assert.match(shellQml, /IpcHandler \{\s*target: "reminders"/);
  assert.match(shellQml, /function open\(\): string \{\s*desktopShell\.openReminders\(\)\s*return "ok"/);
  assert.match(shellQml, /function refresh\(\): string \{\s*desktopShell\.remindersService\.refresh\(\)\s*return "ok"/);
});

test('the indicators widget lists Reminder, Dnd and StayAwake by default', () => {
  assert.match(indicators, /defaultIndicatorEntries: \[ "Reminder", "Dnd", "StayAwake" \]/);
  assert.match(indicators, /"Reminder": reminderIndicator/);
  assert.match(indicators, /Component \{ id: reminderIndicator; Reminder \{ \} \}/);
});

test('the prompt submits an argument vector and sends a transient invalid-input notice', () => {
  assert.match(flow, /\["\/usr\/share\/mirroros\/reminders\/reminder"\]\.concat\(ReminderFlowModel\.reminderArgs\(root\.minutes, selection\)\)/);
  assert.match(flow, /\["notify-send", "-a", "reminder", "-h", "boolean:transient:true", I18n\.t\("reminders\.invalidTitle"\), I18n\.t\("reminders\.invalidBody"\)\]/);
  assert.match(flow, /WlrLayershell\.namespace: "mirroros-reminders"/);
  assert.match(flow, /function open\(\) \{/);
  assert.match(flow, /function dismiss\(\) \{\s*root\.opened = false\s*\}/);
});

test('only a Critical notification from the reminder app passes quiet mode', () => {
  assert.equal(Delivery.bypassesQuiet({ app: 'reminder', urgency: CRITICAL }), true);
  assert.equal(Delivery.bypassesQuiet({ app: 'reminder', urgency: NORMAL }), false);
  assert.equal(Delivery.bypassesQuiet({ app: 'notify-send', urgency: CRITICAL }), true);
  assert.equal(Delivery.bypassesQuiet({ app: 'some-chat', urgency: CRITICAL }), false);
  const quiet = { doNotDisturb: true };
  assert.equal(Delivery.quietReason({ app: 'reminder', urgency: CRITICAL }, quiet), '');
  assert.equal(Delivery.quietReason({ app: 'reminder', urgency: NORMAL, transient: true }, quiet), 'silenced');
  assert.equal(Delivery.isEphemeral({ app: 'reminder', urgency: NORMAL, transient: true }), true);
  assert.equal(Delivery.isEphemeral({ app: 'reminder', urgency: CRITICAL }), false);
});
