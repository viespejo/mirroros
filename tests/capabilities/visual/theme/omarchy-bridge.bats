#!/usr/bin/env bats
# Shared bridge preparation, independent of either application consumer.
setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home"
  mkdir -p "$HOME" "$WORK/bin"
  export PATH="$WORK/bin:$PATH"
  SCRIPT="$ROOT/capabilities/visual/theme/omarchy-bridge"
  BRIDGE="$HOME/.local/state/omarchy"
  cat > "$WORK/bin/systemctl" <<'EOF'
#!/usr/bin/bash
[[ "$*" == '--user show-environment' ]] || exit 97
[[ "${MANAGER_UNAVAILABLE:-false}" != true ]] || exit 1
printf '%s\n' "${MANAGER_ENV:-}"
EOF
  chmod 0755 "$WORK/bin/systemctl"
}
teardown() { rm -rf -- "$WORK"; }

@test "bridge check is read-only and apply creates exactly the expected links then remains unchanged" {
  run bash "$SCRIPT" check --default
  [ "$status" -eq 1 ]
  [ ! -e "$HOME/.local" ]
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 0 ]
  [ "$output" = changed ]
  [ "$(find "$BRIDGE" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)" = $'current\ncurrent/theme\ncurrent/theme.name' ]
  [ "$(readlink "$BRIDGE/current/theme")" = "$HOME/.local/state/mirroros/current/theme" ]
  [ "$(readlink "$BRIDGE/current/theme.name")" = "$HOME/.local/state/mirroros/current/theme/theme.name" ]
  [ "$(stat -c %a "$BRIDGE")" = 755 ]
  local before
  before="$(stat -c '%i:%Y' "$BRIDGE/current/theme")"
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 0 ]
  [ "$output" = unchanged ]
  [ "$(stat -c '%i:%Y' "$BRIDGE/current/theme")" = "$before" ]
  run bash "$SCRIPT" check --default
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! compgen -G "$HOME/.local/state/.omarchy.mirroros.*"
}

@test "bridge uses manager homes with spaces rather than the administrator's environment" {
  export XDG_STATE_HOME=/administrator/state XDG_CONFIG_HOME=/administrator/config
  export MANAGER_ENV="XDG_STATE_HOME=$HOME/session state"$'\n'"XDG_CONFIG_HOME=$HOME/session config"
  run bash "$SCRIPT" apply --session
  [ "$status" -eq 0 ]
  [ "$(readlink "$BRIDGE/current/theme")" = "$HOME/session state/mirroros/current/theme" ]
  run bash "$SCRIPT" check --session
  [ "$status" -eq 0 ]
}

@test "bridge default mode and unavailable manager retain default state resolution" {
  export XDG_STATE_HOME=/administrator/state XDG_CONFIG_HOME=/administrator/config
  export MANAGER_ENV='XDG_STATE_HOME=/session/state' MANAGER_UNAVAILABLE=true
  run bash "$SCRIPT" apply --session
  [ "$status" -eq 0 ]
  [ "$(readlink "$BRIDGE/current/theme")" = "$HOME/.local/state/mirroros/current/theme" ]
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 0 ]
  [ "$output" = unchanged ]
}

@test "bridge rejects relative and duplicate manager homes without creating state" {
  local environment
  for environment in 'XDG_STATE_HOME=relative' 'XDG_CONFIG_HOME=relative' \
    $'XDG_STATE_HOME=/one\nXDG_STATE_HOME=/two' $'XDG_CONFIG_HOME=/one\nXDG_CONFIG_HOME=/two'; do
    export MANAGER_ENV="$environment"
    run bash "$SCRIPT" apply --session
    [ "$status" -eq 4 ]
    [ ! -e "$BRIDGE" ]
  done
}

@test "bridge preserves conflicting files directories and dangling symlinks for apply and check" {
  mkdir -p "${BRIDGE%/*}"
  local kind mode
  for kind in file directory link; do
    case "$kind" in
      file) printf 'keep\n' > "$BRIDGE" ;;
      directory) mkdir "$BRIDGE"; printf 'keep\n' > "$BRIDGE/personal" ;;
      link) ln -s /missing/personal "$BRIDGE" ;;
    esac
    for mode in apply check; do
      run bash "$SCRIPT" "$mode" --default
      [ "$status" -eq 4 ]
      [[ "$output" == *'left untouched'* ]]
      case "$kind" in
        file) [ "$(< "$BRIDGE")" = keep ] ;;
        directory) [ "$(< "$BRIDGE/personal")" = keep ] ;;
        link) [ "$(readlink "$BRIDGE")" = /missing/personal ] ;;
      esac
    done
    rm -rf -- "$BRIDGE"
  done
}

@test "bridge rejects extra entries and changed link targets without rewriting them" {
  bash "$SCRIPT" apply --default
  printf 'keep\n' > "$BRIDGE/current/personal"
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 4 ]
  [ "$(< "$BRIDGE/current/personal")" = keep ]
  rm "$BRIDGE/current/personal" "$BRIDGE/current/theme"
  ln -s /personal/theme "$BRIDGE/current/theme"
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 4 ]
  [ "$(readlink "$BRIDGE/current/theme")" = /personal/theme ]
}

@test "bridge preserves a destination appearing during atomic publication and cleans staging" {
  cat > "$WORK/bin/mv" <<'EOF'
#!/usr/bin/bash
mkdir "$HOME/.local/state/omarchy"
printf 'keep\n' > "$HOME/.local/state/omarchy/personal"
exec /usr/bin/mv "$@"
EOF
  chmod 0755 "$WORK/bin/mv"
  run bash "$SCRIPT" apply --default
  [ "$status" -eq 4 ]
  [ "$(< "$BRIDGE/personal")" = keep ]
  [ ! -e "$BRIDGE/current" ]
  ! compgen -G "$HOME/.local/state/.omarchy.mirroros.*"
}

@test "bridge rejects invalid preparation usage" {
  run bash "$SCRIPT" apply --unknown
  [ "$status" -eq 6 ]
  [[ "$output" == *'Usage:'* ]]
  [ ! -e "$BRIDGE" ]
}
