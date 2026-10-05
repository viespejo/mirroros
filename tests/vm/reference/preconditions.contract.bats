load vm-support

setup() {
  reference_setup
  PRECONDITIONS_MODULE="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib/preconditions.sh"
}

teardown() {
  reference_teardown
}

assert_no_run_state() {
  [ ! -e "$REFERENCE_REPOSITORY_ROOT/build" ]
  [ ! -e "$REFERENCE_REPOSITORY_ROOT/evidence" ]
  [ ! -s "$REFERENCE_CALL_LOG" ]
}

@test "unsupported invocation forms exit 2 before files or domain tools" {
  local arguments

  for arguments in '--unknown' '-x' ''; do
    reference_invoke "$arguments"
    [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
    grep -Fq 'unsupported argument(s)' "$REFERENCE_STDERR_PATH"
    assert_no_run_state
  done

  reference_invoke "$REFERENCE_BUNDLE_DIR" extra
  [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'unsupported argument(s)' "$REFERENCE_STDERR_PATH"
  assert_no_run_state

  reference_invoke --help "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  assert_no_run_state
}

@test "relative bundle paths with spaces resolve against the caller working directory" {
  mkdir -p "${REFERENCE_TEST_ROOT}/caller dir/relative bundle"

  run reference_run_module "$PRECONDITIONS_MODULE" '
    cd -- "$1"
    preconditions_parse_arguments "relative bundle"
    printf "%s" "$QUALIFY_BUNDLE_DIR"
  ' "${REFERENCE_TEST_ROOT}/caller dir"
  [ "$status" -eq 0 ]
  [ "$output" == "${REFERENCE_TEST_ROOT}/caller dir/relative bundle" ]
}

@test "root domain execution is refused with normal-user guidance" {
  run reference_run_module "$PRECONDITIONS_MODULE" 'preconditions_check_user 0'
  [ "$status" -eq 2 ]
  [[ "$output" == *'do not run as root'* ]]
  assert_no_run_state
}

@test "each missing required tool is identified before resource creation" {
  local tool_name

  for tool_name in qemu-system-x86_64 qemu-img xorriso node gitleaks git timeout; do
    reference_make_filtered_path "$tool_name"
    run env PATH="$REFERENCE_FILTERED_PATH" /usr/bin/bash -c \
      'source "$1"; preconditions_check_tools' _ "$PRECONDITIONS_MODULE"
    [ "$status" -eq 2 ]
    [[ "$output" == *"required tool is missing: ${tool_name}"* ]]
    [[ "$output" == *'no host remediation is attempted'* ]]
    assert_no_run_state
  done
}

@test "a coherent bundle is admitted without modifying it" {
  local before
  local after

  before="$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")"
  run reference_run_module "$PRECONDITIONS_MODULE" '
    preconditions_admit_bundle "$1" "$2"
    printf "%s" "$QUALIFY_BUNDLE_ADMISSION"
  ' "$REFERENCE_BUNDLE_DIR" "${REFERENCE_REPOSITORY_ROOT}/vm/reference/bootstrap-documents.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"iso_name":"test.iso"'* ]]
  after="$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")"
  [ "$before" == "$after" ]
}

@test "inadmissible bundles exit 2 before any VM resource or tool" {
  local before
  local after
  local scenario

  for scenario in tampered-iso missing-checksums missing-manifest missing-metadata incoherent-metadata; do
    rm -rf -- "$REFERENCE_BUNDLE_DIR"
    mkdir -p "$REFERENCE_BUNDLE_DIR"
    reference_make_bundle "$REFERENCE_BUNDLE_DIR"
    case "$scenario" in
      tampered-iso) printf 'tampered' > "${REFERENCE_BUNDLE_DIR}/test.iso" ;;
      missing-checksums) rm -- "${REFERENCE_BUNDLE_DIR}/SHA256SUMS" ;;
      missing-manifest) rm -- "${REFERENCE_BUNDLE_DIR}/pkglist.x86_64.txt" ;;
      missing-metadata) rm -- "${REFERENCE_BUNDLE_DIR}/artifact-metadata.json" ;;
      incoherent-metadata) printf '{"schema_version":2}' > "${REFERENCE_BUNDLE_DIR}/artifact-metadata.json" ;;
    esac
    before="$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")"
    reference_invoke "$REFERENCE_BUNDLE_DIR"
    [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
    grep -Fq 'the bundle is not admissible' "$REFERENCE_STDERR_PATH"
    assert_no_run_state
    after="$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")"
    [ "$before" == "$after" ]
  done
}

@test "missing OVMF code or vars exits 2 with actionable guidance" {
  local firmware_dir="${REFERENCE_TEST_ROOT}/firmware"
  local missing

  mkdir -p "$firmware_dir"
  : > "${firmware_dir}/OVMF_CODE.fd"
  : > "${firmware_dir}/OVMF_VARS.fd"

  run reference_run_module "$PRECONDITIONS_MODULE" '
    PRECONDITIONS_OVMF_CODE_PATH="$1/OVMF_CODE.fd"
    PRECONDITIONS_OVMF_VARS_PATH="$1/OVMF_VARS.fd"
    preconditions_check_firmware
  ' "$firmware_dir"
  [ "$status" -eq 0 ]

  for missing in OVMF_CODE.fd OVMF_VARS.fd; do
    mv -- "${firmware_dir}/${missing}" "${firmware_dir}/${missing}.moved"
    run reference_run_module "$PRECONDITIONS_MODULE" '
      PRECONDITIONS_OVMF_CODE_PATH="$1/OVMF_CODE.fd"
      PRECONDITIONS_OVMF_VARS_PATH="$1/OVMF_VARS.fd"
      preconditions_check_firmware
    ' "$firmware_dir"
    [ "$status" -eq 2 ]
    [[ "$output" == *"OVMF firmware is missing or unreadable: ${firmware_dir}/${missing}"* ]]
    [[ "$output" == *'no host remediation is attempted'* ]]
    mv -- "${firmware_dir}/${missing}.moved" "${firmware_dir}/${missing}"
  done
}

@test "functional KVM probe uses only KVM acceleration and no remediation" {
  PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
    run reference_run_module "$PRECONDITIONS_MODULE" 'preconditions_check_kvm'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$REFERENCE_CALL_LOG")" -eq 1 ]
  grep -Fq 'accel=kvm' "$REFERENCE_CALL_LOG"
  ! grep -Eq 'tcg|sudo|pkexec' "$REFERENCE_CALL_LOG"
}

@test "non-functional KVM exits 2 without sudo, changes, or software emulation" {
  : > "$REFERENCE_CALL_LOG"
  PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
    REFERENCE_QEMU_STATUS=1 \
    run reference_run_module "$PRECONDITIONS_MODULE" 'preconditions_check_kvm'
  [ "$status" -eq 2 ]
  [[ "$output" == *'KVM is not functional'* ]]
  [[ "$output" == *'no sudo, group change, or software-emulation fallback is attempted'* ]]
  [ "$(wc -l < "$REFERENCE_CALL_LOG")" -eq 1 ]
  ! grep -Eq 'tcg|sudo|pkexec' "$REFERENCE_CALL_LOG"
  [ ! -e "$REFERENCE_REPOSITORY_ROOT/build" ]
}
