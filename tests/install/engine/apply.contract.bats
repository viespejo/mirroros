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

@test "a missing kernel withholds completion with exit 4, names the check, and cleans up" {
  : > "${DOUBLE_STATE}/postconditions-missing-kernel"
  engine_run
  [ "$ENGINE_STATUS" -eq 4 ]
  [ "$(engine_json outcome)" = not_verified ]
  [ "$(engine_json postconditions.failed_checks)" = '["kernel_installed"]' ]
  [ "$(engine_json reasons.0.code)" = postcondition_failed ]
  [[ "$(engine_json reasons.0.message)" == *'/boot/vmlinuz-linux is missing'* ]]
  grep -q 'kernel_installed' "${TEST_ROOT}/stderr.log"
  [ "$(engine_json not_started)" = '[]' ]
  [ "$(engine_json status state.json)" = not_verified ]
  [ "$(engine_json cleanup.umount)" = ok ]
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
  ! grep -rq -- "$ENGINE_CANARY" "$OUTPUT" "${TEST_ROOT}/stdout.log" "${TEST_ROOT}/stderr.log"
}

@test "missing microcode in the initramfs yields not_verified rather than success or failed" {
  : > "${DOUBLE_STATE}/initramfs-no-microcode"
  engine_run
  [ "$ENGINE_STATUS" -eq 4 ]
  [ "$(engine_json postconditions.failed_checks)" = '["microcode_selection"]' ]
  [ "$(engine_json cleanup.umount)" = ok ]
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
}

@test "an invalid checker result or internal checker failure ends failed with exit 5 and cleanup" {
  local body
  for body in 'printf "not-json\\n"; exit 4' 'printf "{}\\n"; exit 0' 'exit 6'; do
    engine_teardown
    engine_setup
    printf '#!/usr/bin/bash\n%s\n' "$body" > "${CODE_ROOT}/install/postconditions/check"
    engine_run
    [ "$ENGINE_STATUS" -eq 5 ]
    [ "$(engine_json outcome)" = failed ]
    [ "$(engine_json reasons.0.code)" = stage_failed ]
    [ "$(engine_json failed_operation.id)" = postconditions ]
    [ "$(engine_json postconditions)" = undefined ]
    [ "$(engine_json cleanup.umount)" = ok ]
    [ ! -s "${DOUBLE_STATE}/mounted.list" ]
    ! grep -rq -- "$ENGINE_CANARY" "$OUTPUT"
    rm -rf -- "$OUTPUT"
  done
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

@test "the planned fallback is generated explicitly with a persistent Linux preset" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ -s "${RUN_ROOT}/target/boot/initramfs-linux-fallback.img" ]
  grep -qx 'PRESETS=("default" "fallback")' "${RUN_ROOT}/target/etc/mkinitcpio.d/linux.preset"
  grep -qx 'fallback_image="/boot/initramfs-linux-fallback.img"' "${RUN_ROOT}/target/etc/mkinitcpio.d/linux.preset"
  grep -qx 'fallback_options="-S autodetect"' "${RUN_ROOT}/target/etc/mkinitcpio.d/linux.preset"
  [ "$(engine_json postconditions.status)" = passed ]
}

@test "fallback generation failure stops the bootloader operation and cleans up" {
  : > "${DOUBLE_STATE}/mkinitcpio-fail"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json outcome)" = failed ]
  [ "$(engine_json failed_operation.id)" = install_bootloader ]
  [ "$(engine_json cleanup.umount)" = ok ]
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
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

