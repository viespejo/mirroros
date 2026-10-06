#!/usr/bin/bash
# Prototype harness: run identity and private run directories.
# Disk and output paths are derived only under build/ and evidence/; anything else is refused.

RUN_ID=''
BUILD_RUN_DIR=''
EVIDENCE_RUN_DIR=''

proto_resources_new_id() {
  local timestamp
  local uuid

  if ! timestamp="$(date -u +%Y%m%dT%H%M%SZ)" || \
    ! uuid="$(</proc/sys/kernel/random/uuid)" || \
    [[ ! "$timestamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || \
    [[ ! "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf '%s\n' 'MirrorOS prototype: could not create a valid UTC run ID.' >&2
    return 2
  fi
  RUN_ID="${timestamp}-${uuid}"
}

proto_resources_ensure_directory() {
  local path="$1"

  if [[ -L "$path" ]]; then
    printf 'MirrorOS prototype: refusing symlinked path: %s\n' "$path" >&2
    return 2
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    printf 'MirrorOS prototype: refusing non-directory path: %s\n' "$path" >&2
    return 2
  fi
  if [[ ! -e "$path" ]]; then
    if ! mkdir -m 700 -- "$path"; then
      printf 'MirrorOS prototype: could not create private directory: %s\n' "$path" >&2
      return 2
    fi
  fi
}

# Refuses a path that does not resolve below the given base directory.
proto_resources_assert_inside() {
  local path="$1"
  local base="$2"
  local resolved

  if ! resolved="$(realpath -m -- "$path")" || [[ "$resolved" != "${base}/"* ]]; then
    printf 'MirrorOS prototype: refusing path outside %s: %s\n' "$base" "$path" >&2
    return 2
  fi
}

# Arguments: repository root, engine name, run ID.
proto_resources_prepare() {
  local repository_root="$1"
  local engine="$2"
  local requested_run_id="$3"
  local base
  local path
  local -a bases=(
    "${repository_root}/build"
    "${repository_root}/build/prototypes"
    "${repository_root}/build/prototypes/installation"
    "${repository_root}/build/prototypes/installation/${engine}"
    "${repository_root}/evidence"
    "${repository_root}/evidence/prototypes"
    "${repository_root}/evidence/prototypes/installation"
    "${repository_root}/evidence/prototypes/installation/${engine}"
  )

  if [[ ! "$engine" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    printf 'MirrorOS prototype: invalid engine name: %s\n' "$engine" >&2
    return 2
  fi
  if [[ ! "$requested_run_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf 'MirrorOS prototype: invalid run ID: %s\n' "$requested_run_id" >&2
    return 2
  fi

  for path in "${bases[@]}"; do
    if [[ -L "$path" ]]; then
      printf 'MirrorOS prototype: refusing symlinked path: %s\n' "$path" >&2
      return 2
    fi
  done
  for base in "build/prototypes/installation/${engine}/${requested_run_id}" \
    "evidence/prototypes/installation/${engine}/${requested_run_id}"; do
    if [[ -e "${repository_root}/${base}" || -L "${repository_root}/${base}" ]]; then
      printf 'MirrorOS prototype: refusing existing reserved run path: %s\n' "${repository_root}/${base}" >&2
      return 2
    fi
  done
  for path in "${bases[@]}"; do
    proto_resources_ensure_directory "$path" || return 2
  done

  RUN_ID="$requested_run_id"
  BUILD_RUN_DIR="${repository_root}/build/prototypes/installation/${engine}/${RUN_ID}"
  EVIDENCE_RUN_DIR="${repository_root}/evidence/prototypes/installation/${engine}/${RUN_ID}"
  proto_resources_assert_inside "$BUILD_RUN_DIR" "${repository_root}/build" || return 2
  proto_resources_assert_inside "$EVIDENCE_RUN_DIR" "${repository_root}/evidence" || return 2
  if ! mkdir -m 700 -- "$BUILD_RUN_DIR" || ! mkdir -m 700 -- "$EVIDENCE_RUN_DIR"; then
    printf 'MirrorOS prototype: could not create private run directories for %s.\n' "$RUN_ID" >&2
    return 2
  fi
}
