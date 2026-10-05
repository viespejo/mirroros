load builder-support

setup() {
  builder_setup
}

teardown() {
  builder_teardown
}

@test "clean capture uses the committed profile tree and a private area" {
  local destination="${BUILDER_TEST_ROOT}/capture clean"
  local expected_identity
  local profile_path="${destination}/image/archiso"

  expected_identity="$(git -C "$BUILDER_REPOSITORY_ROOT" rev-parse HEAD:image/archiso)"
  run builder_capture_profile "$destination"
  [ "$status" -eq 0 ]
  [[ "$output" == *'dirty=0'* ]]
  [[ "$output" == *"identity=${expected_identity}"* ]]
  [[ "$output" == *"profile=${profile_path}"* ]]
  [ "$(stat -c '%a' "$destination")" = '700' ]
  cmp -s \
    "${BUILDER_REPOSITORY_ROOT}/image/archiso/profiledef.sh" \
    "${profile_path}/profiledef.sh"
  [ -L "${profile_path}/airootfs/etc/localtime" ]
  [ "$(readlink -- "${profile_path}/airootfs/etc/localtime")" = '/usr/share/zoneinfo/UTC' ]
}

@test "dirty capture includes tracked and untracked non-ignored profile paths" {
  local destination="${BUILDER_TEST_ROOT}/dirty capture"
  local added_path="${BUILDER_REPOSITORY_ROOT}/image/archiso/new profile file.txt"

  printf '%s\n' '# dirty profile fixture' >> "${BUILDER_REPOSITORY_ROOT}/image/archiso/profiledef.sh"
  printf '%s\n' 'included untracked profile input' > "$added_path"
  chmod 751 "$added_path"

  run builder_capture_profile "$destination"
  [ "$status" -eq 0 ]
  [[ "$output" == *'dirty=1'* ]]
  [[ "$output" == *'identity=dirty-path-list'* ]]
  [[ "$output" == *'dirty_path=image/archiso/profiledef.sh'* ]]
  [[ "$output" == *'dirty_path=image/archiso/new profile file.txt'* ]]
  cmp -s "$added_path" "${destination}/image/archiso/new profile file.txt"
  [ "$(stat -c '%a' "${destination}/image/archiso/new profile file.txt")" = '751' ]
}

@test "dirty repository state includes unrelated non-ignored changes" {
  local destination="${BUILDER_TEST_ROOT}/repository dirty capture"

  printf '%s\n' 'constructor-side change' > "${BUILDER_REPOSITORY_ROOT}/outside-profile.txt"
  run builder_capture_profile "$destination"
  [ "$status" -eq 0 ]
  [[ "$output" == *'dirty=1'* ]]
  [[ "$output" == *'identity=dirty-path-list'* ]]
  [[ "$output" != *'dirty_path='* ]]
  [ -f "${destination}/image/archiso/profiledef.sh" ]
}

@test "ignored profile files are excluded from clean capture" {
  local destination="${BUILDER_TEST_ROOT}/ignored capture"
  local ignored_path="${BUILDER_REPOSITORY_ROOT}/image/archiso/ignored profile file.txt"

  printf '%s\n' '/image/archiso/ignored profile file.txt' >> \
    "${BUILDER_REPOSITORY_ROOT}/.git/info/exclude"
  printf '%s\n' 'ignored fixture' > "$ignored_path"

  run builder_capture_profile "$destination"
  [ "$status" -eq 0 ]
  [[ "$output" == *'dirty=0'* ]]
  [ ! -e "${destination}/image/archiso/ignored profile file.txt" ]
}

@test "dirty capture preserves a literal symlink target and file mode with spaces" {
  local destination="${BUILDER_TEST_ROOT}/symlink capture"
  local link_path="${BUILDER_REPOSITORY_ROOT}/image/archiso/new link with spaces"
  local file_path="${BUILDER_REPOSITORY_ROOT}/image/archiso/new executable"
  local readonly_dir="${BUILDER_REPOSITORY_ROOT}/image/archiso/read only directory"

  ln -s -- 'literal target with spaces' "$link_path"
  printf '%s\n' 'executable fixture' > "$file_path"
  chmod 751 "$file_path"
  mkdir -- "$readonly_dir"
  printf '%s\n' 'first fixture' > "${readonly_dir}/first.txt"
  printf '%s\n' 'second fixture' > "${readonly_dir}/second.txt"
  chmod 555 "$readonly_dir"

  run builder_capture_profile "$destination"
  [ "$status" -eq 0 ]
  [ -L "${destination}/image/archiso/new link with spaces" ]
  [ "$(readlink -- "${destination}/image/archiso/new link with spaces")" = 'literal target with spaces' ]
  [ "$(stat -c '%a' "${destination}/image/archiso/new executable")" = '751' ]
  [ "$(stat -c '%a' "${destination}/image/archiso/read only directory")" = '555' ]
  [ -f "${destination}/image/archiso/read only directory/first.txt" ]
  [ -f "${destination}/image/archiso/read only directory/second.txt" ]
}

