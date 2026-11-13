#!/usr/bin/env bats
# The owned portal-check command with systemctl and busctl doubles over a disposable system tree; nothing is
# started, activated or written.

setup() {
  TEST_DIR="$(mktemp -d)"
  SOURCE="$BATS_TEST_DIRNAME/../../../../capabilities"
  SCRIPT="$SOURCE/desktop/portal/portal-check"
  export CALLS="$TEST_DIR/calls" HOME="$TEST_DIR/home" MIRROROS_PORTAL_CHECK_ROOT="$TEST_DIR/root"
  unset XDG_CONFIG_HOME XDG_DATA_HOME
  ROOT="$MIRROROS_PORTAL_CHECK_ROOT"
  mkdir -p "$TEST_DIR/bin" "$HOME" "$ROOT/etc/xdg/xdg-desktop-portal" "$ROOT/usr/share/xdg-desktop-portal/portals" \
    "$ROOT/usr/share/dbus-1/services" "$ROOT/usr/bin" "$HOME/.config/hypr"
  : > "$CALLS"
  # The Hyprland provider's grim package and managed share-picker defaults.
  printf '#!/usr/bin/bash\nexit 97\n' > "$ROOT/usr/bin/grim"
  chmod 0755 "$ROOT/usr/bin/grim"
  cp "$SOURCE/desktop/compositor/providers/hyprland/xdph.conf" "$HOME/.config/hypr/xdph.conf"
  cp "$SOURCE/desktop/compositor/providers/hyprland/hyprland-portals.conf" "$ROOT/etc/xdg/xdg-desktop-portal/"
  # The packaged hyprland default, which the /etc/xdg file replaces whole.
  printf '[preferred]\ndefault=hyprland;gtk\n' > "$ROOT/usr/share/xdg-desktop-portal/hyprland-portals.conf"
  portal gtk org.freedesktop.impl.portal.desktop.gtk 'FileChooser;org.freedesktop.impl.portal.AppChooser;org.freedesktop.impl.portal.Settings'
  portal strata org.freedesktop.impl.portal.desktop.strata FileChooser
  portal hyprland org.freedesktop.impl.portal.desktop.hyprland 'Screenshot;org.freedesktop.impl.portal.ScreenCast;org.freedesktop.impl.portal.GlobalShortcuts'
  portal gnome-keyring org.freedesktop.secrets Secret
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/strata --file-manager1\n' \
    > "$ROOT/usr/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service"
  cat > "$TEST_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/bash
printf 'systemctl %s\n' "$*" >> "$CALLS"
[[ "$*" == '--user show-environment' ]] || exit 97
printf 'HOME=/home/alice\nWAYLAND_DISPLAY=wayland-1\nXDG_CURRENT_DESKTOP=Hyprland\nXDG_SESSION_TYPE=wayland\n' |
  grep -v "^${MISSING_VARIABLE:-none}="
EOF
  # Bus names, the dark answer, owners and the Locked flag come from MISSING_NAME, COLOR, SECRETS_EXE,
  # FILEMANAGER_EXE and LOCKED.
  cat > "$TEST_DIR/bin/busctl" <<'EOF'
#!/usr/bin/bash
printf 'busctl %s\n' "$*" >> "$CALLS"
[[ "$1" == --user ]] || exit 97
shift
case "$1 $2" in
  'list --no-legend')
    for name in org.freedesktop.portal.Desktop org.freedesktop.impl.portal.desktop.gtk \
      org.freedesktop.impl.portal.desktop.strata org.freedesktop.impl.portal.desktop.hyprland org.freedesktop.secrets org.freedesktop.FileManager1; do
      [[ "$name" == "${MISSING_NAME:-none}" ]] || printf '%s - - - (activatable) - - -\n' "$name"
    done ;;
  'call org.freedesktop.portal.Desktop')
    [[ "$*" == *' org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme' ]] || exit 97
    printf 'v u %s\n' "${COLOR:-1}" ;;
  'status org.freedesktop.secrets') printf 'PID=900\nComm=gnome-keyring-d\nExe=%s\n' "${SECRETS_EXE:-/usr/bin/gnome-keyring-daemon}" ;;
  'status org.freedesktop.FileManager1')
    [[ -n "${FILEMANAGER_EXE:-}" ]] || { printf 'Failed to get credentials: name has no owner\n' >&2; exit 1; }
    printf 'PID=950\nExe=%s\n' "$FILEMANAGER_EXE" ;;
  'get-property org.freedesktop.secrets')
    [[ "$*" == *' /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked' ]] || exit 97
    printf 'b %s\n' "${LOCKED:-false}" ;;
  *) exit 97 ;;
