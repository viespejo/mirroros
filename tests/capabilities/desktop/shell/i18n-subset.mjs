#!/usr/bin/env node
// Build/check the English catalog subset without changing upstream values.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.env.MIRROROS_SHELL_DIR
  || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const catalogPath = path.join(root, 'Commons/i18n-en.json');
const usage = 'Usage: node tests/capabilities/desktop/shell/i18n-subset.mjs <omarchy-src> [--check] | --keys-only';
const args = process.argv.slice(2);
const flags = args.filter(arg => arg.startsWith('--'));
const sources = args.filter(arg => !arg.startsWith('--'));
const keysOnly = flags.includes('--keys-only');
if (flags.some(flag => !['--check', '--keys-only'].includes(flag))
    || (keysOnly ? sources.length !== 0 || flags.includes('--check') : sources.length !== 1)) {
  console.error(usage);
  process.exit(2);
}
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const keys = [...new Set(walk(root).filter(file => file.endsWith('.qml')).flatMap(file =>
  [...fs.readFileSync(file, 'utf8').matchAll(/I18n\.tn?\(\s*"([A-Za-z0-9_.]+)"/g)]
    .map(match => match[1])))].sort();
const sourcePath = keysOnly ? catalogPath : path.join(sources[0], 'default/i18n/en/shell.json');
const english = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
if (!english || typeof english !== 'object' || Array.isArray(english))
  throw new Error('Catalog must be a JSON object');
const missing = keys.filter(key => !Object.hasOwn(english, key));
for (const key of missing)
  console.error(`${keysOnly ? 'missing key' : 'key not in Omarchy catalog'}: ${key}`);
if (missing.length) process.exit(1);
if (!keysOnly) {
  const text = JSON.stringify(Object.fromEntries(keys.map(key => [key, english[key]])), null, 2) + '\n';
  if (flags.includes('--check')) {
    if (!fs.existsSync(catalogPath) || fs.readFileSync(catalogPath, 'utf8') !== text) {
      console.error(`${catalogPath} is out of date`);
      process.exit(1);
    }
  } else {
    fs.writeFileSync(catalogPath, text);
    console.log(`wrote ${keys.length} keys to ${catalogPath}`);
  }
}
