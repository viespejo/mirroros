#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Screen state is read by the flow library; live preparation state is set by live.sh, which the orchestrator loads.
# The screens of the guided live installer, in the order of the frozen reference
# (prototypes/frontend/guided-installer/): text, widgets, and navigation are reproduced, with only the
# integration differences listed in contracts/installation-confirmation.md. Screen text adapted from
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
    gum style --foreground 8 --padding "$PADDING" 'A guided installation of MirrorOS.'
    gum style --foreground 8 --padding "$PADDING" "Installation keyboard: $live_keyboard_label ($live_keyboard_source)"
    gum style --foreground 8 --padding "$PADDING" 'This layout is for the live installation, not the installed system.'
    action=$(gum choose --show-help --height 2 --selected 'Continue' 'Continue' 'Change installation keyboard layout') || return $?
    case $action in
      Continue) return 0 ;;
      'Change installation keyboard layout')
        step 'Installation keyboard layout'
        status=0
        live_console_keyboard_form || status=$?
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
  action=$(gum choose --show-help --height 2 --selected 'Continue' --header 'Machine check' 'Continue' 'Cancel') || return $?
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
  gum style --padding "$PADDING" 'The installation plan will use the entire selected disk.'
  choice=$(gum choose --show-help --height 5 --selected "$selected" --header 'Select install disk' "${labels[@]}") || return $?
  for index in "${!labels[@]}"; do
    if [[ ${labels[index]} == "$choice" ]]; then
      screen_apply_listed target_disk "${keys[index]}" || status=$?
      return "$status"
    fi
  done
  return 6
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
  gum style --foreground 8 --padding "$PADDING" 'Planned layout: GPT, 2 GiB FAT32 EFI partition, unencrypted root.' 'Selection only: no partitioning, formatting, or erasure runs here.'
  gum style --padding "$PADDING" 'ext4: recovery from independent rescue media.' 'Btrfs + systemd-boot: root snapshots; restore from rescue media.' 'Btrfs + Limine: snapshot boot; persistent restore remains unvalidated.'
  choice=$(gum choose --show-help --height 5 --selected "$selected" --header 'Select storage layout' "${labels[@]}") || return $?
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
    choice=$(gum choose --show-help --height 3 --selected "$selected" --header 'Hibernation' Enabled Disabled) || return $?
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
  local value normalized minimum maximum status
  value=$(flow_choice swapfile_size) || return 6
  minimum=$(flow_assistant get "$FLOW_PREVIEW" options.swapfile_size.minimum) || return 6
  maximum=$(flow_assistant get "$FLOW_PREVIEW" options.swapfile_size.maximum) || return 6
  while true; do
    gum style --foreground 8 --padding "$PADDING" 'The swapfile holds the hibernation image and also serves as fallback swap after zram.' 'The default does not guarantee hibernation for every workload.'
    gum style --padding "$PADDING" "Enter an integer from $minimum to $maximum MiB." 'A real plan checks that the complete layout fits the selected disk.'
    value=$(gum input --show-help --value "$value" --placeholder 'Size in MiB' --prompt 'Swapfile size (MiB)> ') || return $?
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
    gum style --foreground 1 --padding "$PADDING" "Use a whole number from $minimum to $maximum MiB."
  done
}

timezone_form() {
  local value current
  current=$(flow_choice timezone) || return 6
  value=$(printf '%s\n' Europe/Madrid Europe/London UTC | gum choose --show-help --height 10 --selected "$current" --header 'Timezone') || return $?
  screen_apply_listed timezone "$value"
}

