#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Screen state is read by the flow library; live preparation state is set by live.sh, which the orchestrator loads.
# The screens of the guided live installer, in the order of the frozen reference
# (prototypes/frontend/guided-installer/), with approved presentation and integration differences listed
# in contracts/installation-confirmation.md and ADR 0018. Screen text adapted from
# omacom/omarchy-iso; see install/confirmation/UPSTREAM.md.
#
# Defaults, per-value validation, and plan generation come from the plan component through the flow
# library (flow_choice, flow_apply_choice, flow_ensure_plan); a screen holds no policy.
#
# Every form returns 0 to advance, 1 for Esc or Back, 130 for Ctrl+C, and another status for the flow to
# normalize. A form that offers Cancel ends the run through flow_cancel.

# The labels of the reference for the values the plan component resolves.
storage_label_for() {
  case "$1:$2" in
    ext4-systemd-boot:supported) printf '%s' 'ext4 + systemd-boot - Supported' ;;
    btrfs-rescue:supported) printf '%s' 'Btrfs + Snapper + systemd-boot - Supported' ;;
    btrfs-limine:default) printf '%s' 'Btrfs + Snapper + Limine - Default' ;;
    *) printf '%s - %s' "$1" "$2" ;;
  esac
}

language_label_for() {
  case "$1" in
    en_US.UTF-8) printf '%s' 'English (US)' ;;
    es_ES.UTF-8) printf '%s' 'Spanish (Spain)' ;;
    *) printf '%s' "$1" ;;
  esac
}

formats_label_for() {
  case "$1" in
    follow_language) printf '%s' 'Follow system language' ;;
    es_ES.UTF-8) printf '%s' 'Spain' ;;
    en_US.UTF-8) printf '%s' 'United States' ;;
    *) printf '%s' "$1" ;;
  esac
}

root_label_for() {
  case "$1" in
    locked) printf '%s' 'Locked (default)' ;;
    password) printf '%s' 'Password login enabled' ;;
    *) printf '%s' "$1" ;;
  esac
}

keyboard_label_for() {
  case "$1" in
    us) printf '%s' 'English (US)' ;;
    es) printf '%s' 'Spanish (ES)' ;;
    *) printf '%s' '' ;;
  esac
}

# A value the plan component lists for a closed choice can never be rejected; a rejection is an internal
# inconsistency, not a user error.
screen_apply_listed() {
  local status=0
  flow_apply_choice "$1" "$2" || status=$?
  if ((status == 1)); then return 6; fi
  return "$status"
}

# Shows the reasons of the last rejected value in red.
screen_show_invalid() {
  local message next_step
  while IFS=$'\t' read -r message next_step; do
    gum style --foreground 1 --padding "$PADDING" "$message" "$next_step"
  done < "$FLOW_INVALID_TEXT"
}

welcome_form() {
  local action status
  while true; do
    gum style --foreground 8 --padding "$PADDING" "Let's set up your machine."
    echo
    gum style --padding "$PADDING" "Installation keyboard: $live_keyboard_label"
    gum style --foreground 8 --padding "$PADDING" 'Used only during installation.'
    echo
    action=$(ui_choose --show-help --height 3 --selected 'Continue' 'Continue' 'Change keyboard layout' 'Change text size') || return $?
    case $action in
      Continue) return 0 ;;
      'Change keyboard layout')
        step 'Installation keyboard layout'
        status=0
        live_console_keyboard_form || status=$?
        case $status in
          0 | 1) step 'Welcome to MirrorOS' ;;
          *) return "$status" ;;
        esac
        ;;
      'Change text size')
        step 'Installation text size'
        status=0
        live_console_text_size_form || status=$?
        case $status in
          0 | 1) step 'Welcome to MirrorOS' ;;
          *) return "$status" ;;
        esac
        ;;
      *) return 6 ;;
    esac
  done
}

