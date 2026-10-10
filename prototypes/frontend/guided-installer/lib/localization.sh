# shellcheck shell=bash
# Preview-only localization choices. No locale generation or environment changes.

resolve_localization_preview() {
  # shellcheck disable=SC2154 # Choice state is initialized by the entry point.
  case $system_lang in
    en_US.UTF-8) language_label='English (US)' ;;
    es_ES.UTF-8) language_label='Spanish (Spain)' ;;
    *) return 6 ;;
  esac
  # shellcheck disable=SC2154 # Choice state is initialized by the entry point.
  case $regional_format in
    follow) formats_label='Follow system language'; format_locale=$system_lang ;;
    es_ES.UTF-8) formats_label='Spain'; format_locale=es_ES.UTF-8 ;;
    en_US.UTF-8) formats_label='United States'; format_locale=en_US.UTF-8 ;;
    *) return 6 ;;
  esac
  enabled_locales=("$system_lang")
  if [[ $format_locale != "$system_lang" ]]; then enabled_locales+=("$format_locale"); fi
  # These lowercase variables describe future settings; never export LC_* or LC_ALL.
  # shellcheck disable=SC2034 # Preview tests consume individual category values.
  lc_time=$format_locale lc_numeric=$format_locale lc_monetary=$format_locale lc_measurement=$format_locale
}

initialize_localization_preview() {
  system_lang=$(jq -er '.policy.lang.value | select(type == "string")' "$GUIDE_DIR/fixtures/installation-policy.json") || return 6
  regional_format=follow
  resolve_localization_preview
}

system_language_form() {
  local choice value
  gum style --foreground 8 --padding "$PADDING" 'Choose the default language for system messages and applications.' 'Applications may use their own language preference. Keyboard is separate.'
  choice=$(gum choose --show-help --height 5 --selected "$language_label" --header 'System language' 'English (US)' 'Spanish (Spain)') || return $?
  case $choice in
    'English (US)') value=en_US.UTF-8 ;;
    'Spanish (Spain)') value=es_ES.UTF-8 ;;
    *) return 6 ;;
  esac
  system_lang=$value
  resolve_localization_preview
}

regional_formats_form() {
  local choice value
  gum style --foreground 8 --padding "$PADDING" 'Choose formats for dates, numbers, currency, and measurement units.' 'This does not change the language of messages or your keyboard.'
  gum style --padding "$PADDING" "Follow system language currently means: $language_label."
  choice=$(gum choose --show-help --height 5 --selected "$formats_label" --header 'Regional formats' 'Follow system language' 'Spain' 'United States') || return $?
  case $choice in
    'Follow system language') value=follow ;;
    'Spain') value=es_ES.UTF-8 ;;
    'United States') value=en_US.UTF-8 ;;
    *) return 6 ;;
  esac
  regional_format=$value
  resolve_localization_preview
}
