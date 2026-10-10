#!/usr/bin/env bash
# Temporary console color previews. No installation or disk operations.
# Tokyo Night VT palette from the Omarchy ISO; see LICENSE-ISO.
set -euo pipefail

[[ -t 0 && -t 1 ]] || { printf 'Use a guest virtual console.\n' >&2; exit 2; }
logo_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/mirroros-logo.txt"
[[ -r $logo_path ]] || { printf 'Missing mirroros-logo.txt beside this script.\n' >&2; exit 2; }
logo_width=$(awk '{ if (length > max) max = length } END { print max+0 }' "$logo_path")

# Use the same console palette as the guide, not terminal true-color approximations.
if [[ $(tty) == /dev/tty* ]]; then
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5\033[0m'
fi
trap 'printf "\033[0m\n"' EXIT
trap 'exit 130' INT

names=('Tokyo blue' 'Tokyo blue / white' 'Tokyo cyan / white' 'Tokyo violet / white')
mirror_colors=(34 34 36 35)
os_colors=(34 97 97 97)
selected=0
while true; do
  width=$(stty size </dev/tty | awk '{print $2}')
  padding=$(((width - logo_width) / 2))
  (( padding < 0 )) && padding=0
  printf '\033[H\033[2J\n'
  while IFS= read -r row || [[ -n $row ]]; do
    # Six 9-column letters, their spacing and the leading margin occupy 61 columns.
    printf '%*s\033[%sm%s\033[%sm%s\033[0m\n' "$padding" '' \
      "${mirror_colors[selected]}" "${row:0:61}" "${os_colors[selected]}" "${row:61}"
  done < "$logo_path"
  printf '\n%*s%d. %s\n\n' "$padding" '' "$((selected + 1))" "${names[selected]}"
  for index in "${!names[@]}"; do
    printf '%*s%d: %s\n' "$padding" '' "$((index + 1))" "${names[index]}"
  done
  printf '\n%*s\033[90m1-4: select   Enter: next   Esc / q / Ctrl+C: exit\033[0m\n' "$padding" ''
  IFS= read -rsn1 key || break
  case $key in
    [1-4]) selected=$((key - 1)) ;;
    '') selected=$(((selected + 1) % ${#names[@]})) ;;
    $'\e'|q|Q) break ;;
  esac
done