# Replaces the reference's manual profile selection: discovery has identified the machine on its own.
machine_check_form() {
  local status=0 profile_status profile_id action
  flow_discover_initial || status=$?
  if ((status != 0)); then return "$status"; fi
  flow_assistant profile "$FLOW_FACTS_INITIAL" > "${FLOW_TMP}/profile.tsv" || return 6
  IFS=$'\t' read -r profile_status profile_id < "${FLOW_TMP}/profile.tsv"
  case $profile_status in
    matched)
      gum style --padding "$PADDING" "Recognized machine: $profile_id"
      gum style --foreground 8 --padding "$PADDING" 'This machine matches a known profile. That does not guarantee that installation will work on it.'
      ;;
    unqualified)
      gum style --foreground 3 --padding "$PADDING" 'Experimental: this machine matches no known profile.'
      gum style --foreground 8 --padding "$PADDING" 'It meets the technical requirements. Compatibility is not guaranteed and no support is promised.'
      ;;
    *) return 6 ;;
  esac
  echo
  action=$(ui_choose --show-help --height 2 --selected 'Continue' 'Continue' 'Cancel') || return $?
  case $action in
    Continue)
      # An existing plan enters the review directly; the configuration screens stay reachable with Back.
      if [[ -n $FLOW_PLAN_ARG && $FLOW_PLAN_JUMPED != true ]]; then
        NEXT_SCREEN=13
        FLOW_PLAN_JUMPED=true
      fi
      return 0
      ;;
    Cancel) flow_cancel machine_check ;;
    *) return 6 ;;
  esac
}

