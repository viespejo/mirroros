# shellcheck disable=SC2329 # Exported command doubles run indirectly in child Bash processes.
uefi_test_setup() {
  UEFI_TEST_REPO=$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)
  export UEFI_TEST_REPO
  export UEFI_TEST_DIR="$BATS_TEST_TMPDIR/uefi"
  mkdir -p "$UEFI_TEST_DIR/code/operations/lib" "$UEFI_TEST_DIR/boot/EFI/BOOT" \
    "$UEFI_TEST_DIR/boot/EFI/systemd" "$UEFI_TEST_DIR/boot/loader/entries"
  export UEFI_TEST_STATE="$UEFI_TEST_DIR/state.json" UEFI_TEST_CALLS="$UEFI_TEST_DIR/calls.jsonl"
  export UEFI_TEST_ESP_GUID=11111111-2222-3333-4444-555555555555
  export UEFI_TEST_ROOT_UUID=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
  export UEFI_TEST_OTHER_GUID=99999999-8888-7777-6666-555555555555
  export UEFI_TEST_UID=0 UEFI_TEST_FS=btrfs
  : > "$UEFI_TEST_CALLS"
  node --input-type=module <<'JS'
import { writeFileSync } from 'node:fs';
writeFileSync(process.env.UEFI_TEST_STATE, JSON.stringify({
  order: ['0003', '0002', '0001'],
  entries: [
    { id: '0001', label: 'Limine MirrorOS', guid: process.env.UEFI_TEST_ESP_GUID, path: '\\EFI\\BOOT\\BOOTX64.EFI' },
    { id: '0002', label: 'Limine Other', guid: process.env.UEFI_TEST_OTHER_GUID, path: '\\EFI\\limine\\limine_x64.efi' },
    { id: '0003', label: 'Firmware' },
    { id: '0004', label: 'Unordered removable' },
  ],
}));
JS
  cp "$UEFI_TEST_REPO/operations/lib/uefi-boot-entry.sh" "$UEFI_TEST_DIR/code/operations/lib/"
  # Relocate only inspection paths in the copied command, without a production bypass.
  node --input-type=module <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const source = readFileSync(`${process.env.UEFI_TEST_REPO}/operations/boot-first`, 'utf8');
writeFileSync(`${process.env.UEFI_TEST_DIR}/code/operations/boot-first`, source.replace(
  'uefi_identify_running /boot /etc/fstab',
  `uefi_identify_running "${process.env.UEFI_TEST_DIR}/boot" "${process.env.UEFI_TEST_DIR}/fstab"`,
));
JS
  printf 'UUID=%s / btrfs defaults 0 0\nUUID=ABCD-1234 /boot vfat defaults 0 2\n' "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/fstab"
  printf 'cmdline: root=UUID=%s rootflags=subvol=@\n' "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/boot/limine.conf"
  printf 'efi\n' > "$UEFI_TEST_DIR/boot/EFI/BOOT/BOOTX64.EFI"
  printf 'efi\n' > "$UEFI_TEST_DIR/boot/EFI/systemd/systemd-bootx64.efi"
  efibootmgr() { node "$UEFI_TEST_REPO/tests/operations/doubles/efibootmgr.mjs" "$@"; }
  id() { if [[ "$*" == -u ]]; then printf '%s\n' "$UEFI_TEST_UID"; else command id "$@"; fi; }
  readlink() {
    case "${*: -1}" in
      /dev/vda1|/dev/vda2) printf '%s\n' "${*: -1}" ;;
      *) command readlink "$@" ;;
    esac
  }
  findmnt() {
    case "$*" in
      '-nro SOURCE --target /') printf '/dev/vda2[/@]\n' ;;
      "-nro SOURCE --mountpoint $UEFI_TEST_DIR/boot")
        [[ ${UEFI_TEST_NO_MOUNT:-0} == 0 ]] || return 1
        printf '/dev/vda1\n' ;;
      "-nro FSTYPE --mountpoint $UEFI_TEST_DIR/boot") printf 'vfat\n' ;;
      *) return 99 ;;
    esac
  }
  lsblk() {
    case "$*" in
      '-dnro TYPE /dev/vda1'|'-dnro TYPE /dev/vda2') printf 'part\n' ;;
      '-dnro LABEL /dev/vda2') printf '%s\n' "${UEFI_TEST_ROOT_LABEL:-mirroros}" ;;
      '-dnro PARTTYPE /dev/vda2') printf '0fc63daf-8483-4772-8e79-3d69d8477de4\n' ;;
      '-dnro PARTTYPE /dev/vda1') printf '%s\n' "${UEFI_TEST_ESP_TYPE:-c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" ;;
      '-dnro FSTYPE /dev/vda2') printf '%s\n' "$UEFI_TEST_FS" ;;
      '-dnpro PKNAME /dev/vda2') printf '/dev/vda\n' ;;
      '-dnpro PKNAME /dev/vda1') printf '%s\n' "${UEFI_TEST_ESP_DISK:-/dev/vda}" ;;
      '-dnro PTTYPE /dev/vda') printf 'gpt\n' ;;
      '-dnro UUID /dev/vda2') printf '%s\n' "$UEFI_TEST_ROOT_UUID" ;;
      '-dnro UUID /dev/vda1') printf 'ABCD-1234\n' ;;
      '-nrpo UUID /dev/vda')
        printf '%s\nABCD-1234\n' "$UEFI_TEST_ROOT_UUID"
        if [[ ${UEFI_TEST_DUP_UUID:-0} == 1 ]]; then printf 'ABCD-1234\n'; fi ;;
      '-dnro PARTN /dev/vda1') printf '1\n' ;;
      '-dnro PARTUUID /dev/vda1') printf '%s\n' "$UEFI_TEST_ESP_GUID" ;;
      *) return 99 ;;
    esac
  }
  export -f efibootmgr id readlink findmnt lsblk
  # shellcheck disable=SC1091 # Library under test.
  source "$UEFI_TEST_REPO/operations/lib/uefi-boot-entry.sh"
}

