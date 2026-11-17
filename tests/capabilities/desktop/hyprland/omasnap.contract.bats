#!/usr/bin/env bats
load ../../support

setup() {
  cfg_test_setup
  export PROVIDER="$CFG_SOURCE_ROOT/capabilities/desktop/compositor/providers/hyprland"
  printf 'CFG_STEPS=(desktop/compositor/providers/hyprland)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions" "$CFG_TEST_DIR/runtime"
  printf '[Desktop Entry]\nExec=uwsm start hyprland.desktop\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions/hyprland-uwsm.desktop"
  cat > "$CFG_TEST_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/bash
[[ "$*" == '--user show-environment' ]] || exit 97
printf '%s\n' "${CFG_TEST_USER_ENVIRONMENT:-}"
EOF
  cat > "$CFG_TEST_DIR/bin/makepkg" <<'EOF'
#!/usr/bin/bash
set -Eeuo pipefail
printf 'makepkg %s\n' "$*" >> "$CFG_TEST_CALLS"
[[ "$PWD" == "$CFG_TEST_HOME/.cache/mirroros/omasnap/.build."* && -f PKGBUILD ]] || exit 97
[[ "$PKGDEST" == "$CFG_TEST_HOME/.cache/mirroros/omasnap" && "$SRCDEST" == "$PWD/sources" && "$BUILDDIR" == "$PWD/build" ]] || exit 97
package="$PKGDEST/omasnap-1.26.2-4.3-x86_64.pkg.tar.zst"
case "$*" in
  --packagelist) printf '%s\n' "$package" ;;
  '--force --noconfirm --nocolor')
    [[ "${CFG_TEST_MAKEPKG_FAIL:-0}" != 1 ]] || exit 17
    printf 'synthetic package\n' > "$package" ;;
  *) exit 97 ;;
esac
EOF
  cat > "$CFG_TEST_DIR/bin/omasnap" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$OMASNAP_RECENT_DIR" "$@"
exit "${CAPTURE_STATUS:-0}"
EOF
  chmod 0755 "$CFG_TEST_DIR/bin/"{systemctl,makepkg,omasnap}
  export XDG_RUNTIME_DIR="$CFG_TEST_DIR/runtime"
}
teardown() { cfg_test_teardown; }

@test "Omasnap configure installs reviewed package and managed payloads, then reruns unchanged" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ] || { cat "$CFG_TEST_DIR/first/configure.log" >&3; return 1; }
  [ "$(< "$CFG_TEST_INSTALLED/omasnap")" = 1.26.2-4.3 ]
  grep -qxF "pacman -U --needed --noconfirm -- $CFG_TEST_HOME/.cache/mirroros/omasnap/omasnap-1.26.2-4.3-x86_64.pkg.tar.zst" "$CFG_TEST_CALLS"
  grep -q $'^omasnap\t.*\tv1.26.2\t6150151846b0ddc2ca8e6b107324de8b0c7240ae\t1.26.2-4.3$' "$CFG_TEST_DIR/first/sources.tsv"
  cmp "$PROVIDER/omasnap/omasnap.conf" "$CFG_TEST_HOME/.config/omasnap/omasnap.conf"
  cmp "$PROVIDER/omasnap/60-mirroros-omasnap.conf" "$MIRROROS_CONFIGURE_ROOT/etc/environment.d/60-mirroros-omasnap.conf"
  cmp "$PROVIDER/omasnap/screenshot-bindings.lua" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/screenshot-bindings.lua"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/compositor/screenshot-backend")" = 755 ]
  [ "$(readlink "$CFG_TEST_HOME/.local/state/omarchy/current/theme")" = "$CFG_TEST_HOME/.local/state/mirroros/current/theme" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'hyprland: unchanged'* ]]
  ! grep -qE '^(makepkg|pacman -U|sudo) ' "$CFG_TEST_CALLS"
  ! compgen -G "$CFG_TEST_HOME/.cache/mirroros/omasnap/.build.*"
}

@test "Omasnap target configure builds for the target and does not query a session" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -U" "$CFG_TEST_CALLS"
  [ -f "$CFG_TEST_HOME/.config/omasnap/omasnap.conf" ]
  [ -L "$CFG_TEST_HOME/.local/state/omarchy/current/theme" ]
}

@test "Omasnap configure preserves unmarked user configuration and reports bridge conflicts" {
  mkdir -p "$CFG_TEST_HOME/.config/omasnap" "$CFG_TEST_HOME/.local/state/omarchy"
  printf '[output]\nfilename = personal-{app}\n' > "$CFG_TEST_HOME/.config/omasnap/omasnap.conf"
  printf 'personal\n' > "$CFG_TEST_HOME/.local/state/omarchy/keep"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  grep -q 'personal-{app}' "$CFG_TEST_HOME/.config/omasnap/omasnap.conf"
  [ "$(< "$CFG_TEST_HOME/.local/state/omarchy/keep")" = personal ]
  grep -q 'Conflict:' "$CFG_TEST_DIR/conflict/configure.log"
}

@test "Omasnap configure preserves a user configuration link on a successful apply" {
  mkdir -p "$CFG_TEST_HOME/.config/omasnap"
  printf '[output]\nfilename = personal-{app}\n' > "$CFG_TEST_DIR/personal.conf"
  ln -s "$CFG_TEST_DIR/personal.conf" "$CFG_TEST_HOME/.config/omasnap/omasnap.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/omasnap/omasnap.conf")" = "$CFG_TEST_DIR/personal.conf" ]
  grep -qxF 'filename = personal-{app}' "$CFG_TEST_DIR/personal.conf"
}