disk_selection_form() {
  local key label path choice selected='' index current status=0
  local -a keys=() labels=() paths=()
  flow_assistant disks "$FLOW_FACTS_INITIAL" > "${FLOW_TMP}/disks.tsv" || return 6
  current=$(flow_choice target_disk) || return 6
  while IFS=$'\t' read -r key label path; do
    keys+=("$key")
    labels+=("$label")
    paths+=("$path")
    if [[ $key == "$current" ]]; then selected=$label; fi
  done < "${FLOW_TMP}/disks.tsv"
  if ((${#keys[@]} == 0)); then return 6; fi
  if ((${#keys[@]} == 1)); then selected=${labels[0]}; fi
  gum style --foreground 8 --padding "$PADDING" 'Disks detected on this machine just now.' 'Only eligible disks are shown. Selection does not authorize erasure.'
  gum style --foreground 8 --padding "$PADDING" 'Choose the target mode after selecting a disk.'
  echo
  choice=$(ui_choose --show-help --height 5 --selected "$selected" "${labels[@]}") || return $?
  for index in "${!labels[@]}"; do
    if [[ ${labels[index]} == "$choice" ]]; then
      screen_apply_listed target_disk "${keys[index]}" || return $?
      target_mode_form || status=$?
      return "$status"
    fi
  done
  return 6
}

target_mode_form() {
  local mode choice current selected='Whole disk' root
  local -a modes=() labels=()
  flow_assistant target-modes "$FLOW_PREVIEW" > "${FLOW_TMP}/target-modes.txt" || return 6
  while IFS= read -r mode; do
    modes+=("$mode")
    case $mode in
      whole_disk) labels+=('Whole disk') ;;
      replace_installation) labels+=('Replace existing MirrorOS') ;;
      *) return 6 ;;
    esac
  done < "${FLOW_TMP}/target-modes.txt"
  if ((${#modes[@]} == 1)); then
    screen_apply_listed target_mode whole_disk
    return $?
  fi
  ((${#modes[@]} == 2)) || return 6
  current=$(flow_choice target_mode) || return 6
  if [[ $current == replace_installation ]]; then selected='Replace existing MirrorOS'; fi
  gum style --foreground 8 --padding "$PADDING" 'Whole disk erases every partition.' 'Replace existing MirrorOS formats only its ESP and root; other partitions and the partition table are preserved.'
  echo
  choice=$(ui_choose --show-help --height 2 --selected "$selected" "${labels[@]}") || return $?
  case $choice in
    'Whole disk') screen_apply_listed target_mode whole_disk ;;
    'Replace existing MirrorOS')
      root=$(flow_assistant get "$FLOW_PREVIEW" options.replace_root_partuuid.0.value) || return 6
      [[ -n $root ]] || return 6
      screen_apply_listed replace_root_partuuid "$root"
      ;;
    *) return 6 ;;
  esac
}

storage_layout_form() {
  local value tier label choice selected='' index current status=0
  local -a keys=() labels=()
  flow_assistant storage "$FLOW_PREVIEW" > "${FLOW_TMP}/storage.tsv" || return 6
  current=$(flow_choice storage_option) || return 6
  while IFS=$'\t' read -r value tier; do
    label=$(storage_label_for "$value" "$tier")
    keys+=("$value")
    labels+=("$label")
    if [[ $value == "$current" ]]; then selected=$label; fi
  done < "${FLOW_TMP}/storage.tsv"
  [[ -n $selected ]] || return 6
  if [[ $(flow_choice target_mode) == replace_installation ]]; then
    gum style --foreground 8 --padding "$PADDING" 'Reuse the selected ESP and root without resizing or repartitioning.' 'Selection only: no partitioning, formatting, or erasure runs here.'
  else
    gum style --foreground 8 --padding "$PADDING" 'Planned layout: GPT, 2 GiB FAT32 EFI partition, unencrypted root.' 'Selection only: no partitioning, formatting, or erasure runs here.'
  fi
  echo
  gum style --foreground 8 --padding "$PADDING" 'ext4: recovery from independent rescue media.' 'Btrfs + systemd-boot: root snapshots; restore from rescue media.' 'Btrfs + Limine: snapshot boot; persistent restore remains unvalidated.'
  echo
  choice=$(ui_choose --show-help --height 5 --selected "$selected" "${labels[@]}") || return $?
  for index in "${!labels[@]}"; do
    if [[ ${labels[index]} == "$choice" ]]; then
      screen_apply_listed storage_option "${keys[index]}" || status=$?
      return "$status"
    fi
  done
  return 6
}

# Hibernation is enabled by default. The swapfile size is asked only while it is enabled, and Esc from the size
# returns here. A choice is applied only when it differs from the current one, so a revisit keeps an explicit size.
hibernation_form() {
  local current selected choice status
  while true; do
    current=$(flow_choice hibernation) || return 6
    if [[ $current == true ]]; then selected=Enabled; else selected=Disabled; fi
    gum style --foreground 8 --padding "$PADDING" 'Hibernation lets the machine power off and resume where it left off.' 'Enabled keeps a swapfile on disk; it also serves as fallback swap when zram is full.'
    echo
    choice=$(ui_choose --show-help --height 3 --selected "$selected" Enabled Disabled) || return $?
    if [[ $choice != "$selected" ]]; then
      case $choice in
        Enabled) screen_apply_listed hibernation true || return $? ;;
        Disabled) screen_apply_listed hibernation false || return $? ;;
        *) return 6 ;;
      esac
    fi
    if [[ $choice == Disabled ]]; then return 0; fi
    step 'Choose swapfile size'
    status=0
    swapfile_size_form || status=$?
    if ((status != 1)); then return "$status"; fi
    step 'Choose hibernation'
  done
}

swapfile_size_form() {
  local value normalized minimum maximum status error=''
  value=$(flow_choice swapfile_size) || return 6
  minimum=$(flow_assistant get "$FLOW_PREVIEW" options.swapfile_size.minimum) || return 6
  maximum=$(flow_assistant get "$FLOW_PREVIEW" options.swapfile_size.maximum) || return 6
  while true; do
    gum style --foreground 8 --padding "$PADDING" 'The swapfile holds the hibernation image and also serves as fallback swap after zram.' 'The default does not guarantee hibernation for every workload.'
    echo
    gum style --foreground 8 --padding "$PADDING" "Enter an integer from $minimum to $maximum MiB." 'A real plan checks that the complete layout fits the selected disk.'
    if [[ -n $error ]]; then
      echo
      gum style --foreground 1 --padding "$PADDING" "$error"
    fi
    echo
    value=$(gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value "$value" --placeholder 'Size in MiB' --prompt 'Swapfile size (MiB)> ') || return $?
    normalized=$value
    while [[ $normalized == 0* && ${#normalized} -gt 1 ]]; do normalized=${normalized:1}; done
    status=0
    flow_apply_choice swapfile_size "$normalized" || status=$?
    case $status in
      0) return 0 ;;
      1) ;;
      *) return "$status" ;;
    esac
    step 'Choose swapfile size'
    error="Use a whole number from $minimum to $maximum MiB."
  done
}

timezone_form() {
  local value current
  current=$(flow_choice timezone) || return 6
  value=$(printf '%s\n' Europe/Madrid Europe/London UTC | ui_choose --show-help --height 10 --selected "$current") || return $?
  screen_apply_listed timezone "$value"
}

system_language_form() {
  local choice value current
  current=$(flow_choice lang) || return 6
  gum style --foreground 8 --padding "$PADDING" 'Choose the default language for system messages and applications.' 'Applications may use their own language preference. Keyboard is separate.'
  echo
  choice=$(ui_choose --show-help --height 5 --selected "$(language_label_for "$current")" 'English (US)' 'Spanish (Spain)') || return $?
  case $choice in
    'English (US)') value=en_US.UTF-8 ;;
    'Spanish (Spain)') value=es_ES.UTF-8 ;;
    *) return 6 ;;
  esac
  screen_apply_listed lang "$value"
}