uefi_test_state_change() {
  node --input-type=module - "$1" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.env.UEFI_TEST_STATE;
const state = JSON.parse(readFileSync(file, 'utf8'));
delete state.raw;
switch (process.argv[2]) {
  case 'missing': state.entries = state.entries.filter((e) => e.id !== '0001'); state.order.pop(); break;
  case 'duplicate': state.entries.push({ ...state.entries[0], id: '0005' }); break;
  case 'systemd': state.entries[0].path = '\\EFI\\systemd\\systemd-bootx64.efi'; state.entries[0].label = 'MirrorOS'; break;
  case 'first': state.order = ['0001', '0003', '0002']; break;
  case 'empty': state.order = []; break;
  case 'mixed-case': state.entries[0].guid = state.entries[0].guid.toUpperCase(); state.entries[0].path = '/efi/boot/bootx64.efi'; break;
  case 'substring': state.entries[0].path += '.other'; break;
  case 'malformed': state.raw = 'BootOrder: 0001,invalid'; break;
  case 'repeated-order': state.order = ['0003', '0003']; break;
  case 'label-path': state.entries[2].label = `HD(1,GPT,${process.env.UEFI_TEST_ESP_GUID},0x800,0x100000)/File(\\EFI\\BOOT\\BOOTX64.EFI)`; break;
  case 'stale-second-loader': state.entries.push({ ...state.entries[0], id: '0005', path: '\\EFI\\old\\old.efi' }); state.order.push('0005'); break;
  default: throw new Error('unknown state change');
}
writeFileSync(file, JSON.stringify(state));
JS
}

uefi_test_systemd() {
  rm "$UEFI_TEST_DIR/boot/limine.conf"
  printf 'title MirrorOS\noptions root=UUID=%s rw\n' "$UEFI_TEST_ROOT_UUID" > "$UEFI_TEST_DIR/boot/loader/entries/mirroros.conf"
  uefi_test_state_change systemd
}

uefi_test_no_mutation() {
  if [[ -s "$UEFI_TEST_CALLS" ]]; then
    ! grep -Eq -- '--create|--bootorder|--delete' "$UEFI_TEST_CALLS"
  fi
}

uefi_test_order() {
  node --input-type=module - "$1" <<'JS'
import { readFileSync } from 'node:fs';
const state = JSON.parse(readFileSync(process.env.UEFI_TEST_STATE, 'utf8'));
if (state.order.join(',') !== process.argv[2]) process.exit(1);
JS
}
