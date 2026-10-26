import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const profile = join(root, 'image/archiso');
const read = path => readFileSync(join(profile, path), 'utf8');
const request = 'video=1280x720';

function withoutRequest(line) {
  assert.equal(line.split(/\s+/).filter(word => word.startsWith('video=')).length, 1);
  assert.ok(line.endsWith(` ${request}`));
  return line.slice(0, -request.length - 1);
}

function efiEntry(name) {
  return Object.fromEntries(read(`efiboot/loader/entries/${name}`).trim().split('\n').map(line => {
    const [, key, value] = line.match(/^(\S+)\s+(.+)$/);
    return [key, value];
  }));
}

function grubEntries(path) {
  const text = read(path);
  assert.match(text, /^default=archlinux$/m);
  assert.match(text, /^timeout_style=menu$/m);
  const entries = [...text.matchAll(/^menuentry "(MirrorOS Live\/Rescue[^"\n]*)"[^\n]*--id '([^']+)' \{\n([\s\S]*?)^\}/gm)];
  assert.equal(entries.length, 2);
  return entries.map(([, title, id, body]) => ({
    title,
    id,
    body,
    linux: body.match(/^\s+linux (.+)$/m)[1],
    initrd: body.match(/^\s+initrd (.+)$/m)[1],
  }));
}

test('systemd-boot defaults to a best-effort 720p request with a native-display recovery entry', () => {
  const preferred = efiEntry('01-archiso-linux.conf');
  const native = efiEntry('02-archiso-native-linux.conf');
  assert.match(read('efiboot/loader/loader.conf'), /^default 01-archiso-linux.conf$/m);
  assert.match(read('efiboot/loader/loader.conf'), /^timeout [1-9][0-9]*$/m);
  assert.match(preferred.title, /prefer 1280x720/);
  assert.match(native.title, /native display/);
  assert.ok(preferred['sort-key'] < native['sort-key']);
  assert.equal(withoutRequest(preferred.options), native.options);
  assert.equal(native.options, 'archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS%');
  assert.equal(preferred.linux, native.linux);
  assert.equal(native.linux, '/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux');
  assert.equal(preferred.initrd, native.initrd);
  assert.equal(native.initrd, '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img');
});

for (const path of ['grub/grub.cfg', 'grub/loopback.cfg']) {
  test(`${path} keeps both display choices and identical non-display boot arguments`, () => {
    const [preferred, native] = grubEntries(path);
    assert.equal(preferred.id, 'archlinux');
    assert.equal(native.id, 'archlinux-native');
    assert.match(preferred.title, /prefer 1280x720/);
    assert.match(native.title, /native display/);
    assert.equal(withoutRequest(preferred.linux), native.linux);
    assert.equal(preferred.body.replace(` ${request}`, ''), native.body);
    assert.equal(preferred.initrd, native.initrd);
    assert.equal(native.initrd, '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img');
    const location = path.includes('loopback')
      ? 'img_dev=UUID=${archiso_img_dev_uuid} img_loop="${iso_path}"'
      : 'archisosearchuuid=%ARCHISO_UUID%';
    assert.equal(native.linux, `/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% ${location} %KERNEL_PARAMS%`);
  });
}

function filesUnder(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(entry => {
    const child = join(path, entry.name);
    if (entry.isSymbolicLink()) return [];
    return entry.isDirectory() ? filesUnder(child) : [child];
  });
}

test('the request stays out of installed boot, plan, target, and capability implementation', () => {
  for (const directory of ['install/plan', 'install/engine', 'capabilities', 'targets']) {
    for (const path of filesUnder(join(root, directory))) {
      if (path.endsWith('.md')) continue;
      assert.ok(!readFileSync(path, 'utf8').includes(request), path);
    }
  }
});

test('live display preference adds no font loader, persistent font, forced driver, or forced connector', () => {
  for (const path of filesUnder(join(profile, 'airootfs'))) {
    const content = readFileSync(path, 'utf8');
    assert.doesNotMatch(content, /\bsetfont\b|\bFONT=/, path);
  }
  for (const path of ['grub/grub.cfg', 'grub/loopback.cfg',
    'efiboot/loader/entries/01-archiso-linux.conf', 'efiboot/loader/entries/02-archiso-native-linux.conf']) {
    const text = read(path);
    assert.doesNotMatch(text, /nomodeset|modprobe\.blacklist=|fbcon=font:|vconsole\.font=/);
    const requests = text.match(/\bvideo=\S+/g) ?? [];
    assert.deepEqual(requests, path.includes('02-archiso-native') ? [] : [request]);
  }
  const startup = readFileSync(join(root, 'install/confirmation/live-startup'), 'utf8');
  assert.doesNotMatch(startup, /\bsetfont\b/);
});