regional_formats_form() {
  local choice value current language
  current=$(flow_choice regional_format) || return 6
  language=$(flow_choice lang) || return 6
  gum style --foreground 8 --padding "$PADDING" 'Choose formats for dates, numbers, currency, and measurement units.' 'This does not change the language of messages or your keyboard.'
  echo
  gum style --foreground 8 --padding "$PADDING" "Follow system language currently means: $(language_label_for "$language")."
  echo
  choice=$(ui_choose --show-help --height 5 --selected "$(formats_label_for "$current")" 'Follow system language' 'Spain' 'United States') || return $?
  case $choice in
    'Follow system language') value=follow_language ;;
    'Spain') value=es_ES.UTF-8 ;;
    'United States') value=en_US.UTF-8 ;;
    *) return 6 ;;
  esac
  screen_apply_listed regional_format "$value"
}

keyboard_form() {
  local choice value current
  current=$(flow_choice console_keymap) || return 6
  gum style --foreground 8 --padding "$PADDING" "Choose the installed system's console keyboard layout." 'Wayland desktop layouts are configured separately.'
  # This guide offers US and ES console layouts only.
  echo
  choice=$(printf '%s\n' 'English (US)' 'Spanish (ES)' | ui_choose --show-help --height 10 --selected "$(keyboard_label_for "$current")") || return $?
  case $choice in
    'English (US)') value=us ;;
    'Spanish (ES)') value=es ;;
    *) return 6 ;;
  esac
  screen_apply_listed console_keymap "$value"
}

hostname_form() {
  local value status
  value=$(flow_choice hostname) || return 6
  while true; do
    value=$(gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value "$value" --placeholder "Letters, digits, and dashes (or return for 'mirroros')" --prompt 'Hostname> ') || return $?
    value=${value:-mirroros}
    status=0
    flow_apply_choice hostname "$value" || status=$?
    case $status in
      0) return 0 ;;
      1) ;;
      *) return "$status" ;;
    esac
    step 'Name your machine'
    screen_show_invalid
    echo
  done
}

username_form() {
  local value status invalid=false
  value=$(flow_choice user_name) || return 6
  while true; do
    gum style --foreground 8 --padding "$PADDING" "Choose the username you'll use to sign in." 'This user belongs to wheel and can administer the system with sudo.'
    if [[ $invalid == true ]]; then
      echo
      gum style --foreground 1 --padding "$PADDING" 'Use 1-32 characters, starting with a lowercase letter or underscore.' 'Only lowercase letters, digits, underscores, dashes, and an optional final $.' 'The name root is reserved.'
    fi
    echo
    value=$(gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value "$value" --placeholder 'Lowercase letters, digits, underscores, or dashes' --prompt 'Username> ') || return $?
    status=0
    flow_apply_choice user_name "$value" || status=$?
    case $status in
      0) return 0 ;;
      1) ;;
      *) return "$status" ;;
    esac
    step "Let's setup your user account..."
    invalid=true
  done
}

root_account_form() {
  local choice value current
  current=$(flow_choice root_account) || return 6
  gum style --foreground 8 --padding "$PADDING" 'Locked root: use your wheel-group user with sudo for administration.' 'Password enabled: root receives the same password as your user.'
  echo
  gum style --foreground 8 --padding "$PADDING" 'One password is asked, with repetition, after you approve the plan.'
  if [[ $current == password ]]; then
    gum style --foreground 8 --padding "$PADDING" 'Sharing the password does not give root an independent recovery credential.'
  fi
  echo
  choice=$(ui_choose --show-help --height 5 --selected "$(root_label_for "$current")" 'Locked (default)' 'Password login enabled') || return $?
  case $choice in
    'Locked (default)') value=locked ;;
    'Password login enabled') value=password ;;
    *) return 6 ;;
  esac
  screen_apply_listed root_account "$value"
}

