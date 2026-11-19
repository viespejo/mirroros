#!/usr/bin/env bats
# desktop/shell through the configure entry point, in both contexts, with test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/shell)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  SHELL_CODE="$CFG_TEST_DIR/code/capabilities/desktop/shell"
}
teardown() { cfg_test_teardown; }

# Synthetic personal preferences and private state that configure must never read or rewrite.
shell_private_fixture() {
  mkdir -p "$CFG_TEST_HOME/.config/mirroros" "$CFG_TEST_HOME/.local/state/mirroros/shell/notifications"
  printf '{ "version": 1, "notifications": { "fontScale": 110 } }\n' > "$CFG_TEST_HOME/.config/mirroros/shell.json"
  printf '{"synthetic":true}\n' > "$CFG_TEST_HOME/.local/state/mirroros/shell/notifications/history.json"
  chmod 0600 "$CFG_TEST_HOME/.config/mirroros/shell.json" "$CFG_TEST_HOME/.local/state/mirroros/shell/notifications/history.json"
  mkdir -p "$CFG_TEST_HOME/.local/state/mirroros/current"
  ln -s /synthetic/personal.png "$CFG_TEST_HOME/.local/state/mirroros/current/background"
  # Obsolete prototype state is not migrated or removed.
  mkdir -p -m 0700 "$CFG_TEST_HOME/.local/state/mirroros/shell/wallpaper"
  printf '{"version":1,"path":"/synthetic/personal.png"}\n' > "$CFG_TEST_HOME/.local/state/mirroros/shell/wallpaper/selection.json"
  chmod 0600 "$CFG_TEST_HOME/.local/state/mirroros/shell/wallpaper/selection.json"
  (cd "$CFG_TEST_HOME" && find .config/mirroros .local/state/mirroros -type f -exec sha256sum {} + &&
    find .config/mirroros .local/state/mirroros -printf '%m %p %l\n') | sort > "$CFG_TEST_DIR/private.before"
}

shell_private_unchanged() {
  (cd "$CFG_TEST_HOME" && find .config/mirroros .local/state/mirroros -type f -exec sha256sum {} + &&
    find .config/mirroros .local/state/mirroros -printf '%m %p %l\n') | sort | cmp - "$CFG_TEST_DIR/private.before"
}

runtime_current() {
  bash "$SHELL_CODE/install-runtime" check "$SHELL_CODE" "$1/usr/share/mirroros/shell"
}

# A desktop entry <file> starting <exec>, with optional extra lines.
autostart_entry() {
  mkdir -p "$(dirname "$1")"
  printf '[Desktop Entry]\nType=Application\nExec=%s\n%s' "$2" "${3:-}" > "$1"
}

@test "running configure publishes the runtime and user unit without starting anything and reruns unchanged" {
  shell_private_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: changed'* ]]
  runtime_current "$MIRROROS_CONFIGURE_ROOT"
  local sender=/usr/share/mirroros/shell/notifications/mirroros-notification-send
  cmp "$SHELL_CODE/notifications/mirroros-notification-send" "$MIRROROS_CONFIGURE_ROOT$sender"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT$sender")" = 755 ]
  [ "$(readlink "$MIRROROS_CONFIGURE_ROOT/usr/bin/mirroros-notification-send")" = "$sender" ]
  cmp "$SHELL_CODE/systemd/mirroros-shell.service" "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/mirroros-shell.service"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-shell.service")" = \
    /etc/systemd/user/mirroros-shell.service ]
  cmp "$SHELL_CODE/polkit-check/polkit-check" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/polkit/polkit-check"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/polkit/polkit-check")" = 755 ]
  cmp "$SHELL_CODE/polkit-check/agents" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/polkit/agents"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/polkit/agents")" = 644 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/polkit-check" ]
  for package in quickshell util-linux libvips inotify-tools libxkbcommon ttf-liberation wl-clipboard curl; do
    [ -e "$CFG_TEST_INSTALLED/$package" ]
  done
  grep -q "^mirroros-shell-runtime	capabilities/desktop/shell			manifest-sha256:$(bash "$SHELL_CODE/install-runtime" digest "$SHELL_CODE")$" \
    "$CFG_TEST_DIR/first/sources.tsv"
  run grep -rqF fontScale "$CFG_TEST_DIR/first"
  [ "$status" -eq 1 ]
  run grep -qE '^(systemctl|sudo|qs|hyprctl) ' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  shell_private_unchanged
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: unchanged'* ]]
  cfg_test_no_install
  shell_private_unchanged
}

