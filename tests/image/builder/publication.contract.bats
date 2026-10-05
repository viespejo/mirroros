load builder-support

setup() {
  builder_setup
}

teardown() {
  builder_teardown
}

builder_last_evidence_run() {
  find "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build" \
    -mindepth 1 -maxdepth 1 -type d -print | sort | tail -n 1
}

builder_last_result() {
  find "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build" \
    -mindepth 2 -maxdepth 2 -name execution-result.json -print | sort | tail -n 1
}

@test "successful build atomically publishes a private traceable bundle" {
  BUILDER_GITLEAKS_CAPTURE_PENDING=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]

  local evidence_run
  local run_id
  local bundle
  local result_path
  local file_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  bundle="${BUILDER_REPOSITORY_ROOT}/dist/${run_id}"
  result_path="$(builder_last_result)"

  [ -d "$bundle" ]
  [ "$(stat -c '%a' "$bundle")" = '700' ]
  [ -f "${bundle}/mirroros-test.iso" ]
  [ -f "${bundle}/SHA256SUMS" ]
  [ -f "${bundle}/artifact-metadata.json" ]
  [ -f "${bundle}/pkglist.x86_64.txt" ]
  grep -Fq '"outcome": "unknown"' "${BUILDER_TEST_ROOT}/prepublication-result.json"
  grep -Fq '"exit_status": null' "${BUILDER_TEST_ROOT}/prepublication-result.json"
  grep -Fq '"published": false' "${BUILDER_TEST_ROOT}/prepublication-result.json"
  grep -Fq '"outcome": "pending"' "${BUILDER_TEST_ROOT}/prepublication-result.json"
  [ "$(stat -c '%a' "${bundle}/mirroros-test.iso")" = '600' ]
  [ "$(stat -c '%a' "${bundle}/SHA256SUMS")" = '600' ]
  [ "$(stat -c '%a' "${bundle}/artifact-metadata.json")" = '600' ]
  [ "$(stat -c '%a' "${bundle}/pkglist.x86_64.txt")" = '600' ]
  (cd -- "$bundle" && sha256sum -c SHA256SUMS)
  grep -Fq '"secret_scan_scope": "mirroros-created-content"' "${bundle}/artifact-metadata.json"
  grep -Fq '"boot_qualification": "not_performed"' "${bundle}/artifact-metadata.json"
  grep -Fq '"pacman_conf": "image/archiso/pacman.conf"' "${bundle}/artifact-metadata.json"
  grep -Fq '"outcome": "success"' "$result_path"
  grep -Fq '"published": true' "$result_path"
  grep -Fq "published bundle at dist/${run_id}/" "$BUILDER_STDOUT_PATH"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/.tmp-${run_id}" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}" ]

  while IFS= read -r -d '' file_path; do
    [ "$(stat -c '%a' "$file_path")" = '600' ]
  done < <(find "$evidence_run" -type f -print0)
  while IFS= read -r -d '' file_path; do
    [ "$(stat -c '%a' "$file_path")" = '600' ]
  done < <(find "$bundle" -type f -print0)
  ! grep '^gitleaks dir ' "$BUILDER_CALL_LOG" | grep -Fq '.iso'
}

@test "atomic rename failure removes the candidate and leaves no partial run bundle" {
  BUILDER_MV_STATUS=49 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]

  local evidence_run
  local run_id
  local result_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  result_path="$(builder_last_result)"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/${run_id}" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/.tmp-${run_id}" ]
  grep -Fq '"failed_stage": "publication"' "$result_path"
  grep -Fq '"published": false' "$result_path"
  grep -Fq '"publication": 49' "$result_path"
}

@test "cleanup failure after publication keeps the immutable bundle and records failure" {
  BUILDER_RM_FAIL_WORKSPACE=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]

  local evidence_run
  local run_id
  local bundle
  local result_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  bundle="${BUILDER_REPOSITORY_ROOT}/dist/${run_id}"
  result_path="$(builder_last_result)"

  [ -d "$bundle" ]
  [ -d "${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}" ]
  (cd -- "$bundle" && sha256sum -c SHA256SUMS)
  grep -Fq '"failed_stage": "cleanup"' "$result_path"
  grep -Fq '"outcome": "failure"' "$result_path"
  grep -Fq '"published": true' "$result_path"
  grep -Fq '"outcome": "failure"' "$result_path"
  grep -Fq "bundle dist/${run_id}/ was published, but the run failed afterward" "$BUILDER_STDERR_PATH"
  ! grep -Fq "published bundle at dist/${run_id}/" "$BUILDER_STDOUT_PATH"
}