# The review measures its rendered content before choosing an inline or paged presentation.
review_form_width() {
  REVIEW_WIDTH=80
  local available=$((TERM_WIDTH - PADDING_LEFT - 1))
  if ((REVIEW_WIDTH > available)); then REVIEW_WIDTH=$available; fi
  if ((REVIEW_WIDTH < 1)); then REVIEW_WIDTH=1; fi
}

review_text() {
  local foreground=$1 text
  shift
  for text in "$@"; do
    gum style --foreground "$foreground" --padding "$PADDING" "$(printf '%s\n' "$text" | fold -s -w "$REVIEW_WIDTH")"
  done
}

review_row() {
  local text
  printf -v text '%-14s %s' "$1" "$2"
  review_text 7 "$text"
}

review_rows() {
  review_row Machine "${FLOW_REVIEW[machine]}"
  review_row Graphics "${FLOW_REVIEW[rule_graphics]}"
  review_row 'CPU microcode' "${FLOW_REVIEW[rule_cpu_microcode]}"
  review_row Battery "${FLOW_REVIEW[rule_battery]}"
  review_row Virtualization "${FLOW_REVIEW[rule_virtualization]}"
  review_row Disk "${FLOW_REVIEW[disk]}"
  review_target_rows
  review_row Storage "$(storage_label_for "${FLOW_REVIEW[storage_option]}" "${FLOW_REVIEW[storage_tier]}")"
  review_row Hibernation "${FLOW_REVIEW[hibernation_label]}"
  if [[ $REVIEW_GROUP_LOCALE == true ]]; then
    review_text 7 "$REVIEW_LOCALE_LINE"
  else
    review_row Timezone "${FLOW_REVIEW[timezone]}"
    review_row Language "${FLOW_REVIEW[lang]}"
  fi
  review_row Formats "$(formats_label_for "${FLOW_REVIEW[regional_format]}") (${FLOW_REVIEW[format_locale]})"
  if [[ $REVIEW_GROUP_LOCALE != true ]]; then review_row Locales "${FLOW_REVIEW[locales]}"; fi
  review_row Internet "$live_network_status"
  if [[ $REVIEW_GROUP_ACCOUNTS == true ]]; then
    review_text 7 "$REVIEW_ACCOUNTS_LINE"
  else
    review_row Username "${FLOW_REVIEW[user_name]}"
    review_row Root "$(root_label_for "${FLOW_REVIEW[root_account]}")"
    review_row Hostname "${FLOW_REVIEW[hostname]}"
  fi
  review_row Keyboard "${FLOW_REVIEW[console_keymap]}"
  review_row Plan "${FLOW_REVIEW[plan_reference]}"
}

review_target_rows() {
  review_row Mode "${FLOW_REVIEW[target_mode_label]:-${FLOW_REVIEW[target_mode]:-Whole disk}}"
  if [[ ${FLOW_REVIEW[target_mode]:-whole_disk} == replace_installation ]]; then
    review_row 'Format ESP' "${FLOW_REVIEW[target_format_esp]}"
    review_row 'Format root' "${FLOW_REVIEW[target_format_root]}"
    review_row Preserve "${FLOW_REVIEW[target_preserve]}"
  fi
}

review_footer() {
  review_text 8 'Review only: this does not approve a plan or authorize disk changes.'
  if [[ ${FLOW_REVIEW[target_mode]:-whole_disk} == replace_installation ]]; then
    review_text 8 'Next: confirm the disk and root PARTUUID to replace, then set the password. Installation starts after that.'
  else
    review_text 8 'Next: confirm the disk to erase, then set the password. Installation starts after that.'
  fi
}

review_body() {
  local warning
  review_rows
  review_text 8 'After the base system is verified, the graphical environment is configured.'
  echo
  while IFS= read -r warning; do ui_warning_block "$warning"; done < <(flow_assistant review-warnings "$FLOW_PLAN_FILE")
  if [[ ${FLOW_REVIEW[hibernation]} == false ]]; then
    review_text 8 'Hibernation is disabled: no swapfile will be created.'
  fi
  if [[ ${FLOW_REVIEW[swapfile_below_ram]} == true ]]; then
    ui_warning_block 'Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space.'
  fi
  echo
  review_footer
  echo
}

