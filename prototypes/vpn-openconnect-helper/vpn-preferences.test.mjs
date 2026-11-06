import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, readFileSync, writeFileSync, chmodSync, statSync, symlinkSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const script = fileURLToPath(new URL('./vpn-acceptance.sh', import.meta.url));
const uuid = '11111111-2222-3333-4444-555555555555';
const gateway = 'https://vpn.example.invalid/group';
const username = 'test.user@example.invalid';
function fixture(t) {
  const path = mkdtempSync(join(tmpdir(), 'mirroros-vpn-preferences-'));
  t.after(() => rmSync(path, { recursive: true, force: true }));
  return path;
}
function run(command, ...args) {
  return spawnSync('bash', ['-c', `source "$1"; ${command}`, 'test', script, ...args], { encoding: 'utf8' });
}
function preferenceFile(t, data, mode = 0o600) {
  const path = join(fixture(t), `${uuid}.json`);
  writeFileSync(path, JSON.stringify(data), { mode });
  return path;
}

test('saves only gateway/user/schema privately and reloads without printing values', t => {
  const dir = join(fixture(t), 'private');
  const result = run('save_preferences "$2" "$3" "$4" "$5"; load_preferences "$2/$3.json"; [[ "$gateway" == "$4" && "$username" == "$5" ]]', dir, uuid, gateway, username);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '');
  assert.equal(statSync(dir).mode & 0o777, 0o700);
  assert.equal(statSync(join(dir, `${uuid}.json`)).mode & 0o777, 0o600);
  assert.deepEqual(JSON.parse(readFileSync(join(dir, `${uuid}.json`), 'utf8')), { schema_version: 1, gateway, username });
});

test('does not overwrite existing preferences', t => {
  const dir = fixture(t);
  const path = join(dir, `${uuid}.json`);
  writeFileSync(path, 'original', { mode: 0o600 });
  assert.equal(run('save_preferences "$2" "$3" "$4" "$5"', dir, uuid, gateway, username).status, 2);
  assert.equal(readFileSync(path, 'utf8'), 'original');
});

test('rejects extra fields rather than retaining credentials', t => {
  const path = preferenceFile(t, { schema_version: 1, gateway, username, password: 'synthetic-only' });
  const result = run('load_preferences "$2"', path);
  assert.equal(result.status, 2);
  assert.doesNotMatch(result.stdout + result.stderr, /synthetic-only|example\.invalid/);
});

test('rejects unsafe permissions and symlink preference files', t => {
  const path = preferenceFile(t, { schema_version: 1, gateway, username });
  chmodSync(path, 0o644);
  assert.equal(run('load_preferences "$2"', path).status, 2);
  chmodSync(path, 0o600);
  const link = join(fixture(t), 'link');
  symlinkSync(path, link);
  assert.equal(run('load_preferences "$2"', link).status, 2);
});

test('rejects symlink preference directories without following them', t => {
  const root = fixture(t);
  const link = join(root, 'link');
  symlinkSync(root, link);
  assert.equal(run('save_preferences "$2" "$3" "$4" "$5"', link, uuid, gateway, username).status, 2);
  assert.equal(existsSync(join(root, `${uuid}.json`)), false);
});

test('rejects option injection, credential URLs and invalid usernames', () => {
  for (const [g, u] of [
    ['http://vpn.example.invalid', username],
    ['https://user:pass@vpn.example.invalid', username],
    ['https://vpn.example.invalid?token=synthetic', username],
    ['https://vpn.example.invalid\nno-system-trust', username],
    [gateway, 'name\npassword=synthetic'],
    [gateway, 'name with spaces'],
    [gateway, '$(id)'],
  ]) assert.equal(run('validate_preferences "$2" "$3"', g, u).status, 2);
  assert.equal(run('validate_preferences "$2" "$3"', gateway, 'DOMAIN\\user').status, 0);
});

test('rejects control characters in stored values before command substitution', t => {
  for (const data of [
    { schema_version: 1, gateway: `${gateway}\n`, username },
    { schema_version: 1, gateway, username: `${username}\n` },
  ]) assert.equal(run('load_preferences "$2"', preferenceFile(t, data)).status, 2);
});

test('rejects profile path traversal', t => {
  assert.equal(run('save_preferences "$2" "$3" "$4" "$5"', fixture(t), '../escape', gateway, username).status, 2);
});

test('passes gateway and username through the private config with visible prompts', () => {
  const current = readFileSync(script, 'utf8');
  assert.match(current, /printf 'server = %s\\nuser = %s\\n'/);
  assert.doesNotMatch(current, /openconnect[^\n]*--user/);
  assert.match(current, /IFS= read -r gateway/);
  assert.match(current, /IFS= read -r username/);
  assert.doesNotMatch(current, /read -rs (gateway|username)/);
});

test('refuses SSH/noninteractive invocation before persistence/authentication', () => {
  const result = spawnSync('bash', [script], { encoding: 'utf8', env: { ...process.env, SSH_CONNECTION: 'synthetic' } });
  assert.equal(result.status, 2);
});
