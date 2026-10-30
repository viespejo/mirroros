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

# shellcheck disable=SC2030 # Bats run assigns status/output in each isolated test.
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
  run grep -Ev '^(findmnt|blkid|pacman|systemctl|lsinitcpio) |^efibootmgr -v$' "${DOUBLE_STATE}/calls.log"
  [ "$status" -eq 1 ]
  grep -q '^pacman .* -Q$' "${DOUBLE_STATE}/calls.log"
  grep -q '^systemctl .* is-enabled NetworkManager.service$' "${DOUBLE_STATE}/calls.log"
  run grep -q -- "$ENGINE_CANARY" <<< "$output"
  [ "$status" -eq 1 ]
}

# shellcheck disable=SC2030,SC2031,SC2153 # Bats run sets status/output; OUTPUT is assigned by engine_setup in the sourced helper.
replacement_checker() {
  local calls_before
  engine_replacement_layout "$1"
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  # Reconstruct only the double's mount table; no real filesystem is mounted.
  node --input-type=module - "$PLAN" "$TARGET_ROOT" "${DOUBLE_STATE}/mounts.log" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const [file, target, output] = process.argv.slice(2);
const plan = JSON.parse(readFileSync(file));
const btrfs = plan.choices.storage_option.filesystem === 'btrfs';
const points = { '@': '', '@home': '/home', '@log': '/var/log', '@pkg': '/var/cache/pacman/pkg', '@snapshots': '/.snapshots', '@swap': '/swap' };
const options = plan.operations.find(op => op.kind === 'create_btrfs_subvolumes')?.parameters.mount_options;
const rows = btrfs ? plan.operations.find(op => op.kind === 'mount_target').parameters.subvolumes.map(name =>
  `${target}${points[name]}\t/dev/vda2\t${options},subvol=${name}`) : [`${target}\t/dev/vda2\t`];
rows.push(`${target}/boot\t/dev/vda1\tumask=0077`);
writeFileSync(output, `${rows.join('\n')}\n`);
JS
  target_snapshot > "${TEST_ROOT}/before"
  calls_before="$(wc -l < "${DOUBLE_STATE}/calls.log")"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT" \
    --untouched-partitions-before "${OUTPUT}/untouched-partitions-before.json"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
  [[ "$output" == *'"id": "untouched_partitions"'* ]]
  target_snapshot > "${TEST_ROOT}/after"
  cmp "${TEST_ROOT}/before" "${TEST_ROOT}/after"
  tail -n "+$((calls_before + 1))" "${DOUBLE_STATE}/calls.log" > "${TEST_ROOT}/checker-calls.log"
  run grep -Ev '^(findmnt|blkid|pacman|systemctl|lsinitcpio|lsattr) |^filefrag -v |^efibootmgr -v$|^sfdisk --dump /dev/|^lsblk --json --tree --bytes --output |^btrfs inspect-internal map-swapfile -r ' "${TEST_ROOT}/checker-calls.log"
  [ "$status" -eq 1 ] || { printf '%s\n' "$output"; return 1; }
  cp "${DOUBLE_STATE}/out/sfdisk" "${TEST_ROOT}/original-table"
  printf '# changed table metadata\n' >> "${DOUBLE_STATE}/out/sfdisk"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT" \
    --untouched-partitions-before "${OUTPUT}/untouched-partitions-before.json"
  [ "$status" -eq 4 ]
  [[ "$output" == *'differ from the pre-run record'* ]]
  cp "${TEST_ROOT}/original-table" "${DOUBLE_STATE}/out/sfdisk"
  printf '5\n' > "${DOUBLE_STATE}/fail.sfdisk"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT" \
    --untouched-partitions-before "${OUTPUT}/untouched-partitions-before.json"
  [ "$status" -eq 4 ]
  [[ "$output" == *'current partition table or disk identities cannot be read'* ]]
  rm "${DOUBLE_STATE}/fail.sfdisk"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT"
  [ "$status" -eq 4 ]
  [[ "$output" == *'pre-run partition record'* ]]
  printf '{}\n' > "${OUTPUT}/untouched-partitions-before.json"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT" \
    --untouched-partitions-before "${OUTPUT}/untouched-partitions-before.json"
  [ "$status" -eq 4 ]
  [[ "$output" == *'pre-run partition record is invalid'* ]]
}

@test "ext4 replacement independently observes preservation and remains read-only" {
  replacement_checker ext4-systemd-boot
}

@test "Btrfs systemd-boot replacement independently observes preservation and remains read-only" {
  replacement_checker btrfs-rescue
}

@test "Btrfs Limine replacement independently observes preservation and remains read-only" {
  replacement_checker btrfs-limine
}

@test "unreadable NVRAM and missing boot-first delivery fail without repair" {
  engine_use_plan ext4-systemd-boot--hibernation-disabled
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  printf '%s\t/dev/vda2\t\n%s\t/dev/vda1\tumask=0077\n' "$TARGET_ROOT" "${TARGET_ROOT}/boot" > "${DOUBLE_STATE}/mounts.log"
  printf '5\n' > "${DOUBLE_STATE}/fail.efibootmgr"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT"
  [ "$status" -eq 4 ]
  [[ "$output" == *'the UEFI entries cannot be read'* ]]
  rm "${DOUBLE_STATE}/fail.efibootmgr"
  rm "${TARGET_ROOT}/usr/local/lib/mirroros/operations/boot-first"
  target_snapshot > "${TEST_ROOT}/before"
  checker_run --plan "$PLAN" --digest "$DIGEST" --target-root "$TARGET_ROOT"
  [ "$status" -eq 4 ]
  [[ "$output" == *'boot_first_delivered'* ]]
  target_snapshot > "${TEST_ROOT}/after"
  cmp "${TEST_ROOT}/before" "${TEST_ROOT}/after"
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
