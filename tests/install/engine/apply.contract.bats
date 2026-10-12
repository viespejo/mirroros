load support

setup() {
  engine_setup
}

teardown() {
  if [[ -n "${ENGINE_BACKGROUND_PID:-}" ]]; then kill -KILL "$ENGINE_BACKGROUND_PID" 2> /dev/null || true; fi
  pkill -KILL -f "${TEST_ROOT:-/nonexistent}" 2> /dev/null || true
  engine_teardown
}

@test "an approved ext4 plan installs, records installed, and leaves nothing mounted" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(engine_json outcome)" = installed ]
  [ "$(engine_json exit_status)" = 0 ]
  [ "$(engine_json not_started)" = '[]' ]
  [ "$(engine_json completed | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0, "utf8")).length))')" = 17 ]
  [ "$(engine_json status state.json)" = installed ]
  [ "$(engine_json resolved.resume_offset)" = 34816 ]
  [ "$(engine_json mirrors.mirrorlist_sha256 | wc -c)" -eq 64 ]
  run engine_called umount
  [ "$status" -eq 0 ]
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
  grep -q '^base ' "${OUTPUT}/target-packages.txt"
}

@test "the boot entry carries the resolved root, resume parameters, and zswap off for hibernation" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  local entry="${RUN_ROOT}/target/boot/loader/entries/mirroros.conf"
  grep -qx 'options root=UUID=11111111-2222-4333-8444-555555555555 rw zswap.enabled=0 resume=UUID=11111111-2222-4333-8444-555555555555 resume_offset=34816' "$entry"
  grep -qx 'timeout 3' "${RUN_ROOT}/target/boot/loader/loader.conf"
  grep -qx 'editor no' "${RUN_ROOT}/target/boot/loader/loader.conf"
  [ -f "${RUN_ROOT}/target/boot/loader/entries/mirroros-fallback.conf" ]
}

@test "the records and the log are private and plain" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(stat -c %a "$OUTPUT")" = 700 ]
  for file in engine.log engine-run.json state.json target-packages.txt; do
    [ "$(stat -c %a "${OUTPUT}/${file}")" = 600 ]
  done
  ! grep -q $'\033' "${OUTPUT}/engine.log"
  grep -q '^== wipe_disk_signatures ==$' "${OUTPUT}/engine.log"
}

@test "commands that write the target run with umask 022 while the engine's own records stay private" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  # pacstrap creates /etc implicitly and arch-chroot tools create files in the target: neither may inherit 077.
  grep -q '^pacstrap 0022$' "${DOUBLE_STATE}/umask.log"
  grep -q '^arch-chroot 0022$' "${DOUBLE_STATE}/umask.log"
  ! grep -E '^(pacstrap|arch-chroot|genfstab) 0077$' "${DOUBLE_STATE}/umask.log"
  [ "$(stat -c %a "${RUN_ROOT}/target/boot")" = 755 ]
  [ "$(stat -c %a "${OUTPUT}/engine.log")" = 600 ]
}

@test "the destructive operations run in plan order after the disk was re-read" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(engine_call_line wipefs)" -lt "$(engine_call_line sfdisk)" ]
  [ "$(engine_call_line sfdisk)" -lt "$(engine_call_line mkfs.fat)" ]
  [ "$(engine_call_line mkfs.fat)" -lt "$(engine_call_line pacstrap)" ]
  [ "$(engine_call_line pacstrap)" -lt "$(engine_call_line genfstab)" ]
  grep -q 'size=2048MiB' "${DOUBLE_STATE}/sfdisk-input.log"
}

@test "the password reaches only the stdin of chpasswd, once for the user and once for root when planned" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(grep -c -- "$ENGINE_CANARY" "${DOUBLE_STATE}/chroot-stdin.log")" -eq 2 ]
  grep -qx "mirroros:${ENGINE_CANARY}" "${DOUBLE_STATE}/chroot-stdin.log"
  grep -qx "root:${ENGINE_CANARY}" "${DOUBLE_STATE}/chroot-stdin.log"
  ! grep -rq -- "$ENGINE_CANARY" "${DOUBLE_STATE}/calls.log" "${DOUBLE_STATE}/observed.log" "$OUTPUT" "${TEST_ROOT}/stdout.log" "${TEST_ROOT}/stderr.log"
}

