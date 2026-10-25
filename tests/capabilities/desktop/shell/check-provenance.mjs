#!/usr/bin/env node
// Prototype-local provenance coverage and approximate reuse metrics.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const upstream = process.argv[2];
if (!upstream || upstream.startsWith('--')) {
  console.error('Usage: node check-provenance.mjs <omarchy-source> [--report]');
  process.exit(2);
}
const revision = '7075b61c6aaa5d8589f6e816867508fc96dc49d9';
if (execFileSync('git', ['-C', upstream, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() !== revision)
  throw new Error('Upstream revision mismatch');
const rows = fs.readFileSync(path.join(root, 'UPSTREAM.md'), 'utf8').split('\n')
  .filter(line => /^\| `/.test(line)).map(line => {
    const parts = line.split('|').slice(1, -1).map(value => value.trim());
    return { file: parts[0].replaceAll('`', ''), method: parts[1],
      source: parts[2].replaceAll('`', ''), note: parts[3] };
  });
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.relative(root, path.join(dir, entry.name))]);
const files = walk(root), recorded = new Set(rows.map(row => row.file));
if (rows.length !== recorded.size) throw new Error('Duplicate provenance row');
for (const file of files) if (!recorded.has(file)) throw new Error('Missing provenance: ' + file);
for (const row of rows) {
  if (!files.includes(row.file)) throw new Error('Stale provenance: ' + row.file);
  if (!['New', 'Adapted', 'Copied'].includes(row.method)) throw new Error('Unknown method: ' + row.file);
  if (row.method === 'Copied' && !fs.readFileSync(path.join(root, row.file))
    .equals(fs.readFileSync(path.join(upstream, row.source)))) throw new Error('Copy differs: ' + row.file);
}
const notice = fs.readFileSync(path.join(upstream, 'shell/plugins/notifications/Service.qml'), 'utf8')
  .split('\n').slice(0, 5).join('\n');
if (!fs.readFileSync(path.join(root, 'notifications/Service.qml'), 'utf8').startsWith(notice))
  throw new Error('Omapager notice changed');
// Omapager's complete MIT text, verified externally by the host (license evidence only).
const omapagerLicense = 'a2fe33052045a78c35a7a53ec452562e622a425ef7303c2cb631f07b2fd9e05d';
if (createHash('sha256').update(fs.readFileSync(path.join(root, 'LICENSE.omapager'))).digest('hex') !== omapagerLicense)
  throw new Error('Omapager license text changed');