@test "Omasnap build failure does not install and cleans staging" {
  export CFG_TEST_MAKEPKG_FAIL=1
  run "$CFG_TEST_ENTRY"
  [ "$status" -ne 0 ]
  [ ! -e "$CFG_TEST_INSTALLED/omasnap" ]
  ! grep -q '^pacman -U' "$CFG_TEST_CALLS"
  ! compgen -G "$CFG_TEST_HOME/.cache/mirroros/omasnap/.build.*"
}

@test "Omasnap backend translates modes and annotation, overrides disk recent paths and preserves status" {
  local mode expected code
  export OMASNAP_RECENT_DIR=/persistent/not-allowed
  for mode in smart region window full scroll; do
    case "$mode" in window) expected=windows;; full) expected=fullscreen;; scroll) expected=--scroll;; *) expected="$mode";; esac
    for code in 0 1 2; do
      run env CAPTURE_STATUS="$code" bash "$PROVIDER/omasnap/screenshot-backend" "$mode" --edit
      [ "$status" -eq "$code" ]
      [ "$output" = "$XDG_RUNTIME_DIR/omasnap/recent"$'\n'"$expected"$'\n--editor\noverlay' ]
    done
  done
  run bash "$PROVIDER/omasnap/screenshot-backend"
  [ "$status" -eq 0 ]
  [ "$output" = "$XDG_RUNTIME_DIR/omasnap/recent"$'\nsmart' ]
}

@test "Omasnap backend rejects invalid arguments and missing runtime without invoking capture" {
  for args in 'region window' '--edit --edit' '--unknown' 'smart smart'; do
    read -ra arguments <<< "$args"
    run bash "$PROVIDER/omasnap/screenshot-backend" "${arguments[@]}"
    [ "$status" -eq 2 ]
    [[ "$output" == Usage:* ]]
  done
  run env -u XDG_RUNTIME_DIR bash "$PROVIDER/omasnap/screenshot-backend"
  [ "$status" -eq 1 ]
  [[ "$output" == *'fresh graphical session'* ]]
}

@test "Omasnap portal and launcher-name patches apply to pinned sources without an entry override" {
  [[ -n "${MIRROROS_OMASNAP_SOURCE:-}" ]] || skip 'set MIRROROS_OMASNAP_SOURCE to the pinned upstream checkout'
  mkdir -p "$CFG_TEST_DIR/patch/omasnap-1.26.2/src"
  cp "$MIRROROS_OMASNAP_SOURCE/src/"{editor-save-as.cpp,main.cpp} "$CFG_TEST_DIR/patch/omasnap-1.26.2/src/"
  cp "$MIRROROS_OMASNAP_SOURCE/omasnap.desktop" "$CFG_TEST_DIR/patch/omasnap-1.26.2/"
  run bash -e -c 'source "$1"; cd "$2"; (prepare); ! grep -q DontUseNativeDialog omasnap-1.26.2/src/editor-save-as.cpp; grep -qF '\''qputenv("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");'\'' omasnap-1.26.2/src/main.cpp' bash "$PROVIDER/omasnap/PKGBUILD" "$CFG_TEST_DIR/patch"
  [ "$status" -eq 0 ]
  [[ "$output" != *fuzz* && "$output" != *offset* ]]
  ! grep -q 'platformtheme' "$PROVIDER/omasnap/screenshot-backend"
  local desktop
  desktop=$(< "$MIRROROS_OMASNAP_SOURCE/omasnap.desktop")
  printf '%s\n' "${desktop/Name=Screenshot/Name=Omasnap}" > "$CFG_TEST_DIR/expected.desktop"
  cmp "$CFG_TEST_DIR/expected.desktop" "$CFG_TEST_DIR/patch/omasnap-1.26.2/omasnap.desktop"
}

@test "Omasnap recipe and INI keep the pinned archive and output defaults" {
  run bash -e -c 'source "$1"; [[ "$pkgname $pkgver $pkgrel ${arch[*]}" == "omasnap 1.26.2 4.3 x86_64" ]]; [[ "${sha256sums[0]}" == e173edd4f2e797273c967513f24c360b6f00733792b9708757a82c39fbc43bf9 ]]; ! declare -F check; [[ ! -v checkdepends ]]' bash "$PROVIDER/omasnap/PKGBUILD"
  [ "$status" -eq 0 ]
  grep -qxF '+Name=Omasnap' "$PROVIDER/omasnap/PKGBUILD"
  run bash -e -c 'source "$1"; for name in "${depends[@]}" "${makedepends[@]}" base-devel; do grep -qE "^$name (core|extra)$" "$2"; done' bash "$PROVIDER/omasnap/PKGBUILD" "$PROVIDER/packages"
  [ "$status" -eq 0 ]
  [ "$(grep -vcE '^(;|\[output\]|$)' "$PROVIDER/omasnap/omasnap.conf")" -eq 1 ]
  grep -qxF 'filename = screenshot-{date}_{time}' "$PROVIDER/omasnap/omasnap.conf"
  grep -qxF 'OMASNAP_RECENT_DIR=${XDG_RUNTIME_DIR}/omasnap/recent' "$PROVIDER/omasnap/60-mirroros-omasnap.conf"
  ! grep -qE 'sudo|makepkg .*--syncdeps|makepkg .*--install' "$PROVIDER/omasnap/build-omasnap"
}
