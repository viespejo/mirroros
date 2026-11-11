// Reminder prompt model: the cases of Omarchy v4.5.0 test/shell.d/reminders-test.sh
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson), ported to node:test against the unchanged copy in
// reminders/ReminderFlowModel.js.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const reminders = require('../../../../capabilities/desktop/shell/reminders/ReminderFlowModel.js');

const assertEqual = (actual, expected, description) => assert.equal(actual, expected, description);
// Upstream compares deep values through JSON, so the port does too.
const assertDeepEqual = (actual, expected, description) =>
  assert.equal(JSON.stringify(actual), JSON.stringify(expected), description);

test('reminder flow model', () => {
  assertEqual(reminders.validMinutes('15'), '15', 'reminders accepts positive integer minutes');
  assertEqual(reminders.validMinutes('  5  '), '5', 'reminders trims minute input');
  assertEqual(reminders.validMinutes('0'), '', 'reminders rejects zero minutes');
  assertEqual(reminders.validMinutes('-5'), '', 'reminders rejects negative minutes');
  assertEqual(reminders.validMinutes('1.5'), '', 'reminders rejects fractional minutes');
  assertEqual(reminders.validMinutes('soon'), '', 'reminders rejects non-numeric minutes');

  assertDeepEqual(
    reminders.reminderArgs('10', 'Check the oven'),
    ['10', 'Check the oven'],
    'reminders builds command args with message'
  );

  assertDeepEqual(
    reminders.reminderArgs('10', ''),
    ['10'],
    'reminders omits empty message arg'
  );

  assertDeepEqual(
    reminders.reminderArgs('0', 'ignored'),
    [],
    'reminders command args are empty for invalid minutes'
  );
});
