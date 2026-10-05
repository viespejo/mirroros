BUILDER_TEST_SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"

builder_setup() {
  local tool_name
  local repository_path

  BUILDER_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros builder.XXXXXX")"
  BUILDER_REPOSITORY_ROOT="${BUILDER_TEST_ROOT}/repository copy"
  BUILDER_OUTSIDE_DIR="${BUILDER_TEST_ROOT}/outside working directory"
  BUILDER_DOUBLE_DIR="${BUILDER_TEST_ROOT}/tool doubles"
  BUILDER_FILTERED_PATH_DIR="${BUILDER_TEST_ROOT}/filtered path"
  BUILDER_CALL_LOG="${BUILDER_TEST_ROOT}/tool calls.log"
  BUILDER_STDOUT_PATH="${BUILDER_TEST_ROOT}/stdout.log"
  BUILDER_STDERR_PATH="${BUILDER_TEST_ROOT}/stderr.log"
  BUILDER_PATH_FILE="${BUILDER_TEST_ROOT}/filtered PATH"

  mkdir -p \
    "$BUILDER_REPOSITORY_ROOT" \
    "$BUILDER_OUTSIDE_DIR" \
    "$BUILDER_DOUBLE_DIR" \
    "$BUILDER_FILTERED_PATH_DIR"
  cp -a -- "${BUILDER_TEST_SOURCE_ROOT}/operations" "$BUILDER_REPOSITORY_ROOT/"
  mkdir -p "${BUILDER_REPOSITORY_ROOT}/image"
  cp -a -- \
    "${BUILDER_TEST_SOURCE_ROOT}/image/archiso" \
    "${BUILDER_TEST_SOURCE_ROOT}/image/builder" \
    "${BUILDER_REPOSITORY_ROOT}/image/"

  git -C "$BUILDER_REPOSITORY_ROOT" init -q
  git -C "$BUILDER_REPOSITORY_ROOT" config user.name 'MirrorOS contract tests'
  git -C "$BUILDER_REPOSITORY_ROOT" config user.email 'mirroros-contract-tests@example.invalid'
  git -C "$BUILDER_REPOSITORY_ROOT" -c commit.gpgsign=false add -- operations image
  GIT_AUTHOR_NAME='MirrorOS contract tests' \
    GIT_AUTHOR_EMAIL='mirroros-contract-tests@example.invalid' \
    GIT_COMMITTER_NAME='MirrorOS contract tests' \
    GIT_COMMITTER_EMAIL='mirroros-contract-tests@example.invalid' \
    git -C "$BUILDER_REPOSITORY_ROOT" -c commit.gpgsign=false commit -qm 'test fixture'

  cat > "${BUILDER_DOUBLE_DIR}/docker" <<'EOF'
#!/usr/bin/bash
printf 'docker %s\n' "$*" >> "${BUILDER_CALL_LOG:?}"
state_path="${BUILDER_CALL_LOG%/*}/container.state"
if [[ "${1:-}" == 'info' ]]; then
  exit "${BUILDER_DOCKER_INFO_STATUS:-0}"
fi
if [[ "${1:-}" == 'pull' ]]; then
  exit "${BUILDER_DOCKER_PULL_STATUS:-0}"
fi
if [[ "${1:-}" == 'image' && "${2:-}" == 'inspect' ]]; then
  exit_status="${BUILDER_DOCKER_IMAGE_INSPECT_STATUS:-0}"
  if [[ "$exit_status" -ne 0 ]]; then exit "$exit_status"; fi
  if [[ "${BUILDER_DOCKER_SCENARIO:-}" == 'ambiguous-digest' ]]; then
    printf '%s@sha256:%064d\n%s@sha256:%064d\n' \
      'docker.io/archlinux/archlinux' 1 \
      'docker.io/archlinux/archlinux' 2
  elif [[ "${BUILDER_DOCKER_SCENARIO:-}" == 'unqualified-digest' ]]; then
    printf '%s@sha256:%064d\n' 'archlinux/archlinux' 1
  else
    printf '%s@sha256:%064d\n' 'docker.io/archlinux/archlinux' 1
  fi
  exit 0
fi
if [[ "${1:-}" == 'create' ]]; then
  exit_status="${BUILDER_DOCKER_CREATE_STATUS:-0}"
  if [[ "$exit_status" -ne 0 ]]; then exit "$exit_status"; fi
  printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > "$state_path"
  printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  exit 0
fi
if [[ "${1:-}" == 'start' ]]; then
  printf '%s\n' 'running' > "$state_path"
  printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  exit 0
fi
if [[ "${1:-}" == 'exec' ]]; then
  shift
  while [[ "${1:-}" == '--env' ]]; do shift 2; done
  container_id="${1:-}"
  shift || true
  command_name="${1:-}"
  shift || true
  if [[ "$command_name" == 'bash' ]]; then
    script=''
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == '-c' ]]; then
        shift
        script="${1:-}"
        break
      fi
      shift
    done
    if [[ "$script" == *'pacman -Syu'* ]]; then
      exit "${BUILDER_PACMAN_STATUS:-0}"
    fi
    if [[ "$script" == *'xorriso -osirrox'* ]]; then
      sleep "${BUILDER_DOCKER_EXTRACTION_DELAY:-0}"
      exit "${BUILDER_EXTRACTION_STATUS:-0}"
    fi
  fi
  if [[ "$command_name" == 'pacman' && "${1:-}" == '-Q' ]]; then
    if [[ "${BUILDER_DOCKER_SCENARIO:-}" == 'version-mismatch' ]]; then
      printf '%s\n' 'archiso 999-1'
    else
      printf '%s\n' 'archiso 91-1'
    fi
    exit 0
  fi
  if [[ "$command_name" == 'mkarchiso' ]]; then
    sleep "${BUILDER_DOCKER_BUILD_DELAY:-0}"
    exit "${BUILDER_MKARCHISO_STATUS:-0}"
  fi
  if [[ "$command_name" == 'find' ]]; then
    printf '%s\n' '/out/mirroros-test.iso'
    exit 0
  fi
  exit 0