system_language_form() {
  local choice value current
  current=$(flow_choice lang) || return 6
  gum style --foreground 8 --padding "$PADDING" 'Choose the default language for system messages and applications.' 'Applications may use their own language preference. Keyboard is separate.'
  choice=$(gum choose --show-help --height 5 --selected "$(language_label_for "$current")" --header 'System language' 'English (US)' 'Spanish (Spain)') || return $?
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
  gum style --padding "$PADDING" "Follow system language currently means: $(language_label_for "$language")."
  choice=$(gum choose --show-help --height 5 --selected "$(formats_label_for "$current")" --header 'Regional formats' 'Follow system language' 'Spain' 'United States') || return $?
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
  choice=$(printf '%s\n' 'English (US)' 'Spanish (ES)' | gum choose --show-help --height 10 --selected "$(keyboard_label_for "$current")" --header 'Select keyboard layout') || return $?
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
    value=$(gum input --show-help --value "$value" --placeholder "Letters, digits, and dashes (or return for 'mirroros')" --prompt 'Hostname> ') || return $?
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
  done
}

username_form() {
  local value status
  value=$(flow_choice user_name) || return 6
  while true; do
    gum style --foreground 8 --padding "$PADDING" "Choose the username you'll use to sign in." 'This user belongs to wheel and can administer the system with sudo.'
    value=$(gum input --show-help --value "$value" --placeholder 'Lowercase letters, digits, underscores, or dashes' --prompt 'Username> ') || return $?
    status=0
    flow_apply_choice user_name "$value" || status=$?
    case $status in
      0) return 0 ;;
      1) ;;
      *) return "$status" ;;
    esac
    step "Let's setup your user account..."
    gum style --foreground 1 --padding "$PADDING" 'Use 1-32 characters, starting with a lowercase letter or underscore.' 'Only lowercase letters, digits, underscores, dashes, and an optional final $.' 'The name root is reserved.'
  done
}

root_account_form() {
  local choice value current
  current=$(flow_choice root_account) || return 6
  gum style --foreground 8 --padding "$PADDING" 'Locked root: use your wheel-group user with sudo for administration.' 'Password enabled: root receives the same password as your user.'
  gum style --padding "$PADDING" 'One password is asked, with repetition, after you approve the plan.'
  if [[ $current == password ]]; then
    gum style --foreground 8 --padding "$PADDING" 'Sharing the password does not give root an independent recovery credential.'
  fi
  choice=$(gum choose --show-help --height 5 --selected "$(root_label_for "$current")" --header 'Root account' 'Locked (default)' 'Password login enabled') || return $?
  case $choice in
    'Locked (default)') value=locked ;;
    'Password login enabled') value=password ;;
    *) return 6 ;;
  esac
  screen_apply_listed root_account "$value"
}

# Prints the review rows with the reference's layout. The values come from the validated plan.
review_rows() {
  local field value
  while IFS= read -r field && IFS= read -r value; do
    printf '%s%-12s %s\n' "$PADDING_LEFT_SPACES" "$field" "$value"
  done < <(printf '%s\n' \
    Machine "${FLOW_REVIEW[machine]}" \
    Disk "${FLOW_REVIEW[disk]}" \
    Storage "$(storage_label_for "${FLOW_REVIEW[storage_option]}" "${FLOW_REVIEW[storage_tier]}")" \
    Hibernation "${FLOW_REVIEW[hibernation_label]}" \
    Timezone "${FLOW_REVIEW[timezone]}" \
    Language "${FLOW_REVIEW[lang]}" \
    Formats "$(formats_label_for "${FLOW_REVIEW[regional_format]}") (${FLOW_REVIEW[format_locale]})" \
    Locales "${FLOW_REVIEW[locales]}" \
    Internet "$live_network_status" \
    Username "${FLOW_REVIEW[user_name]}" \
    Root "$(root_label_for "${FLOW_REVIEW[root_account]}")" \
    Hostname "${FLOW_REVIEW[hostname]}" \
    Keyboard "${FLOW_REVIEW[console_keymap]}" \
    Plan "${FLOW_REVIEW[plan_reference]}")
}

