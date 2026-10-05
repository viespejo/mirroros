#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { createReadStream, readFileSync, writeFileSync, chmodSync, statSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import {
  buildArtifactMetadata,
  buildExecutionResult,
  ContractError,
  validateBundle,
} from './lib/build-documents-core.mjs';

const usage = 'Usage: build-documents.mjs write-metadata --input FILE --output FILE | write-result --input FILE --output FILE | validate-bundle --metadata FILE --iso FILE --manifest FILE --checksums FILE';

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
  if (Object.keys(options).length !== allowed.length || allowed.some(name => !options[name])) {
    throw new ContractError(`missing required arguments\n${usage}`);
  }
  return options;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function writeJson(path, document) {
  writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
}

async function sha256File(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

async function run(arguments_) {
  const [command, ...rest] = arguments_;
  if (command === 'write-metadata' || command === 'write-result') {
    const options = parseOptions(rest, ['--input', '--output']);
    if (resolve(options['--input']) === resolve(options['--output'])) {
      throw new ContractError('input and output paths must differ');
    }
    const input = readJson(options['--input']);
    const document = command === 'write-metadata'
      ? buildArtifactMetadata(input)
      : buildExecutionResult(input);
    writeJson(options['--output'], document);
    return 0;
  }

  if (command === 'validate-bundle') {
    const options = parseOptions(rest, ['--metadata', '--iso', '--manifest', '--checksums']);
    const metadataBytes = readFileSync(options['--metadata']);
    const metadata = JSON.parse(metadataBytes.toString('utf8'));
    const manifestStat = statSync(options['--manifest']);
    const isoStat = statSync(options['--iso']);
    const errors = validateBundle(metadata, {
      iso: {
        name: basename(options['--iso']),
        size_bytes: isoStat.size,
        sha256: await sha256File(options['--iso']),
      },
      metadata: {
        name: basename(options['--metadata']),
        sha256: createHash('sha256').update(metadataBytes).digest('hex'),
      },
      package_manifest: {
        name: basename(options['--manifest']),
        sha256: await sha256File(options['--manifest']),
      },
      sha256sums: readFileSync(options['--checksums'], 'utf8'),
    });
    if (errors.length > 0) throw new ContractError(errors);
    process.stdout.write('Bundle contract valid.\n');
    return 0;
  }

  throw new ContractError(`unknown subcommand\n${usage}`);
}

try {
  process.exitCode = await run(process.argv.slice(2));
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`build-documents: ${message}\n`);
  process.exitCode = 6;
}