@test "configure leaves an occupied sender alias untouched" {
  local alias="$MIRROROS_CONFIGURE_ROOT/usr/bin/mirroros-notification-send"
  mkdir -p "$(dirname "$alias")"
  printf 'foreign sender\n' > "$alias"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ ! -L "$alias" ]
  [ "$(<"$alias")" = 'foreign sender' ]
  rm "$alias"
  ln -s /synthetic/missing-sender "$alias"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(readlink "$alias")" = /synthetic/missing-sender ]
  [ -x "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/notifications/mirroros-notification-send" ]
}

@test "a changed source is delivered while preferences and private state stay untouched" {
  shell_private_fixture
  "$CFG_TEST_ENTRY"
  printf '{ "version": 1, "bar": {} }\n' > "$SHELL_CODE/defaults.json"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: changed'* ]]
  cmp "$SHELL_CODE/defaults.json" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/defaults.json"
  shell_private_unchanged
}

@test "a locally modified runtime or unit is a conflict that fails the step without overwriting it" {
  shell_private_fixture
  "$CFG_TEST_ENTRY"
  printf '// local edit\n' >> "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/shell.qml"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  grep -qF 'differs from its last MirrorOS delivery' "$CFG_TEST_DIR/conflict/configure.log"
  grep -qP '^step\tdesktop/shell\tfailed\t' "$CFG_TEST_DIR/conflict/configure-run.tsv"
  tail -n1 "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/shell.qml" | grep -qF '// local edit'
  cp "$SHELL_CODE/shell.qml" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell/shell.qml"
  printf '# managed by MirrorOS configure\n# local unit edit\n' > "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/mirroros-shell.service"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qF 'local unit edit' "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/mirroros-shell.service"
  cp "$SHELL_CODE/systemd/mirroros-shell.service" "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/mirroros-shell.service"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  shell_private_unchanged
}

@test "a package failure publishes nothing and the rerun converges" {
  export CFG_TEST_INSTALL_FAIL=1
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 5 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/shell" ]
  [ ! -e "$CFG_TEST_HOME/.config/systemd/user" ]
  unset CFG_TEST_INSTALL_FAIL
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  runtime_current "$MIRROROS_CONFIGURE_ROOT"
}

@test "a user's own shell unit override is preserved and accepted" {
  mkdir -p "$CFG_TEST_HOME/.config/systemd/user"
  ln -s /dev/null "$CFG_TEST_HOME/.config/systemd/user/mirroros-shell.service"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/mirroros-shell.service")" = /dev/null ]
  [ ! -e "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants" ]
}

@test "target configure publishes inside the root and enables the unit as the user through the chroot" {
  cfg_test_target_context
  shell_private_fixture
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  runtime_current "$CFG_TEST_TARGET_ROOT"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-shell.service")" = \
    /etc/systemd/user/mirroros-shell.service ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/quickshell" "$CFG_TEST_CALLS"
  run grep -qE '^(systemctl |arch-chroot [^ ]+ (systemctl |install |bash .*install-runtime))' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  shell_private_unchanged
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: unchanged'* ]]
  cfg_test_no_install
}

