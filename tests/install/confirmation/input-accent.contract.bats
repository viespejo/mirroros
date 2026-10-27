# Approved input accents only: synthetic values, no planning, accounts, credentials, or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced forms consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  : > "$CALLS"
  INPUT_STATUS=1
  FLOW_PREVIEW=synthetic-preview
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    if [[ $1 == input ]]; then return "$INPUT_STATUS"; fi
  }
  flow_choice() {
    case $1 in
      hostname) printf 'synthetic-host\n' ;;
      user_name) printf 'synthetic_user\n' ;;
      swapfile_size) printf '4096\n' ;;
      *) return 6 ;;
    esac
  }
  flow_assistant() {
    [[ $1 == get && $2 == "$FLOW_PREVIEW" ]] || return 6
    case $3 in
      options.swapfile_size.minimum) printf '512\n' ;;
      options.swapfile_size.maximum) printf '8192\n' ;;
      *) return 6 ;;
    esac
  }
  flow_apply_choice() { printf 'apply %s\n' "$*" >> "$CALLS"; return 6; }
}

@test "input-accent hostname username and swapfile preserve prompts values and native help" {
  run hostname_form
  [ "$status" -eq 1 ]
  run username_form
  [ "$status" -eq 1 ]
  run swapfile_size_form
  [ "$status" -eq 1 ]
  grep -qxF "gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value synthetic-host --placeholder Letters, digits, and dashes (or return for 'mirroros') --prompt Hostname> " "$CALLS"
  grep -qxF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value synthetic_user --placeholder Lowercase letters, digits, underscores, or dashes --prompt Username> ' "$CALLS"
  grep -qxF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value 4096 --placeholder Size in MiB --prompt Swapfile size (MiB)> ' "$CALLS"
}

@test "input-accent incomplete fields retain Esc and Ctrl+C without applying values" {
  local form code
  for form in hostname_form username_form swapfile_size_form; do
    for code in 1 130; do
      INPUT_STATUS=$code
      run "$form"
      [ "$status" -eq "$code" ]
    done
  done
  run grep -q '^apply ' "$CALLS"
  [ "$status" -eq 1 ]
}
