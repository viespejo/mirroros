import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, openSync, closeSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const helper = resolve('capabilities/lib/target-exec');

function fixture(t, overrides = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-target-dns-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const bin = join(dir, 'bin');
  const root = join(dir, 'target');
  mkdirSync(bin);
  mkdirSync(root);
  const resolver = join(dir, 'resolver');
  writeFileSync(resolver, 'nameserver 192.0.2.53\n', { mode: 0o600 });
  const scripts = {
    unshare: `[[ "$1 $2 $3 $4" == '--mount --propagation private --' ]] || exit 97
[[ "\${DENY_NAMESPACE:-0}" == 0 ]] || exit 17
shift 4
printf 'private-namespace\n' >> "$TRACE"
exec "$@"`,
    mount: `[[ "$*" == '-t tmpfs -o mode=0755,nosuid,nodev tmpfs /run' ]] || exit 97
[[ "\${DENY_MOUNT:-0}" == 0 ]] || exit 18
printf 'private-run\n' >> "$TRACE"`,
    install: `[[ "$(tail -1 "$TRACE")" == private-run || "$(tail -1 "$TRACE")" == directory ]] || exit 97
case "$*" in
  '-d -m 0755 /run/systemd/resolve')
    /usr/bin/install -d -m 0755 "$FAKE_RUN/systemd/resolve"
    printf 'directory\n' >> "$TRACE" ;;
  '-m 0644 /proc/self/fd/3 /run/systemd/resolve/stub-resolv.conf')
    /usr/bin/install -m 0644 /proc/self/fd/3 "$FAKE_RUN/systemd/resolve/stub-resolv.conf"
    printf 'resolver-copy\n' >> "$TRACE" ;;
  *) exit 97 ;;
esac`,
    'arch-chroot': `[[ "$1" == -r && "$2" == "$EXPECTED_ROOT" ]] || exit 97
[[ ! -e /proc/self/fd/3 ]] || exit 97
cmp -s "$FAKE_RUN/systemd/resolve/stub-resolv.conf" "$EXPECTED_RESOLVER" || exit 97
shift 2
printf '%s\n' "$@" > "$ARGUMENTS"
IFS= read -r input
[[ "$input" == fixture-stdin ]] || exit 97
printf 'chroot\n' >> "$TRACE"
exit "\${CHILD_STATUS:-0}"`,
  };
  for (const [name, body] of Object.entries(scripts)) {
    writeFileSync(join(bin, name), `#!/usr/bin/bash\nset -Eeuo pipefail\n${body}\n`, { mode: 0o755 });
  }
  const trace = join(dir, 'trace');
  const args = join(dir, 'arguments');
  writeFileSync(trace, '');
  const fd = openSync(resolver, 'r');
  t.after(() => closeSync(fd));
  return {
    trace, args,
    run: (target = root) => spawnSync('bash', [helper, target, 'fixture-command', 'literal; no shell expansion'], {
      env: { ...process.env, PATH: `${bin}:/usr/bin:/bin`, TRACE: trace, ARGUMENTS: args,
        FAKE_RUN: join(dir, 'private-run'), EXPECTED_ROOT: root, EXPECTED_RESOLVER: resolver, ...overrides },
      input: 'fixture-stdin\n', encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe', fd],
    }),
  };
}

test('target adapter isolates before resolver copy, preserves argv/stdin and closes resolver fd', (t) => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(f.trace, 'utf8'), 'private-namespace\nprivate-run\ndirectory\nresolver-copy\nchroot\n');
  assert.equal(readFileSync(f.args, 'utf8'), 'fixture-command\nliteral; no shell expansion\n');
});

test('namespace failure never reaches mount or resolver copy', (t) => {
  const f = fixture(t, { DENY_NAMESPACE: '1' });
  assert.equal(f.run().status, 17);
  assert.equal(readFileSync(f.trace, 'utf8'), '');
});

test('mount failure never reaches resolver copy or chroot', (t) => {
  const f = fixture(t, { DENY_MOUNT: '1' });
  assert.equal(f.run().status, 18);
  assert.equal(readFileSync(f.trace, 'utf8'), 'private-namespace\n');
});

test('child exit is preserved', (t) => {
  const f = fixture(t, { CHILD_STATUS: '23' });
  assert.equal(f.run().status, 23);
});

test('a target hidden by private /run is rejected before isolation', (t) => {
  const f = fixture(t);
  assert.equal(f.run('/run').status, 4);
  assert.equal(readFileSync(f.trace, 'utf8'), '');
});
