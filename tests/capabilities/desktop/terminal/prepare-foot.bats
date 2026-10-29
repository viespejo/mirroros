#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home" "$BATS_TEST_TMPDIR/bin"
  script="$root/capabilities/desktop/terminal/prepare-foot"
  standalone="$(base64 -w 0 < "$root/capabilities/desktop/terminal/foot.ini")"
  layered="$(base64 -w 0 < "$root/capabilities/desktop/terminal/personal-foot.ini")"
  dest="$home/.config/foot/foot.ini"
  printf '#!/bin/sh\nexit "${FOOT_CHECK_STATUS:-0}"\n' > "$BATS_TEST_TMPDIR/bin/foot"
  chmod 755 "$BATS_TEST_TMPDIR/bin/foot"
}

prepare() { HOME="$home" PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash "$script" "$standalone" "$layered"; }

@test "new configuration uses validated layers" {
  run prepare
  [ "$status" -eq 0 ]
  cmp "$root/capabilities/desktop/terminal/personal-foot.ini" "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
}

@test "new configuration falls back to standalone when validation fails" {
  export FOOT_CHECK_STATUS=1
  run prepare
  [ "$status" -eq 0 ]
  cmp "$root/capabilities/desktop/terminal/foot.ini" "$dest"
  [[ "$output" == *'using standalone defaults'* ]]
}

@test "a personal configuration created during validation is not overwritten" {
  printf '#!/bin/sh\nprintf "concurrent\\n" > "$HOME/.config/foot/foot.ini"\n' > "$BATS_TEST_TMPDIR/bin/foot"
  run prepare
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
  [ "$(< "$dest")" = concurrent ]
}

@test "existing personal configuration and broken links remain untouched" {
  mkdir -p "${dest%/*}"
  printf 'personal\n' > "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(< "$dest")" = personal ]
  rm "$dest"
  ln -s "$BATS_TEST_TMPDIR/missing" "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ -L "$dest" ]
}