@test "pacstrap receives the plan's packages followed by its rule packages in one transaction" {
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(grep -c '^pacstrap ' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
  grep -q '^pacstrap -K .* networkmanager amd-ucode$' "${DOUBLE_STATE}/calls.log"
}

@test "a plan without rule packages installs only its own packages" {
  local unmatched="${TEST_ROOT}/no-rule-packages.json"
  node --input-type=module - "$PLAN" "$unmatched" "$ENGINE_SOURCE_ROOT" << 'SCRIPT'
import { readFileSync, writeFileSync } from 'node:fs';
const [, , source, destination, root] = process.argv;
const { withDigest } = await import(`${root}/install/plan/digest-plan.mjs`);
const plan = JSON.parse(readFileSync(source, 'utf8'));
plan.hardware_selections.rule_outcomes[1].value = 'CentaurHauls';
plan.hardware_selections.rule_outcomes[1].outcome = 'vendor_not_recognized';
plan.hardware_selections.rule_packages = [];
plan.operations.find(operation => operation.kind === 'install_packages').parameters.rule_packages = [];
plan.warnings.push({
  code: 'cpu_vendor_unknown',
  message: 'The CPU vendor is not AuthenticAMD or GenuineIntel, or was not detected; no microcode package is installed.',
  next_step: 'You may install the microcode package of your CPU vendor after installation.',
});
writeFileSync(destination, `${JSON.stringify(withDigest(plan), null, 2)}\n`);
SCRIPT
  PLAN="$unmatched"
  DIGEST="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).digest.value)' "$PLAN")"
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(grep -c '^pacstrap ' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
  ! grep '^pacstrap ' "${DOUBLE_STATE}/calls.log" | grep -q 'ucode'
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

@test "an approved btrfs-limine plan installs the Limine tools, the baseline, and the snapshot entries" {
  engine_use_plan btrfs-limine--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(engine_json outcome)" = installed ]
  [ "$(engine_json not_started)" = '[]' ]
  [ "$(engine_json constants.sync_limine_snapshot_entries.baseline_snapshot)" = 1 ]
  [ ! -e "${RUN_ROOT}/target/var/tmp/mirroros-packages" ]
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
  grep -q 'systemctl enable limine-snapper-sync.service$' "${DOUBLE_STATE}/calls.log"
}

@test "btrfs-limine writes only the Limine defaults file with the planned command line and rootflags" {
  engine_use_plan btrfs-limine--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  local defaults="${RUN_ROOT}/target/etc/default/limine"
  grep -qx 'ESP_PATH="/boot"' "$defaults"
  grep -qx 'SKIP_UEFI=yes' "$defaults"
  grep -q '^KERNEL_CMDLINE\[default\]="root=UUID=11111111-2222-4333-8444-555555555555 rw zswap.enabled=0 resume=UUID=11111111-2222-4333-8444-555555555555 resume_offset=1998848 rootflags=subvol=@"$' "$defaults"
  ! engine_called bootctl
  ! grep -q '^arch-chroot .* \(limine-update\|limine-deploy\|efibootmgr\|limine\)\( \|$\)' "${DOUBLE_STATE}/calls.log"
}

@test "btrfs-limine carries resume parameters only when hibernation is planned" {
  engine_use_plan btrfs-limine--hibernation-disabled
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  ! grep -q 'resume' "${RUN_ROOT}/target/etc/default/limine"
  ! grep -q 'resume' "${RUN_ROOT}/target/boot/limine.conf"
  grep -q 'rootflags=subvol=@' "${RUN_ROOT}/target/boot/limine.conf"
  ! grep -q '@swap' "${DOUBLE_STATE}/calls.log"
}

@test "no Limine or snapshot tool runs before the package transaction installs it" {
  engine_use_plan btrfs-limine--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  local install_line sync_line baseline_line
  install_line="$(grep -n -m1 'pacman -U' "${DOUBLE_STATE}/calls.log" | cut -d: -f1)"
  sync_line="$(grep -n -m1 'target limine-snapper-sync$' "${DOUBLE_STATE}/calls.log" | cut -d: -f1)"
  baseline_line="$(grep -n -m1 'snapper --no-dbus -c root create --type single' "${DOUBLE_STATE}/calls.log" | cut -d: -f1)"
  [ -n "$install_line" ] && [ -n "$sync_line" ] && [ -n "$baseline_line" ]
  [ "$install_line" -lt "$baseline_line" ]
  [ "$baseline_line" -lt "$sync_line" ]
  [ "$(grep -c 'limine-snapper-sync$' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
  [ -s "${RUN_ROOT}/target/etc/mkinitcpio.conf.d/10-mirroros-limine.conf" ]
  grep -q 'sd-btrfs-overlayfs' "${RUN_ROOT}/target/etc/mkinitcpio.conf.d/10-mirroros-limine.conf"
}

@test "a Limine package whose hash differs from the manifest fails with exit 6 and installs nothing" {
  engine_use_plan btrfs-limine--locked
  printf 'tampered\n' >> "${CODE_ROOT}/packages/limine-snapper-sync-1.0-1-any.pkg.tar.zst"
  engine_run
  [ "$ENGINE_STATUS" -eq 6 ]
  [ "$(engine_json reasons.0.code)" = engine_asset_mismatch ]
  [ "$(engine_json failed_operation.id)" = install_limine_snapshot_tools ]
  ! grep -q 'pacman -U' "${DOUBLE_STATE}/calls.log"
  [ ! -e "${DOUBLE_STATE}/limine-installed" ]
}

@test "a missing Limine manifest fails with exit 6 before any package is installed" {
  engine_use_plan btrfs-limine--locked
  rm -- "${CODE_ROOT}/packages/packages.json"
  engine_run
  [ "$ENGINE_STATUS" -eq 6 ]
  [ "$(engine_json reasons.0.code)" = engine_asset_mismatch ]
  ! grep -q 'pacman -U' "${DOUBLE_STATE}/calls.log"
}

@test "a missing fallback EFI binary, kernel file, or normal entry fails install_limine_snapshot_tools" {
  engine_use_plan btrfs-limine--locked
  for switch in limine-no-efi limine-missing-kernel limine-no-entry limine-uki; do
    rm -rf -- "$RUN_ROOT" "$OUTPUT"
    mkdir -p "$RUN_ROOT"
    : > "${DOUBLE_STATE}/calls.log"
    : > "${DOUBLE_STATE}/${switch}"
    engine_run
    [ "$ENGINE_STATUS" -eq 5 ]
    [ "$(engine_json reasons.0.code)" = stage_failed ]
    [ "$(engine_json failed_operation.id)" = install_limine_snapshot_tools ]
    ! grep -q 'limine-snapper-sync$' "${DOUBLE_STATE}/calls.log"
    rm -f -- "${DOUBLE_STATE}/${switch}"
  done
}

@test "a Limine timeout that differs from the plan fails install_limine_snapshot_tools" {
  engine_use_plan btrfs-limine--locked
  printf '9\n' > "${DOUBLE_STATE}/limine-timeout"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = install_limine_snapshot_tools ]
}

@test "a missing snapshot entry or snapshot file fails sync_limine_snapshot_entries" {
  engine_use_plan btrfs-limine--locked
  for switch in limine-no-snapshot-entry limine-missing-snapshot-file; do
    rm -rf -- "$RUN_ROOT" "$OUTPUT"
    mkdir -p "$RUN_ROOT"
    : > "${DOUBLE_STATE}/calls.log"
    rm -f -- "${DOUBLE_STATE}/snapshots.list"
    : > "${DOUBLE_STATE}/${switch}"
    engine_run
    [ "$ENGINE_STATUS" -eq 5 ]
    [ "$(engine_json failed_operation.id)" = sync_limine_snapshot_entries ]
    rm -f -- "${DOUBLE_STATE}/${switch}"
  done
}

@test "an approved btrfs-rescue plan installs the flat subvolumes, the @swap swapfile, Snapper, and the baseline" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(engine_json outcome)" = installed ]
  [ "$(engine_json completed | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0, "utf8")).length))')" = 20 ]
  [ "$(engine_json resolved.resume_offset)" = 1998848 ]
  for subvolume in @ @home @log @pkg @snapshots @swap; do
    grep -q "^btrfs subvolume create .*/target/${subvolume}\$" "${DOUBLE_STATE}/calls.log"
  done
  grep -q '^btrfs filesystem mkswapfile --size 4096M .*/target/swap/swapfile$' "${DOUBLE_STATE}/calls.log"
  grep -q '^btrfs inspect-internal map-swapfile -r .*/target/swap/swapfile$' "${DOUBLE_STATE}/calls.log"
  ! engine_called filefrag
  ! engine_called mkswap
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
}

@test "btrfs-rescue mounts every subvolume with the planned options and keeps subvolume ids out of fstab" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@ .*/target$' "${DOUBLE_STATE}/calls.log"
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@home .*/target/home$' "${DOUBLE_STATE}/calls.log"
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@log .*/target/var/log$' "${DOUBLE_STATE}/calls.log"
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@pkg .*/target/var/cache/pacman/pkg$' "${DOUBLE_STATE}/calls.log"
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@snapshots .*/target/.snapshots$' "${DOUBLE_STATE}/calls.log"
  grep -q '^mount -o compress=zstd:1,relatime,subvol=@swap .*/target/swap$' "${DOUBLE_STATE}/calls.log"
  local fstab="${RUN_ROOT}/target/etc/fstab"
  ! grep -q 'subvolid=' "$fstab"
  grep -q 'subvol=/@home ' "$fstab"
  grep -q 'subvol=/@swap ' "$fstab"
  grep -qx '/swap/swapfile none swap defaults,pri=0 0 0' "$fstab"
  [ "$(stat -c %a "${RUN_ROOT}/target/swap/swapfile")" = 600 ]
}

@test "btrfs-rescue boots the flat root subvolume with resume parameters and the fallback entry" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  grep -qx 'options root=UUID=11111111-2222-4333-8444-555555555555 rw zswap.enabled=0 resume=UUID=11111111-2222-4333-8444-555555555555 resume_offset=1998848 rootflags=subvol=@' \
    "${RUN_ROOT}/target/boot/loader/entries/mirroros.conf"
  grep -q 'rootflags=subvol=@$' "${RUN_ROOT}/target/boot/loader/entries/mirroros-fallback.conf"
}

