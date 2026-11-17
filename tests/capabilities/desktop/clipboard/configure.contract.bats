#!/usr/bin/env bats
# Clipboard delivery through configure, with native operations replaced by doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/clipboard)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  CLIPBOARD_CODE="$CFG_TEST_DIR/code/capabilities/desktop/clipboard"
}
teardown() { cfg_test_teardown; }

clipboard_delivery() {
  local root="$1" name unit
  cmp "$CLIPBOARD_CODE/clipboard-history" "$root/usr/share/mirroros/clipboard/clipboard-history"
  [ "$(stat -c %a "$root/usr/share/mirroros/clipboard/clipboard-history")" = 755 ]
  for name in text image; do
    unit="mirroros-clipboard-$name.service"
    cmp "$CLIPBOARD_CODE/$unit" "$root/etc/systemd/user/$unit"
    [ "$(stat -c %a "$root/etc/systemd/user/$unit")" = 644 ]
    [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/$unit")" = "/etc/systemd/user/$unit" ]
    grep -qxF 'PartOf=graphical-session.target' "$root/etc/systemd/user/$unit"
    grep -qxF 'After=graphical-session.target' "$root/etc/systemd/user/$unit"
    grep -qxF 'Restart=on-failure' "$root/etc/systemd/user/$unit"
    grep -qxF 'RestartSec=2' "$root/etc/systemd/user/$unit"
    grep -qxF 'WantedBy=graphical-session.target' "$root/etc/systemd/user/$unit"
  done
  grep -qxF 'ExecStart=/usr/bin/wl-paste --type text --watch /usr/share/mirroros/clipboard/clipboard-history store text' \
    "$root/etc/systemd/user/mirroros-clipboard-text.service"
  grep -qxF 'ExecStart=/usr/bin/wl-paste --type image/png --watch /usr/share/mirroros/clipboard/clipboard-history store image/png' \
    "$root/etc/systemd/user/mirroros-clipboard-image.service"
  [ -e "$CFG_TEST_INSTALLED/cliphist" ]
  [ -e "$CFG_TEST_INSTALLED/wl-clipboard" ]
  [ -e "$CFG_TEST_INSTALLED/fzf" ]
  ! grep -qE '(^| )systemctl |(^| )(wl-paste|cliphist|wl-copy) ' "$CFG_TEST_CALLS"
  ! grep -qE 'cfg_exec|cfg_unit_start|cfg_session_agent_unique' "$CLIPBOARD_CODE/apply"
}

@test "running configure delivers clipboard and enables only, then reruns unchanged" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/clipboard: changed'* ]]
  clipboard_delivery "$MIRROROS_CONFIGURE_ROOT"
  grep -qxF 'pacman -S --needed --noconfirm -- extra/cliphist extra/wl-clipboard extra/fzf' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/clipboard: unchanged'* ]]
  cfg_test_no_install
  clipboard_delivery "$MIRROROS_CONFIGURE_ROOT"
}

@test "target configure enables both watchers offline and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  clipboard_delivery "$CFG_TEST_TARGET_ROOT"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/clipboard: unchanged'* ]]
  cfg_test_no_install
  clipboard_delivery "$CFG_TEST_TARGET_ROOT"
}

@test "locally edited clipboard command is preserved and configure fails" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '\n# local change\n' >> "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/clipboard/clipboard-history"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step desktop/clipboard:'* ]]
  grep -q '# local change' "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/clipboard/clipboard-history"
}
