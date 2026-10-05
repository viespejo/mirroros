REFERENCE_TEST_SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
REFERENCE_DOMAIN_TOOLS=(qemu-system-x86_64 qemu-img xorriso gitleaks sudo pkexec)

reference_setup() {
  local tool_name

  REFERENCE_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros reference vm.XXXXXX")"
  REFERENCE_REPOSITORY_ROOT="${REFERENCE_TEST_ROOT}/repository copy"
  REFERENCE_OUTSIDE_DIR="${REFERENCE_TEST_ROOT}/outside working directory"
  REFERENCE_DOUBLE_DIR="${REFERENCE_TEST_ROOT}/tool doubles"
  REFERENCE_FILTERED_PATH_DIR="${REFERENCE_TEST_ROOT}/filtered path"
  REFERENCE_BUNDLE_DIR="${REFERENCE_TEST_ROOT}/bundle with spaces"
  REFERENCE_CALL_LOG="${REFERENCE_TEST_ROOT}/tool calls.log"
  REFERENCE_STDOUT_PATH="${REFERENCE_TEST_ROOT}/stdout.log"
  REFERENCE_STDERR_PATH="${REFERENCE_TEST_ROOT}/stderr.log"

  mkdir -p \
    "$REFERENCE_REPOSITORY_ROOT" \
    "$REFERENCE_OUTSIDE_DIR" \
    "$REFERENCE_DOUBLE_DIR" \
    "$REFERENCE_FILTERED_PATH_DIR" \
    "$REFERENCE_BUNDLE_DIR"
  cp -a -- \
    "${REFERENCE_TEST_SOURCE_ROOT}/operations" \
    "${REFERENCE_TEST_SOURCE_ROOT}/vm" \
    "${REFERENCE_REPOSITORY_ROOT}/"
  : > "$REFERENCE_CALL_LOG"

  cat > "${REFERENCE_DOUBLE_DIR}/tool-double" <<'EOF'
#!/usr/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >> "${REFERENCE_CALL_LOG:?}"
if [[ "${0##*/}" == 'qemu-system-x86_64' ]]; then
  exit "${REFERENCE_QEMU_STATUS:-0}"
fi
exit 0
EOF
  chmod 755 "${REFERENCE_DOUBLE_DIR}/tool-double"
  for tool_name in "${REFERENCE_DOMAIN_TOOLS[@]}"; do
    ln -s -- tool-double "${REFERENCE_DOUBLE_DIR}/${tool_name}"
  done

  reference_make_bundle "$REFERENCE_BUNDLE_DIR"
}

reference_teardown() {
  if [[ -n "${REFERENCE_TEST_ROOT:-}" && -d "$REFERENCE_TEST_ROOT" ]]; then
    chmod -R u+rwX -- "$REFERENCE_TEST_ROOT"
    rm -rf -- "$REFERENCE_TEST_ROOT"
  fi
}

# Creates a small synthetic bundle that satisfies the Story 1.3 contract.
reference_make_bundle() {
  local directory="$1"
  local iso_content='iso-content'
  local manifest_content=$'pkg-a\npkg-b\n'
  local iso_sha
  local manifest_sha
  local metadata_sha

  printf '%s' "$iso_content" > "${directory}/test.iso"
  printf '%s' "$manifest_content" > "${directory}/pkglist.x86_64.txt"
  iso_sha="$(sha256sum "${directory}/test.iso")"
  iso_sha="${iso_sha%% *}"
  manifest_sha="$(sha256sum "${directory}/pkglist.x86_64.txt")"
  manifest_sha="${manifest_sha%% *}"
  printf '{"schema_version":1,"execution":{"run_id":"build-run","commit":"%s","dirty":false},"artifact":{"iso":{"name":"test.iso","size_bytes":%s,"sha256":"%s"},"package_manifest":{"name":"pkglist.x86_64.txt","sha256":"%s"}}}' \
    "$(printf 'a%.0s' {1..40})" "${#iso_content}" "$iso_sha" "$manifest_sha" \
    > "${directory}/artifact-metadata.json"
  metadata_sha="$(sha256sum "${directory}/artifact-metadata.json")"
  metadata_sha="${metadata_sha%% *}"
  printf '%s  test.iso\n%s  artifact-metadata.json\n%s  pkglist.x86_64.txt\n' \
    "$iso_sha" "$metadata_sha" "$manifest_sha" > "${directory}/SHA256SUMS"
}

