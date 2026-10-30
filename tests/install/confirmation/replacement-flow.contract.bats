load support

setup() {
  confirm_setup
  confirm_scenario coexistence-btrfs-limine
  # Discovery's read-only filesystem inspection is simulated, never mounted on the host.
  ln -sf "${CONFIRM_DISCOVERY_SUPPORT}/doubles/lsblk" "${DOUBLE_BIN}/mount"
  ln -sf "${CONFIRM_DISCOVERY_SUPPORT}/doubles/lsblk" "${DOUBLE_BIN}/umount"
  ROOT_ID=10000000-0000-4000-8000-000000000002
}

teardown() {
  confirm_teardown
}

queue_replacement_review() {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/nvme0n1 (238G) [vfat, btrfs, vfat, crypto_LUKS]' \
    '0|Replace existing MirrorOS' '0|Btrfs + Snapper + Limine - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' \
    '0|Locked (default)' '0|Continue to confirmation'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros' '0|nvme0n1'
  confirm_queue confirm 0
}

@test "guided replacement selection persists exact scope and wrong root identity cancels before password or engine" {
  queue_replacement_review
  confirm_queue input '0|00000002'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_reason confirmation_mismatch
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.target_mode === 'replace_installation' && d.target.installation.root.partuuid === '$ROOT_ID'"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.target_mode === 'replace_installation' && d.partitions.root.partuuid === '$ROOT_ID' && d.partitions.esp.path === '/dev/nvme0n1p1'"
  confirm_json_assert "${RUN_DIR}/install-run.json" "!d.stages.includes('password') && !d.stages.includes('engine')"
  confirm_assert_output_contains 'Preserve'
  confirm_assert_output_contains '/dev/nvme0n1p4'
  [ ! -e "${RUN_DIR}/engine" ]
}

@test "guided replacement changed binding at final discovery invalidates approval before engine" {
  queue_replacement_review
  confirm_queue input "0|$ROOT_ID" "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_hook_call input 7 "rm -f -- $(printf '%q' "${DOUBLE_STATE}/filesystems/nvme0n1p1/limine.conf")"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason target_layout_changed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.stages.includes('discovery_final') && !d.stages.includes('engine')"
  confirm_assert_no_canary
  [ ! -e "${RUN_DIR}/engine" ]
}

@test "guided replacement exact disk and root identity reach password but Back discards approval" {
  queue_replacement_review
  confirm_queue input "0|$ROOT_ID" '1'
  confirm_queue choose '130'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.stages.includes('password') && !d.stages.includes('engine')"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.target_mode === 'replace_installation' && d.partitions.root.partuuid === '$ROOT_ID'"
  [ ! -e "${RUN_DIR}/engine" ]
}
