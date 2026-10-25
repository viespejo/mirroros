#!/usr/bin/env node
// Prototype-local warning baseline. No qmllint categories are disabled.
// --capture emits candidate keys for an explicit, reviewed baseline update;
// normal checks fail on new diagnostics and stale baseline entries alike.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const shellDir = path.resolve(testsDir, '../../../../capabilities/desktop/shell');
const baselinePath = path.join(testsDir, 'qmllint-baseline.txt');
// Unmodified copies use stable upstream file:line:column keys. Adapted/new
// files use file + complete message + trimmed source, independent of line shifts.
const copied = new Set([
  'Commons/Border.qml', 'Commons/InputDevices.qml',
  ...['BarIconButton', 'BarIconContent', 'BarIndicator', 'BarWidget',
    'BorderOverlay', 'BorderSurface', 'Button', 'CursorSurface', 'IconContentBounds',
    'KeyboardPanel', 'OpticalGlyph', 'PanelActionButton', 'PanelController', 'PanelHero',
    'PanelKeyCatcher', 'PanelSectionHeader', 'PanelSeparator', 'PanelToolTip',
    'PopupCard', 'ToggleSwitch', 'WidgetButton'].map(name => `Ui/${name}.qml`),
  'bar/widgets/Tray.qml',
  ...['Toast', 'DeedButton', 'NotificationPanel', 'Picker'].map(name => `notifications/${name}.qml`),
]);

function qmlFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return qmlFiles(full);
    return entry.isFile() && entry.name.endsWith('.qml')
      ? [path.relative(shellDir, full)] : [];
  }).sort();
}

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-qmllint-'));
try {
  fs.symlinkSync(shellDir, path.join(tmp, 'qs'));
  const files = qmlFiles(shellDir);
  const result = spawnSync('/usr/lib/qt6/bin/qmllint', ['-I', tmp, ...files], {
    cwd: shellDir, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (process.env.MIRROROS_QMLLINT_LOG) fs.writeFileSync(process.env.MIRROROS_QMLLINT_LOG, output);
  if (result.error || result.status !== 0) {
    console.error(output || String(result.error));
    process.exitCode = 1;
  } else {
    const keys = [];
    const unexpected = [];
    for (const block of output.split(/(?=^(?:Warning|Error):)/m)) {
      if (!/^(Warning|Error):/.test(block)) continue;
      const lines = block.trimEnd().split('\n');
      const match = lines[0].match(/^Warning: (.+?\.qml):(?:(\d+):(\d+):|:)(.*)$/);
      if (!match) { unexpected.push(lines[0]); continue; }
      const [, rawFile, line = '0', column = '0', head] = match;
      const file = rawFile.replace(/^\.\//, '');
      const categoryLine = lines.findIndex(value => /\[[\w-]+\]/.test(value));
      if (categoryLine < 0) { unexpected.push(lines[0]); continue; }
      const message = [head.trim(), ...lines.slice(1, categoryLine + 1).map(value => value.trim())]
        .join(' ').replace(/\s+/g, ' ').trim();
      const source = Number(line) > 0
        ? fs.readFileSync(path.join(shellDir, file), 'utf8').split('\n')[Number(line) - 1].trim() : '';
      keys.push(copied.has(file)
        ? `copy ${file}:${line}:${column}`
        : `adapt ${JSON.stringify([file, message, source])}`);
    }
    if (unexpected.length) {
      console.error('FAIL unparsed qmllint diagnostics:\n' + unexpected.join('\n'));
      process.exitCode = 1;
    } else if (process.argv.includes('--capture')) {
      console.log('# qmllint from qt6-declarative 6.12.0-2');
      console.log('# Reviewed prototype diagnostics; copy keys are file:line:column.');
      console.log('# Adapted/new keys are [file, message, trimmed source]. Duplicate keys count.');
      console.log(keys.sort().join('\n'));
    } else {
      const baseline = fs.readFileSync(baselinePath, 'utf8').split('\n')
        .filter(value => value && !value.startsWith('#'));
      const counts = values => {
        const map = new Map();
        for (const value of values) map.set(value, (map.get(value) || 0) + 1);
        return map;
      };
      const actual = counts(keys), expected = counts(baseline);
      const changes = [];
      for (const key of new Set([...actual.keys(), ...expected.keys()])) {
        const difference = (actual.get(key) || 0) - (expected.get(key) || 0);
        if (difference > 0) changes.push(`NEW (${difference}) ${key}`);
        if (difference < 0) changes.push(`STALE (${-difference}) ${key}`);
      }
      if (changes.length) {
        console.error('FAIL qmllint baseline mismatch:\n' + changes.join('\n'));
        process.exitCode = 1;
      } else {
        console.log(`PASS qmllint: ${files.length} QML files, ${keys.length} reviewed warnings, no new or stale entries`);
      }
    }
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
