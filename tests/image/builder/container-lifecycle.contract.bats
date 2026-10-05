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

@test "build verifies one digest and creates an isolated labeled privileged container" {
  builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]
  grep -Fq 'cosign verify --certificate-identity-regexp' "$BUILDER_CALL_LOG"
  grep -Fq 'docker.io/archlinux/archlinux@sha256:' "$BUILDER_CALL_LOG"

  local create_call
  create_call="$(grep '^docker create ' "$BUILDER_CALL_LOG")"
  [[ "$create_call" == *'--privileged'* ]]
  [[ "$create_call" == *'--platform=linux/amd64'* ]]
  [[ "$create_call" == *'--name mirroros-archiso-build-'* ]]
  [[ "$create_call" == *'--label org.mirroros.stage=build'* ]]
  [[ "$create_call" == *'--label org.mirroros.run-id='* ]]
  [[ "$create_call" == *'target=/profile,readonly'* ]]
  [[ "$create_call" == *'source=mirroros-pacman-cache,target=/var/cache/pacman/pkg'* ]]
  [[ "$create_call" != *'--rm'* ]]
  [[ "$create_call" != *'--env'* ]]
  [[ "$create_call" != *'--env-file'* ]]
  [[ "$create_call" != *'--volume'* && "$create_call" != *' -v '* ]]
  ! grep -Fq 'docker volume rm' "$BUILDER_CALL_LOG"

  grep -Fq 'docker exec --env SOURCE_DATE_EPOCH=' "$BUILDER_CALL_LOG"
  grep -Fq 'mkarchiso -v -w /work -o /out /profile' "$BUILDER_CALL_LOG"
  grep -Fq 'xorriso -osirrox on' "$BUILDER_CALL_LOG"
  local preparation_line
  local version_line
  local evidence_run
  local file_path
  preparation_line="$(grep -n 'pacman -Syu --noconfirm' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  version_line="$(grep -n 'pacman -Q archiso' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  [ "$preparation_line" -lt "$version_line" ]
  evidence_run="$(builder_last_evidence_run)"
  [ "$(stat -c '%a' "$evidence_run")" = '700' ]
  [ "$(stat -c '%a' "${evidence_run}/logs")" = '700' ]
  while IFS= read -r -d '' file_path; do
    [ "$(stat -c '%a' "$file_path")" = '600' ]
  done < <(find "$evidence_run" -type f -print0)
  [ -s "${evidence_run}/container-identity.json" ]
  grep -Fq '"container_id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
    "$(builder_last_evidence_run)/container-identity.json"
  grep -Fq '"org.mirroros.stage": "build"' "$(builder_last_evidence_run)/container-identity.json"
  grep -Fxq 'docker rm aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$BUILDER_CALL_LOG"
  ! grep -Fq 'docker rm -f' "$BUILDER_CALL_LOG"
  [ "$(grep -c '^docker create ' "$BUILDER_CALL_LOG")" -eq 1 ]
}

@test "missing signature configuration is a damaged checkout before resource creation" {
  rm -- "${BUILDER_REPOSITORY_ROOT}/image/builder/arch-image-signature.conf"
  builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 6 ]
  grep -Fq 'signature configuration or Archiso upstream record is missing' "$BUILDER_STDERR_PATH"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/build" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/evidence" ]
  ! grep -Fq 'docker pull' "$BUILDER_CALL_LOG"
}

@test "no-cache omits the shared cache mount and does not remove the cache volume" {
  builder_invoke --no-cache
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]
  local create_call
  create_call="$(grep '^docker create ' "$BUILDER_CALL_LOG")"
  [[ "$create_call" != *'mirroros-pacman-cache'* ]]
  ! grep -Fq 'docker volume rm' "$BUILDER_CALL_LOG"
}

@test "ambiguous digest and failed Cosign verification stop before container creation" {
  BUILDER_DOCKER_SCENARIO=ambiguous-digest builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'expected exactly one' "$BUILDER_STDERR_PATH"
  ! grep -Fq 'docker create' "$BUILDER_CALL_LOG"
  ! grep -Fq 'cosign verify' "$BUILDER_CALL_LOG"

  BUILDER_COSIGN_STATUS=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'Cosign rejected the resolved Arch image digest' "$BUILDER_STDERR_PATH"
  ! grep -Fq 'docker create' "$BUILDER_CALL_LOG"
}

