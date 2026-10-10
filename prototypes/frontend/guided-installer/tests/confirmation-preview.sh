#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/confirmation-preview.sh
source "$ROOT/lib/confirmation-preview.sh"
# shellcheck source=../lib/password-preview.sh
source "$ROOT/lib/password-preview.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
PADDING=0
disk='/dev/vda (32G) - Example VirtIO Disk [vfat, ext4]'
disk_path='/dev/vda'
target_disk='virtio-SYNTH-VDA-0001'
storage_label='ext4 + systemd-boot - Default'
username=mirroros
root_account=locked
mock_status=0
mock_choice='Simulate confirmation'
expected_selected=Back
abort() { exit 3; }
gum() {
  case $1 in
    choose)
      [[ "$*" == *"--selected $expected_selected"* ]] || return 6
      printf '%s\n' "$mock_choice"
      return "$mock_status"
      ;;
    style) printf '%s\n' "$*" ;;
    *) printf 'Unexpected interactive input.\n' >&2; return 6 ;;
  esac
}
confirmation_preview_form > "$work/screen"
grep -Fq 'SIMULATION ONLY' "$work/screen"
grep -Fq "$target_disk" "$work/screen"
grep -Fq "Path: $disk_path" "$work/screen"
grep -Fq "$disk" "$work/screen"
grep -Fq "$storage_label" "$work/screen"
grep -Fq 'erase all existing content' "$work/screen"
mock_choice=Back
status=0; confirmation_preview_form >/dev/null || status=$?
[[ $status == 1 ]]
for mock_status in 1 130 5; do
  status=0; confirmation_preview_form >/dev/null || status=$?
  [[ $status == "$mock_status" ]]
done
mock_status=0
mock_choice='Cancel preview'
status=0; (confirmation_preview_form >/dev/null) || status=$?
[[ $status == 3 ]]
mock_choice=Unknown
status=0; confirmation_preview_form >/dev/null || status=$?
[[ $status == 6 ]]
expected_selected='Finish preview'
mock_choice='Finish preview'
password_preview_form > "$work/screen"
grep -Fq 'one password for mirroros, with repetition' "$work/screen"
grep -Fq 'Root stays locked' "$work/screen"
root_account=password
password_preview_form > "$work/screen"
grep -Fq 'Root receives the same password' "$work/screen"
grep -Fq 'Cancelling password entry must prevent installation' "$work/screen"
mock_choice=Back
status=0; password_preview_form >/dev/null || status=$?
[[ $status == 1 ]]
for mock_status in 1 130 5; do
  status=0; password_preview_form >/dev/null || status=$?
  [[ $status == "$mock_status" ]]
done
mock_status=0
mock_choice=Unknown
status=0; password_preview_form >/dev/null || status=$?
[[ $status == 6 ]]
root_account=unknown
status=0; password_preview_form >/dev/null || status=$?
[[ $status == 6 ]]
grep -Fq '14) confirmation_preview_form' "$ROOT/guest-demo.sh"
grep -Fq '15) password_preview_form' "$ROOT/guest-demo.sh"
printf 'Confirmation and password preview checks passed.\n'
