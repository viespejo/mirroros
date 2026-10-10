#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/localization.sh
source "$ROOT/lib/localization.sh"
GUIDE_DIR=$ROOT
PADDING=0
before=$(env | grep -E '^(LANG|LC_[A-Z_]+)=' || :)
mock_status=0
mock_choice='Spain'
expected_selected='Follow system language'
gum() {
  if [[ $1 == choose ]]; then
    [[ "$*" == *"--selected $expected_selected"* ]] || return 6
    printf '%s\n' "$mock_choice"
    return "$mock_status"
  fi
}
initialize_localization_preview
[[ $system_lang == en_US.UTF-8 && $regional_format == follow && $format_locale == en_US.UTF-8 && ${#enabled_locales[@]} == 1 ]]
regional_formats_form
[[ $system_lang == en_US.UTF-8 && $regional_format == es_ES.UTF-8 && ${enabled_locales[*]} == 'en_US.UTF-8 es_ES.UTF-8' ]]
[[ $lc_time == es_ES.UTF-8 && $lc_numeric == es_ES.UTF-8 && $lc_monetary == es_ES.UTF-8 && $lc_measurement == es_ES.UTF-8 ]]
expected_selected='English (US)'
mock_choice='Spanish (Spain)'
system_language_form
[[ $system_lang == es_ES.UTF-8 && $format_locale == es_ES.UTF-8 && ${#enabled_locales[@]} == 1 ]]
expected_selected='Spain'
mock_choice='United States'
regional_formats_form
[[ ${enabled_locales[*]} == 'es_ES.UTF-8 en_US.UTF-8' && $format_locale == en_US.UTF-8 ]]
expected_selected='United States'
mock_choice='Follow system language'
regional_formats_form
[[ $regional_format == follow && $format_locale == es_ES.UTF-8 ]]
expected_selected='Spanish (Spain)'
mock_choice='English (US)'
system_language_form
[[ $format_locale == en_US.UTF-8 && ${enabled_locales[*]} == en_US.UTF-8 ]]
for mock_status in 1 130 5; do
  expected_selected='English (US)'
  mock_choice='Spanish (Spain)'
  status=0; system_language_form || status=$?
  [[ $status == "$mock_status" && $system_lang == en_US.UTF-8 && $format_locale == en_US.UTF-8 ]]
  expected_selected='Follow system language'
  mock_choice='Spain'
  status=0; regional_formats_form || status=$?
  [[ $status == "$mock_status" && $regional_format == follow && ${enabled_locales[*]} == en_US.UTF-8 ]]
done
mock_status=0
mock_choice='Unknown'
status=0; regional_formats_form || status=$?
[[ $status == 6 && $regional_format == follow ]]
expected_selected='English (US)'
status=0; system_language_form || status=$?
[[ $status == 6 && $system_lang == en_US.UTF-8 ]]
after=$(env | grep -E '^(LANG|LC_[A-Z_]+)=' || :)
[[ $before == "$after" ]]
printf 'Localization checks passed.\n'
