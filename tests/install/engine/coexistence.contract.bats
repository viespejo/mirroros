# shellcheck disable=SC2153 # OUTPUT is assigned by the sourced support helper.
load support

setup() {
  bats_require_minimum_version 1.5.0
  engine_setup
}

teardown() {
  engine_teardown
}

@test "replacement formats only the selected partitions for all storage options" {
  for option in ext4-systemd-boot btrfs-rescue btrfs-limine; do
    engine_teardown
    engine_setup
    engine_replacement_layout "$option"
    engine_run
    [ "$ENGINE_STATUS" -eq 0 ]
    [ "$(engine_json outcome)" = installed ]
    local disk esp root
    disk="$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).target.disk.path' "$PLAN")"
    esp="$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).target.installation.esp.path' "$PLAN")"
    root="$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).target.installation.root.path' "$PLAN")"
    grep -qxF "wipefs --all $FIXTURE_ROOT$esp $FIXTURE_ROOT$root" "$DOUBLE_STATE/calls.log"
    run ! grep -q '^sfdisk --wipe' "$DOUBLE_STATE/calls.log"
    run ! grep -Eq "^wipefs --all .*${disk}( |$)" "$DOUBLE_STATE/calls.log"
    run ! grep -q -- '--delete-bootnum' "$DOUBLE_STATE/nvram-calls.jsonl"
    cmp "$OUTPUT/untouched-partitions-before.json" "$OUTPUT/untouched-partitions-after.json"
    [ "$(engine_json constants.format_partitions.untouched_partitions_verified)" = true ]
    [ "$(readlink "$RUN_ROOT/target/usr/local/bin/mirroros-boot-first")" = /usr/local/lib/mirroros/operations/boot-first ]
    cmp "$CODE_ROOT/operations/boot-first" "$RUN_ROOT/target/usr/local/lib/mirroros/operations/boot-first"
    cmp "$CODE_ROOT/operations/lib/uefi-boot-entry.sh" "$RUN_ROOT/target/usr/local/lib/mirroros/operations/lib/uefi-boot-entry.sh"
  done
}

@test "replacement rejects changed GPT entries before destructive operations" {
  engine_replacement_layout btrfs-limine
  printf '/dev/nvme0n1p5 : start=1, size=1, type=bad, uuid=bad\n' >> "$DOUBLE_STATE/out/sfdisk"
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  [ "$(engine_json outcome)" = invalidated ]
  run ! engine_called wipefs
  run ! engine_called mkfs.fat
  run ! engine_called efibootmgr
}

@test "replacement refuses a changed selected partition identity before wiping" {
  engine_replacement_layout btrfs-limine
  node --input-type=module - "$DOUBLE_STATE/lsblk.json" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const raw = JSON.parse(readFileSync(file));
raw.blockdevices[0].children[1].partuuid = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
writeFileSync(file, JSON.stringify(raw));
JS
  engine_run
  [ "$ENGINE_STATUS" -eq 2 ]
  run ! engine_called wipefs
  run ! engine_called mkfs.fat
}

@test "whole-disk cleanup deletes only entries in the pre-wipe PARTUUID set" {
  node --input-type=module - "$DOUBLE_STATE/nvram.json" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const state = JSON.parse(readFileSync(file));
state.entries.push({ id: '0005', label: 'Stale target', guid: '00000000-0000-4000-8000-0000000000a2', path: '\\EFI\\old.efi' });
state.order.unshift('0005');
writeFileSync(file, JSON.stringify(state));
JS
  engine_run
  [ "$ENGINE_STATUS" -eq 0 ]
  grep -qF '["--bootnum","0005","--delete-bootnum"]' "$DOUBLE_STATE/nvram-calls.jsonl"
  [ "$(grep -c -- '--delete-bootnum' "$DOUBLE_STATE/nvram-calls.jsonl")" -eq 1 ]
  grep -qF '["--bootorder","0000,0003,0002"]' "$DOUBLE_STATE/nvram-calls.jsonl"
  grep -q -- 'bootctl install --esp-path=/boot --variables=no' "$DOUBLE_STATE/calls.log"
}

@test "replacement refuses missing undersized or mounted targets without destructive calls" {
  for change in missing undersized mounted; do
    engine_teardown
    engine_setup
    engine_replacement_layout btrfs-limine
    node --input-type=module - "$DOUBLE_STATE/lsblk.json" "$change" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const raw = JSON.parse(readFileSync(file));
const disk = raw.blockdevices[0];
if (process.argv[3] === 'missing') disk.children.splice(1, 1);
if (process.argv[3] === 'undersized') disk.children[1].size = 1024;
if (process.argv[3] === 'mounted') disk.children[1].mountpoints = ['/mnt/busy'];
writeFileSync(file, JSON.stringify(raw));
JS
    engine_run
    [ "$ENGINE_STATUS" -eq 2 ]
    run ! engine_called wipefs
    run ! engine_called mkfs.fat
    run ! engine_called efibootmgr
  done
}

@test "duplicate matching UEFI entries stop registration without NVRAM mutation" {
  engine_replacement_layout btrfs-limine
  node --input-type=module - "$DOUBLE_STATE/nvram.json" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const state = JSON.parse(readFileSync(file));
for (const id of ['0005', '0006']) state.entries.push({ id, label: 'Limine MirrorOS',
  guid: '10000000-0000-4000-8000-000000000001', path: '\\EFI\\BOOT\\BOOTX64.EFI' });
writeFileSync(file, JSON.stringify(state));
JS
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = register_uefi_boot_entry ]
  run ! grep -Eq -- '--create|--bootorder|--delete' "$DOUBLE_STATE/nvram-calls.jsonl"
}

@test "a changed non-target identity fails the final operation and never configures" {
  engine_replacement_layout btrfs-limine
  touch "$DOUBLE_STATE/change-nontarget-identity"
  engine_run
  [ "$ENGINE_STATUS" -eq 5 ]
  [ "$(engine_json failed_operation.id)" = register_uefi_boot_entry ]
  [ "$(engine_json outcome)" = failed ]
  [[ "$(engine_json completed)" != *register_uefi_boot_entry* ]]
  run ! engine_called configure
  run ! cmp "$OUTPUT/untouched-partitions-before.json" "$OUTPUT/untouched-partitions-after.json"
}

@test "boot-first is delivered before postconditions even when verification fails" {
  touch "$DOUBLE_STATE/postconditions-missing-kernel"
  engine_run
  [ "$ENGINE_STATUS" -eq 4 ]
  [ -s "$RUN_ROOT/target/usr/local/lib/mirroros/operations/boot-first" ]
  [ "$(stat -c %a "$RUN_ROOT/target/usr/local/lib/mirroros/operations/boot-first")" = 755 ]
  [ "$(stat -c %a "$RUN_ROOT/target/usr/local/lib/mirroros/operations/lib/uefi-boot-entry.sh")" = 644 ]
  [ "$(engine_json constants.register_uefi_boot_entry.boot_order)" = 0000,0003,0002 ]
}
