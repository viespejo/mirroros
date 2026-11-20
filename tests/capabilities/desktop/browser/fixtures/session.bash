#!/usr/bin/bash
chrome_session_fixture() {
  local fixtures="$BATS_TEST_DIRNAME/fixtures" command
  export CHROME_TEST_DIR="$BATS_TEST_TMPDIR"
  export XDG_STATE_HOME="$CHROME_TEST_DIR/state"
  export PATH="$CHROME_TEST_DIR/bin:$PATH"
  mkdir "$CHROME_TEST_DIR/bin"
  install -m 0755 "$fixtures/session-command" "$CHROME_TEST_DIR/bin/session-command"
  for command in pacman sudo nm-online busctl notify-send mirroros-notification-send uwsm chrome-channel build-chrome; do
    ln -s session-command "$CHROME_TEST_DIR/bin/$command"
  done
  cp "$BATS_TEST_DIRNAME/../../../../capabilities/desktop/browser/"{chrome-update,chrome-update-check} "$CHROME_TEST_DIR/bin/"
  printf '157.0.0.0-1.1\n' > "$CHROME_TEST_DIR/installed"
  : > "$CHROME_TEST_DIR/calls"
  CHROME_VERSION=158.0.8127.36-1
  CHROME_HASH=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  CHROME_DATE=2024-03-09T16:00:00Z
  CHROME_SUBKEY=FEDCBA9876543210FEDCBA9876543210FEDCBA98 # gitleaks:allow Synthetic test fingerprint.
  export CHROME_VERSION CHROME_HASH CHROME_DATE CHROME_SUBKEY
}