@test "an active system autostart entry of a listed agent fails with its file, package and action and is kept" {
  mkdir -p "$CFG_TEST_DIR/owners"
  local entry="$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop"
  autostart_entry "$entry" /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
  printf 'mate-polkit\n' > "$CFG_TEST_DIR/owners/polkit-mate-authentication-agent-1.desktop"
  autostart_entry "$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/other.desktop" /usr/bin/other-agent
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  local log="$CFG_TEST_DIR/conflict/configure.log"
  grep -qF 'Conflict: /etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop starts polkit-mate-authentication-agent-1, a competing agent (mate-polkit).' "$log"
  grep -qF 'Next action: add a ~/.config/autostart/polkit-mate-authentication-agent-1.desktop entry with Hidden=true, or remove its package, then rerun configure.' "$log"
  grep -qF 'Postcondition failed: cfg_session_agent_unique' "$log"
  run grep -qF 'other.desktop' "$log"
  [ "$status" -eq 1 ]
  [ -f "$entry" ]
  [ ! -e "$CFG_TEST_HOME/.config/autostart" ]
  grep -qxF 'pacman -Qqo -- /etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop' "$CFG_TEST_CALLS"
  run grep -qE '^(pacman -R|systemctl)' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
}

@test "Hidden=true entries, user entries shadowing a system entry and entries without a command are inactive" {
  autostart_entry "$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/lxpolkit.desktop" lxpolkit
  autostart_entry "$CFG_TEST_HOME/.config/autostart/lxpolkit.desktop" lxpolkit 'Hidden=true'
  autostart_entry "$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/xfce-polkit.desktop" /usr/lib/xfce-polkit/xfce-polkit \
    'Hidden=true'
  printf '[Desktop Entry]\nType=Application\nExec=\n' > "$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/empty-exec.desktop"
  printf '[Desktop Entry]\nType=Application\n' > "$MIRROROS_CONFIGURE_ROOT/etc/xdg/autostart/no-exec.desktop"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user" "$CFG_TEST_HOME/.config/systemd/user/default.target.wants"
  printf '[Unit]\nDescription=no command\n' > "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user/no-exec.service"
  ln -s /usr/lib/systemd/user/no-exec.service "$CFG_TEST_HOME/.config/systemd/user/default.target.wants/no-exec.service"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/hidden"
  [ "$status" -eq 0 ]
  run grep -qF 'Conflict:' "$CFG_TEST_DIR/hidden/configure.log"
  [ "$status" -eq 1 ]
  # A user entry replaces the system entry of the same name whole, so its own Exec is what runs.
  autostart_entry "$CFG_TEST_HOME/.config/autostart/lxpolkit.desktop" 'env GDK_BACKEND=wayland /usr/bin/lxpolkit --flag'
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/user"
  [ "$status" -eq 4 ]
  grep -qF 'Conflict: ~/.config/autostart/lxpolkit.desktop starts lxpolkit, a competing agent (not owned by a package).' \
    "$CFG_TEST_DIR/user/configure.log"
  grep -qF 'Next action: remove ~/.config/autostart/lxpolkit.desktop or set Hidden=true in it, then rerun configure.' \
    "$CFG_TEST_DIR/user/configure.log"
  run grep -qF 'Conflict: /etc/xdg/autostart/lxpolkit.desktop' "$CFG_TEST_DIR/user/configure.log"
  [ "$status" -eq 1 ]
  [ -f "$CFG_TEST_HOME/.config/autostart/lxpolkit.desktop" ]
}

