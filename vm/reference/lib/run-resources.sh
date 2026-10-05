#!/usr/bin/bash

RUN_ID=''
BUILD_RUN_DIR=''
EVIDENCE_RUN_DIR=''

run_resources_new_id() {
  local timestamp
  local uuid

  if ! timestamp="$(date -u +%Y%m%dT%H%M%SZ)" || \
    ! uuid="$(</proc/sys/kernel/random/uuid)" || \
    [[ ! "$timestamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || \
    [[ ! "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf '%s\n' 'MirrorOS test: could not create a valid UTC run ID.' >&2
    return 2
  fi

  RUN_ID="${timestamp}-${uuid}"
}

run_resources_check_directory() {
  local path="$1"
  local label="$2"

  if [[ -L "$path" ]]; then
    printf 'MirrorOS test: refusing symlinked %s path: %s\n' "$label" "$path" >&2
    return 2
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    printf 'MirrorOS test: refusing non-directory %s path: %s\n' "$label" "$path" >&2
    return 2
  fi
}

run_resources_ensure_directory() {
  local path="$1"
  local label="$2"

  run_resources_check_directory "$path" "$label" || return 2
  if [[ ! -e "$path" ]]; then
    if ! mkdir -m 700 -- "$path"; then
      printf 'MirrorOS test: could not create private %s directory: %s\n' "$label" "$path" >&2
      return 2
    fi
  fi
}

run_resources_prepare() {
  local repository_root="$1"
  local requested_run_id="$2"
  local reserved_path
  local -a directories=(
    "${repository_root}/build"
    "${repository_root}/build/reference-vm"
    "${repository_root}/evidence"
    "${repository_root}/evidence/reference-vm"
  )
  local -a labels=(
    'build base'
    'build work base'
    'evidence base'
    'reference VM evidence base'
  )
  local index

  if [[ ! "$requested_run_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf 'MirrorOS test: invalid run ID: %s\n' "$requested_run_id" >&2
    return 2
  fi

  for index in "${!directories[@]}"; do
    run_resources_check_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done

  for reserved_path in \
    "${repository_root}/build/reference-vm/${requested_run_id}" \
    "${repository_root}/evidence/reference-vm/${requested_run_id}"; do
    if [[ -e "$reserved_path" || -L "$reserved_path" ]]; then
      printf 'MirrorOS test: refusing existing reserved run path: %s\n' "$reserved_path" >&2
      return 2
    fi
  done

  for index in "${!directories[@]}"; do
    run_resources_ensure_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done

  RUN_ID="$requested_run_id"
  BUILD_RUN_DIR="${repository_root}/build/reference-vm/${RUN_ID}"
  EVIDENCE_RUN_DIR="${repository_root}/evidence/reference-vm/${RUN_ID}"

  if ! mkdir -m 700 -- "$BUILD_RUN_DIR" || ! mkdir -m 700 -- "$EVIDENCE_RUN_DIR"; then
    printf 'MirrorOS test: could not create private run directories for %s.\n' "$RUN_ID" >&2
    return 2
  fi
}
