import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { amendManualSkill } from "../../capabilities/workflow/pi/manual-skill.mjs";

const body = "\nBody with --- inside\n\n---\nstays\n";
const skill = (header, newline = "\n") => `---${newline}${header.join(newline)}${newline}---${newline}${body.replaceAll("\n", newline)}`;

test("a header without the flag gets only that line appended", () => {
  const result = amendManualSkill(skill(["name: teach", "description: Teach things", 'argument-hint: "What?"']), "teach");
  assert.equal(result.changed, true);
  assert.equal(result.text, skill(["name: teach", "description: Teach things", 'argument-hint: "What?"', "disable-model-invocation: true"]));
});

test("a false flag is replaced in place and a true flag is left byte-identical", () => {
  const replaced = amendManualSkill(skill(["name: a", "disable-model-invocation: false", "description: d"]), "a");
  assert.equal(replaced.text, skill(["name: a", "disable-model-invocation: true", "description: d"]));
  const original = skill(["name: a", "description: d", "disable-model-invocation: true"]);
  assert.deepEqual(amendManualSkill(original, "a"), { text: original, changed: false });
});

test("CRLF headers keep their line endings and quoted names match", () => {
  const result = amendManualSkill(skill(['name: "a"', "description: d"], "\r\n"), "a");
  assert.equal(result.text, skill(['name: "a"', "description: d", "disable-model-invocation: true"], "\r\n"));
});

for (const [label, text] of [
  ["no frontmatter", "# Title\n"],
  ["a different name", skill(["name: other", "description: d"])],
  ["a missing name", skill(["description: d"])],
  ["a duplicated name", skill(["name: a", "name: a", "description: d"])],
  ["a missing description", skill(["name: a"])],
  ["a duplicated flag", skill(["name: a", "description: d", "disable-model-invocation: true", "disable-model-invocation: false"])],
  ["a non-boolean flag", skill(["name: a", "description: d", "disable-model-invocation: maybe"])],
]) {
  test(`rejects ${label}`, () => {
    assert.throws(() => amendManualSkill(text, "a"));
  });
}

test("the command amends the file atomically, reports unchanged on rerun and rejects invalid UTF-8", async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "manual-skill-"));
  const script = fileURLToPath(new URL("../../capabilities/workflow/pi/manual-skill.mjs", import.meta.url));
  try {
    const file = path.join(directory, "SKILL.md");
    await writeFile(file, skill(["name: a", "description: d"]));
    let run = spawnSync(process.execPath, [script, file, "a"], { encoding: "utf8" });
    assert.equal(run.status, 0);
    assert.equal(run.stdout, "amended\n");
    assert.equal(await readFile(file, "utf8"), skill(["name: a", "description: d", "disable-model-invocation: true"]));
    run = spawnSync(process.execPath, [script, file, "a"], { encoding: "utf8" });
    assert.equal(run.stdout, "unchanged\n");
    assert.deepEqual(await readdir(directory), ["SKILL.md"]);
    await writeFile(file, Buffer.from([0x2d, 0x2d, 0x2d, 0x0a, 0xff, 0x0a]));
    run = spawnSync(process.execPath, [script, file, "a"], { encoding: "utf8" });
    assert.equal(run.status, 1);
    assert.match(run.stderr, /^manual-skill: /);
    run = spawnSync(process.execPath, [script, file], { encoding: "utf8" });
    assert.equal(run.status, 1);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
