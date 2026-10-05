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

@test "secret finding in retained logs blocks publication and preserves redacted diagnostics" {
  local synthetic_value='synthetic-secret-value-for-test-only'
  BUILDER_CONTAINER_LOG_CONTENT="$synthetic_value" \
    BUILDER_GITLEAKS_STATUS_SEQUENCE='0,0,1,1,1' builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]

  local evidence_run
  local run_id
  local result_path
  local report_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  result_path="$(builder_last_result)"
  grep -Fq "$synthetic_value" "${evidence_run}/logs/container-logs.log"
  grep -Fq '"outcome": "failure"' "$result_path"
  grep -Fq '"published": false' "$result_path"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/${run_id}" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/.tmp-${run_id}" ]

  for report_path in \
    "${evidence_run}/gitleaks-publication.json" \
    "${evidence_run}/gitleaks-final-1.json" \
    "${evidence_run}/gitleaks-final-2.json"; do
    [ -f "$report_path" ]
    [ "$(stat -c '%a' "$report_path")" = '600' ]
    ! grep -Fq "$synthetic_value" "$report_path"
  done
  ! grep -Fq "$synthetic_value" "$result_path"
}

@test "Gitleaks execution failure keeps its original status and blocks publication" {
  BUILDER_GITLEAKS_STATUS_SEQUENCE='0,0,37' builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]

  local evidence_run
  local run_id
  local result_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  result_path="$(builder_last_result)"
  grep -Fq '"failed_stage": "publication-secret-scan"' "$result_path"
  grep -Fq '"publication-secret-scan": 37' "$result_path"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/${run_id}" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/.tmp-${run_id}" ]
}

@test "post-publication finding records failure without mutating the published bundle" {
  local synthetic_value='synthetic-late-secret-value-for-test-only'
  BUILDER_CONTAINER_LOG_CONTENT="$synthetic_value" \
    BUILDER_GITLEAKS_STATUS_SEQUENCE='0,0,0,1,1' builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]

  local evidence_run
  local run_id
  local bundle
  local result_path
  local before_hashes
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  bundle="${BUILDER_REPOSITORY_ROOT}/dist/${run_id}"
  result_path="$(builder_last_result)"
  [ -d "$bundle" ]
  grep -Fq '"failed_stage": "final-secret-scan"' "$result_path"
  grep -Fq '"published": true' "$result_path"
  grep -Fq '"outcome": "failure"' "$result_path"
  before_hashes="$(cd -- "$bundle" && sha256sum SHA256SUMS artifact-metadata.json pkglist.x86_64.txt mirroros-test.iso)"
  (cd -- "$bundle" && sha256sum -c SHA256SUMS)
  [ "$before_hashes" = "$(cd -- "$bundle" && sha256sum SHA256SUMS artifact-metadata.json pkglist.x86_64.txt mirroros-test.iso)" ]
  grep -Fq "bundle dist/${run_id}/ was published, but the run failed afterward" "$BUILDER_STDERR_PATH"
  ! grep -Fq "$synthetic_value" "${evidence_run}/gitleaks-final-1.json"
  ! grep -Fq "$synthetic_value" "${evidence_run}/gitleaks-final-2.json"
}
