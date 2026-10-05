load builder-support

setup() {
  builder_setup
}

teardown() {
  builder_teardown
}

@test "build help is side-effect free from outside the repository copy" {
  builder_invoke --help
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]
  grep -Fq 'Purpose:' "$BUILDER_STDOUT_PATH"
  grep -Fq 'Prerequisites:' "$BUILDER_STDOUT_PATH"
  grep -Fq 'Inputs:' "$BUILDER_STDOUT_PATH"
  grep -Fq 'Consequential effects:' "$BUILDER_STDOUT_PATH"
  grep -Fq 'Evidence:' "$BUILDER_STDOUT_PATH"
  grep -Fq 'Documentation: docs/procedures/build.md' "$BUILDER_STDOUT_PATH"
  [ ! -s "$BUILDER_STDERR_PATH" ]
  [ ! -s "$BUILDER_CALL_LOG" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/dist" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/evidence" ]
}

@test "unsupported and repeated invocation forms fail before files or Docker" {
  builder_invoke --unknown
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'unsupported argument(s)' "$BUILDER_STDERR_PATH"
  [ ! -s "$BUILDER_CALL_LOG" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/dist" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/evidence" ]

  builder_invoke --no-cache --no-cache
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'unsupported argument(s)' "$BUILDER_STDERR_PATH"
  [ ! -s "$BUILDER_CALL_LOG" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]

  builder_invoke --help extra
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'unsupported argument(s)' "$BUILDER_STDERR_PATH"
  [ ! -s "$BUILDER_CALL_LOG" ]
}

@test "Cosign identity settings match the official Arch Linux OCI README" {
  local config_path="${BUILDER_REPOSITORY_ROOT}/image/builder/arch-image-signature.conf"

  run /usr/bin/bash -c 'source "$1"; printf "%s\n%s\n" "$ARCH_CI_IDENTITY_REGEXP" "$ARCH_CI_ISSUER"' _ "$config_path"
  [ "$status" -eq 0 ]
  [[ "$output" == *'https://gitlab.archlinux.org'* ]]
  grep -Fxq "ARCH_CI_IDENTITY_REGEXP='https://gitlab\\.archlinux\\.org/archlinux/archlinux-docker//\\.gitlab-ci\\.yml@refs/tags/v[0-9]+\\.0\\.[0-9]+'" "$config_path"
  grep -Fxq "ARCH_CI_ISSUER='https://gitlab.archlinux.org'" "$config_path"
  grep -Fq 'https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md' "$config_path"
  grep -Fq 'Retrieved: 2026-10-05' "$config_path"
}

@test "root is rejected with normal-user Docker guidance" {
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/preconditions.sh"

  run builder_run_module_function "$module_path" preconditions_check_user 0
  [ "$status" -eq 2 ]
  [[ "$output" == *'do not run as root'*'normal user with direct Docker access'* ]]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]
  [ ! -s "$BUILDER_CALL_LOG" ]
}

@test "each missing prerequisite is identified before resource creation" {
  local tool_name
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/preconditions.sh"
  local filtered_path

  for tool_name in docker cosign gitleaks git node flock timeout; do
    builder_make_filtered_path "$tool_name"
    filtered_path="$(<"$BUILDER_PATH_FILE")"
    run env PATH="$filtered_path" /usr/bin/bash -c \
      'source "$1"; preconditions_check_tools' _ "$module_path"
    [ "$status" -eq 2 ]
    [[ "$output" == *"required tool is missing: ${tool_name}"* ]]
    [[ "$output" == *'Install it and retry'* ]]
  done

  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/dist" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/evidence" ]
}

@test "inaccessible Docker fails before run directories without remediation" {
  BUILDER_DOCKER_INFO_STATUS=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'Docker is unavailable to this user' "$BUILDER_STDERR_PATH"
  grep -Fq 'no sudo fallback or host remediation' "$BUILDER_STDERR_PATH"
  grep -Fxq 'docker info' "$BUILDER_CALL_LOG"
  [ "$(wc -l < "$BUILDER_CALL_LOG")" -eq 1 ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/build" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/dist" ]
  [ ! -e "$BUILDER_REPOSITORY_ROOT/evidence" ]
}

