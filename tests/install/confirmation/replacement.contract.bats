# Isolated replacement forms: synthetic providers only, no engine or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Shared state and doubles are consumed by sourced forms.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  FLOW_TMP="$BATS_TEST_TMPDIR" FLOW_PREVIEW=synthetic-preview FLOW_PLAN_FILE=synthetic-plan
  FLOW_PROFILE_STATUS=unqualified CALLS="${BATS_TEST_TMPDIR}/calls"
  ROOT_ID=10000000-0000-4000-8000-000000000002
  ROOT_TYPED=$ROOT_ID ROOT_STATUS=0 DISK_TYPED=vda MODE_COUNT=2 CHOOSE_STATUS=0
  MODE_ANSWER='Replace existing MirrorOS'
  declare -gA FLOW_REVIEW=([disk]='Synthetic disk' [storage_option]=btrfs-limine [storage_tier]=default
    [plan_reference]=0123456789ab [target_mode]=replace_installation [target_mode_label]='Replace existing MirrorOS'
    [target_format_esp]='/dev/vda1 PARTUUID=synthetic-esp' [target_format_root]="/dev/vda2 PARTUUID=$ROOT_ID"
    [target_preserve]='/dev/vda3, /dev/vda4' [root_partuuid]="$ROOT_ID")
  TERM_WIDTH=100 PADDING_LEFT=10 PADDING='0 0 0 10'
  : > "$CALLS"
  flow_assistant() {
    case $1 in
      target-modes)
        printf 'whole_disk\n'
        if [[ $MODE_COUNT == 2 ]]; then printf 'replace_installation\n'; fi
        ;;
      get)
        case $3 in
          options.replace_root_partuuid.0.value) printf '%s\n' "$ROOT_ID" ;;
          target.disk.path) printf '/dev/vda\n' ;;
          target.disk.by_id) printf 'synthetic-disk\n' ;;
          *) return 6 ;;
        esac
        ;;
      *) return 6 ;;
    esac
  }
  flow_choice() { printf 'whole_disk\n'; }
  screen_apply_listed() { printf 'apply %s %s\n' "$1" "$2" >> "$CALLS"; }
  ui_choose() { printf 'choose %s\n' "$*" >> "$CALLS"; printf '%s\n' "$MODE_ANSWER"; return "$CHOOSE_STATUS"; }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      input)
        if [[ $* == *'Root PARTUUID> '* ]]; then
          printf '%s\n' "$ROOT_TYPED"
          return "$ROOT_STATUS"
        fi
        printf '%s\n' "$DISK_TYPED"
        ;;
    esac
  }
  flow_reached() { :; }
  flow_device_name() { FLOW_DEVICE_NAME=vda; }
  flow_load_review() { :; }
  flow_cancel() { printf 'cancel\n' >> "$CALLS"; exit 3; }
  flow_mismatch() { printf 'mismatch\n' >> "$CALLS"; exit 3; }
  flow_confirmed() { printf 'confirmed\n' >> "$CALLS"; }
}

@test "replacement mode is offered only for a preview with a valid candidate" {
  run target_mode_form
  [ "$status" -eq 0 ]
  grep -qxF "apply replace_root_partuuid $ROOT_ID" "$CALLS"
  grep -qF 'Whole disk Replace existing MirrorOS' "$CALLS"
  : > "$CALLS"
  MODE_COUNT=1
  run target_mode_form
  [ "$status" -eq 0 ]
  grep -qxF 'apply target_mode whole_disk' "$CALLS"
  run grep -q '^choose ' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "replacement mode preserves whole-disk choice and propagates Back and Ctrl+C without applying" {
  MODE_ANSWER='Whole disk'
  run target_mode_form
  [ "$status" -eq 0 ]
  grep -qxF 'apply target_mode whole_disk' "$CALLS"
  for code in 1 130; do
    : > "$CALLS"
    CHOOSE_STATUS=$code
    run target_mode_form
    [ "$status" -eq "$code" ]
    run grep -q '^apply ' "$CALLS"
    [ "$status" -eq 1 ]
  done
}

@test "replacement confirmation shows exact scope and requires disk plus full root PARTUUID" {
  run confirmation_form
  [ "$status" -eq 0 ]
  grep -qF '/dev/vda1 PARTUUID=synthetic-esp' "$CALLS"
  grep -qF "/dev/vda2 PARTUUID=$ROOT_ID" "$CALLS"
  grep -qF '/dev/vda3, /dev/vda4' "$CALLS"
  grep -qF 'This will erase only the selected MirrorOS ESP and root partitions.' "$CALLS"
  run grep -qF 'This will erase all existing content on this disk.' "$CALLS"
  [ "$status" -eq 1 ]
  grep -qF -- '--default=false --affirmative Yes, replace --negative No' "$CALLS"
  [ "$(grep -c '^gum input ' "$CALLS")" -eq 2 ]
  grep -qxF confirmed "$CALLS"
}

@test "replacement rejects short wrong or empty root identity without retry or approval" {
  for value in 00000002 wrong '' "$ROOT_ID "; do
    : > "$CALLS"
    ROOT_TYPED=$value
    run confirmation_form
    [ "$status" -eq 3 ]
    [ "$(grep -c '^gum input ' "$CALLS")" -eq 2 ]
    grep -qxF mismatch "$CALLS"
    run grep -qxF confirmed "$CALLS"
    [ "$status" -eq 1 ]
  done
}

@test "replacement root prompt Esc and Ctrl+C cancel and wrong disk never reaches it" {
  for code in 1 130; do
    : > "$CALLS"
    ROOT_STATUS=$code
    run confirmation_form
    [ "$status" -eq 3 ]
    grep -qxF cancel "$CALLS"
    run grep -qxF confirmed "$CALLS"
    [ "$status" -eq 1 ]
  done
  : > "$CALLS"
  ROOT_STATUS=0 DISK_TYPED=wrong
  run confirmation_form
  [ "$status" -eq 3 ]
  [ "$(grep -c '^gum input ' "$CALLS")" -eq 1 ]
  run grep -qxF confirmed "$CALLS"
  [ "$status" -eq 1 ]
}
