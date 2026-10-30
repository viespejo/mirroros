load uefi-support

setup() {
  uefi_test_setup
  entry="$UEFI_TEST_DIR/code/operations/boot-first"
}

@test "boot-first verifies Btrfs Limine and restores order without deleting" {
  run bash "$entry"
  [ "$status" -eq 0 ]
  uefi_test_order 0001,0003,0002
  ! grep -Eq -- '--delete|--create' "$UEFI_TEST_CALLS"
}

@test "boot-first supports ext4 and Btrfs systemd-boot installations" {
  uefi_test_systemd
  for fs in ext4 btrfs; do
    export UEFI_TEST_FS="$fs"
    run bash "$entry"
    [ "$status" -eq 0 ]
    uefi_test_order 0001,0003,0002
  done
  ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
}

@test "boot-first recreates the running bootloader entry when missing" {
  for loader in limine systemd-boot; do
    if [[ "$loader" == systemd-boot ]]; then uefi_test_systemd; fi
    uefi_test_state_change missing
    run bash "$entry"
    [ "$status" -eq 0 ]
    uefi_test_order 0000,0003,0002
    ! grep -q -- '--delete' "$UEFI_TEST_CALLS"
    # Reset state for the other bootloader without touching real NVRAM.
    uefi_test_setup
  done
}

@test "boot-first unprivileged refusal precedes NVRAM access" {
  export UEFI_TEST_UID=1000
  run bash "$entry"
  [ "$status" -eq 2 ]
  [[ "$output" == *'root using sudo'* ]]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses missing mount wrong ESP type and other-disk ESP" {
  export UEFI_TEST_NO_MOUNT=1
  run bash "$entry"
  [ "$status" -eq 2 ]
  unset UEFI_TEST_NO_MOUNT
  export UEFI_TEST_ESP_TYPE=0fc63daf-8483-4772-8e79-3d69d8477de4
  run bash "$entry"
  [ "$status" -eq 2 ]
  unset UEFI_TEST_ESP_TYPE
  export UEFI_TEST_ESP_DISK=/dev/vdb
  run bash "$entry"
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses wrong label and ambiguous ESP volume ID" {
  export UEFI_TEST_ROOT_LABEL=other
  run bash "$entry"
  [ "$status" -eq 2 ]
  unset UEFI_TEST_ROOT_LABEL
  export UEFI_TEST_DUP_UUID=1
  run bash "$entry"
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses wrong or ambiguous fstab binding" {
  printf 'UUID=0000-0000 /boot vfat defaults 0 2\n' > "$UEFI_TEST_DIR/fstab"
  run bash "$entry"
  [ "$status" -eq 2 ]
  printf 'UUID=%s / btrfs defaults 0 0\nUUID=ABCD-1234 /boot vfat defaults 0 2\nUUID=ABCD-1234 /boot vfat defaults 0 2\n' \
    "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/fstab"
  run bash "$entry"
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses wrong root configuration and comments masquerading as binding" {
  printf '# cmdline: root=UUID=%s\ncmdline: root=UUID=other\n' "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/boot/limine.conf"
  run bash "$entry"
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses conflicting bootloaders missing configuration and missing binary" {
  printf 'options root=UUID=%s\n' "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/boot/loader/entries/mirroros.conf"
  run bash "$entry"
  [ "$status" -eq 2 ]
  rm "$UEFI_TEST_DIR/boot/loader/entries/mirroros.conf" "$UEFI_TEST_DIR/boot/EFI/BOOT/BOOTX64.EFI"
  run bash "$entry"
  [ "$status" -eq 2 ]
  rm "$UEFI_TEST_DIR/boot/limine.conf"
  run bash "$entry"
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first refuses duplicate firmware entries without mutation" {
  uefi_test_state_change duplicate
  run bash "$entry"
  [ "$status" -eq 2 ]
  uefi_test_no_mutation
}

@test "boot-first help and unsupported arguments do not inspect NVRAM" {
  run bash "$entry" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'never deletes'* ]]
  run bash "$entry" --help extra
  [ "$status" -eq 2 ]
  run bash "$entry" --disk /dev/vda
  [ "$status" -eq 2 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}

@test "boot-first resolves its library through an external launcher symlink" {
  ln -s "$entry" "$UEFI_TEST_DIR/mirroros-boot-first"
  cd "$UEFI_TEST_DIR"
  run bash "$UEFI_TEST_DIR/mirroros-boot-first"
  [ "$status" -eq 0 ]
}

@test "boot-first missing library reports damaged installation before NVRAM access" {
  rm "$UEFI_TEST_DIR/code/operations/lib/uefi-boot-entry.sh"
  run bash "$entry"
  [ "$status" -eq 6 ]
  [ ! -s "$UEFI_TEST_CALLS" ]
}
