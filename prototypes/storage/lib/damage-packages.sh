#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Storage prototype harness: builds the synthetic damage packages (DEC-007).
#
# Both packages are built locally with tar and zstd (no network, no makepkg) and are installed in the
# guest with `pacman -U`, so snap-pac snapshots around them exactly as around a real update.
#   mirroros-damage-d1  damages userspace inside @: a failing unit required by local-fs.target, which
#                       stops the boot in emergency mode before login.
#   mirroros-damage-d2  damages the boot path on the ESP: its post-install scriptlet overwrites the
#                       /boot initramfs with a non-archive, so the kernel cannot find the root.
# Fixed timestamps and ownership keep the packages reproducible. They are unsigned: pacman accepts
# unsigned local files (LocalFileSigLevel = Optional).

DAMAGE_PACKAGE_VERSION='1-1'
DAMAGE_PACKAGES_DIR=''
DAMAGE_PACKAGES_JSON='[]'

# Argument: package staging directory (already holding the package files).
# Writes .PKGINFO (and .INSTALL when present), then the archive. Arguments: staging dir, name, output dir.
damage_build_archive() {
  local stage="$1"
  local name="$2"
  local output_dir="$3"
  local size
  local package_file="${output_dir}/${name}-${DAMAGE_PACKAGE_VERSION}-any.pkg.tar.zst"
  local -a members=()

  size="$(du -sb --exclude=.PKGINFO --exclude=.INSTALL -- "$stage" | cut -f1)" || return 1
  cat > "${stage}/.PKGINFO" <<EOF
pkgname = ${name}
pkgbase = ${name}
pkgver = ${DAMAGE_PACKAGE_VERSION}
pkgdesc = MirrorOS prototype synthetic damage package (never part of any product)
url = https://example.invalid/mirroros-prototype
builddate = 1
packager = MirrorOS prototype <noreply@example.invalid>
size = ${size}
arch = any
license = custom
EOF
  mapfile -t members < <(cd -- "$stage" && find . -mindepth 1 -printf '%P\n' | LC_ALL=C sort)
  (
    cd -- "$stage" && \
      tar --create --zstd --file "$package_file" --owner=0 --group=0 --numeric-owner --mtime='@1' \
        --no-recursion -- "${members[@]}"
  ) || return 1
  chmod 600 -- "$package_file"
}

# Builds both packages under the given directory (created 0700) and fills DAMAGE_PACKAGES_JSON with
# their names, versions, sizes, hashes, and file lists, for the evidence record.
# Argument: output directory.
damage_build_all() {
  local output_dir="$1"
  local stage
  local file
  local name
  local entries=''
  local files_json

  DAMAGE_PACKAGES_DIR="$output_dir"
  mkdir -m 700 -- "$output_dir" || return 1
  stage="$(mktemp -d "${output_dir}/stage.XXXXXX")" || return 1

  # D1: userspace damage inside @ (the root subvolume on Btrfs).
  name='mirroros-damage-d1'
  mkdir -p -- "${stage}/${name}/usr/lib/systemd/system/local-fs.target.d"
  cat > "${stage}/${name}/usr/lib/systemd/system/mirroros-damage-d1.service" <<'EOF'
[Unit]
Description=MirrorOS prototype synthetic damage D1 (always fails)
DefaultDependencies=no
Before=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/false
EOF
  cat > "${stage}/${name}/usr/lib/systemd/system/local-fs.target.d/10-mirroros-damage-d1.conf" <<'EOF'
[Unit]
Requires=mirroros-damage-d1.service
After=mirroros-damage-d1.service
EOF
  damage_build_archive "${stage}/${name}" "$name" "$output_dir" || return 1

  # D2: boot-path damage on the ESP, applied by the post-install scriptlet.
  name='mirroros-damage-d2'
  mkdir -p -- "${stage}/${name}/usr/share/mirroros-damage"
  printf 'MirrorOS prototype synthetic damage D2: the post-install scriptlet corrupts the initramfs.\n' \
    > "${stage}/${name}/usr/share/mirroros-damage/d2"
  cat > "${stage}/${name}/.INSTALL" <<'EOF'
post_install() {
  local initramfs=/boot/initramfs-linux.img
  if [[ -f /boot/limine.conf ]]; then
    initramfs="/boot/$(cat /etc/machine-id)/linux/initramfs"
  fi
  if [[ ! -f "$initramfs" ]]; then
    printf 'MIRROROS-DAMAGE-D2: expected active initramfs missing: %s\n' "$initramfs" >&2
    return 1
  fi
  printf 'MIRROROS-DAMAGE-D2: corrupting %s\n' "$initramfs"
  printf 'MIRROROS-DAMAGE-D2: not an initramfs archive\n' > "$initramfs"
}
EOF
  damage_build_archive "${stage}/${name}" "$name" "$output_dir" || return 1
  rm -rf -- "$stage"

  for file in "${output_dir}"/*.pkg.tar.zst; do
    files_json="$(tar --list --zstd --file "$file" | jq -R . | jq -s .)" || return 1
    entries+="${entries:+,}$(jq -n --arg file "${file##*/}" \
      --arg sha256 "$(sha256sum -- "$file" | cut -d' ' -f1)" \
      --argjson size "$(stat -c %s -- "$file")" --argjson files "$files_json" \
      '{file: $file, sha256: $sha256, size_bytes: $size, members: $files}')" || return 1
  done
  DAMAGE_PACKAGES_JSON="[${entries}]"
}
