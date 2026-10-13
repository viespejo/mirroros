#!/usr/bin/env bats
# Read-only checker contract against a temporary target and native-command doubles; no real mount or disk.
load ../engine/support

setup() {
  engine_setup
  CHECKER="${CODE_ROOT}/install/postconditions/check"
  TARGET_ROOT="${RUN_ROOT}/target"
}

teardown() {
  engine_teardown
}

checker_run() {
  run env PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" "$CHECKER" "$@"
}

# Ignore access times: queries may read files, but must preserve contents, modes, ownership, and modification times.
target_snapshot() {
  find "$TARGET_ROOT" -printf '%P|%y|%m|%U|%G|%s|%T@|%l\n' | sort
  find "$TARGET_ROOT" -type f -exec sha256sum -- {} + | sort
}

@test "the checker reads only, leaves the target identical, and reports passed" {
  engine_use_plan ext4-systemd-boot--hibernation-disabled
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  # Restore only the double's mount observations after engine cleanup, not any real mount.
  printf '%s\t/dev/vda2\t\n%s\t/dev/vda1\tumask=0077\n' "$TARGET_ROOT" "${TARGET_ROOT}/boot" > "${DOUBLE_STATE}/mounts.log"
  target_snapshot > "${TEST_ROOT}/before"
  : > "${DOUBLE_STATE}/calls.log"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "passed"'* ]]
  target_snapshot > "${TEST_ROOT}/after"
  cmp "${TEST_ROOT}/before" "${TEST_ROOT}/after"
  ! grep -Ev '^(findmnt|blkid|pacman|systemctl|lsinitcpio) ' "${DOUBLE_STATE}/calls.log"
  grep -q '^pacman .* -Q$' "${DOUBLE_STATE}/calls.log"
  grep -q '^systemctl .* is-enabled NetworkManager.service$' "${DOUBLE_STATE}/calls.log"
  ! grep -q -- "$ENGINE_CANARY" <<< "$output"
}

@test "invalid arguments exit 2 without observing the target" {
  mkdir -p "$TARGET_ROOT"
  checker_run
  [ "$status" -eq 2 ]
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT" --unknown
  [ "$status" -eq 2 ]
  checker_run --plan "$PLAN" --digest invalid --target-root "$TARGET_ROOT"
  [ "$status" -eq 2 ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "invalid plans and a digest mismatch exit 2 before target inspection" {
  mkdir -p "$TARGET_ROOT"
  checker_run --plan "$PLAN" --digest "$(printf '%064d' 0)" --target-root "$TARGET_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *digest* ]]
  engine_use_invalid_plan plan_format_unsupported--version-3
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *regenerat* || "$output" == *Regenerat* ]]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}
