#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/swapfile-size.sh
source "$ROOT/lib/swapfile-size.sh"
PADDING=0
swapfile_size=$(jq -r '.policy.swapfile_size.value' "$ROOT/fixtures/installation-policy.json")
[[ $swapfile_size == 4096 ]]
mock_status=0
cancel_after_invalid=false
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
step() { printf '%s\n' "$*" >> "$work/redraws"; }
gum() {
  if [[ $1 == input ]]; then
    if [[ $cancel_after_invalid == true && -f $work/redraws ]]; then return 1; fi
    local value
    IFS= read -r value <&3 || return 6
    printf '%s\n' "$value"
    return "$mock_status"
  fi
}
for value in 512 4096 65536 0008192; do
  exec 3<<< "$value"
  swapfile_size_form
  [[ $swapfile_size == "$((10#$value))" ]]
done
for value in '' 511 65537 -512 1.5 abc ' 4096' 999999999999999999999999; do
  exec 3<<< "$value"$'\n4096'
  swapfile_size_form
  [[ $swapfile_size == 4096 && -s $work/redraws ]]
  rm -- "$work/redraws"
done
for mock_status in 1 130 5; do
  exec 3<<< '8192'
  status=0; swapfile_size_form || status=$?
  [[ $status == "$mock_status" && $swapfile_size == 4096 ]]
done
mock_status=0
cancel_after_invalid=true
exec 3<<< 'invalid'
status=0; swapfile_size_form || status=$?
[[ $status == 1 && $swapfile_size == 4096 ]]
exec 3<&-
printf 'Swapfile size checks passed.\n'
