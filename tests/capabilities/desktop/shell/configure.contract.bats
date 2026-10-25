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
  (cd "$CFG_TEST_HOME" && find .config/mirroros .local/state/mirroros -type f -exec sha256sum {} + &&
    find .config/mirroros .local/state/mirroros -printf '%m %p\n') | sort > "$CFG_TEST_DIR/private.before"
}

shell_private_unchanged() {
  (cd "$CFG_TEST_HOME" && find .config/mirroros .local/state/mirroros -type f -exec sha256sum {} + &&
    find .config/mirroros .local/state/mirroros -printf '%m %p\n') | sort | cmp - "$CFG_TEST_DIR/private.before"
}

runtime_current() {
  bash "$SHELL_CODE/install-runtime" check "$SHELL_CODE" "$1/usr/share/mirroros/shell"
}

@test "running configure publishes the runtime and user unit without starting anything and reruns unchanged" {
  shell_private_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/shell: changed'* ]]
  runtime_current "$MIRROROS_CONFIGURE_ROOT"
  cmp "$SHELL_CODE/systemd/mirroros-shell.service" "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/mirroros-shell.service"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-shell.service")" = \
    /etc/systemd/user/mirroros-shell.service ]
  for package in quickshell inotify-tools libxkbcommon ttf-liberation wl-clipboard; do
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