esac
EOF
  chmod 0755 "$TEST_DIR/bin/"*
  export PATH="$TEST_DIR/bin:$PATH"
}
teardown() { rm -rf -- "$TEST_DIR"; }

portal() {
  printf '[portal]\nDBusName=%s\nInterfaces=org.freedesktop.impl.portal.%s;\n' "$2" "$3" \
    > "$ROOT/usr/share/xdg-desktop-portal/portals/$1.portal"
}

# Only read-only queries reach the user manager and the bus.
read_only_calls() {
  ! grep -vE '^(systemctl --user show-environment|busctl --user (list|status|get-property) |busctl --user call org\.freedesktop\.portal\.Desktop /org/freedesktop/portal/desktop org\.freedesktop\.portal\.Settings Read(One)? )' "$CALLS"
}

@test "a correct session passes every check with exit 0" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* && "$output" != *notice* ]]
  [[ "$output" == *"ok: portal preferences: $ROOT/etc/xdg/xdg-desktop-portal/hyprland-portals.conf"* ]]
  for line in 'FileChooser: routed to strata' 'Screenshot: routed to hyprland' 'ScreenCast: routed to hyprland' \
    'Settings: routed to gtk' 'Secret: routed to gnome-keyring' 'Settings: color-scheme answers 1 (dark)' \
    'org.freedesktop.secrets: owned by gnome-keyring-daemon' 'login collection: unlocked' \
    'org.freedesktop.FileManager1: activatable through strata' \
    'Screenshot: grim present for xdg-desktop-portal-hyprland' "share picker: restore token checked by default ($HOME/.config/hypr/xdph.conf)"; do
    [[ "$output" == *"ok: $line"* ]]
  done
  read_only_calls
}

@test "a running FileManager1 owner must be strata" {
  FILEMANAGER_EXE=/usr/bin/strata run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'ok: org.freedesktop.FileManager1: owned by strata'* ]]
  FILEMANAGER_EXE=/usr/bin/nautilus run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: org.freedesktop.FileManager1: owned by nautilus; expected strata'* ]]
}

@test "a missing backend fails naming the interface and the expected owner" {
  rm "$ROOT/usr/share/xdg-desktop-portal/portals/hyprland.portal"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: Screenshot: no configured backend declares org.freedesktop.impl.portal.Screenshot; expected hyprland'* ]]
  [[ "$output" == *'FAIL: ScreenCast:'* ]]
  [[ "$output" == *'ok: FileChooser: routed to strata'* ]]
  MISSING_NAME=org.freedesktop.impl.portal.desktop.strata run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: FileChooser: backend strata bus name org.freedesktop.impl.portal.desktop.strata is neither owned nor activatable; expected strata'* ]]
}

@test "without strata.portal the FileChooser falls back to gtk and fails naming strata" {
  rm "$ROOT/usr/share/xdg-desktop-portal/portals/strata.portal"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: FileChooser: routed to gtk; expected strata'* ]]
}

@test "a missing system preference file falls back to the packaged one and fails" {
  rm "$ROOT/etc/xdg/xdg-desktop-portal/hyprland-portals.conf"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: portal preferences: effective file is $ROOT/usr/share/xdg-desktop-portal/hyprland-portals.conf"* ]]
  [[ "$output" == *'FAIL: Secret: no configured backend declares org.freedesktop.impl.portal.Secret; expected gnome-keyring'* ]]
}

@test "a wrong Secret owner fails without reading the collection" {
  SECRETS_EXE=/usr/bin/kwalletd6 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: org.freedesktop.secrets: owner '/usr/bin/kwalletd6'; expected gnome-keyring-daemon started at SDDM login"* ]]
  ! grep -q 'get-property' "$CALLS"
}

