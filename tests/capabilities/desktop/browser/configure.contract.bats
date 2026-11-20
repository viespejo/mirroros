#!/usr/bin/env bats
load ../../support
load fixtures/configure

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/browser)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  chrome_configure_fixture
  local themes="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes"
  mkdir -p "$themes/default"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/theme/"{check-trusted-path,resolve-current} "$themes/"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/theme/default/"{colors.toml,chromium.theme} "$themes/default/"
  # Run the real writer against the disposable root instead of opening a privileged host path.
  printf '%s\n' '#!/usr/bin/bash' '
    if [[ "$*" == "-p /usr/share/mirroros/browser/browser-theme-color --user alice" ]]; then
      printf "chrome color offline=%s\n" "$MIRROROS_BROWSER_OFFLINE" >> "$CFG_TEST_CALLS"
      root=${CFG_TEST_TARGET_ROOT:-$MIRROROS_CONFIGURE_ROOT}
      source "$root$2"
      write_color_policy "$root" "$CFG_TEST_HOME/.local/state" "$(/usr/bin/id -u)" "$(/usr/bin/id -g)"
    else
      exec /usr/bin/bash "$@"
    fi' > "$CFG_TEST_DIR/bin/bash"
  printf '%s\n' '#!/usr/bin/bash' '[[ "$*" == "query default x-scheme-handler/https" ]] || exit 97' \
    'printf "%s\n" "${CHROME_TEST_HANDLER:-google-chrome.desktop}"' > "$CFG_TEST_DIR/bin/xdg-mime"
  chmod 0755 "$CFG_TEST_DIR/bin/"{bash,xdg-mime}
}
teardown() { cfg_test_teardown; }

@test "running configure installs the verified package once and records provenance" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/browser: changed'* ]]
  local policy="$MIRROROS_CONFIGURE_ROOT/etc/opt/chrome/policies/managed"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/mirroros.json" "$policy/mirroros.json"
  grep -Fx '{"BrowserThemeColor":"#111c18"}' "$policy/color.json"
  local recommended="${policy%/*}/recommended"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/recommended.json" "$recommended/mirroros.json"
  python3 - "$policy/mirroros.json" "$recommended/mirroros.json" <<'PY'
import json
import sys
from pathlib import Path

assert json.loads(Path(sys.argv[1]).read_text())["SyncTypesListDisabled"] == [
    "apps", "extensions", "preferences", "themes",
]
safe_browsing = json.loads(Path(sys.argv[2]).read_text())["SafeBrowsingProtectionLevel"]
assert type(safe_browsing) is int and safe_browsing == 1
PY
  [ "$(stat -c '%a:%u:%g' "$recommended")" = "755:$(/usr/bin/id -u):$(/usr/bin/id -g)" ]
  [ "$(stat -c '%a:%u:%g' "$recommended/mirroros.json")" = "644:$(/usr/bin/id -u):$(/usr/bin/id -g)" ]
  [ "$(stat -c '%a:%u:%g' "$policy")" = "755:$(/usr/bin/id -u):$(/usr/bin/id -g)" ]
  [ "$(stat -c '%a:%u:%g' "$policy/mirroros.json")" = "644:$(/usr/bin/id -u):$(/usr/bin/id -g)" ]
  grep -Fx 'chrome color offline=0' "$CFG_TEST_CALLS"
  grep -Fx 'chrome transaction SNAP_PAC_SKIP=unset' "$CFG_TEST_CALLS"
  grep -F $'InRelease=2024-03-09T16:00:00Z; signing-subkey=FEDCBA9876543210FEDCBA9876543210FEDCBA98\tsha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    "$MIRROROS_CONFIGURE_ROOT"/var/log/mirroros/configure/*/sources.tsv
  printf '159.0.0.0-1.1\n' > "$CFG_TEST_INSTALLED/google-chrome"
  : > "$CFG_TEST_CALLS"
  export CHROME_TEST_HANDLER=org.example.Other.desktop
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  grep -F 'notice: effective HTTPS handler differs from Google Chrome; left unchanged.' \
    "$MIRROROS_CONFIGURE_ROOT"/var/log/mirroros/configure/*/configure.log
  grep -Fx 'MirrorOS Google Chrome 159.0.0.0-1.1 is unchanged.' \
    "$MIRROROS_CONFIGURE_ROOT"/var/log/mirroros/configure/*/configure.log
  [[ "$output" == *'desktop/browser: unchanged'* ]]
  ! grep -Eq 'chrome build|pacman -U' "$CFG_TEST_CALLS"
}

