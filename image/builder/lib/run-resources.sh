#!/usr/bin/bash

RUN_ID=''
BUILD_RUN_DIR=''
EVIDENCE_RUN_DIR=''
RUN_LOCK_PATH=''
RUN_LOCK_FD=''

run_resources_new_id() {
  local timestamp
  local uuid

  if ! timestamp="$(date -u +%Y%m%dT%H%M%SZ)" || \
    ! uuid="$(</proc/sys/kernel/random/uuid)" || \
    [[ ! "$timestamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || \
    [[ ! "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf '%s\n' 'MirrorOS build: could not create a valid UTC run ID.' >&2
    return 2
  fi

  RUN_ID="${timestamp}-${uuid}"
}

run_resources_check_directory() {
  local path="$1"
  local label="$2"

  if [[ -L "$path" ]]; then
    printf 'MirrorOS build: refusing symlinked %s path: %s\n' "$label" "$path" >&2
    return 2
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    printf 'MirrorOS build: refusing non-directory %s path: %s\n' "$label" "$path" >&2
    return 2
  fi
}

run_resources_ensure_directory() {
  local path="$1"
  local label="$2"

  run_resources_check_directory "$path" "$label" || return 2
  if [[ ! -e "$path" ]]; then
    if ! mkdir -m 700 -- "$path"; then
      printf 'MirrorOS build: could not create private %s directory: %s\n' "$label" "$path" >&2
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
    "${repository_root}/build/archiso"
    "${repository_root}/dist"
    "${repository_root}/evidence"
    "${repository_root}/evidence/archiso-build"
  )
  local -a labels=(
    'build base'
    'build work base'
    'distribution base'
    'evidence base'
    'build evidence base'
  )
  local index

  if [[ ! "$requested_run_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf 'MirrorOS build: invalid run ID: %s\n' "$requested_run_id" >&2
    return 2
  fi

  for index in "${!directories[@]}"; do
    run_resources_check_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done

  reserved_path="${repository_root}/build/archiso/${requested_run_id}"
  if [[ -e "$reserved_path" || -L "$reserved_path" ]]; then
    printf 'MirrorOS build: refusing existing reserved run path: %s\n' "$reserved_path" >&2
    return 2
  fi
  reserved_path="${repository_root}/dist/${requested_run_id}"
  if [[ -e "$reserved_path" || -L "$reserved_path" ]]; then
    printf 'MirrorOS build: refusing existing reserved run path: %s\n' "$reserved_path" >&2
    return 2
  fi
  reserved_path="${repository_root}/evidence/archiso-build/${requested_run_id}"
  if [[ -e "$reserved_path" || -L "$reserved_path" ]]; then
    printf 'MirrorOS build: refusing existing reserved run path: %s\n' "$reserved_path" >&2
    return 2
  fi

  for index in "${!directories[@]}"; do
    run_resources_ensure_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done

  RUN_ID="$requested_run_id"
  BUILD_RUN_DIR="${repository_root}/build/archiso/${RUN_ID}"
  EVIDENCE_RUN_DIR="${repository_root}/evidence/archiso-build/${RUN_ID}"
  RUN_LOCK_PATH="${EVIDENCE_RUN_DIR}/run.lock"

  if ! mkdir -m 700 -- "$BUILD_RUN_DIR" || ! mkdir -m 700 -- "$EVIDENCE_RUN_DIR"; then
    printf 'MirrorOS build: could not create private run directories for %s.\n' "$RUN_ID" >&2
    return 2
  fi

  if [[ -e "$RUN_LOCK_PATH" || -L "$RUN_LOCK_PATH" ]]; then
    printf 'MirrorOS build: refusing existing run lock: %s\n' "$RUN_LOCK_PATH" >&2
    return 2
  fi
  if ! (set -o noclobber; : > "$RUN_LOCK_PATH"); then
    printf 'MirrorOS build: could not create run lock: %s\n' "$RUN_LOCK_PATH" >&2
    return 2
  fi
  chmod 600 -- "$RUN_LOCK_PATH"
  exec {RUN_LOCK_FD}<>"$RUN_LOCK_PATH"
  if ! flock -x "$RUN_LOCK_FD"; then
    printf 'MirrorOS build: could not acquire run lock: %s\n' "$RUN_LOCK_PATH" >&2
    return 2
  fi
}
