# shellcheck shell=bash
# Synthetic discovery fixture presentation only; no live disk access.

disk_selection_form() {
  local rows key label path choice selected='' index
  local -a keys=() labels=() paths=()
  command -v jq >/dev/null || { printf 'The disk preview requires jq.\n' >&2; return 6; }
  rows=$(jq -r -f "$GUIDE_DIR/lib/disk-options.jq" "$GUIDE_DIR/fixtures/target-facts.json") || return 6
  if [[ -z $rows ]]; then
    printf 'The example discovery facts contain no eligible disk.\n' >&2
    return 2
  fi
  while IFS=$'\t' read -r key label path; do
    keys+=("$key")
    labels+=("$label")
    paths+=("$path")
    # shellcheck disable=SC2154 # Disk choice state is initialized by the entry point.
    if [[ $key == "$target_disk" ]]; then selected=$label; fi
  done <<< "$rows"
  if (( ${#keys[@]} == 1 )); then selected=${labels[0]}; fi
  gum style --foreground 8 --padding "$PADDING" 'Example discovery facts, not the current disk state.' 'Only eligible disks are shown. Selection does not authorize erasure.'
  gum style --padding "$PADDING" 'The installation plan will use the entire selected disk.'
  choice=$(gum choose --show-help --height 5 --selected "$selected" --header 'Select install disk' "${labels[@]}") || return $?
  for index in "${!labels[@]}"; do
    if [[ ${labels[index]} == "$choice" ]]; then
      # shellcheck disable=SC2034 # The entry point consumes the disk choice and preview labels.
      target_disk=${keys[index]} disk=${labels[index]} disk_path=${paths[index]}
      return 0
    fi
  done
  return 6
}
