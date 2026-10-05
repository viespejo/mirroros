#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { chmodSync, createReadStream, lstatSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import {
  BUNDLE_CHECKSUM_FILE,
  BUNDLE_METADATA_FILE,
  buildResultDocument,
  ContractError,
  renderSummary,
  validateBundleAdmission,
  validateGuestReport,
} from './lib/bootstrap-documents.mjs';

const usage = 'Usage: bootstrap-documents.mjs admit-bundle --bundle DIR | validate-report --report FILE --run-id ID | write-result --input FILE --output FILE | render-summary --result FILE';

class InadmissibleBundle extends Error {}

function parseOptions(arguments_, allowed) {
  const options = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const name = arguments_[index];
    const value = arguments_[index + 1];
    if (!allowed.includes(name) || !value || value.startsWith('--') || options[name]) {
      throw new ContractError(`invalid arguments\n${usage}`);
    }
    options[name] = value;
  }
  if (allowed.some(name => !options[name])) throw new ContractError(`missing required arguments\n${usage}`);
  return options;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

async function sha256File(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

function requireRegular(path, name) {
  let stat;
  try {
    stat = lstatSync(path);
  } catch {
    throw new InadmissibleBundle(`bundle is missing ${name}`);
  }
  if (!stat.isFile()) throw new InadmissibleBundle(`bundle entry ${name} must be a regular file`);
  return stat;
}

async function admitBundle(bundle) {
  let entries;
  try {
    if (!lstatSync(bundle).isDirectory()) throw new Error('not a directory');
    entries = readdirSync(bundle);
  } catch {
    throw new InadmissibleBundle(`bundle directory is not readable: ${bundle}`);
  }
  requireRegular(join(bundle, BUNDLE_METADATA_FILE), BUNDLE_METADATA_FILE);
  requireRegular(join(bundle, BUNDLE_CHECKSUM_FILE), BUNDLE_CHECKSUM_FILE);
  const metadataBytes = readFileSync(join(bundle, BUNDLE_METADATA_FILE));
  let metadata;
  try {
    metadata = JSON.parse(metadataBytes.toString('utf8'));
  } catch {
    throw new InadmissibleBundle(`${BUNDLE_METADATA_FILE} is not valid JSON`);
  }
  const isoName = metadata?.artifact?.iso?.name;
  const manifestName = metadata?.artifact?.package_manifest?.name;
  for (const name of [isoName, manifestName]) {
    if (typeof name !== 'string' || name.length === 0 || /[\\/\u0000-\u001f\u007f]/.test(name) || name === '.' || name === '..') {
      throw new InadmissibleBundle('metadata names an unsafe artifact filename');
    }
  }
  const isoStat = requireRegular(join(bundle, isoName), isoName);
  requireRegular(join(bundle, manifestName), manifestName);
  const files = {
    entries,
    iso: { name: isoName, size_bytes: isoStat.size, sha256: await sha256File(join(bundle, isoName)) },
    metadata: { name: BUNDLE_METADATA_FILE, sha256: createHash('sha256').update(metadataBytes).digest('hex') },
    package_manifest: { name: manifestName, sha256: await sha256File(join(bundle, manifestName)) },
    sha256sums: readFileSync(join(bundle, BUNDLE_CHECKSUM_FILE), 'utf8'),
  };
  const errors = validateBundleAdmission(metadata, files);
  if (errors.length > 0) throw new InadmissibleBundle(errors.join('\n'));
  return {
    iso_name: isoName,
    iso_path: resolve(bundle, isoName),
    iso_sha256: files.iso.sha256,
    iso_size_bytes: files.iso.size_bytes,
    metadata_sha256: files.metadata.sha256,
    build_run_id: metadata.execution.run_id,
    build_commit: metadata.execution.commit,
    build_dirty: metadata.execution.dirty,
  };
}

async function run(arguments_) {
  const [command, ...rest] = arguments_;

  if (command === 'admit-bundle') {
    const options = parseOptions(rest, ['--bundle']);
    try {
      process.stdout.write(`${JSON.stringify(await admitBundle(options['--bundle']))}\n`);
    } catch (error) {
      if (!(error instanceof InadmissibleBundle)) throw error;
      process.stderr.write(`bootstrap-documents: ${error.message}\n`);
      return 2;
    }
    return 0;
  }

  if (command === 'validate-report') {
    const options = parseOptions(rest, ['--report', '--run-id']);
    let report;
    try {
      report = readJson(options['--report']);
    } catch {
      process.stderr.write('bootstrap-documents: guest report is missing or not valid JSON\n');
      return 5;
    }
    const verdict = validateGuestReport(report, options['--run-id']);
    process.stdout.write(`${JSON.stringify(verdict)}\n`);
    if (verdict.errors.length > 0) {
      process.stderr.write(`bootstrap-documents: guest report rejected\n${verdict.errors.join('\n')}\n`);
      return 5;
    }
    return verdict.passed ? 0 : 4;
  }

  if (command === 'write-result') {
    const options = parseOptions(rest, ['--input', '--output']);
    if (resolve(options['--input']) === resolve(options['--output'])) {
      throw new ContractError('input and output paths must differ');
    }
    const document = buildResultDocument(readJson(options['--input']));
    writeFileSync(options['--output'], `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
    chmodSync(options['--output'], 0o600);
    return 0;
  }

  if (command === 'render-summary') {
    const options = parseOptions(rest, ['--result']);
    process.stdout.write(renderSummary(readJson(options['--result'])));
    return 0;
  }

  throw new ContractError(`unknown subcommand\n${usage}`);
}

try {
  process.exitCode = await run(process.argv.slice(2));
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`bootstrap-documents: ${message}\n`);
  process.exitCode = 6;
}
