#!/usr/bin/bash
# shellcheck disable=SC2034 # BTRFS_MOUNT_OPTIONS is read by the mount and Snapper operations of this file.
# Btrfs operations of the installation engine: flat subvolumes, subvolume mounts, the Snapper root
# configuration, and the baseline snapshot (contracts/installation-engine.md, "Operations, values, and checks").
# The subvolume layout is flat and the mount points are engine constants; the plan supplies the subvolume names
# and the mount options.

BTRFS_MOUNT_OPTIONS=''

# Engine constants: where each flat subvolume other than @ is mounted in the target.
declare -A BTRFS_MOUNT_POINT=(
  [@home]=/home
  [@log]=/var/log
  [@pkg]=/var/cache/pacman/pkg
  [@snapshots]=/.snapshots
  [@swap]=/swap
)

# Engine constants: the Snapper root configuration (root only, no timeline).
readonly SNAPPER_CONSTANTS=(TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=10)
readonly BASELINE_DESCRIPTION='post-install baseline'

btrfs_options_valid() {
  [[ "$1" =~ ^[a-z0-9:,=_-]+$ ]] || check_fail 'the Btrfs mount options are not valid'
}

op_create_btrfs_subvolumes() {
  local subvolumes=() name listing
  param_lines subvolumes subvolumes
  BTRFS_MOUNT_OPTIONS="$(param mount_options)"
  btrfs_options_valid "$BTRFS_MOUNT_OPTIONS"
  [[ "${#subvolumes[@]}" -gt 0 && "${subvolumes[0]}" == @ ]] || check_fail 'the plan does not list @ first'
  install -d -m 0700 -- "$TARGET"
  run mount "$ROOT_PART" "$TARGET"
  for name in "${subvolumes[@]}"; do
    [[ "$name" == @ || -n "${BTRFS_MOUNT_POINT[$name]:-}" ]] || check_fail "the subvolume ${name} is not one the engine knows"
    run btrfs subvolume create "${TARGET}/${name}"
  done
  capture listing btrfs subvolume list "$TARGET"
  for name in "${subvolumes[@]}"; do
    [[ "$listing" =~ (^|[[:space:]])path[[:space:]]+"${name}"($|$'\n') ]] || check_fail "the subvolume ${name} does not exist"
  done
  run umount "$TARGET"
}

# Mounts the subvolumes beneath the already mounted @ (called by mount_target for a Btrfs root).
mount_btrfs_subvolumes() {
  local subvolumes=() name point mode
  param_lines subvolumes subvolumes
  [[ -n "$BTRFS_MOUNT_OPTIONS" ]] || check_fail 'the Btrfs mount options were not resolved'
  for name in "${subvolumes[@]}"; do
    [[ "$name" == @ ]] && continue
    point="${BTRFS_MOUNT_POINT[$name]:-}"
    [[ -n "$point" ]] || check_fail "the subvolume ${name} has no mount point"
    mode=0755
    [[ "$name" != @snapshots ]] || mode=0750
    install -d -m "$mode" -- "${TARGET}${point}"
    run mount -o "${BTRFS_MOUNT_OPTIONS},subvol=${name}" "$ROOT_PART" "${TARGET}${point}"
  done
  for name in "${subvolumes[@]}"; do
    [[ "$name" == @ ]] && continue
    mountpoint -q "${TARGET}${BTRFS_MOUNT_POINT[$name]}" || check_fail "the subvolume ${name} is not mounted"
  done
}

# Removes the subvolume ids that genfstab writes, so a rollback of @ cannot leave a stale id.
filter_fstab_subvolume_ids() {
  # The whole file is read before it is rewritten: a pipe would truncate it while sed is still reading.
  local filtered
  filtered="$(sed -E 's/(,subvolid=[0-9]+)|(subvolid=[0-9]+,)//g' "${TARGET}/etc/fstab")" || check_fail 'fstab cannot be filtered'
  printf '%s\n' "$filtered" | put_file 0644 /etc/fstab
}

op_configure_snapper() {
  local constant key value config="${TARGET}/etc/snapper/configs/root"
  # Snapper creates its own /.snapshots subvolume; the engine's @snapshots mount is replaced around it.
  run umount "${TARGET}/.snapshots"
  rmdir -- "${TARGET}/.snapshots" || check_fail 'the /.snapshots mount point cannot be released'
  chroot_run snapper --no-dbus -c root create-config /
  run btrfs subvolume delete "${TARGET}/.snapshots"
  install -d -m 0750 -- "${TARGET}/.snapshots"
  run mount -o "${BTRFS_MOUNT_OPTIONS},subvol=@snapshots" "$ROOT_PART" "${TARGET}/.snapshots"
  chroot_run snapper --no-dbus -c root set-config "${SNAPPER_CONSTANTS[@]}"
  # The configuration file is where set-config stores the values, as KEY="value" lines.
  for constant in "${SNAPPER_CONSTANTS[@]}"; do
    key="${constant%%=*}"
    value="${constant#*=}"
    grep -qxF -- "${key}=\"${value}\"" "$config" || check_fail "the snapper configuration does not hold ${constant}"
  done
  mountpoint -q "${TARGET}/.snapshots" || check_fail '/.snapshots is not the @snapshots subvolume'
  record_constant configure_snapper.config "${SNAPPER_CONSTANTS[*]}"
}

op_create_baseline_snapshot() {
  local listing
  chroot_run snapper --no-dbus -c root create --type single --description "$BASELINE_DESCRIPTION"
  capture listing arch-chroot "$TARGET" snapper --no-dbus -c root list
  [[ "$listing" == *"$BASELINE_DESCRIPTION"* ]] || check_fail 'the baseline snapshot is not listed'
  record_constant create_baseline_snapshot.description "$BASELINE_DESCRIPTION"
}

# Snapper timeline snapshots are never wanted; the unit must not be enabled after the services step.
disable_snapper_timeline() {
  chroot_run systemctl disable snapper-timeline.timer
  if arch-chroot "$TARGET" systemctl is-enabled snapper-timeline.timer < /dev/null > /dev/null 2>&1 3>&- 4>&-; then
    check_fail 'snapper-timeline.timer is still enabled'
  fi
}