@test "an enabled user unit of a listed agent fails for the user or globally and stays enabled" {
  mkdir -p "$CFG_TEST_DIR/owners" "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user"
  local unit=/usr/lib/systemd/user/plasma-polkit-agent.service
  printf '[Service]\nExecStart=/usr/lib/polkit-kde-authentication-agent-1\n' > "$MIRROROS_CONFIGURE_ROOT$unit"
  printf 'polkit-kde-agent\n' > "$CFG_TEST_DIR/owners/plasma-polkit-agent.service"
  mkdir -p "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants"
  ln -s "$unit" "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/user"
  [ "$status" -eq 4 ]
  grep -qF 'Conflict: ~/.config/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service starts polkit-kde-authentication-agent-1, a competing agent (polkit-kde-agent).' \
    "$CFG_TEST_DIR/user/configure.log"
  grep -qF 'Next action: systemctl --user disable plasma-polkit-agent.service, then rerun configure.' \
    "$CFG_TEST_DIR/user/configure.log"
  [ -L "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service" ]
  rm "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/graphical-session.target.wants"
  ln -s "$unit" "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/global"
  [ "$status" -eq 4 ]
  grep -qF 'Conflict: /etc/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service starts polkit-kde-authentication-agent-1, a competing agent (polkit-kde-agent).' \
    "$CFG_TEST_DIR/global/configure.log"
  grep -qF 'Next action: sudo systemctl --global disable plasma-polkit-agent.service, then rerun configure.' \
    "$CFG_TEST_DIR/global/configure.log"
  [ -L "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/graphical-session.target.wants/plasma-polkit-agent.service" ]
  run grep -qE '^systemctl' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
}

@test "an enabled hyprpolkitagent unit left by plan 02-36 is a conflict naming its package" {
  mkdir -p "$CFG_TEST_DIR/owners" "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user" \
    "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants"
  printf '[Service]\nExecStart=/usr/lib/hyprpolkitagent/hyprpolkitagent\n' \
    > "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user/hyprpolkitagent.service"
  printf 'hyprpolkitagent\n' > "$CFG_TEST_DIR/owners/hyprpolkitagent.service"
  ln -s /usr/lib/systemd/user/hyprpolkitagent.service \
    "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hyprpolkitagent.service"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/residue"
  [ "$status" -eq 4 ]
  grep -qF 'Conflict: ~/.config/systemd/user/graphical-session.target.wants/hyprpolkitagent.service starts hyprpolkitagent, a competing agent (hyprpolkitagent).' \
    "$CFG_TEST_DIR/residue/configure.log"
  grep -qF 'Next action: systemctl --user disable hyprpolkitagent.service, then rerun configure.' \
    "$CFG_TEST_DIR/residue/configure.log"
  [ -L "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hyprpolkitagent.service" ]
  rm "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hyprpolkitagent.service"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: unchanged'* ]]
}

@test "target configure reports a competing agent through the chroot" {
  cfg_test_target_context
  mkdir -p "$CFG_TEST_DIR/owners"
  autostart_entry "$CFG_TEST_TARGET_ROOT/etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop" \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 4 ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT pacman -Qqo -- /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop" \
    "$CFG_TEST_CALLS"
  [ -x "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/polkit/polkit-check" ]
}

@test "the shell unit is the single session-bound owner with bounded restarts and no lock dependency" {
  local unit="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/shell/systemd/mirroros-shell.service"
  for line in PartOf=graphical-session.target After=graphical-session.target Requisite=graphical-session.target \
    StartLimitIntervalSec=60 StartLimitBurst=5 Restart=on-failure 'ExecStart=/usr/bin/qs -p /usr/share/mirroros/shell' \
    WantedBy=graphical-session.target; do
    grep -qxF "$line" "$unit"
  done
  run grep -qiE 'hypridle|hyprlock|Restart=always|KillMode|BindsTo' <<< "$(grep -viE '^#' "$unit")"
  [ "$status" -eq 1 ]
  run grep -rqE 'qs (-p|--path)|mirroros-shell' "$BATS_TEST_DIRNAME/../../../../capabilities/desktop/compositor/providers/hyprland/hyprland.lua"
  [ "$status" -eq 1 ]
  command -v systemd-analyze > /dev/null || skip 'systemd-analyze is not installed'
  sed 's#^ExecStart=/usr/bin/qs #ExecStart=/usr/bin/true #' "$unit" > "$CFG_TEST_DIR/mirroros-shell.service"
  run systemd-analyze verify --user --man=no "$CFG_TEST_DIR/mirroros-shell.service"
  [ "$status" -eq 0 ]
  [[ "$output" != *mirroros-shell* ]]
}
