import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, existsSync, readFileSync, rmSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const script = fileURLToPath(new URL('./vpn-acceptance.sh', import.meta.url));
const valid = "COOKIE='synthetic-cookie'\nHOST='synthetic.invalid'\nFINGERPRINT='synthetic-fingerprint'\nRESOLVE='synthetic-resolution'\n";
function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-vpn-parser-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}
function parse(t, text) {
  const dir = fixture(t);
  const input = join(dir, 'input');
  const output = join(dir, 'output');
  writeFileSync(input, text, { mode: 0o600 });
  const result = spawnSync('bash', ['-c', 'source "$1"; parse_auth "$2" "$3"', 'test', script, input, output], { encoding: 'utf8' });
  return { ...result, output };
}
test('maps required synthetic fields without printing authentication data', t => {
  const result = parse(t, valid + "CONNECT_URL='https://synthetic.invalid/group'\n");
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '');
  assert.equal(readFileSync(result.output, 'utf8'), 'vpn.secrets.cookie:synthetic-cookie\nvpn.secrets.gwcert:synthetic-fingerprint\nvpn.secrets.gateway:synthetic.invalid\nvpn.secrets.resolve:synthetic-resolution\n');
});
for (const [name, text] of [
  ['missing required field', valid.replace("RESOLVE='synthetic-resolution'\n", '')],
  ['empty required field', valid.replace('synthetic-cookie', '')],
  ['duplicate field', valid + "COOKIE='second-synthetic-value'\n"],
  ['unknown field', valid + "UNEXPECTED='synthetic-value'\n"],
  ['unquoted output', valid.replace("COOKIE='synthetic-cookie'", 'COOKIE=synthetic-cookie')],
  ['embedded quote', valid.replace('synthetic-cookie', "synthetic'cookie")],
  ['control character', valid.replace('synthetic-cookie', 'synthetic\rcookie')],
]) {
  test(`rejects ${name} without creating a passwd file or leaking fields`, t => {
    const result = parse(t, text);
    assert.equal(result.status, 2);
    assert.equal(existsSync(result.output), false);
    assert.equal(result.stdout, '');
    assert.doesNotMatch(result.stderr, /synthetic-cookie|synthetic-fingerprint|synthetic-resolution/);
  });
}
test('does not execute command substitution in authentication fields', t => {
  const dir = fixture(t);
  const marker = join(dir, 'must-not-exist');
  const result = parse(t, valid.replace('synthetic-cookie', `$(touch ${marker})`));
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(marker), false);
  assert.ok(readFileSync(result.output, 'utf8').includes(`$(touch ${marker})`));
});
test('EXIT cleanup removes only temporary authentication files and preserves failure status', t => {
  const dir = fixture(t);
  const runtime = join(dir, 'runtime');
  mkdirSync(runtime, { mode: 0o700 });
  for (const name of ['auth.conf', 'auth.result', 'passwd']) writeFileSync(join(runtime, name), 'synthetic', { mode: 0o600 });
  const result = spawnSync('bash', ['-c', 'source "$1"; runtime=$2; activating=0; connected=0; trap cleanup EXIT; exit 7', 'test', script, runtime], { encoding: 'utf8' });
  assert.equal(result.status, 7, result.stderr);
  assert.equal(existsSync(runtime), false);
  assert.equal(existsSync(dir), true);
});
test('refuses noninteractive execution before authentication or connection', () => {
  const result = spawnSync('bash', [script], { encoding: 'utf8', env: { ...process.env, SSH_CONNECTION: 'synthetic-ssh-session' } });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Run locally|Run as the graphical user/);
});
