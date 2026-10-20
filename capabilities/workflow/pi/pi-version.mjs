#!/usr/bin/env node
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { pathToFileURL } from "node:url";

const packageName = "@earendil-works/pi-coding-agent";
const execute = promisify(execFile);
const versionPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$/;

function parseVersion(value) {
  if (typeof value !== "string") return null;
  const match = versionPattern.exec(value);
  if (!match) return null;
  const numbers = match.slice(1, 4).map(Number);
  if (numbers.some((number) => !Number.isSafeInteger(number))) return null;
  const prerelease = match[4];
  if (prerelease?.split(".").some((part) => /^\d+$/.test(part) && part.length > 1 && part[0] === "0")) {
    return null;
  }
  return { numbers, prerelease };
}

function object(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export async function resolvePiVersion(packageText, getPublishedVersions) {
  let metadata;
  try {
    metadata = JSON.parse(packageText);
  } catch {
    throw new Error("pi-config package.json is malformed JSON; repair the selected repository before rerunning.");
  }
  if (!object(metadata)) throw new Error("pi-config package.json must contain an object.");
  const dependencies = metadata.devDependencies;
  if (dependencies !== undefined && !object(dependencies)) {
    throw new Error("pi-config devDependencies must be an object; no registry fallback was attempted.");
  }
  if (dependencies && Object.hasOwn(dependencies, packageName)) {
    const version = dependencies[packageName];
    if (!parseVersion(version)) {
      throw new Error(`pi-config devDependencies["${packageName}"] must be an exact valid version, not a range; repair it manually.`);
    }
    return { version, source: "exact_dependency" };
  }

  const published = await getPublishedVersions();
  if (!Array.isArray(published) || published.some((version) => !parseVersion(version))) {
    throw new Error("npm returned an invalid published-version list; no Pi version was selected.");
  }
  let selected;
  let selectedNumbers;
  for (const version of published) {
    const { numbers, prerelease } = parseVersion(version);
    if (prerelease) continue;
    const differing = selectedNumbers && numbers.findIndex((number, index) => number !== selectedNumbers[index]);
    if (!selected || (differing !== -1 && numbers[differing] > selectedNumbers[differing])) {
      selected = version;
      selectedNumbers = numbers;
    }
  }
  if (!selected) throw new Error("npm has no stable published Pi version; review the registry response manually.");
  return { version: selected, source: "stable_registry" };
}

async function publishedVersions() {
  const { stdout } = await execute("npm", ["view", packageName, "versions", "--json"], {
    timeout: 120_000,
    maxBuffer: 4 * 1024 * 1024,
  });
  try {
    return JSON.parse(stdout);
  } catch {
    throw new Error("npm returned malformed version JSON; no Pi version was selected.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    if (process.argv.length !== 3) throw new Error("Usage: pi-version.mjs <pi-config-package.json>");
    const result = await resolvePiVersion(await readFile(process.argv[2], "utf8"), publishedVersions);
    process.stdout.write(`${result.version}\t${result.source}\n`);
  } catch (error) {
    process.stderr.write(`Pi version selection failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
