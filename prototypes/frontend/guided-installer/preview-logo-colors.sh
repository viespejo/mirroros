#!/usr/bin/env bash
# Presentation-only color preview. Does not change the guide or logo file.
set -euo pipefail

[[ -t 0 && -t 1 ]] || { printf 'Use a guest virtual console.\n' >&2; exit 2; }
command -v gum >/dev/null || { printf 'This preview requires Gum.\n' >&2; exit 6; }
LOGO_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/mirroros-logo.txt"
mapfile -t logo < "$LOGO_PATH"
width=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH")
read -r rows cols < <(stty size </dev/tty)
padding=$(((cols - width) / 2))
(( padding >= 0 )) || padding=0
export CLICOLOR_FORCE=1 FORCE_COLOR=1
# Linux VTs use indexed colors rather than true-color RGB values.
if [[ $(tty) == /dev/tty* ]]; then
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5\033[0m'
fi

names=('White / Cyan mirrors' 'White / Violet mirrors' 'White / Blue mirrors' 'White / Green mirrors')
accents=('6' '5' '4' '2')

show_logo() {
  local index=$1 row accent white=$'\033[97m'
  printf -v accent '\033[3%sm' "${accents[index]}"
  gum style --foreground "${accents[index]}" --padding "0 0 0 $padding" "${names[index]}"
  for row in "${logo[@]}"; do
    row=${row//░/${accent}░${white}}
    row=${row//▒/${accent}▒${white}}
    printf '%*s%s%s\033[0m\n' "$padding" '' "$white" "$row"
  done
  printf '\n'
}

trap 'printf "\nPreview cancelled.\n"; exit 3' INT
printf '\033[H\033[2J'
if (( rows >= 4 * (${#logo[@]} + 2) + 2 )); then
  for index in 0 1 2 3; do show_logo "$index"; done
  printf 'Press Enter to close the preview.'
  read -r
else
  for index in 0 1 2 3; do
    printf '\033[H\033[2J'
    show_logo "$index"
    if (( index < 3 )); then
      printf 'Press Enter for the next palette (%s/4).' "$((index + 1))"
    else
      printf 'Press Enter to close the preview (4/4).'
    fi
    read -r
  done
fi