fi
if [[ "${1:-}" == 'cp' ]]; then
  source_path="${2:-}"
  destination_path="${3:-}"
  if [[ "$source_path" == *'.iso' ]]; then
    printf '%s\n' 'synthetic ISO fixture' > "$destination_path"
  elif [[ "$source_path" == *'pkglist.x86_64.txt' ]]; then
    printf '%s\n' 'base 1-1' 'archiso 91-1' > "$destination_path"
  elif [[ "$source_path" == *'/mirrorlist' ]]; then
    printf '%s\n' 'Server = https://mirror.example.invalid/$repo/os/$arch' > "$destination_path"
  else
    exit 41
  fi
  chmod 600 -- "$destination_path"
  exit 0
fi
if [[ "${1:-}" == 'inspect' ]]; then
  if [[ "${2:-}" == '--format' ]]; then
    if [[ ! -f "$state_path" ]]; then exit 42; fi
    state="$(<"$state_path")"
    if [[ "${BUILDER_DOCKER_SCENARIO:-}" == 'stop-unverified' && "$state" == 'exited' ]]; then
      state='running'
    fi
    printf '%s\n' "$state"
    exit 0
  fi
fi
if [[ "${1:-}" == 'stop' ]]; then
  if [[ "${BUILDER_DOCKER_SCENARIO:-}" == 'stop-fails' ]]; then exit 43; fi
  sleep "${BUILDER_DOCKER_STOP_DELAY:-0}"
  printf '%s\n' 'exited' > "$state_path"
  printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  exit 0
fi
if [[ "${1:-}" == 'logs' ]]; then
  printf '%s\n' "${BUILDER_CONTAINER_LOG_CONTENT:-synthetic container diagnostics}"
  exit 0
fi
if [[ "${1:-}" == 'rm' ]]; then
  exit_status="${BUILDER_DOCKER_RM_STATUS:-0}"
  if [[ "$exit_status" -ne 0 ]]; then exit "$exit_status"; fi
  rm -f -- "$state_path"
  printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  exit 0
fi
exit "${BUILDER_DOCKER_STATUS:-0}"
EOF
  cat > "${BUILDER_DOUBLE_DIR}/cosign" <<'EOF'
