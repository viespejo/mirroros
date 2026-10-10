# shellcheck shell=bash
# Policy snapshot presentation only; no partitioning or filesystem operations.

storage_layout_form() {
  local rows key tier label choice selected='' index
  local -a keys=() labels=()
  command -v jq >/dev/null || { printf 'The storage preview requires jq.\n' >&2; return 6; }
  rows=$(jq -r '.storage_options | to_entries[] | [.key, .value.tier] | @tsv' "$GUIDE_DIR/fixtures/installation-policy.json") || return 6
  while IFS=$'\t' read -r key tier; do
    case "$key:$tier" in
      ext4-systemd-boot:default) label='ext4 + systemd-boot - Default' ;;
      btrfs-rescue:supported) label='Btrfs + Snapper + systemd-boot - Supported' ;;
      btrfs-limine:experimental) label='Btrfs + Snapper + Limine - Experimental' ;;
      *) printf 'Unknown storage option in the preview policy.\n' >&2; return 6 ;;
    esac
    keys+=("$key")
    labels+=("$label")
    # shellcheck disable=SC2154 # Choice state is initialized by the entry point.
    if [[ $key == "$storage_option" ]]; then selected=$label; fi
  done <<< "$rows"
  [[ -n $selected ]] || { printf 'The storage choice is absent from the preview policy.\n' >&2; return 6; }
  gum style --foreground 8 --padding "$PADDING" 'Planned layout: GPT, 1 GiB FAT32 EFI partition, unencrypted root.' 'Selection only: no partitioning, formatting, or erasure runs here.'
  gum style --padding "$PADDING" 'ext4: recovery from independent rescue media.' 'Btrfs + systemd-boot: root snapshots; restore from rescue media.' 'Btrfs + Limine: snapshot boot; persistent restore remains unvalidated.'
  gum style --foreground 3 --padding "$PADDING" 'Limine is experimental, with no support commitment and AUR dependencies.'
  choice=$(gum choose --show-help --height 5 --selected "$selected" --header 'Select storage layout' "${labels[@]}") || return $?
  for index in "${!labels[@]}"; do
    if [[ ${labels[index]} == "$choice" ]]; then
      # shellcheck disable=SC2034 # The entry point consumes the choice and review label.
      storage_option=${keys[index]} storage_label=${labels[index]}
      return 0
    fi
  done
  return 6
}