if (!process.argv.includes('--report')) {
  console.log(`PASS provenance: ${files.length} files covered; copied files, Omapager notice and license text unchanged`);
} else {
  const lines = text => text.replace(/\n$/, '').split('\n');
  const extras = {
    'bar/widgets/Audio.qml': ['shell/plugins/panels/audio/Model.js'],
    'bar/widgets/Bluetooth.qml': ['shell/plugins/panels/bluetooth/Model.js'],
    'services/ShellConfig.qml': ['config/omarchy/shell.json'],
  };
  let report = '# Brief 3 reuse record — current implementation snapshot\n\n'
    + `Source: Omarchy at \`${revision}\`, MIT. Copyright holders: David Heinemeier Hansson and Neil Jagdish Patel (Omapager notification engine). The complete original Omapager MIT text is retained in LICENSE.omapager (host-verified license evidence only; not a code revision or a full license audit). Destination root: \`capabilities/desktop/shell/\`.\n\n`
    + 'Covers Briefs 1-3; fixed Brief 1 and Brief 2 evidence is unchanged. Per-file provenance is in UPSTREAM.md; LICENSE.omarchy is an unchanged upstream copy and LICENSE.omapager is the host-provided original text. All declared copies were byte-compared; no MirrorOS headers were added.\n\n'
    + 'Source ranges below are whole-file comparison envelopes, NOT claims that all lines were incorporated into adaptations. Copied files incorporate the full range. Selected fragment ranges and reasons are recorded in brief-1-reuse.md, brief-2-log.md (01:16, 01:21, 01:31 and notification/OSD entries) and brief-3-log.md (menu extraction). Reuse preserves the upstream appearance, data handling and subtle interaction fixes. The Changes column describes each adaptation boundary.\n\n'
    + 'Metrics: From source = non-blank destination lines whose trimmed text appears verbatim in the listed origin(s), including trivial braces. This is approximate textual reuse, not a semantic percentage. Catalog values are unchanged but flattened JSON keys/layout may not line-match. New lines within adaptations are counted separately. Documentation/license/baseline outputs are excluded from code totals, but have provenance. Tests/tooling live under tests/capabilities/desktop/shell/ and are not counted.\n\n'
    + 'Reproduce: node tests/capabilities/desktop/shell/check-provenance.mjs <omarchy-source> --report\n\n'
    + '| Destination | Method | Source comparison envelope | Lines | Non-blank | From source | New | Changes / rationale |\n|---|---|---|---:|---:|---:|---:|---|\n';
  const totals = { all: [0, 0, 0, 0], product: [0, 0, 0, 0], tooling: [0, 0, 0, 0] };
  for (const row of rows) {
    if (!/\.(qml|js|mjs|sh|py|json)$/.test(row.file) && !row.file.endsWith('/qmldir')) continue;
    const dest = fs.readFileSync(path.join(root, row.file), 'utf8');
    const nonblank = lines(dest).filter(line => line.trim()).length;
    const sources = row.source === '—' ? [] : [row.source, ...(extras[row.file] || [])];
    const originals = sources.map(source => fs.readFileSync(path.join(upstream, source), 'utf8'));
    const originalLines = new Set(originals.flatMap(text => lines(text).map(line => line.trim()).filter(Boolean)));
    const from = row.method === 'Copied' ? nonblank
      : lines(dest).filter(line => line.trim() && originalLines.has(line.trim())).length;
    const values = [lines(dest).length, nonblank, from, nonblank - from];
    for (const key of ['all', row.file.startsWith('tests/') ? 'tooling' : 'product'])
      values.forEach((value, index) => totals[key][index] += value);
    const envelope = sources.map((source, index) => `\`${source}\` 1-${lines(originals[index]).length}`).join('; ') || '—';
    report += `| \`${row.file}\` | ${row.method} | ${envelope} | ${values.join(' | ')} | ${row.note} |\n`;
  }
  report += '\n## Totals\n\n| Scope | Lines | Non-blank | From source | New |\n|---|---:|---:|---:|---:|\n';
  for (const [scope, values] of Object.entries(totals)) report += `| ${scope} | ${values.join(' | ')} |\n`;
  report += '\n## Boundaries and remaining work\n\n'
    + '- New composition, closed component maps, native IPC, provider inventory, prototype state preparation, unavailable states and read-only OSD probes replace excluded host machinery or meet an explicit brief requirement. Tests isolate synthetic state and verify this composition rather than the upstream product.\n'
    + '- Brief 3: the shared menu replaces the Brief 1 launcher (Apps is its submenu); MenuModel.js differs from upstream only by its header and the removed Bash guard/summon block; session actions, keyboard help and the owned menu model are new or model-derived. Prototype Lua bindings live outside this directory and are not counted here.\n'
    + '- Excluded: full shell/plugin host/supervisor, Omarchy IPC/authentication/lock code, hardware control panels, theme/private configuration loading, personal notification icon overrides, legacy DND/cleanup and focus-app fallback.\n'
    + '- Unused legacyDnd and unused icon/helper branches remain in unmodified copies; the adapted service never calls the legacy helper. No unrelated deletion to reduce counts.\n'
    + '- Catalog tooling uses architecture-approved Node.js ESM. The pending prototype Python generator was replaced, preserving the shipped catalog byte-for-byte; no project-owned Python is shipped.\n'
    + '- Authorized Lua runtime us/es observation passed and restored us. Six-panel source study complete, no panels implemented. Synthetic SNI visibility/menu remain unverified without a suitable installed approved-language client. Guest-console review found an inherited DND-panel lifetime asymmetry, documented but not fixed. Complete per-gesture/clipboard/preferences visual acceptance and physical hardware qualification are not claimed. Refresh metrics after further changes. No production policy/adoption decision is made.\n';
  process.stdout.write(report);
}