@test "target configure replaces even a same-version AUR package and only enables the units" {
  cfg_test_target_context
  printf '158.0.8127.36-1.1\n' > "$CFG_TEST_INSTALLED/google-chrome"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  grep -F 'Replaced non-MirrorOS Google Chrome' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/configure.log
  grep -Fx 'chrome transaction SNAP_PAC_SKIP=y' "$CFG_TEST_CALLS"
  grep -Fx 'chrome color offline=1' "$CFG_TEST_CALLS"
  local policies="$CFG_TEST_TARGET_ROOT/etc/opt/chrome/policies"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/mirroros.json" "$policies/managed/mirroros.json"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/recommended.json" "$policies/recommended/mirroros.json"
  ! grep -Eq 'pacman -R|systemctl .*(start|restart|reload)' "$CFG_TEST_CALLS"
  for unit in mirroros-chrome-update-check.service mirroros-chrome-update-check.timer; do
    [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/$unit")" = "/etc/systemd/user/$unit" ]
    cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/$unit" "$CFG_TEST_TARGET_ROOT/etc/systemd/user/$unit"
  done
  grep -Fx 'After=graphical-session.target mirroros-shell.service' \
    "$CFG_TEST_TARGET_ROOT/etc/systemd/user/mirroros-chrome-update-check.service"
}

@test "configure preserves a customized managed policy" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local policy="$MIRROROS_CONFIGURE_ROOT/etc/opt/chrome/policies/managed/mirroros.json"
  printf '%s\n' '{"MetricsReportingEnabled":true}' > "$policy"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -Fx '{"MetricsReportingEnabled":true}' "$policy"
}

@test "configure folds unmodified legacy Chrome policies into mirroros.json" {
  local dir="$MIRROROS_CONFIGURE_ROOT/etc/opt/chrome/policies"
  mkdir -p "$dir/managed" "$dir/recommended"
  printf '%s\n' '{' '  "DefaultBrowserSettingEnabled": false,' '  "MetricsReportingEnabled": false' '}' > "$dir/managed/mirroros.json"
  printf '%s\n' '{' '  "RestoreOnStartup": 1,' '  "DefaultSearchProviderEnabled": true,' \
    '  "DefaultSearchProviderName": "Google",' '  "DefaultSearchProviderSearchURL": "{google:baseURL}search?q={searchTerms}",' \
    '  "ShowHomeButton": true,' '  "BackgroundModeEnabled": false' '}' > "$dir/recommended/mirroros.json"
  printf '%s\n' '{' '  "SyncTypesListDisabled": [' '    "apps",' '    "extensions",' \
    '    "preferences",' '    "themes"' '  ]' '}' > "$dir/managed/local-sync-types.json"
  printf '%s\n' '{' '  "SafeBrowsingProtectionLevel": 1' '}' > "$dir/recommended/local-safe-browsing.json"
  chmod 0755 "$dir" "$dir/managed" "$dir/recommended"
  chmod 0644 "$dir"/*/*.json
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/mirroros.json" "$dir/managed/mirroros.json"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/browser/policies/recommended.json" "$dir/recommended/mirroros.json"
  [ ! -e "$dir/managed/local-sync-types.json" ]
  [ ! -e "$dir/recommended/local-safe-browsing.json" ]
}

@test "configure preserves a conflicting local sync policy" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local policy="$MIRROROS_CONFIGURE_ROOT/etc/opt/chrome/policies/managed/local-sync-types.json"
  printf '%s\n' '{"SyncTypesListDisabled":["extensions"]}' > "$policy"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -Fx '{"SyncTypesListDisabled":["extensions"]}' "$policy"
}

@test "verification failure aborts readiness and leaves a foreign package installed" {
  printf '157.0.0.0-1\n' > "$CFG_TEST_INSTALLED/google-chrome"
  export CHROME_CONFIGURE_FAIL=1
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -F 'resolve the reported channel integrity failure' \
    "$MIRROROS_CONFIGURE_ROOT"/var/log/mirroros/configure/*/configure.log
  [[ "$output" == *'Next action:'* ]]
  ! grep -Eq 'pacman -[UR]' "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_INSTALLED/google-chrome")" = '157.0.0.0-1' ]
}
