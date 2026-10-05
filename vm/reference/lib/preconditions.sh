#!/usr/bin/bash

PRECONDITIONS_OVMF_CODE_PATH='/usr/share/edk2/x64/OVMF_CODE.4m.fd'
PRECONDITIONS_OVMF_VARS_PATH='/usr/share/edk2/x64/OVMF_VARS.4m.fd'
PRECONDITIONS_KVM_PROBE_SECONDS=20
# shellcheck disable=SC2034 # Read by the qualification orchestrator after argument parsing.
QUALIFY_BUNDLE_DIR=''
# shellcheck disable=SC2034 # Read by the qualification orchestrator after bundle admission.
QUALIFY_BUNDLE_ADMISSION=''

preconditions_parse_arguments() {
  local bundle_argument
  local resolved_directory

  if [[ "$#" -eq 0 ]]; then
    printf '%s\n' \
      'MirrorOS test: the bundle directory argument is missing.' \
      'Accepted forms: operations/test BUNDLE_DIRECTORY, operations/test --help.' >&2
    return 2
  fi

  if [[ "$#" -ne 1 || -z "$1" || "$1" == -* ]]; then
    printf 'MirrorOS test: unsupported argument(s):' >&2
    printf ' %q' "$@" >&2
    printf '\nAccepted forms: operations/test BUNDLE_DIRECTORY, operations/test --help.\n' >&2
    return 2
  fi

  bundle_argument="$1"
  if [[ ! -d "$bundle_argument" ]] || \
    ! resolved_directory="$(cd -- "$bundle_argument" 2>/dev/null && pwd -P)"; then
    printf 'MirrorOS test: the bundle directory is not an accessible directory: %s\n' \
      "$bundle_argument" >&2
    return 2
  fi

  # shellcheck disable=SC2034 # Read by the qualification orchestrator after argument parsing.
  QUALIFY_BUNDLE_DIR="$resolved_directory"
}

preconditions_check_user() {
  local effective_uid="$1"

  if [[ "$effective_uid" -eq 0 ]]; then
    printf '%s\n' \
      'MirrorOS test: do not run as root; run as a normal user with functional KVM access.' >&2
    return 2
  fi
}

preconditions_check_tools() {
  local tool

  for tool in qemu-system-x86_64 qemu-img xorriso node gitleaks git timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'MirrorOS test: required tool is missing: %s. Install it and retry; no host remediation is attempted.\n' \
        "$tool" >&2
      return 2
    fi
  done
}

preconditions_admit_bundle() {
  local bundle_directory="$1"
  local documents_cli="$2"
  local admission
  local status

  if admission="$(node "$documents_cli" admit-bundle --bundle "$bundle_directory")"; then
    # shellcheck disable=SC2034 # Read by the qualification orchestrator after bundle admission.
    QUALIFY_BUNDLE_ADMISSION="$admission"
    return 0
  else
    status=$?
  fi

  if [[ "$status" -eq 2 ]]; then
    printf '%s\n' \
      'MirrorOS test: the bundle is not admissible; no VM resources were created.' >&2
    return 2
  fi

  printf 'MirrorOS test: bundle admission failed internally (status %s); no VM resources were created.\n' \
    "$status" >&2
  return 6
}

preconditions_check_firmware() {
  local firmware_path

  for firmware_path in "$PRECONDITIONS_OVMF_CODE_PATH" "$PRECONDITIONS_OVMF_VARS_PATH"; do
    if [[ ! -f "$firmware_path" || ! -r "$firmware_path" ]]; then
      printf 'MirrorOS test: OVMF firmware is missing or unreadable: %s. Install the OVMF (edk2) firmware package yourself and retry; no host remediation is attempted.\n' \
        "$firmware_path" >&2
      return 2
    fi
  done
}

preconditions_check_kvm() {
  if timeout "$PRECONDITIONS_KVM_PROBE_SECONDS" qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -m 128 \
    -display none -nodefaults -S -monitor stdio \
    <<< 'quit' >/dev/null 2>&1; then
    return 0
  fi

  printf '%s\n' \
    'MirrorOS test: KVM is not functional for this user. Enable virtualization and grant your user access to /dev/kvm yourself, then retry; no sudo, group change, or software-emulation fallback is attempted.' >&2
  return 2
}