reference_snapshot_bundle() {
  local directory="$1"

  (
    cd -- "$directory" || exit 125
    find . -printf '%p %y %m %s %T@\n' | LC_ALL=C sort
    find . -type f -exec sha256sum {} + | LC_ALL=C sort
  )
}

reference_invoke() {
  local command_path="${REFERENCE_REPOSITORY_ROOT}/operations/test"

  : > "$REFERENCE_CALL_LOG"
  if (
    cd -- "$REFERENCE_OUTSIDE_DIR" || exit 125
    PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" \
      REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
      REFERENCE_QEMU_STATUS="${REFERENCE_QEMU_STATUS:-0}" \
      "$command_path" "$@"
  ) > "$REFERENCE_STDOUT_PATH" 2> "$REFERENCE_STDERR_PATH"; then
    REFERENCE_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the Bats contract suites.
    REFERENCE_COMMAND_STATUS=$?
  fi
}

# Builds a PATH directory with the system tools, the doubles, and node, minus one tool.
reference_make_filtered_path() {
  local missing_tool="$1"
  local tool_path
  local tool_name
  local node_path

  rm -rf -- "$REFERENCE_FILTERED_PATH_DIR"
  mkdir -p "$REFERENCE_FILTERED_PATH_DIR"
  while IFS= read -r -d '' tool_path; do
    tool_name="${tool_path##*/}"
    [[ "$tool_name" == "$missing_tool" ]] && continue
    case "$tool_name" in
      qemu-system-x86_64 | qemu-img | xorriso | gitleaks | sudo | pkexec) continue ;;
    esac
    ln -s -- "$tool_path" "${REFERENCE_FILTERED_PATH_DIR}/${tool_name}" 2>/dev/null || true
  done < <(find /usr/bin -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -print0)

  for tool_name in qemu-system-x86_64 qemu-img xorriso gitleaks; do
    [[ "$tool_name" == "$missing_tool" ]] && continue
    ln -sf -- "${REFERENCE_DOUBLE_DIR}/${tool_name}" "${REFERENCE_FILTERED_PATH_DIR}/${tool_name}"
  done
  node_path="$(command -v node)"
  if [[ "$missing_tool" != 'node' ]]; then
    ln -sf -- "$node_path" "${REFERENCE_FILTERED_PATH_DIR}/node"
  fi
  # shellcheck disable=SC2034 # Read by the Bats contract suites.
  REFERENCE_FILTERED_PATH="$REFERENCE_FILTERED_PATH_DIR"
}

# Sources a module and evaluates a snippet that may use "$@" for its data.
reference_run_module() {
  local module_path="$1"
  local snippet="$2"
  shift 2

  /usr/bin/bash -c '
    set -Eeuo pipefail
    source "$1"
    snippet="$2"
    shift 2
    eval "$snippet"
  ' _ "$module_path" "$snippet" "$@"
}

# Replaces the generic doubles with doubles that emulate a guest session, for full-orchestrator runs.
# REFERENCE_QEMU_MODE: pass (default), fail (HTTPS check fails), hang (no report), exit (QEMU exits early).
# REFERENCE_GITLEAKS_FAIL_ON: a path fragment; scans whose target contains it exit REFERENCE_GITLEAKS_STATUS (default 1).
reference_install_e2e_doubles() {
  rm -f -- "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" \
    "${REFERENCE_DOUBLE_DIR}/gitleaks" "${REFERENCE_DOUBLE_DIR}/xorriso"

  cat > "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" <<'EOF'
#!/usr/bin/bash
printf 'qemu-system-x86_64 %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
if [[ "${1:-}" == '--version' ]]; then
  echo 'QEMU emulator version 9.9.9'
  exit 0
fi
serial=''
for argument in "$@"; do
  [[ "$argument" == '-S' ]] && exit 0
  [[ "$argument" == file:*guest-serial.log ]] && serial="${argument#file:}"
done
if [[ -n "${REFERENCE_QEMU_PID_FILE:-}" ]]; then printf '%s' "$$" > "$REFERENCE_QEMU_PID_FILE"; fi
run_id="$(basename "$(dirname "$serial")")"
printf 'SERIAL-NOISE-MARKER\r\n' >> "$serial"
case "${REFERENCE_QEMU_MODE:-pass}" in
  exit) exit 3 ;;
  hang) ;;
  pass | fail)
    https='"status":"passed","detail":"d","http_status":200,"tls_verified":true'
    result=passed
    if [[ "$REFERENCE_QEMU_MODE" == 'fail' ]]; then
      https='"status":"failed","detail":"d","http_status":null,"tls_verified":false'
      result=failed
    fi
    checks='"uefi_mode":{"status":"passed","detail":"ok"},"root_shell":{"status":"passed","detail":"ok"}'
    checks+=',"native_install_tools":{"status":"passed","detail":"ok"},"dns_resolution":{"status":"passed","detail":"ok"}'
    checks+=',"default_route":{"status":"passed","detail":"ok"}'
    checks+=',"ipv4_address":{"status":"passed","detail":"ok","address":"10.0.2.15"}'
    checks+=",\"https_request\":{${https}}"
    printf 'MIRROROS-REPORT-BEGIN %s\r\n{"schema_version":1,"run_id":"%s","checks":{%s},"result":"%s"}\r\nMIRROROS-REPORT-END %s\r\n' \
      "$run_id" "$run_id" "$checks" "$result" "$run_id" >> "$serial"
    ;;
