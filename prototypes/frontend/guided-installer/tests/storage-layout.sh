#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/storage-layout.sh
source "$ROOT/lib/storage-layout.sh"
GUIDE_DIR=$ROOT
PADDING=0
storage_option='ext4-systemd-boot'
storage_label='ext4 + systemd-boot - Default'
mock_status=0
mock_choice=$storage_label
expected_selected=$storage_label
gum() {
  if [[ $1 == choose ]]; then
    [[ "$*" == *"--selected $expected_selected"* ]] || return 6
    [[ "$*" == *'ext4 + systemd-boot - Default'* && "$*" == *'Btrfs + Snapper + systemd-boot - Supported'* && "$*" == *'Btrfs + Snapper + Limine - Experimental'* ]] || return 6
    printf '%s\n' "$mock_choice"
    return "$mock_status"
  fi
}
storage_layout_form
[[ $storage_option == ext4-systemd-boot && $storage_label == "$mock_choice" ]]
mock_choice='Btrfs + Snapper + systemd-boot - Supported'
storage_layout_form
[[ $storage_option == btrfs-rescue && $storage_label == "$mock_choice" ]]
expected_selected=$storage_label
mock_choice='Btrfs + Snapper + Limine - Experimental'
storage_layout_form
[[ $storage_option == btrfs-limine && $storage_label == "$mock_choice" ]]
expected_selected=$storage_label
mock_choice='ext4 + systemd-boot - Default'
for mock_status in 1 130 5; do
  status=0; storage_layout_form || status=$?
  [[ $status == "$mock_status" && $storage_option == btrfs-limine && $storage_label == "$expected_selected" ]]
done
mock_status=0
mock_choice='Unknown option'
status=0; storage_layout_form || status=$?
[[ $status == 6 && $storage_option == btrfs-limine ]]
storage_option='unknown'
status=0; storage_layout_form 2>/dev/null || status=$?
[[ $status == 6 ]]
printf 'Storage layout checks passed.\n'
