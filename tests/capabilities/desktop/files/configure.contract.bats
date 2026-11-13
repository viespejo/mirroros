#!/usr/bin/env bats
# desktop/files through the configure entry point, in both contexts, with disposable roots and test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/files)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  export CFG_TEST_USER_ENVIRONMENT=$'WAYLAND_DISPLAY=wayland-1\nXDG_CURRENT_DESKTOP=Hyprland'
  # The user manager environment read by prepare-strata --session; any other systemctl use is unexpected.
  cat > "$CFG_TEST_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/bash
printf 'systemctl %s\n' "$*" >> "$CFG_TEST_CALLS"
[[ "$*" == '--user show-environment' ]] || exit 97
printf '%s\n' "$CFG_TEST_USER_ENVIRONMENT"
EOF
  chmod 0755 "$CFG_TEST_DIR/bin/systemctl"
  mkdir -p "$CFG_TEST_DIR/owners"
}
teardown() { cfg_test_teardown; }
refute() { if "$@"; then return 1; fi; }

# The pacman double records installations without extracting payloads; this is the recipe's FileManager1 file.
files_strata_payload() {
  local services="$1/usr/share/dbus-1/services"
  mkdir -p "$services"
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/strata --gapplication-service\n' \
    > "$services/io.github.lgse.Strata.FileManager1.service"
  printf 'strata-bin\n' > "$CFG_TEST_DIR/owners/io.github.lgse.Strata.FileManager1.service"
}

files_nautilus_payload() {
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/nautilus --gapplication-service\n' \
    > "$1/usr/share/dbus-1/services/org.freedesktop.FileManager1.service"
  printf 'nautilus\n' > "$CFG_TEST_DIR/owners/org.freedesktop.FileManager1.service"
}

files_bridge_is() {
  local state="$1" bridge="$CFG_TEST_HOME/.local/state/omarchy"
  [ "$(find "$bridge" -mindepth 1 -printf '%P\n' | LC_ALL=C sort | tr '\n' ' ')" = 'current current/theme current/theme.name ' ]
  [ "$(readlink "$bridge/current/theme")" = "$state/mirroros/current/theme" ]
  [ "$(readlink "$bridge/current/theme.name")" = "$state/mirroros/current/theme/theme.name" ]
}

