#!/usr/bin/env bats
# Static live-profile contracts; bundle checks require actual resolved build inputs.

REPOSITORY_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
PROFILE="${REPOSITORY_ROOT}/image/archiso"
AUDIT="${REPOSITORY_ROOT}/docs/procedures/iso-size-and-live-branding.md"
VENDOR_BASELINE='bc4cd22b0e4294914f38f4ba800b88474ab3a50a'

@test "the x86_64 declarations match the approved Keep rows plus ADR 0019 Plymouth" {
  run node --input-type=module - "$AUDIT" "${PROFILE}/packages.x86_64" <<'JS'
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const [auditPath, packagesPath] = process.argv.slice(2);
const audit = readFileSync(auditPath, 'utf8');
const rows = [...audit.matchAll(/^\| ([^|]+) \| (Keep|Remove \/ accepted|Remove \/ proposed) \|/gm)];
assert.equal(rows.length, 131);
assert.equal(new Set(rows.map(row => row[1])).size, 131);
assert.match(audit, /Package-review state: approved/);
const keep = rows.filter(row => row[2] === 'Keep').map(row => row[1].trim());
assert.equal(keep.length, 62);
assert.deepEqual(readFileSync(packagesPath, 'utf8').trim().split('\n'), [...keep, 'plymouth'].sort());
JS
  [ "$status" -eq 0 ]
}

@test "metadata uses MirrorOS and preserves reproducible date, paths and compression" {
  run bash -c '
    set -e
    export TZ=UTC
    declare -A file_permissions
    SOURCE_DATE_EPOCH=1791849600
    source "$1"
    [[ "$iso_name-$iso_version-x86_64.iso" == mirroros-2026.10.13-x86_64.iso ]]
    [[ "$iso_label" == MIRROROS_202610 ]]
    [[ "$iso_publisher" == MirrorOS && "$iso_application" == "MirrorOS Live/Rescue" ]]
    [[ "$install_dir" == arch && "${bootmodes[*]}" == uefi.systemd-boot ]]
    [[ "$airootfs_image_type" == squashfs ]]
    [[ "${airootfs_image_tool_options[*]}" == "-comp xz -Xbcj x86,arm64 -b 1M -Xdict-size 1M" ]]
    [[ "${bootstrap_tarball_compression[*]}" == "zstd -c -T0 --auto-threads=logical --long -19" ]]
    [[ ! -v file_permissions[/usr/local/bin/Installation_guide] ]]
    [[ ! -v file_permissions[/usr/local/bin/livecd-sound] ]]
  ' _ "${PROFILE}/profiledef.sh"
  [ "$status" -eq 0 ]
}

