#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/root-account.sh
source "$ROOT/lib/root-account.sh"
GUIDE_DIR=$ROOT
PADDING=0
mock_status=0
mock_choice='Password login enabled'
expected_selected='Locked (default)'
gum() {
  if [[ $1 == choose ]]; then
    [[ "$*" == *"--selected $expected_selected"* ]] || return 6
    printf '%s\n' "$mock_choice"
    return "$mock_status"
  fi
}
initialize_root_account_preview
[[ $root_account == locked && $root_account_label == "$expected_selected" ]]
root_account_form
[[ $root_account == password && $root_account_label == "$mock_choice" ]]
expected_selected=$root_account_label
mock_choice='Locked (default)'
for mock_status in 1 130 5; do
  status=0; root_account_form || status=$?
  [[ $status == "$mock_status" && $root_account == password && $root_account_label == "$expected_selected" ]]
done
mock_status=0
mock_choice='Unknown'
status=0; root_account_form || status=$?
[[ $status == 6 && $root_account == password ]]
mock_choice='Locked (default)'
root_account_form
[[ $root_account == locked && $root_account_label == "$mock_choice" ]]
if grep -Eq 'full_name|email_address|\*{8}' "$ROOT/guest-demo.sh"; then
  printf 'Legacy Git or fake password fields remain.\n' >&2
  exit 1
fi
grep -Fq 'root receives the same password as your user.' "$ROOT/lib/root-account.sh"
grep -Fq 'one password, with repetition, after plan approval.' "$ROOT/lib/root-account.sh"
grep -Fq 'This user belongs to wheel and can administer the system with sudo.' "$ROOT/guest-demo.sh"
printf 'Root account checks passed.\n'