@test "a locked login collection fails" {
  LOCKED=true run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: login collection: locked; expected unlocked by pam_gnome_keyring at SDDM login'* ]]
}

@test "a light Settings answer fails" {
  COLOR=0 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: Settings: color-scheme answers 'v u 0'; expected 1 (dark)"* ]]
}

@test "a missing activation variable fails naming uwsm" {
  MISSING_VARIABLE=XDG_SESSION_TYPE run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: activation environment: XDG_SESSION_TYPE missing; expected export by uwsm'* ]]
}

@test "two system FileManager1 services fail naming both files" {
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/nautilus --gapplication-service\n' \
    > "$ROOT/usr/share/dbus-1/services/org.freedesktop.FileManager1.service"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: org.freedesktop.FileManager1: 2 system service files'*'io.github.lgse.Strata.FileManager1.service'*'org.freedesktop.FileManager1.service'*'expected one from strata'* ]]
}

@test "user overrides are notices with exit 0" {
  mkdir -p "$HOME/.config/xdg-desktop-portal" "$HOME/.local/share/xdg-desktop-portal/portals" \
    "$HOME/.local/share/dbus-1/services"
  printf '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=kde\norg.freedesktop.impl.portal.Secret=gnome-keyring\n' \
    > "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
  portal kde org.freedesktop.impl.portal.desktop.kde FileChooser
  printf '[portal]\n' > "$HOME/.local/share/xdg-desktop-portal/portals/custom.portal"
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\n' > "$HOME/.local/share/dbus-1/services/custom.FileManager1.service"
  printf '[Default Applications]\ninode/directory=org.example.Files.desktop\n' > "$HOME/.config/mimeapps.list"
  MISSING_NAME=none run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: FileChooser: backend kde bus name org.freedesktop.impl.portal.desktop.kde is neither owned nor activatable'* ]]
  sed -i 's/=kde/=gtk/' "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
  [[ "$output" == *"notice: portal preferences: user override $HOME/.config/xdg-desktop-portal/hyprland-portals.conf"* ]]
  [[ "$output" == *"notice: user override: $HOME/.config/xdg-desktop-portal/hyprland-portals.conf"* ]]
  [[ "$output" == *"notice: user override: $HOME/.local/share/xdg-desktop-portal/portals/custom.portal"* ]]
  [[ "$output" == *"notice: user override: $HOME/.local/share/dbus-1/services/custom.FileManager1.service"* ]]
  [[ "$output" == *"notice: user choice: inode/directory in $HOME/.config/mimeapps.list"* ]]
  read_only_calls
}

@test "missing grim or share-picker defaults fail; a user-owned xdph.conf is a notice" {
  rm "$ROOT/usr/bin/grim"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: Screenshot: grim missing; expected grim from the Hyprland provider for the hyprland backend'* ]]
  printf '#!/usr/bin/bash\n' > "$ROOT/usr/bin/grim"
  chmod 0755 "$ROOT/usr/bin/grim"
  sed -i 's/= true/= false/' "$HOME/.config/hypr/xdph.conf"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: share picker: $HOME/.config/hypr/xdph.conf lacks allow_token_by_default = true"* ]]
  rm "$HOME/.config/hypr/xdph.conf"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: share picker: $HOME/.config/hypr/xdph.conf missing; expected the managed copy from the Hyprland provider"* ]]
  printf 'screencopy {\n    allow_token_by_default = false\n}\n' > "$HOME/.config/hypr/xdph.conf"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"notice: user override: $HOME/.config/hypr/xdph.conf"* ]]
  read_only_calls
}

@test "a user preference routing elsewhere is a notice, not a failure" {
  mkdir -p "$HOME/.config/xdg-desktop-portal"
  printf '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=gnome-keyring;gtk\norg.freedesktop.impl.portal.Secret=gnome-keyring\n' \
    > "$HOME/.config/xdg-desktop-portal/portals.conf"
  portal gnome-keyring org.freedesktop.secrets 'Secret;org.freedesktop.impl.portal.FileChooser'
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'notice: FileChooser: routed to gnome-keyring by the user override; system expects strata'* ]]
}
