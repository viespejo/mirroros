# Isolated machine, disk, and storage presentation: synthetic providers, no discovery or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced libraries consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  FLOW_TMP="${BATS_TEST_TMPDIR}/private"
  mkdir "$FLOW_TMP"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  : > "$CALLS"
  FLOW_FACTS_INITIAL=synthetic-facts FLOW_PREVIEW=synthetic-preview
  FLOW_PLAN_ARG='' FLOW_PLAN_JUMPED=false NEXT_SCREEN=''
  PROFILE_STATUS=matched DISK_COUNT=2 CHOOSE_STATUS=0 DISCOVERY_STATUS=0
  ANSWER=Continue ROWS=40 COLS=149
  declare -gA CHOICES=([target_disk]=synthetic-b [storage_option]=btrfs-limine)
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    if [[ $1 == choose ]]; then
      if [[ $CHOOSE_STATUS != 0 ]]; then return "$CHOOSE_STATUS"; fi
      printf '%s\n' "$ANSWER"
    fi
  }
  flow_discover_initial() { return "$DISCOVERY_STATUS"; }
  flow_assistant() {
    case $1 in
      profile) printf '%s\treference-vm\n' "$PROFILE_STATUS" ;;
      disks)
        printf 'synthetic-a\t/dev/vda (64.0G) - Synthetic disk A\t/dev/vda\n'
        if [[ $DISK_COUNT == 2 ]]; then
          printf 'synthetic-b\t/dev/vdb (128.0G) - Synthetic disk B [ext4]\t/dev/vdb\n'
        fi
        ;;
      storage) printf 'ext4-systemd-boot\tsupported\nbtrfs-rescue\tsupported\nbtrfs-limine\tdefault\n' ;;
      *) return 6 ;;
    esac
  }
  flow_choice() { printf '%s\n' "${CHOICES[$1]}"; }
  flow_apply_choice() {
    printf 'apply %s %s\n' "$1" "$2" >> "$CALLS"
    CHOICES[$1]=$2
  }
  flow_cancel() { printf 'cancel %s\n' "$1" >> "$CALLS"; exit 3; }
}

@test "machine-storage machine variants preserve identity warnings and separated shared choices" {
  machine_check_form > "${BATS_TEST_TMPDIR}/machine-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/machine-output")" -eq 1 ]
  grep -qxF 'gum style --padding 0 0 0 0 Recognized machine: reference-vm' "$CALLS"
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 This machine matches a known profile. That does not guarantee that installation will work on it.' "$CALLS"
  PROFILE_STATUS=unqualified
  machine_check_form > /dev/null
  grep -qxF 'gum style --foreground 3 --padding 0 0 0 0 Experimental: this machine matches no known profile.' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 It meets the technical requirements. Compatibility is not guaranteed and no support is promised.' "$CALLS"
  grep -qF 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 2 --selected Continue Continue Cancel' "$CALLS"
}

@test "machine-storage machine preserves existing-plan jump cancellation and discovery failure" {
  FLOW_PLAN_ARG=synthetic-plan
  machine_check_form > /dev/null
  [ "$NEXT_SCREEN" -eq 13 ]
  [ "$FLOW_PLAN_JUMPED" = true ]
  NEXT_SCREEN=''
  machine_check_form > /dev/null
  [ -z "$NEXT_SCREEN" ]
  ANSWER=Cancel
  run machine_check_form
  [ "$status" -eq 3 ]
  grep -qxF 'cancel machine_check' "$CALLS"
  : > "$CALLS"
  DISCOVERY_STATUS=5
  run machine_check_form
  [ "$status" -eq 5 ]
  [ ! -s "$CALLS" ]
}

@test "machine-storage disk screen preserves all notices current choice and stable key mapping" {
  ANSWER='/dev/vda (64.0G) - Synthetic disk A'
  disk_selection_form > "${BATS_TEST_TMPDIR}/disk-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/disk-output")" -eq 1 ]
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Disks detected on this machine just now. Only eligible disks are shown. Selection does not authorize erasure.' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 The installation plan will use the entire selected disk.' "$CALLS"
  grep -qF -- '--height 5 --selected /dev/vdb (128.0G) - Synthetic disk B [ext4] /dev/vda (64.0G) - Synthetic disk A /dev/vdb (128.0G) - Synthetic disk B [ext4]' "$CALLS"
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  [ "${CHOICES[target_disk]}" = synthetic-a ]
  grep -qxF 'apply target_disk synthetic-a' "$CALLS"
}

@test "machine-storage single eligible disk remains an explicit selected choice" {
  DISK_COUNT=1
  ANSWER='/dev/vda (64.0G) - Synthetic disk A'
  disk_selection_form > /dev/null
  grep -qF -- '--height 5 --selected /dev/vda (64.0G) - Synthetic disk A /dev/vda (64.0G) - Synthetic disk A' "$CALLS"
  run grep -qF 'Synthetic disk B' "$CALLS"
  [ "$status" -eq 1 ]
  [ "${CHOICES[target_disk]}" = synthetic-a ]
}

@test "machine-storage layout preserves recovery limitations options and selected default" {
  ANSWER='ext4 + systemd-boot - Supported'
  storage_layout_form > "${BATS_TEST_TMPDIR}/storage-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/storage-output")" -eq 2 ]
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Planned layout: GPT, 2 GiB FAT32 EFI partition, unencrypted root. Selection only: no partitioning, formatting, or erasure runs here.' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 ext4: recovery from independent rescue media. Btrfs + systemd-boot: root snapshots; restore from rescue media. Btrfs + Limine: snapshot boot; persistent restore remains unvalidated.' "$CALLS"
  grep -qF -- '--height 5 --selected Btrfs + Snapper + Limine - Default ext4 + systemd-boot - Supported Btrfs + Snapper + systemd-boot - Supported Btrfs + Snapper + Limine - Default' "$CALLS"
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  [ "${CHOICES[storage_option]}" = ext4-systemd-boot ]
  grep -qxF 'apply storage_option ext4-systemd-boot' "$CALLS"
}

@test "machine-storage selectors preserve Esc and Ctrl+C without applying an incomplete choice" {
  local form code
  for form in machine_check_form disk_selection_form storage_layout_form; do
    for code in 1 130; do
      CHOOSE_STATUS=$code
      run "$form"
      [ "$status" -eq "$code" ]
    done
  done
  run grep -q '^apply ' "$CALLS"
  [ "$status" -eq 1 ]
  [ "${CHOICES[target_disk]}" = synthetic-b ]
  [ "${CHOICES[storage_option]}" = btrfs-limine ]
}

@test "machine-storage headings match welcome spacing and omit the symbol on short consoles" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  local title
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  for title in 'Machine check' 'Choose installation disk' 'Choose storage layout'; do
    step "$title" > "${BATS_TEST_TMPDIR}/screen-output"
    cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/screen-output"
  done
  ROWS=20 COLS=74
  for title in 'Machine check' 'Choose installation disk' 'Choose storage layout'; do
    run step "$title"
    [ "$status" -eq 0 ]
    [[ "$output" != *'█'* ]]
    grep -qF "$title" "$CALLS"
  done
}
