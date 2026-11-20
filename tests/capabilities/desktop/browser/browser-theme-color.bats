#!/usr/bin/env bats

setup() {
  local capabilities="$BATS_TEST_DIRNAME/../../../../capabilities"
  browser="$capabilities/desktop/browser/browser-theme-color"
  root="$BATS_TEST_TMPDIR/root"
  themes="$root/usr/share/mirroros/themes"
  state="$BATS_TEST_TMPDIR/state"
  policy="$root/etc/opt/chrome/policies/managed/color.json"
  mkdir -m 0755 -p "$themes/default" "$themes/other" "$state/mirroros/current" "${policy%/*}"
  cp "$capabilities/visual/theme/"{resolve-current,check-trusted-path} "$themes/"
  for theme in default other; do
    cp "$capabilities/visual/theme/default/"{colors.toml,chromium.theme} "$themes/$theme/"
  done
}

apply_color() { bash -c 'source "$1"; write_color_policy "$2" "$3" "$(id -u)" "$(id -g)"' bash "$browser" "$root" "$state"; }

@test "the default and selected trusted colors are published atomically and idempotently" {
  run apply_color
  [ "$status" -eq 0 ]
  [ "$(< "$policy")" = '{"BrowserThemeColor":"#111c18"}' ]
  [ "$(stat -c '%a:%u:%g' "$policy")" = "644:$(id -u):$(id -g)" ]
  inode=$(stat -c %i "$policy")
  run apply_color
  [ "$status" -eq 0 ]
  [[ "$output" == *unchanged ]]
  [ "$(stat -c %i "$policy")" = "$inode" ]
  ln -s /usr/share/mirroros/themes/other "$state/mirroros/current/theme"
  printf '255,0,10\n' > "$themes/other/chromium.theme"
  run apply_color
  [ "$status" -eq 0 ]
  [ "$(< "$policy")" = '{"BrowserThemeColor":"#ff000a"}' ]
  [ "$(stat -c %i "$policy")" != "$inode" ]
}

@test "untrusted paths or invalid colors cannot replace a valid policy" {
  run apply_color
  [ "$status" -eq 0 ]
  for bad in '256,0,10' '17,28,24,1' $'17,28,24\n1,2,3'; do
    printf '%s\n' "$bad" > "$themes/default/chromium.theme"
    run apply_color
    [ "$status" -eq 4 ]
  done
  mv "$themes/default/chromium.theme" "$BATS_TEST_TMPDIR/untrusted"
  ln -s "$BATS_TEST_TMPDIR/untrusted" "$themes/default/chromium.theme"
  run apply_color
  [ "$status" -eq 4 ]
  [ "$(< "$policy")" = '{"BrowserThemeColor":"#111c18"}' ]
}

@test "the CLI rejects anything other than a validated user option" {
  for login in /tmp 123 --name; do
    run bash "$browser" --user "$login"
    [ "$status" -eq 6 ]
  done
}
