#!/usr/bin/env node
import { readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const field = "disable-model-invocation";
const headerPattern = /^(---\r?\n)([\s\S]*?)(\r?\n---(?:\r?\n|$))/;

function scalar(value) {
  return value.trim().replace(/^(["'])(.*)\1$/, "$2");
}

// Sets only the manual-only flag in the frontmatter; the body and every other header line stay byte-identical.
export function amendManualSkill(text, name) {
  const match = headerPattern.exec(text);
  if (!match) throw new Error("the frontmatter is absent or ambiguous");
  const [, open, header, close] = match;
  const lines = header.split(/\r?\n/);
  const named = lines.filter((line) => /^name\s*:/.test(line));
  if (named.length !== 1 || scalar(named[0].replace(/^name\s*:/, "")) !== name) {
    throw new Error(`the frontmatter name must be exactly ${name}`);
  }
  const described = lines.filter((line) => /^description\s*:/.test(line));
  if (described.length !== 1) throw new Error("the frontmatter needs exactly one description");
  const flags = lines.filter((line) => new RegExp(`^${field}\\s*:`).test(line));
  if (flags.length > 1) throw new Error(`the frontmatter repeats ${field}`);
  if (flags.length === 1 && !/^[^:]+:\s*(true|false)\s*$/.test(flags[0])) {
    throw new Error(`${field} must be a plain boolean`);
  }
  if (flags.length === 1 && /:\s*true\s*$/.test(flags[0])) return { text, changed: false };
  const newline = open.includes("\r") ? "\r\n" : "\n";
  const amended = flags.length === 1
    ? lines.map((line) => (line === flags[0] ? `${field}: true` : line)).join(newline)
    : `${header}${newline}${field}: true`;
  return { text: open + amended + close + text.slice(match[0].length), changed: true };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    if (process.argv.length !== 4) throw new Error("Usage: manual-skill.mjs <SKILL.md> <skill-name>");
    const file = process.argv[2];
    const bytes = await readFile(file);
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    const result = amendManualSkill(text, process.argv[3]);
    if (result.changed) {
      const temporary = `${file}.mirroros`;
      await writeFile(temporary, result.text, { flag: "wx" });
      await rename(temporary, file);
    }
    process.stdout.write(result.changed ? "amended\n" : "unchanged\n");
  } catch (error) {
    process.stderr.write(`manual-skill: ${error.message}\n`);
    process.exit(1);
  }
}