@test "build normalizes Docker's unqualified default-registry digest" {
  BUILDER_DOCKER_SCENARIO=unqualified-digest builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]

  local expected_digest
  local expected_reference
  local cosign_call
  local create_call
  printf -v expected_digest '%064d' 1
  expected_reference="docker.io/archlinux/archlinux@sha256:${expected_digest}"
  cosign_call="$(grep '^cosign verify ' "$BUILDER_CALL_LOG")"
  create_call="$(grep '^docker create ' "$BUILDER_CALL_LOG")"
  [[ "$cosign_call" == *"$expected_reference"* ]]
  [[ "$create_call" == *"$expected_reference"* ]]
}

@test "Archiso version mismatch blocks mkarchiso and identifies the update procedure" {
  BUILDER_DOCKER_SCENARIO=version-mismatch builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'does not match profile version' "$BUILDER_STDERR_PATH"
  grep -Fq 'docs/procedures/update-archiso.md' "$BUILDER_STDERR_PATH"
  ! grep -Fq 'docker exec --env SOURCE_DATE_EPOCH=' "$BUILDER_CALL_LOG"
  ! grep -Fq 'docker exec aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa mkarchiso' \
    "$BUILDER_CALL_LOG"
  [ ! -e "$(builder_last_evidence_run)/execution-result.json.tmp" ]
  grep -Fq '"failed_stage": "archiso-version"' "$(builder_last_result)"
}

@test "mkarchiso failure records its original status and exports diagnostics before removal" {
  BUILDER_MKARCHISO_STATUS=17 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  local evidence_run
  local result_path
  local logs_line
  local scan_line
  local remove_line
  evidence_run="$(builder_last_evidence_run)"
  result_path="$(builder_last_result)"
  grep -Fq '"failed_stage": "mkarchiso"' "$result_path"
  grep -Fq '"mkarchiso": 17' "$result_path"
  grep -Fq '"published": false' "$result_path"
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/$(basename "$evidence_run")" ]
  logs_line="$(grep -n '^docker logs ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  scan_line="$(grep -n 'gitleaks dir .*gitleaks-diagnostics.json' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  remove_line="$(grep -n '^docker rm ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  [ "$logs_line" -lt "$scan_line" ]
  [ "$scan_line" -lt "$remove_line" ]
  [ "$(stat -c '%a' "$result_path")" = '600' ]
}

@test "timed out mkarchiso preserves its timeout status and stops before removing the container" {
  BUILDER_MKARCHISO_STATUS=124 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  grep -Fq '"mkarchiso": 124' "$(builder_last_result)"
  local stop_line
  local stopped_state_line
  local remove_line
  stop_line="$(grep -n '^docker stop -t 30 ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  stopped_state_line="$(grep -n '^docker inspect --format {{.State.Status}}' "$BUILDER_CALL_LOG" | tail -n 1 | cut -d: -f1)"
  remove_line="$(grep -n '^docker rm ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  [ "$stop_line" -lt "$stopped_state_line" ]
  [ "$stopped_state_line" -lt "$remove_line" ]
}

@test "container removal failure is recorded without removing its run evidence" {
  BUILDER_DOCKER_RM_STATUS=41 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  local result_path
  local evidence_run
  result_path="$(builder_last_result)"
  evidence_run="$(builder_last_evidence_run)"
  grep -Fq '"failed_stage": "cleanup"' "$result_path"
  grep -Fq '"container-remove": 41' "$result_path"
  grep -Fq '"cleanup": {' "$result_path"
  grep -Fq '"outcome": "failure"' "$result_path"
  grep -Fq 'container:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$result_path"
  [ -f "${evidence_run}/container-identity.json" ]
  [ -f "${evidence_run}/run.lock" ]
  ! grep -Fq 'docker volume rm' "$BUILDER_CALL_LOG"
}

@test "failed stop or unverifiable stopped state retains the container and source workspace" {
  BUILDER_DOCKER_SCENARIO=stop-fails BUILDER_MKARCHISO_STATUS=17 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  local evidence_run
  local run_id
  local result_path
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  result_path="$(builder_last_result)"
  grep -Fq '"mkarchiso": 17' "$result_path"
  grep -Fq '"outcome": "failure"' "$result_path"
  grep -Fq 'container:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$result_path"
  ! grep -Fq 'docker rm ' "$BUILDER_CALL_LOG"
  [ -d "${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}" ]

  BUILDER_DOCKER_SCENARIO=stop-unverified BUILDER_MKARCHISO_STATUS=17 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  evidence_run="$(builder_last_evidence_run)"
  run_id="$(basename "$evidence_run")"
  ! grep -Fq 'docker rm ' "$BUILDER_CALL_LOG"
  [ -d "${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}" ]
}