#!/usr/bin/bash
printf 'cosign %s\n' "$*" >> "${BUILDER_CALL_LOG:?}"
exit "${BUILDER_COSIGN_STATUS:-0}"
EOF
  cat > "${BUILDER_DOUBLE_DIR}/gitleaks" <<'EOF'
#!/usr/bin/bash
printf 'gitleaks %s\n' "$*" >> "${BUILDER_CALL_LOG:?}"
if [[ "${BUILDER_GITLEAKS_REAL:-0}" == '1' ]]; then
  exec "${BUILDER_REAL_GITLEAKS:-/usr/bin/gitleaks}" "$@"
fi
report_path=''
scan_input=''
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '--report-path' ]]; then
    shift
    report_path="${1:-}"
  elif [[ "$1" != --* ]]; then
    scan_input="$1"
  fi
  shift
 done
if [[ "${BUILDER_GITLEAKS_CAPTURE_PENDING:-0}" == '1' && \
  "$report_path" == *gitleaks-publication.json && -f "${scan_input}/execution-result.json" ]]; then
  cp -- "${scan_input}/execution-result.json" "${BUILDER_CALL_LOG%/*}/prepublication-result.json"
fi
status="${BUILDER_GITLEAKS_STATUS:-0}"
if [[ -n "$report_path" && -n "${BUILDER_GITLEAKS_STATUS_SEQUENCE:-}" ]]; then
  count_path="${BUILDER_CALL_LOG%/*}/gitleaks.count"
  count=0
  [[ ! -f "$count_path" ]] || count="$(<"$count_path")"
  count=$((count + 1))
  printf '%s\n' "$count" > "$count_path"
  IFS=, read -r -a statuses <<< "$BUILDER_GITLEAKS_STATUS_SEQUENCE"
  if [[ "$count" -le "${#statuses[@]}" ]]; then
    status="${statuses[$((count - 1))]}"
  fi
fi
if [[ -n "$report_path" ]]; then
  if [[ "$status" -eq 0 ]]; then
    printf '[]\n' > "$report_path"
  elif [[ "$status" -eq 1 ]]; then
    printf '[{"Description":"redacted synthetic finding"}]\n' > "$report_path"
  fi
fi
exit "$status"
EOF
  cat > "${BUILDER_DOUBLE_DIR}/rm" <<'EOF'
