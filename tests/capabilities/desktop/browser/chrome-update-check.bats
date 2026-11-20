#!/usr/bin/env bats
load fixtures/session

setup() {
  chrome_session_fixture
  CHECK="$CHROME_TEST_DIR/bin/chrome-update-check"
  OFFERED="$XDG_STATE_HOME/mirroros/chrome-update-offered"
  INTEGRITY="$XDG_STATE_HOME/mirroros/chrome-update-integrity-notified"
}

@test "one critical offer per verified version launches the fixed update command on default action" {
  run env CHROME_ACTION=default bash "$CHECK"
  [ "$status" -eq 0 ]
  [ "$(< "$OFFERED")" = "$CHROME_VERSION" ]
  grep -F "notify-send --wait -u critical -A default=Update Chrome $CHROME_VERSION available" "$CHROME_TEST_DIR/calls"
  grep -Fx 'uwsm app -- foot -e /usr/share/mirroros/browser/chrome-update' "$CHROME_TEST_DIR/calls"
  run bash "$CHECK"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^notify-send ' "$CHROME_TEST_DIR/calls")" -eq 1 ]
  run env CHROME_VERSION=159.0.0.0-1 bash "$CHECK"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^notify-send ' "$CHROME_TEST_DIR/calls")" -eq 2 ]
}

@test "offline and transient verification failures leave both markers unchanged with no notice" {
  mkdir -p "${OFFERED%/*}"
  printf '156.0.0.0-1\n' > "$OFFERED"
  printf 'prior integrity failure\n' > "$INTEGRITY"
  for flag in CHROME_OFFLINE=1 CHROME_CHANNEL_STATUS=10; do
    run env "$flag" bash "$CHECK"
    [ "$status" -eq 0 ]
    [ "$(< "$OFFERED")" = '156.0.0.0-1' ]
    [ "$(< "$INTEGRITY")" = 'prior integrity failure' ]
  done
  ! grep -Eq '^(notify-send|mirroros-notification-send) ' "$CHROME_TEST_DIR/calls"
}

@test "integrity failures are visible once per cause, fail the check and reset on success" {
  for cause in 'primary fingerprint mismatch' 'primary fingerprint mismatch' 'Packages SHA256 mismatch'; do
    run env CHROME_CHANNEL_STATUS=11 CHROME_CAUSE="$cause" bash "$CHECK"
    [ "$status" -eq 11 ]
    [ "$(< "$INTEGRITY")" = "$cause" ]
    [ ! -e "$OFFERED" ]
  done
  [ "$(grep -c '^mirroros-notification-send .*journalctl --user -u mirroros-chrome-update-check' "$CHROME_TEST_DIR/calls")" -eq 2 ]
  ! grep -q '^notify-send ' "$CHROME_TEST_DIR/calls"
  run env CHROME_VERSION=157.0.0.0-1 bash "$CHECK"
  [ "$status" -eq 0 ]
  [ ! -e "$INTEGRITY" ]
  [ ! -e "$OFFERED" ]
}