review_select_layout() {
  measure_terminal
  review_form_width
  REVIEW_GROUP_ACCOUNTS=false REVIEW_GROUP_LOCALE=false REVIEW_PAGED=false
  REVIEW_BODY_FILE="${FLOW_TMP}/review-body.txt"
  REVIEW_ACCOUNTS_LINE="Hostname: ${FLOW_REVIEW[hostname]} | Username: ${FLOW_REVIEW[user_name]} | Root: $(root_label_for "${FLOW_REVIEW[root_account]}")"
  REVIEW_LOCALE_LINE="Timezone: ${FLOW_REVIEW[timezone]} | Language: ${FLOW_REVIEW[lang]} | Locales: ${FLOW_REVIEW[locales]}"
  review_body > "$REVIEW_BODY_FILE" || return 6
  # Two top lines, title and gap, six menu/help lines, and one spare cursor line.
  REVIEW_REQUIRED_ROWS=$(($(wc -l < "$REVIEW_BODY_FILE") + 11))
  if ((REVIEW_REQUIRED_ROWS <= TERM_HEIGHT)); then return 0; fi
  if ((${#REVIEW_ACCOUNTS_LINE} <= REVIEW_WIDTH)); then REVIEW_GROUP_ACCOUNTS=true; fi
  if ((${#REVIEW_LOCALE_LINE} <= REVIEW_WIDTH)); then REVIEW_GROUP_LOCALE=true; fi
  review_body > "$REVIEW_BODY_FILE" || return 6
  REVIEW_REQUIRED_ROWS=$(($(wc -l < "$REVIEW_BODY_FILE") + 11))
  if ((REVIEW_REQUIRED_ROWS > TERM_HEIGHT)); then REVIEW_PAGED=true; fi
}

review_show_body() {
  local line
  while IFS= read -r line || [[ -n $line ]]; do printf '%s\n' "$line"; done < "$REVIEW_BODY_FILE"
}

review_show_paged() {
  local status=0
  gum pager --border-foreground 4 < "$REVIEW_BODY_FILE" || status=$?
  case $status in
    0 | 1) return 0 ;;
    *) return "$status" ;;
  esac
}

# Planning and validation still precede review. Neither layout nor inspection authorizes anything.
review_form() {
  local choice status complete
  local -a options=()
  flow_ensure_plan || return $?
  flow_reached review
  flow_load_review
  while true; do
    review_select_layout || return $?
    options=('Continue to confirmation')
    if [[ $REVIEW_PAGED == true ]]; then
      review_show_paged || return $?
      step 'Review your choices'
      review_footer
      echo
      options+=('Inspect review')
    else
      step 'Review your choices'
      review_show_body
    fi
    options+=('Inspect complete plan' 'Back')
    choice=$(ui_choose --show-help --height "${#options[@]}" --selected 'Continue to confirmation' "${options[@]}") || return $?
    case $choice in
      'Continue to confirmation') return 0 ;;
      'Inspect review') ;;
      'Inspect complete plan')
        complete="${FLOW_TMP}/complete-plan.txt"
        flow_cli review complete "$FLOW_PLAN_FILE" > "$complete" || return 6
        status=0
        gum pager --border-foreground 4 < "$complete" || status=$?
        case $status in
          0 | 1) ;;
          *) return "$status" ;;
        esac
        ;;
      'Back') return 1 ;;
      *) return 6 ;;
    esac
  done
}

