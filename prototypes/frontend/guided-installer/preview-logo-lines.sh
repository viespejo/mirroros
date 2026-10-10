#!/usr/bin/env bash
# Presentation-only separator preview. Does not modify the logo.
set -euo pipefail
[[ -t 0 && -t 1 ]] || { printf 'Use a guest virtual console.\n' >&2; exit 2; }
command -v gum >/dev/null || { printf 'This preview requires Gum.\n' >&2; exit 6; }
LOGO_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/mirroros-logo.txt"
width=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH")
read -r _ cols < <(stty size </dev/tty)
padding=$(((cols - width) / 2))
(( padding >= 0 )) || padding=0
export CLICOLOR_FORCE=1 FORCE_COLOR=1
names=('Heavy line (current)' 'Thin line' 'Upper block' 'Lower block')
glyphs=('━' '─' '▔' '▁')
printf '\033[H\033[2J'
for index in 0 1 2 3; do
  separator=''
  for ((column = 0; column < width; column++)); do separator+=${glyphs[index]}; done
  gum style --foreground '#C0CAF5' --padding "0 0 0 $padding" "${names[index]}"
  gum style --foreground '#7DCFFF' --padding "0 0 0 $padding" "$separator"
  printf '\n'
done
printf 'Press Enter to close the preview.'
read -r