# The review: it generates (or regenerates) and validates the plan on entry, then offers confirmation,
# inspection of the complete plan, or Back. Nothing here authorizes anything.
review_form() {
  local choice status complete
  flow_ensure_plan || return $?
  flow_reached review
  flow_load_review
  while true; do
    review_rows
    echo
    if [[ ${FLOW_REVIEW[hibernation]} == false ]]; then
      gum style --foreground 8 --padding "$PADDING" 'Hibernation is disabled: no swapfile will be created.'
    fi
    if [[ ${FLOW_REVIEW[swapfile_below_ram]} == true ]]; then
      gum style --foreground 3 --padding "$PADDING" 'Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space.'
    fi
    gum style --foreground 8 --padding "$PADDING" 'Review only: this does not approve a plan or authorize disk changes.' 'Next: confirm the disk to erase, then set the password. Installation starts after that.'
    choice=$(gum choose --show-help --height 3 --selected 'Continue to confirmation' --header 'Review navigation' 'Continue to confirmation' 'Inspect complete plan' 'Back') || return $?
    case $choice in
      'Continue to confirmation') return 0 ;;
      'Inspect complete plan')
        complete="${FLOW_TMP}/complete-plan.txt"
        flow_cli review complete "$FLOW_PLAN_FILE" > "$complete" || return 6
        status=0
        gum pager < "$complete" || status=$?
        case $status in
          0 | 1) ;;
          *) return "$status" ;;
        esac
        step 'Review your choices'
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
  gum style --padding "$PADDING" "Disk: ${FLOW_REVIEW[disk]}" "Path: $path" "Disk ID: ${identity:-not reported}" "New layout: $(storage_label_for "${FLOW_REVIEW[storage_option]}" "${FLOW_REVIEW[storage_tier]}")" "Plan reference: ${FLOW_REVIEW[plan_reference]}"
  gum style --foreground 1 --padding "$PADDING" 'This will erase all existing content on this disk.'
  status=0
  gum confirm --default=false --affirmative 'Yes, erase' --negative 'No' "Erase $path and apply plan ${FLOW_REVIEW[plan_reference]}?" || status=$?
  case $status in
    0) ;;
    1 | 130) flow_cancel confirmation ;;
    *) return "$status" ;;
  esac
  typed=$(gum input --show-help --header "Type the device name ($name) to confirm." --prompt 'Device name> ') || status=$?
  case $status in
    0) ;;
    1 | 130) flow_cancel confirmation ;;
    *) return "$status" ;;
  esac
  if [[ $typed != "$name" ]]; then
    flow_mismatch
  fi
  flow_confirmed
}

# The single account password, asked twice with a protected prompt. It is kept only in FLOW_PASSWORD (a global,
# never exported, never logged, never recorded) until the engine invocation consumes it. A blank or mismatching
# pair asks both fields again. Esc discards the value and returns to the review; Ctrl+C cancels.
password_form() {
  local first second root_message status failure
  flow_reached password
  flow_load_review
  FLOW_PASSWORD=''
  case ${FLOW_REVIEW[root_account]} in
    locked) root_message='Root stays locked; no password is assigned to root.' ;;
    password) root_message='Root receives the same password as your user, not a second password.' ;;
    *) return 6 ;;
  esac
  while true; do
    gum style --padding "$PADDING" "One password is used for ${FLOW_REVIEW[user_name]}." 'Your user can administer the system with sudo.' "$root_message"
    gum style --foreground 8 --padding "$PADDING" 'Passwords follow real bound plan/disk confirmation, before disk writes.' 'Cancelling password entry must prevent installation from starting.' 'Passwords never belong in the plan, review, or retained evidence.'
    status=0
    first=$(gum input --password --show-help --prompt 'Password> ') || status=$?
    case $status in
      0) ;;
      1) return 1 ;;
      130) flow_cancel password ;;
      *) return "$status" ;;
    esac
    status=0
    second=$(gum input --password --show-help --prompt 'Confirm> ') || status=$?
    case $status in
      0) ;;
      1) return 1 ;;
      130) flow_cancel password ;;
      *) return "$status" ;;
    esac
    if [[ -n $first && $first == "$second" ]]; then
      FLOW_PASSWORD=$first
      return 0
    fi
    if [[ -z $first ]]; then failure="Password can't be blank"; else failure="Passwords didn't match"; fi
    step 'Password'
    gum style --foreground 1 --padding "$PADDING" "$failure"
  done
}
