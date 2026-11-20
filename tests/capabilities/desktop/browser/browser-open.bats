#!/usr/bin/env bats

setup() {
  browser="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/browser/browser-open"
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data" XDG_DATA_DIRS="$BATS_TEST_TMPDIR/system"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$XDG_DATA_HOME/applications" "$XDG_DATA_DIRS/applications"
  printf '#!/usr/bin/bash\n[[ "$*" == "query default x-scheme-handler/https" ]] || exit 97\nprintf "%%s" "${HANDLER:-}"\n' > "$BATS_TEST_TMPDIR/bin/xdg-mime"
  printf '#!/usr/bin/bash\nprintf "<%%s>\\n" "$@"\n' > "$BATS_TEST_TMPDIR/bin/uwsm"
  cp "$BATS_TEST_TMPDIR/bin/uwsm" "$BATS_TEST_TMPDIR/bin/mirroros-notification-send"
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
}

@test "normal launch passes the selected desktop ID to uwsm as one argument" {
  export HANDLER=org.example.Browser.desktop
  run bash "$browser"
  [ "$status" -eq 0 ]
  [ "$output" = $'<app>\n<-->\n<org.example.Browser.desktop>' ]
}

@test "private launch requires the action on the effective desktop entry" {
  export HANDLER=org.example.Browser.desktop
  printf '[Desktop Entry]\nActions=new-window;new-private-window;\n[Desktop Action new-private-window]\nExec=fake --private\n' \
    > "$XDG_DATA_DIRS/applications/$HANDLER"
  run bash "$browser" --private
  [ "$status" -eq 0 ]
  [ "$output" = $'<app>\n<-->\n<org.example.Browser.desktop:new-private-window>' ]
  printf '[Desktop Entry]\nActions=new-window;\n[Desktop Action new-private-window]\nExec=fake --private\n' \
    > "$XDG_DATA_HOME/applications/$HANDLER"
  run bash "$browser" --private
  [ "$status" -eq 0 ]
  [[ "$output" == *'<The default browser offers no private window>'* && "$output" != *'<app>'* ]]
}

@test "a missing or malformed handler gives a notice with a next step" {
  for handler in '' '--scope.desktop' 'fake.desktop:new-private-window'; do
    export HANDLER="$handler"
    run bash "$browser"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Select a default HTTPS handler'* && "$output" != *'<app>'* ]]
  done
}