#!/usr/bin/bash
if [[ "${BUILDER_RM_FAIL_WORKSPACE:-0}" == '1' && "${1:-}" == '-rf' ]]; then
  for argument in "${@:2}"; do
    if [[ "$argument" == */build/archiso/* ]]; then
      exit 47
    fi
  done
fi
exec /usr/bin/rm "$@"
EOF
  cat > "${BUILDER_DOUBLE_DIR}/mv" <<'EOF'
#!/usr/bin/bash
if [[ "${BUILDER_MV_STATUS:-0}" -ne 0 ]]; then
  exit "$BUILDER_MV_STATUS"
fi
exec /usr/bin/mv "$@"
EOF
  chmod 755 \
    "${BUILDER_DOUBLE_DIR}/docker" \
    "${BUILDER_DOUBLE_DIR}/cosign" \
    "${BUILDER_DOUBLE_DIR}/gitleaks" \
    "${BUILDER_DOUBLE_DIR}/rm" \
    "${BUILDER_DOUBLE_DIR}/mv"

  : > "$BUILDER_CALL_LOG"
  : > "${BUILDER_TEST_ROOT}/gitleaks.count"
  for tool_name in docker cosign gitleaks rm mv; do
    ln -s -- "${BUILDER_DOUBLE_DIR}/${tool_name}" "${BUILDER_FILTERED_PATH_DIR}/${tool_name}"
  done
  repository_path="$(command -v node)"
  ln -s -- "$repository_path" "${BUILDER_FILTERED_PATH_DIR}/node"
}

builder_teardown() {
  if [[ -n "${BUILDER_TEST_ROOT:-}" && -d "$BUILDER_TEST_ROOT" ]]; then
    chmod -R u+rwX -- "$BUILDER_TEST_ROOT"
    rm -rf -- "$BUILDER_TEST_ROOT"
  fi
}

builder_invoke() {
  local builder_path="${BUILDER_REPOSITORY_ROOT}/operations/build"

  : > "$BUILDER_CALL_LOG"
  : > "${BUILDER_TEST_ROOT}/gitleaks.count"
  if (
    cd -- "$BUILDER_OUTSIDE_DIR" || exit 125
    PATH="${BUILDER_DOUBLE_DIR}:${PATH}" \
      BUILDER_CALL_LOG="$BUILDER_CALL_LOG" \
      BUILDER_DOCKER_INFO_STATUS="${BUILDER_DOCKER_INFO_STATUS:-0}" \
      BUILDER_DOCKER_STATUS="${BUILDER_DOCKER_STATUS:-0}" \
      BUILDER_COSIGN_STATUS="${BUILDER_COSIGN_STATUS:-0}" \
      BUILDER_GITLEAKS_STATUS="${BUILDER_GITLEAKS_STATUS:-0}" \
      BUILDER_GITLEAKS_REAL="${BUILDER_GITLEAKS_REAL:-0}" \
      BUILDER_DOCKER_SCENARIO="${BUILDER_DOCKER_SCENARIO:-}" \
      BUILDER_DOCKER_PULL_STATUS="${BUILDER_DOCKER_PULL_STATUS:-0}" \
      BUILDER_DOCKER_IMAGE_INSPECT_STATUS="${BUILDER_DOCKER_IMAGE_INSPECT_STATUS:-0}" \
      BUILDER_DOCKER_CREATE_STATUS="${BUILDER_DOCKER_CREATE_STATUS:-0}" \
      BUILDER_DOCKER_RM_STATUS="${BUILDER_DOCKER_RM_STATUS:-0}" \
      BUILDER_DOCKER_STOP_DELAY="${BUILDER_DOCKER_STOP_DELAY:-0}" \
      BUILDER_DOCKER_BUILD_DELAY="${BUILDER_DOCKER_BUILD_DELAY:-0}" \
      BUILDER_DOCKER_EXTRACTION_DELAY="${BUILDER_DOCKER_EXTRACTION_DELAY:-0}" \
      BUILDER_PACMAN_STATUS="${BUILDER_PACMAN_STATUS:-0}" \
      BUILDER_MKARCHISO_STATUS="${BUILDER_MKARCHISO_STATUS:-0}" \
      BUILDER_EXTRACTION_STATUS="${BUILDER_EXTRACTION_STATUS:-0}" \
      "$builder_path" "$@"
  ) > "$BUILDER_STDOUT_PATH" 2> "$BUILDER_STDERR_PATH"; then
    BUILDER_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the Bats contract suites.
    BUILDER_COMMAND_STATUS=$?
  fi
}

builder_launch() {
  local builder_path="${BUILDER_REPOSITORY_ROOT}/operations/build"

  : > "$BUILDER_CALL_LOG"
  : > "${BUILDER_TEST_ROOT}/gitleaks.count"
  (
    cd -- "$BUILDER_OUTSIDE_DIR" || exit 125
    exec env \
      PATH="${BUILDER_DOUBLE_DIR}:${PATH}" \
      BUILDER_CALL_LOG="$BUILDER_CALL_LOG" \
      BUILDER_DOCKER_INFO_STATUS="${BUILDER_DOCKER_INFO_STATUS:-0}" \
      BUILDER_DOCKER_STATUS="${BUILDER_DOCKER_STATUS:-0}" \
      BUILDER_COSIGN_STATUS="${BUILDER_COSIGN_STATUS:-0}" \
      BUILDER_GITLEAKS_STATUS="${BUILDER_GITLEAKS_STATUS:-0}" \
      BUILDER_DOCKER_SCENARIO="${BUILDER_DOCKER_SCENARIO:-}" \
      BUILDER_DOCKER_PULL_STATUS="${BUILDER_DOCKER_PULL_STATUS:-0}" \
      BUILDER_DOCKER_IMAGE_INSPECT_STATUS="${BUILDER_DOCKER_IMAGE_INSPECT_STATUS:-0}" \
      BUILDER_DOCKER_CREATE_STATUS="${BUILDER_DOCKER_CREATE_STATUS:-0}" \
      BUILDER_DOCKER_RM_STATUS="${BUILDER_DOCKER_RM_STATUS:-0}" \
      BUILDER_DOCKER_STOP_DELAY="${BUILDER_DOCKER_STOP_DELAY:-0}" \
      BUILDER_DOCKER_BUILD_DELAY="${BUILDER_DOCKER_BUILD_DELAY:-0}" \
      BUILDER_DOCKER_EXTRACTION_DELAY="${BUILDER_DOCKER_EXTRACTION_DELAY:-0}" \
      BUILDER_PACMAN_STATUS="${BUILDER_PACMAN_STATUS:-0}" \
      BUILDER_MKARCHISO_STATUS="${BUILDER_MKARCHISO_STATUS:-0}" \
      BUILDER_EXTRACTION_STATUS="${BUILDER_EXTRACTION_STATUS:-0}" \
      "$builder_path" "$@"
  ) > "$BUILDER_STDOUT_PATH" 2> "$BUILDER_STDERR_PATH" &
  BUILDER_PROCESS_PID=$!
}

builder_wait() {
  if wait "$BUILDER_PROCESS_PID"; then
    BUILDER_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the Bats contract suites.
    BUILDER_COMMAND_STATUS=$?
  fi
}

builder_make_filtered_path() {
  local missing_tool="$1"
  local tool_path
  local tool_name
  local node_path

  rm -rf -- "$BUILDER_FILTERED_PATH_DIR"
  mkdir -p "$BUILDER_FILTERED_PATH_DIR"
  while IFS= read -r -d '' tool_path; do
    tool_name="${tool_path##*/}"
    [[ "$tool_name" == "$missing_tool" ]] && continue
    ln -s -- "$tool_path" "${BUILDER_FILTERED_PATH_DIR}/${tool_name}" 2>/dev/null || true
  done < <(find /usr/bin -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -print0)

  for tool_name in docker cosign gitleaks; do
    [[ "$tool_name" == "$missing_tool" ]] && continue
    ln -sf -- "${BUILDER_DOUBLE_DIR}/${tool_name}" "${BUILDER_FILTERED_PATH_DIR}/${tool_name}"
  done
  node_path="$(command -v node)"
  if [[ "$missing_tool" != 'node' ]]; then
    ln -sf -- "$node_path" "${BUILDER_FILTERED_PATH_DIR}/node"
  fi
  printf '%s' "$BUILDER_FILTERED_PATH_DIR" > "$BUILDER_PATH_FILE"
}