@test "live identity is a regular override with accurate Arch lineage" {
  [ "$(<"${PROFILE}/airootfs/etc/hostname")" = mirroros ]
  [ -f "${PROFILE}/airootfs/etc/os-release" ]
  [ ! -L "${PROFILE}/airootfs/etc/os-release" ]
  [ ! -e "${PROFILE}/airootfs/usr/lib/os-release" ]
  run bash -c '
    set -e
    source "$1"
    [[ "$NAME" == MirrorOS && "$PRETTY_NAME" == "MirrorOS Live/Rescue" ]]
    [[ "$ID" == mirroros && "$ID_LIKE" == arch ]]
    [[ "$DOCUMENTATION_URL" == https://wiki.archlinux.org/ ]]
  ' _ "${PROFILE}/airootfs/etc/os-release"
  [ "$status" -eq 0 ]
  grep -Fq 'Welcome to MirrorOS Live/Rescue.' "${PROFILE}/airootfs/etc/motd"
  grep -Fq 'https://wiki.archlinux.org/title/Installation_guide' "${PROFILE}/airootfs/etc/motd"
  ! grep -Eq 'mmcli|convenience script|To install .*Arch Linux' "${PROFILE}/airootfs/etc/motd"
}

@test "boot menus retain technical Archiso and EFI tools but no speech or BIOS memtest" {
  local menu
  for menu in efiboot/loader/entries/01-archiso-linux.conf grub/grub.cfg grub/loopback.cfg; do
    grep -Fq 'MirrorOS Live/Rescue' "${PROFILE}/${menu}"
    grep -Fq 'archisobasedir=%INSTALL_DIR%' "${PROFILE}/${menu}"
    grep -Fq '/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux' "${PROFILE}/${menu}"
    ! grep -Eq 'speakup|accessibility=|Arch Linux install medium|^play ' "${PROFILE}/${menu}"
  done
  grep -Fxq 'default 01-archiso-linux.conf' "${PROFILE}/efiboot/loader/loader.conf"
  ! grep -q '^beep ' "${PROFILE}/efiboot/loader/loader.conf"
  [ -f "${PROFILE}/efiboot/loader/entries/03-archiso-memtest86+x64.conf" ]
  grep -Fq 'memtest.efi' "${PROFILE}/grub/loopback.cfg"
  ! grep -Eq '^[[:space:]]*linux /boot/memtest86\+/memtest$' "${PROFILE}/grub/loopback.cfg" "${PROFILE}/grub/grub.cfg"
  grep -Fq 'img_loop="${iso_path}"' "${PROFILE}/grub/loopback.cfg"
  grep -Fq 'archisosearchuuid=%ARCHISO_UUID%' "${PROFILE}/grub/grub.cfg"
}

@test "approved dedicated resources and enabling symlinks are absent" {
  local path
  for path in \
    efiboot/loader/entries/02-archiso-speech-linux.conf \
    syslinux/archiso_head.cfg syslinux/archiso_pxe.cfg syslinux/archiso_pxe-linux.cfg \
    syslinux/archiso_sys.cfg syslinux/archiso_sys-linux.cfg syslinux/archiso_tail.cfg \
    syslinux/splash.png syslinux/syslinux.cfg \
    airootfs/usr/local/bin/Installation_guide airootfs/usr/local/bin/livecd-sound \
    airootfs/usr/local/share/livecd-sound/asound.conf.in \
    airootfs/etc/systemd/system/livecd-alsa-unmuter.service \
    airootfs/etc/systemd/system/livecd-talk.service \
    airootfs/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service \
    airootfs/etc/systemd/system/sound.target.wants/livecd-alsa-unmuter.service \
    airootfs/etc/systemd/system/multi-user.target.wants/livecd-talk.service \
    airootfs/etc/systemd/system/multi-user.target.wants/ModemManager.service \
    airootfs/etc/systemd/system/multi-user.target.wants/hv_fcopy_daemon.service \
    airootfs/etc/systemd/system/multi-user.target.wants/hv_kvp_daemon.service \
    airootfs/etc/systemd/system/multi-user.target.wants/hv_vss_daemon.service \
    airootfs/etc/systemd/system/multi-user.target.wants/vboxservice.service \
    airootfs/etc/systemd/system/multi-user.target.wants/vmtoolsd.service \
    airootfs/etc/systemd/system/multi-user.target.wants/vmware-vmblock-fuse.service; do
    [ ! -e "${PROFILE}/${path}" ]
    [ ! -L "${PROFILE}/${path}" ]
  done
  ! grep -REq 'livecd-sound|livecd-talk|livecd-alsa-unmuter|accessibility=|SINGLE_LINE_ZLE|mmcli' \
    "${PROFILE}/profiledef.sh" "${PROFILE}/airootfs/root" "${PROFILE}/airootfs/etc" \
    "${PROFILE}/grub" "${PROFILE}/efiboot"
}

@test "SSH policy and credentials remain byte-identical to the inherited profile" {
  local path
  for path in airootfs/etc/ssh/sshd_config.d/10-archiso.conf airootfs/etc/passwd airootfs/etc/shadow; do
    git -C "$REPOSITORY_ROOT" show "${VENDOR_BASELINE}:image/archiso/${path}" | cmp - "${PROFILE}/${path}"
  done
  [ "$(readlink "${PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service")" = /usr/lib/systemd/system/sshd.service ]
  [ "$(readlink "${PROFILE}/airootfs/etc/systemd/system/sockets.target.wants/pcscd.socket")" = /usr/lib/systemd/system/pcscd.socket ]
  grep -Fq '/usr/lib/libpcsclite.so' "${PROFILE}/airootfs/root/.gnupg/scdaemon.conf"
}

@test "firmware declarations and networking remain intact" {
  local package
  for package in linux-firmware linux-firmware-marvell sof-firmware amd-ucode intel-ucode b43-fwcutter \
    cloud-init arch-install-scripts nodejs gum dosfstools e2fsprogs btrfs-progs parted \
    openssh libfido2 vim gpm dmidecode iw iwd wpa_supplicant wireless-regdb; do
    grep -Fxq "$package" "${PROFILE}/packages.x86_64"
  done
  for package in iwd systemd-networkd systemd-resolved; do
    [ "$(readlink "${PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/${package}.service")" = "/usr/lib/systemd/system/${package}.service" ]
  done
  git -C "$REPOSITORY_ROOT" diff --exit-code "$VENDOR_BASELINE" -- image/archiso/airootfs/etc/systemd/network
}

@test "UEFI-only initramfs omits memdisk and adds Plymouth after udev without other changes" {
  ! grep -Fxq syslinux "${PROFILE}/packages.x86_64"
  run bash -c '
    set -e
    baseline=$(git -C "$1" show "$2:image/archiso/airootfs/etc/mkinitcpio.conf.d/archiso.conf")
    [[ "$baseline" == *" kms memdisk archiso "* ]]
    expected="${baseline/ kms memdisk archiso / kms archiso }"
    expected="${expected/base udev /base udev plymouth }"
    [[ "$(<"$3")" == "$expected" ]]
  ' _ "$REPOSITORY_ROOT" "$VENDOR_BASELINE" "${PROFILE}/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
  [ "$status" -eq 0 ]
}

@test "actual reduced bundle resolves retained tools, excludes cuts and preserves baseline firmware" {
  [ -n "${MIRROROS_REDUCED_BUNDLE:-}" ] && [ -n "${MIRROROS_BASELINE_BUNDLE:-}" ] || \
    skip 'Actual reduced and baseline bundles are required; build/runtime acceptance remains pending.'
  (cd -- "$MIRROROS_REDUCED_BUNDLE" && sha256sum --check SHA256SUMS)
  (cd -- "$MIRROROS_BASELINE_BUNDLE" && sha256sum --check SHA256SUMS)
  run node --input-type=module - "$AUDIT" "$MIRROROS_REDUCED_BUNDLE" "$MIRROROS_BASELINE_BUNDLE" <<'JS'
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
const [auditPath, reduced, baseline] = process.argv.slice(2);
const names = dir => new Set(readFileSync(join(dir, 'pkglist.x86_64.txt'), 'utf8').trim().split('\n').map(line => line.trim().split(/\s+/)[0]));
const actual = names(reduced);
const rows = [...readFileSync(auditPath, 'utf8').matchAll(/^\| ([^|]+) \| (Keep|Remove \/ accepted|Remove \/ proposed) \|/gm)];
for (const row of rows) assert.equal(actual.has(row[1].trim()), row[2] === 'Keep', row[1]);
for (const name of names(baseline)) {
  if (/firmware|^(amd|intel)-ucode$|^b43-fwcutter$/.test(name)) assert.ok(actual.has(name), name);
}
for (const name of ['bash', 'coreutils', 'util-linux', 'systemd', 'pacman', 'curl', 'gnupg', 'cryptsetup', 'kbd', 'python', 'dhcpcd', 'sudo', 'tpm2-tss', 'vim-runtime', 'gpm']) assert.ok(actual.has(name), name);
const metadata = JSON.parse(readFileSync(join(reduced, 'artifact-metadata.json'), 'utf8'));
assert.match(metadata.artifact.iso.name, /^mirroros-\d{4}\.\d{2}\.\d{2}-x86_64\.iso$/);
JS
  [ "$status" -eq 0 ]
}