@test "btrfs-rescue without hibernation has no @swap, no swapfile, and no resume parameter" {
  engine_use_plan btrfs-rescue--hibernation-disabled
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ "$(engine_json completed | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0, "utf8")).length))')" = 19 ]
  ! grep -q '@swap' "${DOUBLE_STATE}/calls.log"
  ! grep -q 'mkswapfile' "${DOUBLE_STATE}/calls.log"
  ! grep -q '/swap' "${RUN_ROOT}/target/etc/fstab"
  ! grep -q 'resume' "${RUN_ROOT}/target/boot/loader/entries/mirroros.conf"
  grep -q 'rootflags=subvol=@$' "${RUN_ROOT}/target/boot/loader/entries/mirroros.conf"
}

@test "Snapper is configured for the root only after the packages, around the @snapshots mount, and the baseline comes last" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  local calls="${DOUBLE_STATE}/calls.log" pacstrap umount_line create_config delete_line mount_line baseline enable_line
  pacstrap="$(engine_call_line pacstrap)"
  umount_line="$(grep -n -m1 '^umount .*/target/.snapshots$' "$calls" | cut -d: -f1)"
  create_config="$(grep -n -m1 'snapper --no-dbus -c root create-config /$' "$calls" | cut -d: -f1)"
  delete_line="$(grep -n -m1 '^btrfs subvolume delete .*/target/.snapshots$' "$calls" | cut -d: -f1)"
  mount_line="$(grep -n '^mount -o compress=zstd:1,relatime,subvol=@snapshots ' "$calls" | tail -n 1 | cut -d: -f1)"
  baseline="$(grep -n -m1 'snapper --no-dbus -c root create --type single --description post-install baseline$' "$calls" | cut -d: -f1)"
  enable_line="$(grep -n -m1 'systemctl enable' "$calls" | cut -d: -f1)"
  [ "$pacstrap" -lt "$umount_line" ]
  [ "$umount_line" -lt "$create_config" ]
  [ "$create_config" -lt "$delete_line" ]
  [ "$delete_line" -lt "$mount_line" ]
  [ "$enable_line" -lt "$baseline" ]
  grep -q 'snapper --no-dbus -c root set-config TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=10$' "$calls"
  [ "$(grep -c 'snapper --no-dbus -c root create-config' "$calls")" -eq 1 ]
  [ "$(engine_json constants.configure_snapper.config)" != undefined ]
  grep -qx 'TIMELINE_CREATE="no"' "${RUN_ROOT}/target/etc/snapper/configs/root"
  grep -qx 'NUMBER_CLEANUP="yes"' "${RUN_ROOT}/target/etc/snapper/configs/root"
  grep -qx 'NUMBER_LIMIT="10"' "${RUN_ROOT}/target/etc/snapper/configs/root"
  grep -q 'post-install baseline' "${DOUBLE_STATE}/snapshots.list"
}