# The real, bound confirmation: No is focused, then the kernel device name is typed. No, Esc, Ctrl+C, and a
# mismatch cancel; there is no Back and no second attempt.
confirmation_form() {
  local name path identity typed status
  flow_reached confirmation
  flow_device_name
  name=$FLOW_DEVICE_NAME
  flow_load_review
  path=$(flow_assistant get "$FLOW_PLAN_FILE" target.disk.path) || return 6
  identity=$(flow_assistant get "$FLOW_PLAN_FILE" target.disk.by_id) || return 6
  if [[ ${FLOW_PROFILE_STATUS} == unqualified ]]; then
    gum style --foreground 3 --padding "$PADDING" 'Experimental: this machine matches no known profile.'
  fi
  review_form_width
  review_row Disk "${FLOW_REVIEW[disk]}"
  review_row Path "$path"
  review_row 'Disk ID' "${identity:-not reported}"
  review_row 'New layout' "$(storage_label_for "${FLOW_REVIEW[storage_option]}" "${FLOW_REVIEW[storage_tier]}")"
  review_row 'Plan reference' "${FLOW_REVIEW[plan_reference]}"
  echo
  local prompt="Erase $path and apply plan ${FLOW_REVIEW[plan_reference]}?" affirmative='Yes, erase'
  if [[ ${FLOW_REVIEW[target_mode]:-whole_disk} == replace_installation ]]; then
    review_target_rows
    gum style --foreground 1 --padding "$PADDING" 'This will erase only the selected MirrorOS ESP and root partitions.'
    prompt="Replace MirrorOS on $path and apply plan ${FLOW_REVIEW[plan_reference]}?"
    affirmative='Yes, replace'
  else
    gum style --foreground 1 --padding "$PADDING" 'This will erase all existing content on this disk.'
  fi
  echo
  status=0
  gum confirm --prompt.foreground 7 --selected.foreground 4 --selected.background 0 --default=false --affirmative "$affirmative" --negative 'No' "$prompt" || status=$?
  case $status in
    0) ;;
    1 | 130) flow_cancel confirmation ;;
    *) return "$status" ;;
  esac
  echo
  gum style --foreground 8 --padding "$PADDING" "Type the device name ($name) to confirm."
  echo
  typed=$(gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt 'Device name> ') || status=$?
  case $status in
    0) ;;
    1 | 130) flow_cancel confirmation ;;
    *) return "$status" ;;
  esac
  if [[ $typed != "$name" ]]; then
    flow_mismatch
  fi
  if [[ ${FLOW_REVIEW[target_mode]:-whole_disk} == replace_installation ]]; then
    echo
    review_text 8 "Type the full root PARTUUID (${FLOW_REVIEW[root_partuuid]}) to confirm."
    typed=$(gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt 'Root PARTUUID> ') || status=$?
    case $status in
      0) ;;
      1 | 130) flow_cancel confirmation ;;
      *) return "$status" ;;
    esac
    if [[ $typed != "${FLOW_REVIEW[root_partuuid]}" ]]; then flow_mismatch; fi
  fi
  flow_confirmed
}

# The single account password, asked twice with a protected prompt. It is kept only in FLOW_PASSWORD (a global,
# never exported, never logged, never recorded) until the engine invocation consumes it. A blank or mismatching
# pair asks both fields again. Esc at Confirm restarts entry; Esc at Password returns to review; Ctrl+C cancels.
password_form() {
  local first second root_message status failure=''
  flow_reached password
  flow_load_review
  FLOW_PASSWORD=''
  case ${FLOW_REVIEW[root_account]} in
    locked) root_message='Root stays locked; no password is assigned to root.' ;;
    password) root_message='Root receives the same password as your user, not a second password.' ;;
    *) return 6 ;;
  esac
  while true; do
    gum style --foreground 8 --padding "$PADDING" "One password is used for ${FLOW_REVIEW[user_name]}." 'Your user can administer the system with sudo.' "$root_message"
    echo
    gum style --foreground 8 --padding "$PADDING" 'Passwords follow real bound plan/disk confirmation, before disk writes.' 'Cancelling password entry must prevent installation from starting.' 'Passwords never belong in the plan, review, or retained evidence.'
    if [[ -n $failure ]]; then
      echo
      gum style --foreground 1 --padding "$PADDING" "$failure"
    fi
    echo
    status=0
    first=$(gum input --password --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt 'Password> ') || status=$?
    case $status in
      0) ;;
      1) return 1 ;;
      130) flow_cancel password ;;
      *) return "$status" ;;
    esac
    status=0
    second=$(gum input --password --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt 'Confirm> ') || status=$?
    case $status in
      0) ;;
      1)
        first='' second='' failure=''
        step 'Password'
        continue
        ;;
      130) flow_cancel password ;;
      *) return "$status" ;;
    esac
    if [[ -n $first && $first == "$second" ]]; then
      FLOW_PASSWORD=$first
      return 0
    fi
    if [[ -z $first ]]; then failure="Password can't be blank"; else failure="Passwords didn't match"; fi
    step 'Password'
  done
}
