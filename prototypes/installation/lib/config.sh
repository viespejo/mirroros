#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Prototype harness: VM shape and deadlines.
# The VM shape is read from vm/reference/reference-vm.conf, which this file never modifies.
# The 01-05 qualification deadline (REFERENCE_VM_GLOBAL_DEADLINE_SECONDS) does not apply here.

# Installation deadlines are owned by the harness, not by the 01-05 contract.
PROTO_INSTALL_DEADLINE_SECONDS=1800
PROTO_VERIFY_DEADLINE_SECONDS=600
PROTO_ATTENDED_DEADLINE_SECONDS=7200

# Fixed prototype target. The reference VM disk is the only virtio-blk device.
PROTO_TARGET_DISK='/dev/vda'

proto_config_load() {
  local config_path="$1"
  local name

  if [[ ! -f "$config_path" || ! -r "$config_path" ]]; then
    printf 'MirrorOS prototype: the reference VM configuration is missing: %s\n' "$config_path" >&2
    return 6
  fi
  # shellcheck disable=SC1090 # The versioned configuration path is resolved by the caller.
  if ! source "$config_path"; then
    printf 'MirrorOS prototype: the reference VM configuration could not be loaded: %s\n' "$config_path" >&2
    return 6
  fi
  for name in REFERENCE_VM_CONFIG_VERSION REFERENCE_VM_MACHINE REFERENCE_VM_ACCEL REFERENCE_VM_CPU \
    REFERENCE_VM_SMP REFERENCE_VM_MEMORY_MIB REFERENCE_VM_DISK_SIZE REFERENCE_VM_DISK_FORMAT \
    REFERENCE_VM_NETDEV REFERENCE_VM_NIC REFERENCE_VM_NOCLOUD_LABEL \
    REFERENCE_VM_GUEST_HTTPS_URL REFERENCE_VM_GUEST_HTTPS_TIMEOUT_SECONDS; do
    if [[ -z "${!name:-}" ]]; then
      printf 'MirrorOS prototype: the reference VM configuration does not define %s.\n' "$name" >&2
      return 6
    fi
  done
}