@test "a locked root account is locked and receives no password" {
  engine_use_plan ext4-systemd-boot--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(grep -c -- "$ENGINE_CANARY" "${DOUBLE_STATE}/chroot-stdin.log")" -eq 1 ]
  ! grep -q "^root:${ENGINE_CANARY}" "${DOUBLE_STATE}/chroot-stdin.log"
  grep -q '^arch-chroot .* passwd -l root' "${DOUBLE_STATE}/calls.log"
}

@test "without hibernation there is no swapfile and no resume parameter" {
  engine_use_plan ext4-systemd-boot--hibernation-disabled
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  ! engine_called mkswap
  ! engine_called filefrag
  [ "$(engine_json resolved.resume_offset)" = undefined ]
}

@test "a digest other than the plan's is invalidated with the disk untouched" {
  DIGEST="$(printf 'f%.0s' {1..64})"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = invalidated ]
  [ "$(engine_json reasons.0.code)" = digest_mismatch ]
  engine_disk_untouched
}

@test "an edited plan, an unknown kind, and a different order are rejected before the password is read" {
  local name
  for name in digest_mismatch--edited-content operation_kind_unknown--format-disk operation_order_invalid--swapped; do
    rm -rf -- "$(dirname -- "$OUTPUT")"
    engine_use_invalid_plan "$name"
    ENGINE_PASSWORD=''
    engine_run
    [ "$ENGINE_STATUS" -eq 2 ]
    [ "$(engine_json reasons.0.code)" != password_unavailable ]
    engine_disk_untouched
  done
}

@test "a plan of another code identity is blocked as an engine version mismatch" {
  printf '{\n  "commit": "%s",\n  "dirty": false\n}\n' 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' > "${CODE_ROOT}/identity.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = blocked ]
  [ "$(engine_json reasons.0.code)" = engine_version_mismatch ]
  engine_disk_untouched
}

@test "a missing embedded identity is damaged code with exit 6" {
  rm -- "${CODE_ROOT}/identity.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 6 ]
  [ "$(engine_json outcome)" = failed ]
  engine_disk_untouched
}

@test "a keyring that is not ready is blocked without waiting" {
  : > "${DOUBLE_STATE}/keyring-not-ready"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = blocked ]
  [ "$(engine_json reasons.0.code)" = live_keyring_not_ready ]
  engine_disk_untouched
}

@test "an empty, multi-line, or missing password is blocked" {
  ENGINE_PASSWORD=''
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json reasons.0.code)" = password_unavailable ]
  engine_disk_untouched
  rm -rf -- "$(dirname -- "$OUTPUT")"
  ENGINE_PASSWORD=$'first\nsecond'
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json reasons.0.code)" = password_unavailable ]
  engine_disk_untouched
}

@test "the pre-check order is fixed: the keyring is reported before the password and the disk" {
  : > "${DOUBLE_STATE}/keyring-not-ready"
  ENGINE_PASSWORD=''
  printf '/dev/vda1 /somewhere ext4 rw 0 0\n' >> "${FIXTURE_ROOT}/proc/self/mounts"
  engine_run
  [ "$(engine_json reasons.0.code)" = live_keyring_not_ready ]
  rm -f -- "${DOUBLE_STATE}/keyring-not-ready"
  rm -rf -- "$(dirname -- "$OUTPUT")"
  engine_run
  [ "$(engine_json reasons.0.code)" = password_unavailable ]
  rm -rf -- "$(dirname -- "$OUTPUT")"
  ENGINE_PASSWORD="$ENGINE_CANARY"
  engine_run
  [ "$(engine_json reasons.0.code)" = target_disk_in_use ]
  engine_disk_untouched
}

@test "a disk whose identity changed after the review is invalidated and never wiped" {
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const document = JSON.parse(fs.readFileSync(file, "utf8"));
    document.blockdevices.find(device => device.path === "/dev/vda").serial = "REPLACED";
    fs.writeFileSync(file, JSON.stringify(document));
  ' "${DOUBLE_STATE}/lsblk.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = invalidated ]
  [ "$(engine_json reasons.0.code)" = target_identity_changed ]
  engine_disk_untouched
  ! grep -rq -- "$ENGINE_CANARY" "$OUTPUT"
}

