#!/usr/bin/env bats
load fixtures/session

setup() {
  if (( EUID == 0 )); then skip 'chrome-update must be exercised as an unprivileged user'; fi
  chrome_session_fixture
  UPDATE="$CHROME_TEST_DIR/bin/chrome-update"
  PROVENANCE="$XDG_STATE_HOME/mirroros/chrome-update/provenance.tsv"
}

@test "a successful update verifies, builds as the user, installs with sudo and records provenance" {
  run bash "$UPDATE"
  [ "$status" -eq 0 ]
  [ "$(< "$CHROME_TEST_DIR/installed")" = "$CHROME_VERSION.1" ]
  [ "$(< "$PROVENANCE")" = "$CHROME_VERSION.1"$'\t'"$CHROME_HASH"$'\t'"$CHROME_DATE"$'\t'"$CHROME_SUBKEY" ]
  grep -Fx "sudo pacman -U -- $CHROME_TEST_DIR/chrome.pkg.tar.zst" "$CHROME_TEST_DIR/calls"
  [ "$(grep -c '^sudo ' "$CHROME_TEST_DIR/calls")" -eq 1 ]
  run bash "$UPDATE"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^build-chrome ' "$CHROME_TEST_DIR/calls")" -eq 1 ]
  [ "$(wc -l < "$PROVENANCE")" -eq 1 ]
}

@test "integrity or build failure never invokes sudo" {
  run env CHROME_CHANNEL_STATUS=11 bash "$UPDATE"
  [ "$status" -eq 4 ]
  ! grep -Eq '^(build-chrome|sudo) ' "$CHROME_TEST_DIR/calls"
  run env CHROME_BUILD_FAIL=1 bash "$UPDATE"
  [ "$status" -eq 4 ]
  ! grep -q '^sudo ' "$CHROME_TEST_DIR/calls"
  [ "$(< "$CHROME_TEST_DIR/installed")" = '157.0.0.0-1.1' ]
  [ ! -e "$PROVENANCE" ]
}

@test "a failed privileged transaction preserves the installed version and appends no provenance" {
  run env CHROME_SUDO_FAIL=1 bash "$UPDATE"
  [ "$status" -eq 5 ]
  [[ "$output" == *'review pacman output, then rerun chrome-update'* ]]
  [ "$(< "$CHROME_TEST_DIR/installed")" = '157.0.0.0-1.1' ]
  [ ! -s "$PROVENANCE" ]
}
