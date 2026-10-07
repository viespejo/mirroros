#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Variant contract variables and installer globals (see lib/README.md).
# btrfs-limine variant (Story 2.1, Track 2): Btrfs/Snapper with Limine snapshot boot entries.
# Limine is installed unsigned (no Secure Boot). Sourced by guest/install. Non-production.

# shellcheck disable=SC1091 # Resolved from the mounted NoCloud medium at run time.
source "${MIRROROS_SEED_DIR:?}/engine/support/btrfs-stage.sh"

# base-devel and git exist only in this variant, for makepkg. libnotify and gettext are runtime and
# build dependencies of the AUR tools (README.md, provenance review).
VARIANT_PACKAGES=(btrfs-progs snapper snap-pac compsize limine efibootmgr libnotify gettext base-devel git)
MIRROROS_STORAGE_EXCLUDE_GROUPS='storage swap boot'

LIMINE_BUILD_USER='mirrorosbuild'
LIMINE_BUILD_DIR='/var/tmp/mirroros-build'

variant_plan_lines() {
  btrfs_plan_lines
  printf '  4. Limine (unsigned) on the ESP with snapshot entries from the pinned AUR tools (makepkg as an\n'
  printf '     unprivileged user), Snapper root configuration (snap-pac, no timeline), and a\n'
  printf '     "post-install baseline" snapshot\n'
}

variant_install_storage() {
  btrfs_install_storage
}

# Swap and the Limine configuration. The loader itself is installed in variant_finalize, once the
# pinned tools that provide limine-install exist.
variant_configure_swap_and_boot() {
  btrfs_configure_swap

  mirroros_proto_log 'boot: Limine configuration'
  # SKIP_UEFI=yes places Limine on the standard fallback path, so no firmware boot entry is needed.
  put "${TARGET_ROOT}/etc/default/limine" <<EOF
ESP_PATH="/boot"
SKIP_UEFI=yes
KERNEL_CMDLINE[default]+=root=UUID=${BTRFS_ROOT_UUID} rootflags=subvol=@,compress=zstd:1,relatime rw resume=UUID=${BTRFS_ROOT_UUID} resume_offset=${BTRFS_RESUME_OFFSET}
EOF
}

# Builds the pinned tools as an unprivileged user and installs them. SNAP_PAC_SKIP keeps snap-pac
# from taking snapshots inside the installation chroot (no D-Bus there).
limine_build_and_install_tools() {
  mirroros_proto_log 'boot: building the pinned Limine snapshot tools'
  run arch-chroot "$TARGET_ROOT" useradd --system --create-home --home-dir "$LIMINE_BUILD_DIR" \
    --shell /usr/bin/bash "$LIMINE_BUILD_USER"
  put "${TARGET_ROOT}/etc/sudoers.d/99-mirroros-build" <<EOF
${LIMINE_BUILD_USER} ALL=(root) NOPASSWD: /usr/bin/pacman
EOF
  run chmod 0440 "${TARGET_ROOT}/etc/sudoers.d/99-mirroros-build"
  run install -m 0755 -o root -g root "${MIRROROS_SEED_DIR}/engine/variant/aur-build.sh" \
    "${TARGET_ROOT}${LIMINE_BUILD_DIR}/aur-build.sh"
  # arch-chroot -u runs the command in a new PID namespace but keeps the outer /proc, so the GraalVM
  # native-image watcher cannot find its driver (exit status 30). A private /proc matches the namespace.
  run arch-chroot "$TARGET_ROOT" /usr/bin/unshare --mount --pid --fork --mount-proc \
    /usr/bin/runuser -u "$LIMINE_BUILD_USER" -- /usr/bin/env "MIRROROS_BUILD_DIR=${LIMINE_BUILD_DIR}" \
    "HOME=${LIMINE_BUILD_DIR}" "${LIMINE_BUILD_DIR}/aur-build.sh"

  mirroros_proto_log 'boot: installing the pinned Limine snapshot tools'
  run arch-chroot "$TARGET_ROOT" /usr/bin/env SNAP_PAC_SKIP=y /usr/bin/bash -c \
    "pacman -U --noconfirm ${LIMINE_BUILD_DIR}/out/*.pkg.tar.zst"
  run rm -f "${TARGET_ROOT}/etc/sudoers.d/99-mirroros-build"
  run arch-chroot "$TARGET_ROOT" userdel "$LIMINE_BUILD_USER"
  run rm -rf -- "${TARGET_ROOT}${LIMINE_BUILD_DIR}"
}

variant_finalize() {
  btrfs_configure_snapper
  # Documented requirement of limine-snapper-sync with mkinitcpio: the overlay hook (systemd flavor)
  # after filesystems, so that a read-only snapshot can boot. The hook ships with the pinned package,
  # whose pacman transaction rebuilds the initramfs and writes the Limine entries (no limine-update).
  put "${TARGET_ROOT}/etc/mkinitcpio.conf.d/10-mirroros-limine.conf" <<'EOF'
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)
EOF
  limine_build_and_install_tools
  mirroros_proto_log 'boot: enabling the snapshot entry sync'
  run arch-chroot "$TARGET_ROOT" systemctl enable limine-snapper-sync.service
  btrfs_take_baseline
  run arch-chroot "$TARGET_ROOT" limine-snapper-sync
}
