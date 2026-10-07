#!/usr/bin/bash
# Guest helper for the storage installer, sourced in the live environment after common.sh.
# It adds, to the 02-01 verification contamination, the storage action unit and, for the Btrfs
# variants, the storage checks that stand in for the check groups excluded from the 02-01 script.

# Installs the storage support into the target. Run after mirroros_proto_install_verifier.
# Argument: the target root mount point.
# Environment (set by the variant stage before the call):
#   MIRROROS_STORAGE_VARIANT          control, btrfs-rescue, or btrfs-limine (from seed.env)
#   MIRROROS_SEED_LABEL               NoCloud volume label (from seed.env)
#   MIRROROS_STORAGE_EXCLUDE_GROUPS   groups excluded from verify-postconditions.sh (default none)
#   MIRROROS_STORAGE_SWAPFILE         swapfile path for the verification (default /swapfile)
#   MIRROROS_STORAGE_OFFSET_TOOL      filefrag (default) or btrfs
mirroros_storage_install_support() {
  local target_root="$1"
  local support_dir="${MIRROROS_SEED_DIR:?}/engine/support"
  local lib_dir=/usr/local/lib/mirroros-proto

  install -D -m 0755 "${support_dir}/storage-action.sh" "${target_root}${lib_dir}/storage-action.sh" || return 1
  install -D -m 0644 "${support_dir}/mirroros-storage-action.service" \
    "${target_root}/etc/systemd/system/mirroros-storage-action.service" || return 1
  {
    printf "MIRROROS_SEED_LABEL='%s'\n" "${MIRROROS_SEED_LABEL:?}"
    printf "MIRROROS_STORAGE_VARIANT='%s'\n" "${MIRROROS_STORAGE_VARIANT:?}"
  } > "${target_root}/etc/mirroros-proto/storage.env" || return 1

  if [[ -n "${MIRROROS_STORAGE_EXCLUDE_GROUPS:-}" ]]; then
    install -D -m 0644 "${support_dir}/storage-checks.sh" "${target_root}${lib_dir}/storage-checks.sh" || return 1
    {
      printf "MIRROROS_VERIFY_EXCLUDE_GROUPS='%s'\n" "$MIRROROS_STORAGE_EXCLUDE_GROUPS"
      printf "MIRROROS_VERIFY_SWAPFILE='%s'\n" "${MIRROROS_STORAGE_SWAPFILE:-/swapfile}"
      printf "MIRROROS_VERIFY_SWAP_OFFSET_TOOL='%s'\n" "${MIRROROS_STORAGE_OFFSET_TOOL:-filefrag}"
      printf "MIRROROS_VERIFY_EXTRA_CHECKS='%s'\n" "${lib_dir}/storage-checks.sh"
      printf "MIRROROS_STORAGE_VARIANT='%s'\n" "$MIRROROS_STORAGE_VARIANT"
    } >> "${target_root}/etc/mirroros-proto/verify.env" || return 1
  fi
  systemctl --root="$target_root" enable mirroros-storage-action.service
}