@test "running configure installs Strata from the recipe, prepares it once and reruns unchanged" {
  local root="$MIRROROS_CONFIGURE_ROOT" cache="$CFG_TEST_HOME/.cache/mirroros/strata"
  files_strata_payload "$root"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ] || { cat "$CFG_TEST_DIR/first/configure.log" >&3; return 1; }
  [[ "$output" == *'desktop/files: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/xdg-user-dirs" ]
  [ ! -e "$CFG_TEST_INSTALLED/nautilus" ]
  refute grep -q nautilus "$CFG_TEST_CALLS"
  [ "$(grep -c '^makepkg --force --noconfirm --nocolor$' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF "pacman -U --needed --noconfirm -- $cache/strata-bin-1.2.1-1.1-x86_64.pkg.tar.zst" "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_INSTALLED/strata-bin")" = 1.2.1-1.1 ]
  refute compgen -G "$cache/.build.*" > /dev/null
  grep -q $'^strata-bin\t1.2.1-1.1\tlocal$' "$CFG_TEST_DIR/first/packages.tsv"
  grep -q $'^strata\thttps://github.com/lgse/strata/releases/download/v1.2.1/strata-1.2.1-x86_64-unknown-linux-gnu.tar.gz\tv1.2.1\t491e6ba9735e821f9f49910ffd2582076196865c\t1.2.1-1.1$' \
    "$CFG_TEST_DIR/first/sources.tsv"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/files/files-cwd" "$root/usr/share/mirroros/files/files-cwd"
  [ "$(stat -c %a "$root/usr/share/mirroros/files/files-cwd")" = 755 ]
  files_bridge_is "$CFG_TEST_HOME/.local/state"
  [ "$(< "$CFG_TEST_HOME/.config/strata/portal-opt-in-v1")" = 1 ]
  [ "$(grep -c '^strata --dismiss-portal-prompt$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ ! -e "$CFG_TEST_HOME/.config/strata/settings.toml" ]
  refute grep -qE '^(sudo|systemctl (start|restart|reload|--user (start|restart|reload)))' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/files: unchanged'* ]]
  refute grep -qE '^(makepkg|pacman -U|strata) ' "$CFG_TEST_CALLS"
  grep -q $'^strata-bin\t1.2.1-1.1\tlocal$' "$CFG_TEST_DIR/rerun/packages.tsv"
  files_bridge_is "$CFG_TEST_HOME/.local/state"
  cfg_test_no_install
}

@test "target configure installs Strata inside the target with the default XDG homes" {
  cfg_test_target_context
  local root="$CFG_TEST_TARGET_ROOT"
  files_strata_payload "$root"
  export CFG_TEST_USER_ENVIRONMENT='XDG_STATE_HOME=/session/state'
  run "$CFG_TEST_ENTRY" --target-root "$root" --user alice
  [ "$status" -eq 0 ] || { cat "$root"/var/log/mirroros/configure/*/configure.log >&3; return 1; }
  grep -qF "arch-chroot $root env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/xdg-user-dirs" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $root env SNAP_PAC_SKIP=y pacman -U --needed --noconfirm -- $CFG_TEST_HOME/.cache/mirroros/strata/strata-bin-1.2.1-1.1-x86_64.pkg.tar.zst" "$CFG_TEST_CALLS"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/files/files-cwd" "$root/usr/share/mirroros/files/files-cwd"
  files_bridge_is "$CFG_TEST_HOME/.local/state"
  [ -f "$CFG_TEST_HOME/.config/strata/portal-opt-in-v1" ]
  refute grep -q '^systemctl ' "$CFG_TEST_CALLS"
}

@test "running configure follows the user manager's state and configuration homes" {
  files_strata_payload "$MIRROROS_CONFIGURE_ROOT"
  export CFG_TEST_USER_ENVIRONMENT="XDG_STATE_HOME=$CFG_TEST_HOME/state"$'\n'"XDG_CONFIG_HOME=$CFG_TEST_HOME/config"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  files_bridge_is "$CFG_TEST_HOME/state"
  [ -f "$CFG_TEST_HOME/config/strata/portal-opt-in-v1" ]
  [ ! -e "$CFG_TEST_HOME/.config/strata" ]
  grep -qx 'systemctl --user show-environment' "$CFG_TEST_CALLS"
}

@test "existing omarchy state is a preserved conflict and an existing offer marker is kept" {
  files_strata_payload "$MIRROROS_CONFIGURE_ROOT"
  mkdir -p "$CFG_TEST_HOME/.local/state/omarchy/current" "$CFG_TEST_HOME/.config/strata"
  printf 'tokyo-night\n' > "$CFG_TEST_HOME/.local/state/omarchy/current/theme.name"
  printf 'kept\n' > "$CFG_TEST_HOME/.config/strata/portal-opt-in-v1"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  grep -qF "Conflict: $CFG_TEST_HOME/.local/state/omarchy is not the MirrorOS theme bridge for Strata" \
    "$CFG_TEST_DIR/conflict/configure.log"
  [ "$(< "$CFG_TEST_HOME/.local/state/omarchy/current/theme.name")" = tokyo-night ]
  [ ! -e "$CFG_TEST_HOME/.local/state/omarchy/current/theme" ]
  [ "$(< "$CFG_TEST_HOME/.config/strata/portal-opt-in-v1")" = kept ]
  refute grep -q '^strata ' "$CFG_TEST_CALLS"
  refute compgen -G "$CFG_TEST_HOME/.local/state/.omarchy.mirroros.*" > /dev/null
  rm -r "$CFG_TEST_HOME/.local/state/omarchy"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  files_bridge_is "$CFG_TEST_HOME/.local/state"
}

@test "a second FileManager1 owner fails naming both owners and the removal action, then a rerun passes" {
  local root="$MIRROROS_CONFIGURE_ROOT"
  files_strata_payload "$root"
  files_nautilus_payload "$root"
  : > "$CFG_TEST_INSTALLED/nautilus"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/owners-run"
  [ "$status" -eq 4 ]
  local log="$CFG_TEST_DIR/owners-run/configure.log"
  grep -qF 'Conflict: org.freedesktop.FileManager1 has 2 packaged owners:' "$log"
  grep -qF '/usr/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service (strata-bin)' "$log"
  grep -qF '/usr/share/dbus-1/services/org.freedesktop.FileManager1.service (nautilus)' "$log"
  grep -qF 'Next action: sudo pacman -Rns nautilus, then rerun configure.' "$log"
  refute grep -qF 'Next action: sudo pacman -Rns strata-bin' "$log"
  refute grep -qE '^pacman -R' "$CFG_TEST_CALLS"
  [ -e "$CFG_TEST_INSTALLED/nautilus" ]
  [ -f "$root/usr/share/dbus-1/services/org.freedesktop.FileManager1.service" ]
  # The maintainer's action, outside configure.
  rm "$root/usr/share/dbus-1/services/org.freedesktop.FileManager1.service" "$CFG_TEST_INSTALLED/nautilus"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/files: '* ]]
}

@test "a missing Strata FileManager1 activation file fails the postcondition" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [[ "$output" == *'postcondition not satisfied'* ]]
}