@test "a disk whose layout changed after the review is invalidated and never wiped" {
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const document = JSON.parse(fs.readFileSync(file, "utf8"));
    document.blockdevices.find(device => device.path === "/dev/vda").children.pop();
    fs.writeFileSync(file, JSON.stringify(document));
  ' "${DOUBLE_STATE}/lsblk.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json reasons.0.code)" = target_layout_changed ]
  engine_disk_untouched
}

@test "a mounted partition, swap on the disk, or a holder blocks the run with the disk untouched" {
  printf '/dev/vda2 /mnt/other ext4 rw 0 0\n' >> "${FIXTURE_ROOT}/proc/self/mounts"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = blocked ]
  [ "$(engine_json reasons.0.code)" = target_disk_in_use ]
  engine_disk_untouched

  : > "${FIXTURE_ROOT}/proc/self/mounts"
  rm -rf -- "$(dirname -- "$OUTPUT")"
  printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/vda2 partition 1 0 -2\n' > "${FIXTURE_ROOT}/proc/swaps"
  engine_run
  [ "$(engine_json reasons.0.code)" = target_disk_in_use ]
  engine_disk_untouched

  rm -f -- "${FIXTURE_ROOT}/proc/swaps"
  rm -rf -- "$(dirname -- "$OUTPUT")"
  mkdir -p "${FIXTURE_ROOT}/sys/block/vda/vda2/holders/dm-0"
  engine_run
  [ "$(engine_json reasons.0.code)" = target_disk_in_use ]
  engine_disk_untouched
}

@test "a held installer lock makes the engine exit 2 on stderr only, with no directory and no mount touched" {
  flock -n "${RUN_ROOT}/install.lock" sleep 30 &
  ENGINE_BACKGROUND_PID=$!
  sleep 0.5
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  grep -q install_already_running "${TEST_ROOT}/stderr.log"
  [ ! -e "$(dirname -- "$OUTPUT")" ]
  [ ! -s "${TEST_ROOT}/stdout.log" ]
  ! engine_called umount
  engine_disk_untouched
}

@test "an inherited lock that another process holds is refused, and an inherited free lock is accepted" {
  flock -n "${RUN_ROOT}/install.lock" sleep 30 &
  ENGINE_BACKGROUND_PID=$!
  sleep 0.5
  ENGINE_STATUS=0
  PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" MIRROROS_DISCOVERY_ROOT="$FIXTURE_ROOT" MIRROROS_ENGINE_RUN_ROOT="$RUN_ROOT" \
    "${CODE_ROOT}/install/engine/apply" --plan "$PLAN" --digest "$DIGEST" --output "$OUTPUT" \
    3< <(printf '%s\n' "$ENGINE_PASSWORD") 4> "${RUN_ROOT}/install.lock" > /dev/null 2> "${TEST_ROOT}/stderr.log" || ENGINE_STATUS=$?
  [ "$ENGINE_STATUS" -eq 2 ]
  grep -q install_already_running "${TEST_ROOT}/stderr.log"
  kill -KILL "$ENGINE_BACKGROUND_PID" 2> /dev/null || true
  wait "$ENGINE_BACKGROUND_PID" 2> /dev/null || true
  ENGINE_BACKGROUND_PID=''
  ENGINE_STATUS=0
  PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" MIRROROS_DISCOVERY_ROOT="$FIXTURE_ROOT" MIRROROS_ENGINE_RUN_ROOT="$RUN_ROOT" \
    flock -n "${RUN_ROOT}/install.lock" "${CODE_ROOT}/install/engine/apply" --plan "$PLAN" --digest "$DIGEST" --output "$OUTPUT" \
    3< <(printf '%s\n' "$ENGINE_PASSWORD") > /dev/null 2> "${TEST_ROOT}/stderr.log" || ENGINE_STATUS=$?
  [ "$ENGINE_STATUS" -eq 0 ] || [ "$ENGINE_STATUS" -eq 1 ]
}

@test "the lock is released after success and after failure" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  flock -n "${RUN_ROOT}/install.lock" true
  rm -rf -- "$(dirname -- "$OUTPUT")"
  printf '7\n' > "${DOUBLE_STATE}/fail.pacstrap"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  flock -n "${RUN_ROOT}/install.lock" true
}

