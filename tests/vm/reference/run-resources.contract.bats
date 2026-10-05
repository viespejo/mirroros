load vm-support

setup() {
  reference_setup
  RESOURCES_MODULE="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib/run-resources.sh"
  RESOURCES_ROOT="${REFERENCE_TEST_ROOT}/resource root"
  VALID_RUN_ID='20261005T120000Z-11111111-2222-4333-8444-555555555555'
  mkdir -p "$RESOURCES_ROOT"
}

teardown() {
  reference_teardown
}

@test "run IDs are UTC timestamp plus UUID and differ between calls" {
  run reference_run_module "$RESOURCES_MODULE" '
    run_resources_new_id
    first="$RUN_ID"
    run_resources_new_id
    printf "%s\n%s\n" "$first" "$RUN_ID"
  '
  [ "$status" -eq 0 ]
  mapfile -t ids <<< "$output"
  [[ "${ids[0]}" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  [[ "${ids[1]}" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  [ "${ids[0]}" != "${ids[1]}" ]
}

@test "preparation creates private build and evidence directories named by the run ID" {
  run reference_run_module "$RESOURCES_MODULE" '
    umask 077
    run_resources_prepare "$1" "$2"
    printf "%s\n%s\n%s\n" "$RUN_ID" "$BUILD_RUN_DIR" "$EVIDENCE_RUN_DIR"
  ' "$RESOURCES_ROOT" "$VALID_RUN_ID"
  [ "$status" -eq 0 ]
  mapfile -t lines <<< "$output"
  [ "${lines[0]}" == "$VALID_RUN_ID" ]
  [ "${lines[1]}" == "${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}" ]
  [ "${lines[2]}" == "${RESOURCES_ROOT}/evidence/reference-vm/${VALID_RUN_ID}" ]
  [ "$(stat -c '%a' "${lines[1]}")" == '700' ]
  [ "$(stat -c '%a' "${lines[2]}")" == '700' ]
  [ "$(stat -c '%a' "${RESOURCES_ROOT}/build/reference-vm")" == '700' ]
  [ "$(stat -c '%a' "${RESOURCES_ROOT}/evidence/reference-vm")" == '700' ]
}

@test "an invalid run ID is refused before anything is created" {
  run reference_run_module "$RESOURCES_MODULE" 'run_resources_prepare "$1" "not-a-run-id"' "$RESOURCES_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *'invalid run ID'* ]]
  [ ! -e "${RESOURCES_ROOT}/build" ]
  [ ! -e "${RESOURCES_ROOT}/evidence" ]
}

@test "an occupied reserved build run location is refused and left untouched" {
  mkdir -p "${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}"
  printf 'marker' > "${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}/marker"

  run reference_run_module "$RESOURCES_MODULE" 'run_resources_prepare "$1" "$2"' "$RESOURCES_ROOT" "$VALID_RUN_ID"
  [ "$status" -eq 2 ]
  [[ "$output" == *'refusing existing reserved run path'* ]]
  [ "$(<"${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}/marker")" == 'marker' ]
  [ ! -e "${RESOURCES_ROOT}/evidence" ]
}

@test "an occupied reserved evidence run location is refused and left untouched" {
  mkdir -p "${RESOURCES_ROOT}/evidence/reference-vm/${VALID_RUN_ID}"
  printf 'marker' > "${RESOURCES_ROOT}/evidence/reference-vm/${VALID_RUN_ID}/marker"

  run reference_run_module "$RESOURCES_MODULE" 'run_resources_prepare "$1" "$2"' "$RESOURCES_ROOT" "$VALID_RUN_ID"
  [ "$status" -eq 2 ]
  [[ "$output" == *'refusing existing reserved run path'* ]]
  [ "$(<"${RESOURCES_ROOT}/evidence/reference-vm/${VALID_RUN_ID}/marker")" == 'marker' ]
  [ ! -e "${RESOURCES_ROOT}/build" ]
}

@test "a symlinked output directory is refused without touching its target" {
  local layout

  for layout in build build/reference-vm evidence evidence/reference-vm; do
    rm -rf -- "$RESOURCES_ROOT" "${REFERENCE_TEST_ROOT}/link target"
    mkdir -p "$RESOURCES_ROOT" "${REFERENCE_TEST_ROOT}/link target"
    mkdir -p "$(dirname -- "${RESOURCES_ROOT}/${layout}")"
    ln -s -- "${REFERENCE_TEST_ROOT}/link target" "${RESOURCES_ROOT}/${layout}"

    run reference_run_module "$RESOURCES_MODULE" 'run_resources_prepare "$1" "$2"' "$RESOURCES_ROOT" "$VALID_RUN_ID"
    [ "$status" -eq 2 ]
    [[ "$output" == *'refusing symlinked'* ]]
    [ -z "$(ls -A -- "${REFERENCE_TEST_ROOT}/link target")" ]
    [ ! -e "${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}" ]
    [ ! -e "${RESOURCES_ROOT}/evidence/reference-vm/${VALID_RUN_ID}" ]
  done
}

@test "a non-directory output base is refused" {
  : > "${RESOURCES_ROOT}/build"

  run reference_run_module "$RESOURCES_MODULE" 'run_resources_prepare "$1" "$2"' "$RESOURCES_ROOT" "$VALID_RUN_ID"
  [ "$status" -eq 2 ]
  [[ "$output" == *'refusing non-directory'* ]]
  [ ! -e "${RESOURCES_ROOT}/evidence" ]
}

@test "earlier runs are neither recovered, reused, nor deleted" {
  local earlier='20260101T000000Z-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'

  mkdir -p "${RESOURCES_ROOT}/build/reference-vm/${earlier}" "${RESOURCES_ROOT}/evidence/reference-vm/${earlier}"
  printf 'old' > "${RESOURCES_ROOT}/build/reference-vm/${earlier}/disk.qcow2"
  printf 'old' > "${RESOURCES_ROOT}/evidence/reference-vm/${earlier}/result.json"

  run reference_run_module "$RESOURCES_MODULE" 'umask 077; run_resources_prepare "$1" "$2"' "$RESOURCES_ROOT" "$VALID_RUN_ID"
  [ "$status" -eq 0 ]
  [ "$(<"${RESOURCES_ROOT}/build/reference-vm/${earlier}/disk.qcow2")" == 'old' ]
  [ "$(<"${RESOURCES_ROOT}/evidence/reference-vm/${earlier}/result.json")" == 'old' ]
  [ -z "$(ls -A -- "${RESOURCES_ROOT}/build/reference-vm/${VALID_RUN_ID}")" ]
}