esac
exec sleep 31
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/qemu-img" <<'EOF'
#!/usr/bin/bash
printf 'qemu-img %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
: > "$5"
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/gitleaks" <<'EOF'
#!/usr/bin/bash
printf 'gitleaks %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
target="${*: -1}"
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '--report-path' ]]; then printf '[]\n' > "$2"; fi
  shift
done
if [[ -n "${REFERENCE_GITLEAKS_FAIL_ON:-}" && "$target" == *"${REFERENCE_GITLEAKS_FAIL_ON}"* ]]; then
  exit "${REFERENCE_GITLEAKS_STATUS:-1}"
fi
exit 0
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/xorriso" <<'EOF'
#!/usr/bin/bash
printf 'xorriso %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '-output' ]]; then printf 'seed' > "$2"; fi
  shift
done
EOF
  chmod 755 "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" \
    "${REFERENCE_DOUBLE_DIR}/gitleaks" "${REFERENCE_DOUBLE_DIR}/xorriso"
}

# Turns the disposable repository copy into a committed Git checkout with fake firmware paths.
reference_prepare_e2e() {
  local firmware_dir="${REFERENCE_TEST_ROOT}/firmware"
  local preconditions="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib/preconditions.sh"

  mkdir -p "$firmware_dir"
  printf 'code' > "${firmware_dir}/OVMF_CODE.4m.fd"
  printf 'vars' > "${firmware_dir}/OVMF_VARS.4m.fd"
  sed -i \
    -e "s#^PRECONDITIONS_OVMF_CODE_PATH=.*#PRECONDITIONS_OVMF_CODE_PATH='${firmware_dir}/OVMF_CODE.4m.fd'#" \
    -e "s#^PRECONDITIONS_OVMF_VARS_PATH=.*#PRECONDITIONS_OVMF_VARS_PATH='${firmware_dir}/OVMF_VARS.4m.fd'#" \
    "$preconditions"
  printf 'build/\nevidence/\n' > "${REFERENCE_REPOSITORY_ROOT}/.gitignore"
  git -C "$REFERENCE_REPOSITORY_ROOT" init -q
  git -C "$REFERENCE_REPOSITORY_ROOT" add -A
  git -C "$REFERENCE_REPOSITORY_ROOT" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q -m fixture
  reference_install_e2e_doubles
}

# Arguments: signal name, seconds before the signal, then the operations/test arguments.
reference_invoke_signalled() {
  local signal_name="$1"
  local seconds="$2"
  local command_path="${REFERENCE_REPOSITORY_ROOT}/operations/test"

  shift 2
  : > "$REFERENCE_CALL_LOG"
  if (
    cd -- "$REFERENCE_OUTSIDE_DIR" || exit 125
    PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" \
      REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
      timeout --preserve-status --signal="$signal_name" "$seconds" "$command_path" "$@"
  ) > "$REFERENCE_STDOUT_PATH" 2> "$REFERENCE_STDERR_PATH"; then
    REFERENCE_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the Bats contract suites.
    REFERENCE_COMMAND_STATUS=$?
  fi
}

reference_e2e_evidence_dir() {
  local -a directories=("${REFERENCE_REPOSITORY_ROOT}"/evidence/reference-vm/*/)

  printf '%s' "${directories[0]%/}"
}

# Prints the value of a JavaScript expression over the parsed JSON file as variable r.
reference_json() {
  node -e 'const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); process.stdout.write(String(eval(process.argv[2])))' "$1" "$2"
}
