load uefi-support

setup() { uefi_test_setup; }

@test "UEFI moves Limine first and keeps all entries and relative order" {
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  [[ "$output" == *'BootOrder before: 0003,0002,0001'* ]]
  [[ "$output" == *'BootOrder after: 0001,0003,0002'* ]]
  uefi_test_order 0001,0003,0002
  ! grep -Eq -- '--create|--delete' "$UEFI_TEST_CALLS"
}

@test "UEFI systemd-boot uses its own accepted path and label" {
  uefi_test_state_change missing
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" systemd-boot
  [ "$status" -eq 0 ]
  grep -F -- '"--label","MirrorOS","--loader","\\EFI\\systemd\\systemd-bootx64.efi"' "$UEFI_TEST_CALLS"
  uefi_test_order 0000,0003,0002
  ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
}

@test "UEFI recreates Limine with create-only and never deletes" {
  uefi_test_state_change missing
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  grep -F -- '"--create-only","--disk","/dev/vda","--part","1","--label","Limine MirrorOS"' "$UEFI_TEST_CALLS"
  uefi_test_order 0000,0003,0002
  ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
}

@test "UEFI duplicate matching entries refuse all mutations" {
  uefi_test_state_change duplicate
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 2 ]
  [[ "$output" == *'duplicate matching entries'* ]]
  uefi_test_no_mutation
}

@test "UEFI already first is idempotent" {
  uefi_test_state_change first
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  uefi_test_no_mutation
}

@test "UEFI matches GUID and loader case insensitively with slash normalization" {
  uefi_test_state_change mixed-case
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  ! grep -q -- '--create' "$UEFI_TEST_CALLS"
}

@test "UEFI rejects substring path matching and preserves the unrelated entry" {
  uefi_test_state_change substring
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  uefi_test_order 0000,0003,0002,0001
  ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
}

@test "UEFI accepts an empty BootOrder without deleting unordered entries" {
  uefi_test_state_change empty
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  uefi_test_order 0001
  ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
}

@test "UEFI rejects malformed or repeated BootOrder before mutation" {
  for change in malformed repeated-order; do
    uefi_test_state_change "$change"
    run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
    [ "$status" -eq 2 ]
    uefi_test_no_mutation
  done
}

@test "UEFI validates loader PARTUUID and partition number before mutation" {
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" grub
  [ "$status" -eq 2 ]
  run uefi_ensure_first /dev/vda 1 invalid limine
  [ "$status" -eq 2 ]
  run uefi_ensure_first /dev/vda 0 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 2 ]
  uefi_test_no_mutation
}

@test "UEFI removes only entries referencing pre-wipe PARTUUIDs" {
  run uefi_remove_partuuids "$UEFI_TEST_ESP_GUID"
  [ "$status" -eq 0 ]
  uefi_test_order 0003,0002
  grep -F -- '["--bootnum","0001","--delete-bootnum"]' "$UEFI_TEST_CALLS"
  [ "$(grep -c -- '--delete-bootnum' "$UEFI_TEST_CALLS")" -eq 1 ]
  ! grep -Eq -- '--bootorder|--delete-bootorder|--create' "$UEFI_TEST_CALLS"
}

@test "UEFI ignores PARTUUID and loader text in descriptions" {
  uefi_test_state_change label-path
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 0 ]
  run uefi_remove_partuuids "$UEFI_TEST_ESP_GUID"
  [ "$status" -eq 0 ]
  uefi_test_order 0003,0002
  [ "$(grep -c -- '--delete-bootnum' "$UEFI_TEST_CALLS")" -eq 1 ]
}

@test "UEFI cleanup removes all scoped entries regardless of loader path" {
  uefi_test_state_change stale-second-loader
  run uefi_remove_partuuids "$UEFI_TEST_ESP_GUID"
  [ "$status" -eq 0 ]
  uefi_test_order 0003,0002
  [ "$(grep -c -- '--delete-bootnum' "$UEFI_TEST_CALLS")" -eq 2 ]
}

@test "UEFI empty or nonmatching cleanup set changes nothing" {
  run uefi_remove_partuuids
  [ "$status" -eq 0 ]
  run uefi_remove_partuuids aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb
  [ "$status" -eq 0 ]
  uefi_test_no_mutation
}

@test "UEFI validates the entire cleanup set before deleting anything" {
  run uefi_remove_partuuids "$UEFI_TEST_ESP_GUID" invalid
  [ "$status" -eq 2 ]
  uefi_test_no_mutation
}

@test "UEFI propagates provider failures without ordering after failed creation" {
  uefi_test_state_change missing
  export UEFI_TEST_FAIL=--create-only
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 5 ]
  [[ "$output" == *'synthetic efibootmgr failure'* ]]
  ! grep -q -- '--bootorder' "$UEFI_TEST_CALLS"
}

@test "UEFI failed observation does not cause any mutation" {
  export UEFI_TEST_FAIL=-v
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 5 ]
  uefi_test_no_mutation
}

@test "UEFI library supports strict-shell consumers and empty cleanup sets" {
  run bash -Eeuo pipefail -c '
    source "$UEFI_TEST_REPO/operations/lib/uefi-boot-entry.sh"
    uefi_remove_partuuids
    uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  '
  [ "$status" -eq 0 ]
  uefi_test_order 0001,0003,0002
}

@test "UEFI provider ordering and deletion errors remain failures" {
  export UEFI_TEST_FAIL=--bootorder
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 5 ]
  export UEFI_TEST_FAIL=--bootnum
  run uefi_remove_partuuids "$UEFI_TEST_ESP_GUID"
  [ "$status" -eq 5 ]
  uefi_test_order 0003,0002,0001
}

@test "UEFI detects ignored ordering and implicit creation reordering" {
  export UEFI_TEST_IGNORE_ORDER=1
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 6 ]
  unset UEFI_TEST_IGNORE_ORDER
  uefi_test_state_change missing
  : > "$UEFI_TEST_CALLS"
  export UEFI_TEST_BAD_CREATE=1
  run uefi_ensure_first /dev/vda 1 "$UEFI_TEST_ESP_GUID" limine
  [ "$status" -eq 6 ]
  ! grep -q -- '--bootorder' "$UEFI_TEST_CALLS"
}
