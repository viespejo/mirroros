import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { resolvePiVersion } from "../../capabilities/workflow/pi/pi-version.mjs";

const packageName = "@earendil-works/pi-coding-agent";
const declaration = (value) => JSON.stringify({ devDependencies: { [packageName]: value } });
const noRegistry = () => { throw new Error("Registry must not be queried"); };

for (const version of ["1.3.0", "0.0.0", "24.22.0", "1.3.0-rc.1", "1.3.0+build.5"]) {
  test(`exact dependency ${version} never queries npm`, async () => {
    assert.deepEqual(await resolvePiVersion(declaration(version), noRegistry), {
      version, source: "exact_dependency",
    });
  });
}

for (const value of ["^1.3.0", "~1.3.0", ">=1.0.0", "*", "latest", "v1.3.0", "=1.3.0", "1.3", "01.3.0", "1.3.0-01", " 1.3.0", "1.3.0\n", "9007199254740992.0.0", "", null, 130, {}, []]) {
  test(`invalid present dependency ${JSON.stringify(value)} cannot fall back`, async () => {
    await assert.rejects(resolvePiVersion(declaration(value), noRegistry), /exact valid version/);
  });
}

for (const metadata of [{}, { devDependencies: {} }, { devDependencies: { unrelated: "^1.0.0" } }]) {
  test(`absent dependency resolves the stable registry choice once: ${JSON.stringify(metadata)}`, async () => {
    let queries = 0;
    const result = await resolvePiVersion(JSON.stringify(metadata), async () => {
      queries += 1;
      return ["1.9.0", "1.10.0", "2.0.0-rc.1", "1.10.1", "1.10.0+build.1"];
    });
    assert.equal(queries, 1);
    assert.deepEqual(result, { version: "1.10.1", source: "stable_registry" });
  });
}

test("stable comparison is numeric across major, minor and patch components", async () => {
  const result = await resolvePiVersion("{}", async () => ["2.1.12", "10.0.0", "2.20.0", "2.1.100"]);
  assert.equal(result.version, "10.0.0");
});

for (const text of ["{", "null", "[]", '"text"', '{"devDependencies":null}', '{"devDependencies":[]}', '{"devDependencies":false}']) {
  test(`malformed package metadata fails before registry access: ${text}`, async () => {
    await assert.rejects(resolvePiVersion(text, noRegistry), /package.json|devDependencies/);
  });
}

for (const versions of [[], ["2.0.0-beta.1"], ["invalid"], [null], "1.3.0", null]) {
  test(`unusable registry response ${JSON.stringify(versions)} fails actionably`, async () => {
    let queries = 0;
    await assert.rejects(resolvePiVersion("{}", async () => {
      queries += 1;
      return versions;
    }), /npm/);
    assert.equal(queries, 1);
  });
}

test("a registry failure is not retried or replaced with a compatibility fallback", async () => {
  let queries = 0;
  await assert.rejects(resolvePiVersion("{}", async () => {
    queries += 1;
    throw new Error("fixture registry failure");
  }), /fixture registry failure/);
  assert.equal(queries, 1);
});

test("CLI exact dependency emits allowlisted TSV without npm on PATH", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "mirroros-pi-version-"));
  try {
    const file = path.join(root, "package with spaces.json");
    await writeFile(file, declaration("1.3.0"));
    const selector = fileURLToPath(new URL("../../capabilities/workflow/pi/pi-version.mjs", import.meta.url));
    const result = spawnSync(process.execPath, [selector, file], {
      encoding: "utf8", timeout: 10_000,
      env: { HOME: root, PATH: path.join(root, "no-commands") },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, "1.3.0\texact_dependency\n");
    assert.equal(result.stderr, "");
    await writeFile(file, declaration("^1.3.0"));
    const invalid = spawnSync(process.execPath, [selector, file], {
      encoding: "utf8", timeout: 10_000,
      env: { HOME: root, PATH: path.join(root, "no-commands") },
    });
    assert.equal(invalid.status, 1);
    assert.equal(invalid.stdout, "");
    assert.match(invalid.stderr, /exact valid version/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
