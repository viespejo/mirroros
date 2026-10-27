import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const profile = join(root, 'image/archiso');
const read = path => readFileSync(join(profile, path), 'utf8');

function efiEntry(name) {
  return Object.fromEntries(read(`efiboot/loader/entries/${name}`).trim().split('\n').map(line => {
    const [, key, value] = line.match(/^(\S+)\s+(.+)$/);
    return [key, value];
  }));
}

test('systemd-boot has one normal live entry preserving the firmware/kernel display choice', () => {
  const entry = efiEntry('01-archiso-linux.conf');
  const entries = readdirSync(join(profile, 'efiboot/loader/entries'));
  assert.deepEqual(entries.filter(name => /archiso.*linux\.conf$/.test(name)), ['01-archiso-linux.conf']);
  assert.match(read('efiboot/loader/loader.conf'), /^default 01-archiso-linux.conf$/m);
  assert.match(read('efiboot/loader/loader.conf'), /^timeout [1-9][0-9]*$/m);
  assert.equal(entry.title, 'MirrorOS Live/Rescue (%ARCH%, UEFI)');
  assert.equal(entry.options, 'archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS% quiet splash');
  assert.equal(entry.linux, '/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux');
  assert.equal(entry.initrd, '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img');
});

for (const path of ['grub/grub.cfg', 'grub/loopback.cfg']) {
  test(`${path} keeps one live entry and its non-display boot arguments`, () => {
    const text = read(path);
    assert.match(text, /^default=archlinux$/m);
    assert.match(text, /^timeout_style=menu$/m);
    const entries = [...text.matchAll(/^menuentry "(MirrorOS Live\/Rescue[^"\n]*)"[^\n]*--id '([^']+)' \{\n([\s\S]*?)^\}/gm)];
    assert.equal(entries.length, 1);
    const [, title, id, body] = entries[0];
    assert.equal(id, 'archlinux');
    assert.equal(title, 'MirrorOS Live/Rescue (%ARCH%, ${archiso_platform})');
    const location = path.includes('loopback')
      ? 'img_dev=UUID=${archiso_img_dev_uuid} img_loop="${iso_path}"'
      : 'archisosearchuuid=%ARCHISO_UUID%';
    assert.equal(body.match(/^\s+linux (.+)$/m)[1], `/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% ${location} %KERNEL_PARAMS% quiet splash`);
    assert.equal(body.match(/^\s+initrd (.+)$/m)[1], '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img');
  });
}

function filesUnder(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(entry => {
    const child = join(path, entry.name);
    if (entry.isSymbolicLink()) return [];
    return entry.isDirectory() ? filesUnder(child) : [child];
  });
}

test('no live display request or font preference leaks into installed-system implementation', () => {
  for (const directory of ['install/plan', 'install/engine', 'capabilities', 'targets']) {
    for (const path of filesUnder(join(root, directory))) {
      if (path.endsWith('.md')) continue;
      assert.ok(!readFileSync(path, 'utf8').includes('video=1280x720'), path);
      assert.ok(!readFileSync(path, 'utf8').includes('original-font.psf'), path);
    }
  }
});

test('live boot adds no persistent font, display request, forced driver, or forced connector', () => {
  for (const path of filesUnder(join(profile, 'airootfs'))) {
    const content = readFileSync(path, 'utf8');
    assert.doesNotMatch(content, /\bsetfont\b|\bFONT=/, path);
  }
  for (const path of ['grub/grub.cfg', 'grub/loopback.cfg', 'efiboot/loader/entries/01-archiso-linux.conf']) {
    assert.doesNotMatch(read(path), /\bvideo=|nomodeset|modprobe\.blacklist=|fbcon=font:|vconsole\.font=/);
  }
  const startup = readFileSync(join(root, 'install/confirmation/live-startup'), 'utf8');
  assert.doesNotMatch(startup, /\bsetfont\b/);
});