builder_run_module_function() {
  local module_path="$1"
  local function_name="$2"
  shift 2

  /usr/bin/bash -c '
    set -Eeuo pipefail
    source "$1"
    function_name="$2"
    shift 2
    "$function_name" "$@"
  ' _ "$module_path" "$function_name" "$@"
}

builder_capture_profile() {
  local destination_root="$1"
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/source-capture.sh"

  /usr/bin/bash -c '
    set -Eeuo pipefail
    source "$1"
    source_capture_profile "$2" "$3"
    printf "dirty=%s\ncommit=%s\nidentity=%s\nprofile=%s\n" \
      "$SOURCE_CAPTURE_DIRTY" \
      "$SOURCE_CAPTURE_COMMIT" \
      "$SOURCE_CAPTURE_PROFILE_IDENTITY" \
      "$SOURCE_CAPTURE_PROFILE_PATH"
    for path in "${SOURCE_CAPTURE_DIRTY_PATHS[@]}"; do
      printf "dirty_path=%s\n" "$path"
    done
  ' _ "$module_path" "$BUILDER_REPOSITORY_ROOT" "$destination_root"
}

builder_scan_profile() {
  local profile_path="$1"
  local report_path="$2"
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/source-capture.sh"

  BUILDER_CALL_LOG="$BUILDER_CALL_LOG" \
    BUILDER_GITLEAKS_REAL="${BUILDER_GITLEAKS_REAL:-0}" \
    PATH="${BUILDER_DOUBLE_DIR}:${PATH}" \
    /usr/bin/bash -c '
      set -Eeuo pipefail
      source "$1"
      source_capture_scan "$2" "$3"
    ' _ "$module_path" "$profile_path" "$report_path"
}