@test "tracked and ignored profile paths are rejected by name" {
  local destination="${BUILDER_TEST_ROOT}/tracked ignored capture"
  local tracked_path='image/archiso/profiledef.sh'

  printf '%s\n' '/image/archiso/profiledef.sh' >> \
    "${BUILDER_REPOSITORY_ROOT}/.git/info/exclude"
  run builder_capture_profile "$destination"
  [ "$status" -eq 2 ]
  [[ "$output" == *"tracked and ignored: ${tracked_path}"* ]]
  [ ! -e "$destination" ]
}

@test "Git submodules in the profile are rejected by path" {
  local destination="${BUILDER_TEST_ROOT}/submodule capture"
  local commit_id

  commit_id="$(git -C "$BUILDER_REPOSITORY_ROOT" rev-parse HEAD)"
  git -C "$BUILDER_REPOSITORY_ROOT" update-index --add --cacheinfo \
    "160000,${commit_id},image/archiso/submodule with spaces"

  run builder_capture_profile "$destination"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Git submodules are unsupported in the profile: image/archiso/submodule with spaces'* ]]
  [ ! -e "$destination" ]
}

@test "profile directories are supported entry types" {
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/source-capture.sh"

  run builder_run_module_function "$module_path" source_capture_check_entry_type \
    'image/archiso/nested directory' directory
  [ "$status" -eq 0 ]
}

@test "a FIFO in the profile is rejected by path before copying" {
  local destination="${BUILDER_TEST_ROOT}/fifo capture"
  local fifo_path="${BUILDER_REPOSITORY_ROOT}/image/archiso/fifo with spaces"

  mkfifo -- "$fifo_path"
  run builder_capture_profile "$destination"
  [ "$status" -eq 2 ]
  [[ "$output" == *'unsupported profile entry type (fifo): image/archiso/fifo with spaces'* ]]
  [ ! -e "$destination" ]
}

@test "devices sockets and FIFOs are rejected as unsupported entry types" {
  local module_path="${BUILDER_REPOSITORY_ROOT}/image/builder/lib/source-capture.sh"
  local entry_type

  for entry_type in 'block special file' 'character special file' socket fifo; do
    run builder_run_module_function "$module_path" source_capture_check_entry_type \
      'image/archiso/special entry with spaces' "$entry_type"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unsupported profile entry type (${entry_type}): image/archiso/special entry with spaces"* ]]
  done
}

@test "synthetic profile findings block construction before Docker container operations" {
  local synthetic='ghp_'
  local fragment
  local index
  local report_path

  for ((index = 0; index < 9; index++)); do
    printf -v fragment '%04x' "$RANDOM"
    synthetic+="$fragment"
  done
  printf 'token=%s\n' "$synthetic" > \
    "${BUILDER_REPOSITORY_ROOT}/image/archiso/synthetic-secret.txt"

  BUILDER_GITLEAKS_REAL=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 2 ]
  grep -Fq 'Gitleaks detected a secret in the captured profile' "$BUILDER_STDERR_PATH"
  [ "$(grep -c '^docker ' "$BUILDER_CALL_LOG")" -eq 1 ]
  grep -Fxq 'docker info' "$BUILDER_CALL_LOG"
  ! grep -Fq 'docker create' "$BUILDER_CALL_LOG"

  report_path="$(find "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build" -name 'gitleaks-profile.json' -print -quit)"
  [ -n "$report_path" ]
  [ -f "$report_path" ]
  [ "$(stat -c '%a' "$report_path")" = '600' ]
  ! grep -Fq -- "$synthetic" "$report_path"
  ! grep -Fq -- "$synthetic" "$BUILDER_STDOUT_PATH" "$BUILDER_STDERR_PATH"
}