@test "run resources refuse symlinked build dist and evidence bases" {
  local run_id='20261005T120000Z-12345678-1234-1234-1234-123456789abc'
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/run-resources.sh"
  local base_name

  for base_name in build dist evidence; do
    ln -s -- "$BUILDER_OUTSIDE_DIR" "${BUILDER_REPOSITORY_ROOT}/${base_name}"
    run builder_run_module_function "$module_path" run_resources_prepare "$BUILDER_REPOSITORY_ROOT" "$run_id"
    [ "$status" -eq 2 ]
    [[ "$output" == *'refusing symlinked'*"${BUILDER_REPOSITORY_ROOT}/${base_name}"* ]]
    [ -L "${BUILDER_REPOSITORY_ROOT}/${base_name}" ]
    [ -z "$(find "$BUILDER_OUTSIDE_DIR" -mindepth 1 -print -quit)" ]
    rm -- "${BUILDER_REPOSITORY_ROOT}/${base_name}"
  done
}

@test "run resources refuse an existing reserved path without changing it" {
  local run_id='20261005T120000Z-12345678-1234-1234-1234-123456789abc'
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/run-resources.sh"
  local reserved_path="${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}"
  local marker_path="${reserved_path}/keep.txt"

  mkdir -p "$reserved_path"
  printf '%s\n' 'keep' > "$marker_path"
  chmod 640 "$marker_path"

  run builder_run_module_function "$module_path" run_resources_prepare "$BUILDER_REPOSITORY_ROOT" "$run_id"
  [ "$status" -eq 2 ]
  [[ "$output" == *"refusing existing reserved run path: ${reserved_path}"* ]]
  [ "$(<"$marker_path")" = 'keep' ]
  [ "$(stat -c '%a' "$marker_path")" = '640' ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build/${run_id}" ]
}

@test "run resources refuse existing distribution and evidence reservations unchanged" {
  local run_id='20261005T120000Z-12345678-1234-1234-1234-123456789abc'
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/run-resources.sh"
  local reserved_path
  local marker_path
  local destination_kind

  for destination_kind in dist evidence; do
    if [[ "$destination_kind" == 'dist' ]]; then
      reserved_path="${BUILDER_REPOSITORY_ROOT}/dist/${run_id}"
    else
      reserved_path="${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build/${run_id}"
    fi
    mkdir -p "$reserved_path"
    marker_path="${reserved_path}/keep.txt"
    printf '%s\n' 'keep' > "$marker_path"
    chmod 640 "$marker_path"

    run builder_run_module_function "$module_path" run_resources_prepare "$BUILDER_REPOSITORY_ROOT" "$run_id"
    [ "$status" -eq 2 ]
    [[ "$output" == *"refusing existing reserved run path: ${reserved_path}"* ]]
    [ "$(<"$marker_path")" = 'keep' ]
    [ "$(stat -c '%a' "$marker_path")" = '640' ]
    rm -rf -- "$reserved_path"
  done
}

@test "run resources create private directories and retain the run lock" {
  local run_id='20261005T120000Z-12345678-1234-1234-1234-123456789abc'
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/run-resources.sh"
  local build_path="${BUILDER_REPOSITORY_ROOT}/build/archiso/${run_id}"
  local evidence_path="${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build/${run_id}"

  run builder_run_module_function "$module_path" run_resources_prepare "$BUILDER_REPOSITORY_ROOT" "$run_id"
  [ "$status" -eq 0 ]
  [ "$(stat -c '%a' "$build_path")" = '700' ]
  [ "$(stat -c '%a' "$evidence_path")" = '700' ]
  [ "$(stat -c '%a' "${evidence_path}/run.lock")" = '600' ]
  [ -f "${evidence_path}/run.lock" ]
  [ ! -e "${BUILDER_REPOSITORY_ROOT}/dist/${run_id}" ]
}
