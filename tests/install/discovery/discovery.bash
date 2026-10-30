DISCOVERY_SUPPORT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DISCOVERY_SOURCE_ROOT="$(cd -- "${DISCOVERY_SUPPORT_DIR}/../../.." && pwd -P)"
DISCOVERY_FIXTURES="${DISCOVERY_SOURCE_ROOT}/tests/fixtures/discovery/raw"

DISCOVERY_PLANTED_VALUES=(
  'PLANTED-SSID-7f3a'
  'PLANTED-IWD-STATE'
  'PLANTED-DMI-SERIAL-0001'
  '00000000-0000-4000-8000-00000000dead'
  'PLANTED-BOARD-SERIAL-0001'
  'PLANTED-CHASSIS-SERIAL-0001'
  'PLANTED-BATTERY-SERIAL-0001'
  'aa:bb:cc:dd:ee:ff'
)

discovery_setup() {
  local tool_name

  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros discovery.XXXXXX")"
  CODE_ROOT="${TEST_ROOT}/embedded code"
  FIXTURE_ROOT="${TEST_ROOT}/fixture root"
  DOUBLE_STATE="${TEST_ROOT}/double state"
  DOUBLE_BIN="${TEST_ROOT}/double bin"
  WORK_DIR="${TEST_ROOT}/work directory"
  OUTPUT_DIR="${TEST_ROOT}/evidence output"
  STDOUT_PATH="${TEST_ROOT}/stdout.log"
  STDERR_PATH="${TEST_ROOT}/stderr.log"
  mkdir -p "$CODE_ROOT/operations/lib" "$FIXTURE_ROOT" "$DOUBLE_STATE" "$DOUBLE_BIN" "$WORK_DIR"

  # The embedded layout of the live medium: only the declared subtrees plus the identity file.
  cp -p "${DISCOVERY_SOURCE_ROOT}/operations/install" "${CODE_ROOT}/operations/install"
  cp -p "${DISCOVERY_SOURCE_ROOT}/operations/lib/lifecycle-discovery.sh" "${CODE_ROOT}/operations/lib/lifecycle-discovery.sh"
  cp -a "${DISCOVERY_SOURCE_ROOT}/install" "${CODE_ROOT}/install"
  mkdir -p "${CODE_ROOT}/hardware"
  cp -a "${DISCOVERY_SOURCE_ROOT}/hardware/discovery" "${CODE_ROOT}/hardware/discovery"
  cp -a "${DISCOVERY_SOURCE_ROOT}/targets" "${CODE_ROOT}/targets"
  printf '{\n  "commit": "%s",\n  "dirty": false\n}\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > "${CODE_ROOT}/identity.json"

  for tool_name in lsblk ip getent curl uname systemd-detect-virt bootctl; do
    ln -s "${DISCOVERY_SUPPORT_DIR}/doubles/${tool_name}" "${DOUBLE_BIN}/${tool_name}"
  done
  for tool_name in mount umount; do
    ln -s "${DISCOVERY_SUPPORT_DIR}/doubles/lsblk" "${DOUBLE_BIN}/${tool_name}"
  done
  for tool_name in sudo pkexec doas su; do
    ln -s "${DISCOVERY_SUPPORT_DIR}/doubles/elevation" "${DOUBLE_BIN}/${tool_name}"
  done
}

discovery_teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}

# Builds the fake system root and the double state from a raw fixture name, replacing any earlier one.
discovery_scenario() {
  find "$FIXTURE_ROOT" "$DOUBLE_STATE" -mindepth 1 -delete
  node "${DISCOVERY_SUPPORT_DIR}/build-root.mjs" "${DISCOVERY_FIXTURES}/${1}.json" "$FIXTURE_ROOT" "$DOUBLE_STATE"
}

discovery_root_manifest() {
  (
    cd -- "$FIXTURE_ROOT" || exit 1
    find . -printf '%p %y %m %s\n'
    find . -type f -exec sha256sum {} +
  ) | LC_ALL=C sort
}

discovery_run() {
  local before after

  : > "${DOUBLE_STATE}/calls.log"
  : > "${DOUBLE_STATE}/elevation.log"
  before="$(discovery_root_manifest)"
  if (
    cd -- "$WORK_DIR" || exit 125
    PATH="${DOUBLE_BIN}:${PATH}" \
      MIRROROS_DISCOVERY_ROOT="$FIXTURE_ROOT" \
      DOUBLE_STATE="$DOUBLE_STATE" \
      "${CODE_ROOT}/operations/install" discover "$@"
  ) > "$STDOUT_PATH" 2> "$STDERR_PATH"; then
    DISCOVERY_STATUS=0
  else
    DISCOVERY_STATUS=$?
  fi
  after="$(discovery_root_manifest)"

  # No discovery run may elevate privileges or change the inspected system.
  [[ ! -s "${DOUBLE_STATE}/elevation.log" ]] || { printf 'elevation invoked: %s\n' "$(< "${DOUBLE_STATE}/elevation.log")" >&2; return 1; }
  [[ "$before" == "$after" ]] || { printf '%s\n' 'the fixture system root changed' >&2; return 1; }
}

discovery_facts_path() {
  printf '%s/target-facts.json' "$OUTPUT_DIR"
}

# Evaluates a JavaScript expression against the parsed JSON file; "d" is the document.
discovery_json_assert() {
  node -e '
    const d = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    if (!eval(process.argv[2])) { console.error("assertion failed: " + process.argv[2]); process.exit(1); }
  ' "$1" "$2"
}

discovery_reason_codes_include() {
  discovery_json_assert "$(discovery_facts_path)" "d.validation.reasons.some(r => r.code === '$1')"
}

discovery_assert_no_planted_values() {
  local value

  for value in "${DISCOVERY_PLANTED_VALUES[@]}"; do
    if grep -rFq -- "$value" "$OUTPUT_DIR" "$STDOUT_PATH" "$STDERR_PATH"; then
      printf 'planted value leaked: %s\n' "$value" >&2
      return 1
    fi
  done
}

discovery_assert_private_permissions() {
  [[ -z "$(find "$OUTPUT_DIR" -type d ! -perm 700 -print -quit)" ]]
  [[ -z "$(find "$OUTPUT_DIR" -type f ! -perm 600 -print -quit)" ]]
}
