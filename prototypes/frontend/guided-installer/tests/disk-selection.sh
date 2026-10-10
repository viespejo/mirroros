#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/disk-selection.sh
source "$ROOT/lib/disk-selection.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/lib" "$work/fixtures"
cp -- "$ROOT/lib/disk-options.jq" "$work/lib/"
cp -- "$ROOT/fixtures/target-facts.json" "$work/fixtures/"
GUIDE_DIR=$work
PADDING=0
target_disk=''; disk=''; disk_path=''
mock_status=0
mock_choice='/dev/vda (32G) - Example VirtIO Disk [vfat, ext4]'
gum() {
  if [[ $1 == choose ]]; then
    if [[ $mock_choice == '/dev/vda (32G) - Example VirtIO Disk [vfat, ext4]' ]]; then
      [[ "$*" == *'--selected /dev/vda (32G) - Example VirtIO Disk [vfat, ext4]'* ]] || return 6
    fi
    printf '%s\n' "$mock_choice"
    return "$mock_status"
  fi
}
rows=$(jq -r -f "$ROOT/lib/disk-options.jq" "$ROOT/fixtures/target-facts.json")
[[ $rows == $'virtio-SYNTH-VDA-0001\t/dev/vda (32G) - Example VirtIO Disk [vfat, ext4]\t/dev/vda' ]]
disk_selection_form
[[ $target_disk == virtio-SYNTH-VDA-0001 && $disk_path == /dev/vda && $disk == "$mock_choice" ]]
for mock_status in 1 130 5; do
  status=0; disk_selection_form || status=$?
  [[ $status == "$mock_status" && $target_disk == virtio-SYNTH-VDA-0001 ]]
done
mock_status=0
jq '
  .effective["storage.disks"].value += [{
    identity: {path: "/dev/vdb", by_id: "virtio-SYNTH-SECOND", model: "Example Disk", size_bytes: 68719476736},
    eligible: true,
    layout: {partitions: [{fstype: "vfat"}, {fstype: "ext4"}]}
  }]
' "$ROOT/fixtures/target-facts.json" > "$work/fixtures/target-facts.json"
mock_choice='/dev/vdb (64G) - Example Disk [vfat, ext4]'
disk_selection_form
[[ $target_disk == virtio-SYNTH-SECOND && $disk_path == /dev/vdb && $disk == "$mock_choice" ]]
mock_status=1
status=0; disk_selection_form || status=$?
[[ $status == 1 && $target_disk == virtio-SYNTH-SECOND ]]
jq '.effective["storage.disks"].value = []' "$ROOT/fixtures/target-facts.json" > "$work/fixtures/target-facts.json"
status=0; disk_selection_form 2>/dev/null || status=$?
[[ $status == 2 && $target_disk == virtio-SYNTH-SECOND ]]
printf 'Disk selection checks passed.\n'