@test "btrfs-rescue enables the cleanup timer and leaves the timeline timer disabled" {
  engine_use_plan btrfs-rescue--locked
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  [ -f "${DOUBLE_STATE}/enabled/snapper-cleanup.timer" ]
  [ -f "${DOUBLE_STATE}/enabled/systemd-boot-update.service" ]
  [ ! -e "${DOUBLE_STATE}/enabled/snapper-timeline.timer" ]
  grep -q 'systemctl disable snapper-timeline.timer$' "${DOUBLE_STATE}/calls.log"
}

@test "a Snapper failure stops the later operations and the baseline is never taken" {
  engine_use_plan btrfs-rescue--locked
  printf '3\n' > "${DOUBLE_STATE}/fail.arch-chroot.snapper"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = configure_snapper ]
  [ "$(engine_json failed_operation.child_exit_status)" = 3 ]
  [ ! -d "${DOUBLE_STATE}/enabled" ]
  [ ! -e "${DOUBLE_STATE}/snapshots.list" ]
  [ "$(grep -c '^wipefs --all' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
}

@test "a failing subvolume creation ends the run at that operation with the top-level mount cleaned up" {
  engine_use_plan btrfs-rescue--locked
  printf '1\n' > "${DOUBLE_STATE}/fail.btrfs"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = create_btrfs_subvolumes ]
  ! engine_called pacstrap
  [ ! -s "${DOUBLE_STATE}/mounted.list" ]
}