@test "a failing operation stops every later one, keeps the original status, and cleans up without wiping again" {
  printf '7\n' > "${DOUBLE_STATE}/fail.pacstrap"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json outcome)" = failed ]
  [ "$(engine_json reasons.0.code)" = stage_failed ]
  [ "$(engine_json failed_operation.id)" = install_packages ]
  [ "$(engine_json failed_operation.child_exit_status)" = 7 ]
  [ "$(engine_json reasons.0.child_exit_status)" = 7 ]
  ! engine_called genfstab
  ! engine_called mkswap
  [ "$(grep -c '^wipefs --all' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
  engine_called umount
  [ "$(engine_json cleanup.umount)" = ok ]
  [ "$(engine_json completed | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0, "utf8")).length))')" = 5 ]
  [ "$(engine_json operations.5.status state.json)" = failed ]
  grep -q 'pacstrap: simulated failure' "${OUTPUT}/engine.log"
  grep -qi 'status 7' "${TEST_ROOT}/stderr.log"
}

@test "an immediate-effect check that fails ends the run as a failed operation" {
  printf '1\n' > "${DOUBLE_STATE}/fail.arch-chroot.bootctl"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = install_bootloader ]
  [ ! -d "${DOUBLE_STATE}/enabled" ]
  [ "$(engine_json operations.16.status state.json)" = pending ]
}

@test "a configuration asset whose hash differs from the plan fails with exit 6 without being written" {
  printf '# changed\n' >> "${CODE_ROOT}/install/plan/assets/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf"
  engine_run
  [ "$ENGINE_STATUS" -eq 6 ]
  [ "$(engine_json reasons.0.code)" = engine_asset_mismatch ]
  [ "$(engine_json failed_operation.id)" = configure_zram ]
  ! engine_called mkswap
}

@test "a signal during the engine ends it as interrupted with 128+n and non-destructive cleanup" {
  : > "${DOUBLE_STATE}/pacstrap-hang"
  (
    PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" MIRROROS_DISCOVERY_ROOT="$FIXTURE_ROOT" MIRROROS_ENGINE_RUN_ROOT="$RUN_ROOT" \
      exec "${CODE_ROOT}/install/engine/apply" --plan "$PLAN" --digest "$DIGEST" --output "$OUTPUT" \
      3< <(printf '%s\n' "$ENGINE_PASSWORD") > /dev/null 2> "${TEST_ROOT}/stderr.log"
  ) &
  ENGINE_BACKGROUND_PID=$!
  for _ in $(seq 1 100); do
    [ -f "${DOUBLE_STATE}/pacstrap-started" ] && break
    /usr/bin/sleep 0.1
  done
  [ -f "${DOUBLE_STATE}/pacstrap-started" ]
  kill -TERM "$ENGINE_BACKGROUND_PID"
  ENGINE_STATUS=0
  wait "$ENGINE_BACKGROUND_PID" || ENGINE_STATUS=$?
  ENGINE_BACKGROUND_PID=''
  : > "${DOUBLE_STATE}/pacstrap-release"
  [ "$ENGINE_STATUS" -eq 143 ]
  [ "$(engine_json outcome)" = failed ]
  [ "$(engine_json reasons.0.code)" = engine_interrupted ]
  [ "$(engine_json exit_status)" = 143 ]
  engine_called umount
  [ "$(grep -c '^wipefs --all' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
}

@test "the engine never needs install/plan/policy.json" {
  rm -- "${CODE_ROOT}/install/plan/policy.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  ! grep -rq 'policy\.json' "${CODE_ROOT}/install/engine"
}

@test "the engine has no public command and rejects unknown or missing options on stderr" {
  run "${CODE_ROOT}/install/engine/apply" --bypass
  [ "$status" -eq 2 ]
  run "${CODE_ROOT}/install/engine/apply" --plan "$PLAN"
  [ "$status" -eq 2 ]
  run "${CODE_ROOT}/install/engine/apply" apply --plan "$PLAN" --digest "$DIGEST" --output "$OUTPUT"
  [ "$status" -eq 2 ]
  [ ! -e "$OUTPUT" ]
}

@test "btrfs and Limine plans are rejected in the pre-check naming the operation, with the disk untouched" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json reasons.0.code)" = stage_failed ]
  [ "$(engine_json reasons.0.operation)" = create_btrfs_subvolumes ]
  engine_disk_untouched
}
