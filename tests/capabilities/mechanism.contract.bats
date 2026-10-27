load support

setup() { cfg_test_setup; }
teardown() { cfg_test_teardown; }

@test "managed user files are created updated and never replace user-owned content or links" {
  printf '# managed by MirrorOS configure\nfirst\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .config/example'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$CFG_TEST_HOME/.config/example"
  printf '# managed by MirrorOS configure\nsecond\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .config/example'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$CFG_TEST_HOME/.config/example"
  printf 'user content\n' > "$CFG_TEST_HOME/.config/example"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .config/example'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned'* ]]
  [ "$(< "$CFG_TEST_HOME/.config/example")" = 'user content' ]
  rm "$CFG_TEST_HOME/.config/example"
  ln -s "$CFG_TEST_DIR/source" "$CFG_TEST_HOME/.config/example"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .config/example'
  [ "$status" -eq 0 ]
  [ -L "$CFG_TEST_HOME/.config/example" ]
  [ "$(grep -c '^runuser -u alice' "$CFG_TEST_CALLS")" -eq 4 ]
}

@test "legacy user configuration prevents creation of a shadowing Lua file" {
  mkdir -p "$CFG_TEST_HOME/.config/hypr"
  printf 'user configuration\n' > "$CFG_TEST_HOME/.config/hypr/hyprland.conf"
  printf '%s\n' '-- managed by MirrorOS configure' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .config/hypr/hyprland.lua; cfg_user_file_present .config/hypr/hyprland.lua'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned'* ]]
  [ ! -e "$CFG_TEST_HOME/.config/hypr/hyprland.lua" ]
}

@test "system managed files preserve non-managed content and symbolic links" {
  printf '# managed by MirrorOS configure\nfirst\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_system_file "$CFG_TEST_DIR/source" /etc/example 0644'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$MIRROROS_CONFIGURE_ROOT/etc/example"
  printf '# managed by MirrorOS configure\nsecond\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_system_file "$CFG_TEST_DIR/source" /etc/example 0644'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$MIRROROS_CONFIGURE_ROOT/etc/example"
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_system_file "$CFG_TEST_DIR/source" /etc/example 0644'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  printf 'user configuration\n' > "$MIRROROS_CONFIGURE_ROOT/etc/example"
  run cfg_test_helpers 'cfg_system_file "$CFG_TEST_DIR/source" /etc/example 0644'
  [ "$status" -eq 0 ]
  [ "$(< "$MIRROROS_CONFIGURE_ROOT/etc/example")" = 'user configuration' ]
  rm "$MIRROROS_CONFIGURE_ROOT/etc/example"
  ln -s "$CFG_TEST_DIR/source" "$MIRROROS_CONFIGURE_ROOT/etc/example"
  run cfg_test_helpers 'cfg_system_file "$CFG_TEST_DIR/source" /etc/example 0644'
  [ "$status" -eq 0 ]
  [ -L "$MIRROROS_CONFIGURE_ROOT/etc/example" ]
}

@test "bashrc gains exactly one block without rewriting the existing prefix" {
  printf '# user shell configuration\nalias example=true\n' > "$CFG_TEST_HOME/.bashrc"
  cp "$CFG_TEST_HOME/.bashrc" "$CFG_TEST_DIR/original"
  for repetition in 1 2 3; do
    run cfg_test_helpers 'cfg_bashrc_block .config/mirroros/bash/starship.bash; cfg_bashrc_block_present'
    [ "$status" -eq 0 ]
  done
  [ "$(grep -c '^# BEGIN MirrorOS configure$' "$CFG_TEST_HOME/.bashrc")" -eq 1 ]
  [ "$(grep -c '^# END MirrorOS configure$' "$CFG_TEST_HOME/.bashrc")" -eq 1 ]
  head -c "$(stat -c %s "$CFG_TEST_DIR/original")" "$CFG_TEST_HOME/.bashrc" | cmp - "$CFG_TEST_DIR/original"
}

@test "pending upgrades block package installation and list all validation problems" {
  cfg_test_step
  export CFG_TEST_UPGRADES='bash 1 -> 2'
  printf 'KEYMAP=not-a-layout\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'known XKB layout'* ]]
  [[ "$output" == *'sudo pacman -Syu or rerun with --refresh'* ]]
  cfg_test_no_install
}

@test "missing XKB data is rejected before package mutation" {
  cfg_test_step
  rm "$MIRROROS_CONFIGURE_ROOT/usr/share/X11/xkb/rules/base.lst"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'xkeyboard-config'* ]]
  cfg_test_no_install
}

@test "keyboard resolution prefers XKBLAYOUT over KEYMAP and ignores shell syntax" {
  printf 'KEYMAP=not-a-layout\nXKBLAYOUT="es"\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf 'XKBLAYOUT=$(touch %s)\n' "$CFG_TEST_DIR/unsafe" > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [ ! -e "$CFG_TEST_DIR/unsafe" ]
}

@test "default installation never syncs and ignored upgrades do not block it" {
  cfg_test_step
  export CFG_TEST_UPGRADES='bash 1 -> 2 [ignored]'
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  grep -q '^pacman -S --needed --noconfirm -- extra/example$' "$CFG_TEST_CALLS"
  ! grep -q '^pacman -Sy ' "$CFG_TEST_CALLS"
  ! grep -q '^pacman -Syu ' "$CFG_TEST_CALLS"
}

@test "refresh uses a full upgrade only on the first transaction" {
  cfg_test_step first
  cfg_test_step second
  printf 'second extra\n' > "$CFG_TEST_DIR/code/capabilities/second/packages"
  printf 'CFG_STEPS=(first second)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  export CFG_TEST_UPGRADES='bash 1 -> 2'
  run "$CFG_TEST_ENTRY" --refresh
  [ "$status" -eq 0 ]
  grep -q '^pacman -Syu --needed --noconfirm -- extra/example$' "$CFG_TEST_CALLS"
  grep -q '^pacman -S --needed --noconfirm -- extra/second$' "$CFG_TEST_CALLS"
  ! grep -q '^pacman -Sy ' "$CFG_TEST_CALLS"
}

@test "an already configured rerun performs no package transaction even with refresh" {
  cfg_test_step
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --refresh
  [ "$status" -eq 0 ]
  [[ "$output" == *'example: unchanged'* ]]
  cfg_test_no_install
}

@test "repository mismatch absent databases and a held lock prevent convergence" {
  cfg_test_step
  export CFG_TEST_REPOSITORY=core
  rm "$MIRROROS_CONFIGURE_ROOT/var/lib/pacman/sync/extra.db"
  exec 9> "$MIRROROS_CONFIGURE_ROOT/run/mirroros/configure.lock"
  flock -n 9
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'holds the lock'* ]]
  [[ "$output" == *'Sync databases are absent'* ]]
  [[ "$output" == *'declared repository extra'* ]]
  cfg_test_no_install
  exec 9>&-
}

@test "step command and postcondition failures remain distinct and later steps do not run" {
  cfg_test_step first 'false'
  cfg_test_step second 'printf later'
  printf 'CFG_STEPS=(first second)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/failure"
  [ "$status" -eq 5 ]
  [[ "$output" == *'step first'* ]]
  [[ "$output" != *'available at the next boot'* ]]
  grep -q $'step\tsecond\tnot_run\tnot_checked' "$CFG_TEST_DIR/failure/configure-run.tsv"
  grep -q $'timing\tstep.first\tavailable\t' "$CFG_TEST_DIR/failure/configure-run.tsv"
  run grep -q $'timing\tstep.second\t' "$CFG_TEST_DIR/failure/configure-run.tsv"
  [ "$status" -eq 1 ]
  printf 'cfg_require false\n' > "$CFG_TEST_DIR/code/capabilities/first/apply"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/postcondition"
  [ "$status" -eq 4 ]
}

@test "evidence is private TSV with run identity package provenance and no temporary state" {
  cfg_test_step
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/evidence"
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "$CFG_TEST_DIR/evidence")" = 700 ]
  grep -q $'run\tcontext\trunning' "$CFG_TEST_DIR/evidence/configure-run.tsv"
  [[ "$output" == *'== 1/1 example =='* ]]
  grep -q $'run\toutcome\t0' "$CFG_TEST_DIR/evidence/configure-run.tsv"
  grep -q $'run\tformat_version\t2' "$CFG_TEST_DIR/evidence/configure-run.tsv"
  for interval in total validation step.example; do
    grep -q $'timing\t'"$interval"$'\tavailable\t' "$CFG_TEST_DIR/evidence/configure-run.tsv"
  done
  grep -q $'example\t1.0-1\textra' "$CFG_TEST_DIR/evidence/packages.tsv"
  [ "$(find "$CFG_TEST_DIR/evidence" -type f | wc -l)" -eq 3 ]
}

@test "unavailable timing does not change configure success or invent a duration" {
  cfg_test_step
  printf '\ntiming_clock_read() { TIMING_NOW=""; TIMING_CLOCK_REASON=clock_malformed; }\n' >> "$CFG_TEST_DIR/code/operations/lib/timing.sh"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/no-clock"
  [ "$status" -eq 0 ]
  grep -q $'timing\ttotal\tunavailable\t\tclock_malformed' "$CFG_TEST_DIR/no-clock/configure-run.tsv"
  grep -q $'timing\tvalidation\tunavailable\t\tclock_malformed' "$CFG_TEST_DIR/no-clock/configure-run.tsv"
  grep -q $'timing\tstep.example\tunavailable\t\tclock_malformed' "$CFG_TEST_DIR/no-clock/configure-run.tsv"
}

@test "a linked bashrc is user-owned and its target stays untouched" {
  printf '# external shell configuration\n' > "$CFG_TEST_DIR/external"
  ln -s "$CFG_TEST_DIR/external" "$CFG_TEST_HOME/.bashrc"
  run cfg_test_helpers 'cfg_bashrc_block .config/mirroros/bash/starship.bash; cfg_bashrc_block_present'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned: .bashrc'* ]]
  [ "$(< "$CFG_TEST_DIR/external")" = '# external shell configuration' ]
}

@test "signals yield normalized outcomes identify the step and allow a full rerun" {
  for signal in INT TERM HUP; do
    cfg_test_step first 'kill -s '"$signal"' "$$"'
    cfg_test_step second 'cfg_packages_ensure "$STEP_DIR/packages"'
    printf 'CFG_STEPS=(first second)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
    run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/signal-$signal"
    if [ "$signal" = INT ]; then [ "$status" -eq 3 ]; else [ "$status" -eq 5 ]; fi
    [[ "$output" == *"SIG$signal"* ]]
    [[ "$output" == *'step first'* ]]
    [[ "$output" != *'available at the next boot'* ]]
    grep -q $'step\tsecond\tnot_run' "$CFG_TEST_DIR/signal-$signal/configure-run.tsv"
    grep -q $'timing\tstep.first\tavailable\t' "$CFG_TEST_DIR/signal-$signal/configure-run.tsv"
    run grep -q $'timing\tstep.second\t' "$CFG_TEST_DIR/signal-$signal/configure-run.tsv"
    [ "$status" -eq 1 ]
    printf ':\n' > "$CFG_TEST_DIR/code/capabilities/first/apply"
    run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/rerun-$signal"
    [ "$status" -eq 0 ]
    grep -q $'step\tfirst\tunchanged\tpassed' "$CFG_TEST_DIR/rerun-$signal/configure-run.tsv"
  done
}

@test "package transaction failure preserves the original child status in the log" {
  cfg_test_step
  export CFG_TEST_INSTALL_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/transaction-failure"
  [ "$status" -eq 5 ]
  grep -q 'child status 17' "$CFG_TEST_DIR/transaction-failure/configure.log"
  [ ! -e "$CFG_TEST_INSTALLED/example" ]
}

@test "a missing base tool is reported before convergence" {
  cfg_test_step
  for tool in bash flock install awk grep cmp dirname mkdir chmod chown ln readlink rm mv cat date find sort stat mktemp; do
    [ -e "$CFG_TEST_DIR/bin/$tool" ] || ln -s "$(command -v "$tool")" "$CFG_TEST_DIR/bin/$tool"
  done
  old_path="$PATH"
  export PATH="$CFG_TEST_DIR/bin"
  run "$CFG_TEST_ENTRY"
  export PATH="$old_path"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Missing base tool: systemctl'* ]]
  cfg_test_no_install
}

@test "each repeated package declaration must resolve to its own repository" {
  cfg_test_step
  printf 'example extra\nexample core\n' > "$CFG_TEST_DIR/code/capabilities/example/packages"
  export CFG_TEST_REPOSITORY=extra
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'declared repository core'* ]]
  cfg_test_no_install
}

@test "an upgrade query failure is not accepted as an empty guard" {
  cfg_test_step
  export CFG_TEST_QUERY_STATUS=1 CFG_TEST_UPGRADES='error: database query failed'
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Cannot query pending upgrades'* ]]
  cfg_test_no_install
}

@test "the package helper makes no pacman call when its package set is installed" {
  cfg_test_step
  run cfg_test_helpers 'CFG_INSTALLED[example]=1; CFG_REFRESH=1; cfg_packages_ensure "$CAPABILITIES_DIR/example/packages"'
  [ "$status" -eq 0 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "an unknown execution context fails closed with outcome 6" {
  run cfg_test_helpers 'CONFIGURE_CONTEXT=unknown; cfg_packages_ensure /unused'
  [ "$status" -eq 6 ]
  [[ "$output" == *'invalid execution context'* ]]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "session query requires one readable entry and every Exec marker without mutation" {
  directory="$MIRROROS_CONFIGURE_ROOT/usr/share/example-sessions"
  mkdir -p "$directory" "$MIRROROS_CONFIGURE_ROOT/usr/share/package-sessions"
  file="$MIRROROS_CONFIGURE_ROOT/usr/share/package-sessions/example.desktop"
  printf '[Desktop Entry]\nExec=session-manager start example.desktop\n' > "$file"
  ln -s /usr/share/package-sessions/example.desktop "$directory/example.desktop"
  run cfg_test_helpers 'cfg_session_is_only /usr/share/example-sessions example.desktop "session-manager start" example.desktop'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  touch "$directory/second.desktop"
  run cfg_test_helpers 'cfg_session_is_only /usr/share/example-sessions example.desktop "session-manager start" example.desktop'
  [ "$status" -eq 1 ]
  rm "$directory/second.desktop"
  printf '[Desktop Entry]\nExec=direct-session\n' > "$file"
  run cfg_test_helpers 'cfg_session_is_only /usr/share/example-sessions example.desktop "session-manager start" example.desktop'
  [ "$status" -eq 1 ]
  rm "$file"
  run cfg_test_helpers 'cfg_session_is_only /usr/share/example-sessions example.desktop "session-manager start" example.desktop'
  [ "$status" -eq 1 ]
  [ -L "$directory/example.desktop" ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "apply scripts never invoke effectful base commands directly" {
  while IFS= read -r -d '' script; do
    ! grep -vE '^[[:space:]]*#' "$script" |
      grep -En '(^|[;&|()[:space:]])((/usr)?/bin/)?(pacman|systemctl|install|runuser)([[:space:]]|$)'
  done < <(find "$CFG_SOURCE_ROOT/capabilities" -type f -name apply -print0)
}

terminal_desktop_entry() {
  mkdir -p "$CFG_TEST_HOME/.local/share/applications"
  printf '[Desktop Entry]\nName=Foot\nExec=foot\n' > "$CFG_TEST_HOME/.local/share/applications/${1:-foot.desktop}"
}

@test "terminal delivers approved native defaults and emoji dependency with unchanged rerun" {
  printf 'CFG_STEPS=(desktop/terminal)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  terminal_desktop_entry
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/terminal/foot.ini" "$CFG_TEST_HOME/.config/foot/foot.ini"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/terminal/xdg-terminals.list" "$CFG_TEST_HOME/.config/xdg-terminals.list"
  [ "$(grep -v '^#' "$CFG_TEST_HOME/.config/xdg-terminals.list")" = foot.desktop ]
  grep -q '^font=JetBrainsMono Nerd Font Mono:size=14$' "$CFG_TEST_HOME/.config/foot/foot.ini"
  grep -q '^pad=16x16 center$' "$CFG_TEST_HOME/.config/foot/foot.ini"
  grep -qF '\x1b[13;2u=Shift+Return' "$CFG_TEST_HOME/.config/foot/foot.ini"
  [ -e "$CFG_TEST_INSTALLED/noto-fonts-emoji" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/terminal: unchanged'* ]]
  cfg_test_no_install
}

@test "terminal preserves user-owned native defaults and package system configuration" {
  printf 'CFG_STEPS=(desktop/terminal)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  terminal_desktop_entry
  mkdir -p "$CFG_TEST_HOME/.config/foot" "$MIRROROS_CONFIGURE_ROOT/etc/xdg/foot"
  printf '# user terminal\nfont=local\n' > "$CFG_TEST_HOME/.config/foot/foot.ini"
  printf '# package terminal\n' > "$MIRROROS_CONFIGURE_ROOT/etc/xdg/foot/foot.ini"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/terminal: changed'* ]]
  [ "$(< "$CFG_TEST_HOME/.config/foot/foot.ini")" = $'# user terminal\nfont=local' ]
  [ "$(< "$MIRROROS_CONFIGURE_ROOT/etc/xdg/foot/foot.ini")" = '# package terminal' ]
}

@test "a user-owned terminal list naming no installed terminal is an actionable conflict and is preserved" {
  printf 'CFG_STEPS=(desktop/terminal)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  terminal_desktop_entry
  printf '# my terminals\nmissing-terminal.desktop\n' > "$CFG_TEST_DIR/list"
  mkdir -p "$CFG_TEST_HOME/.config"
  cp "$CFG_TEST_DIR/list" "$CFG_TEST_HOME/.config/xdg-terminals.list"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/out"
  [ "$status" -eq 4 ]
  grep -qF 'No installed terminal is listed in .config/xdg-terminals.list' "$CFG_TEST_DIR/out/configure.log"
  cmp "$CFG_TEST_DIR/list" "$CFG_TEST_HOME/.config/xdg-terminals.list"
  printf 'missing-terminal.desktop\n+foot.desktop:new-window\n' > "$CFG_TEST_HOME/.config/xdg-terminals.list"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf 'missing-terminal.desktop\n' > "$CFG_TEST_HOME/.config/hyprland-xdg-terminals.list"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
}

@test "an unknown session keyboard layout is rejected before package mutation" {
  cfg_test_step
  printf 'CFG_STEPS=(example desktop/compositor/providers/hyprland)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  printf '! layout\n  us English (US)\n! variant\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/X11/xkb/rules/base.lst"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Session keyboard layout es is not a known XKB layout'* ]]
  cfg_test_no_install
}

@test "session and greeter share the resolved-first layout list and the greeter receives the layout indicator" {
  printf 'CFG_STEPS=(desktop/compositor/providers/hyprland)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  printf 'KEYMAP=es\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions"
  printf '[Desktop Entry]\nExec=uwsm start hyprland.desktop\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions/hyprland-uwsm.desktop"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local session="$CFG_TEST_HOME/.config/hypr/hyprland.lua" provider="$CFG_SOURCE_ROOT/capabilities/desktop/compositor/providers/hyprland"
  for file in "$session" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/hyprland.lua"; do
    grep -qF 'kb_options = "compose:ralt"' "$file"
  done
  for file in "$session" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/hyprland.lua"; do
    grep -qF 'kb_layout = require("/usr/share/mirroros/hypr/layouts.lua")' "$file"
  done
  for file in "$session" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/hyprland.lua"; do
    grep -qxF 'dofile("/usr/share/mirroros/hypr/monitors.lua")' "$file"
  done
  cmp "$provider/monitors.lua" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/monitors.lua"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/monitors.lua")" = 644 ]
  cmp "$provider/layouts.lua" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/layouts.lua"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/layouts.lua")" = 644 ]
  cmp "$provider/greeter/layout-indicator" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/layout-indicator"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/layout-indicator")" = 755 ]
  grep -qF 'preserve_split = true' "$session"
  grep -qF 'dofile("/usr/share/mirroros/hypr/shell-bindings.lua")' "$session"
  grep -qF 'dofile("/usr/share/mirroros/hypr/window-bindings.lua")' "$session"
  refute grep -qE 'SHIFT \+ [QE]"' "$session"
  for file in shell-bindings.lua window-bindings.lua; do
    cmp "$provider/$file" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/$file"
  done
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/compositor/providers/hyprland: unchanged'* ]]
  grep -qF 'repeat_delay = 230' "$CFG_TEST_HOME/.config/hypr/hyprland.lua"
  grep -qF 'repeat_rate = 62' "$CFG_TEST_HOME/.config/hypr/hyprland.lua"
  [[ "$(< "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/hyprland.lua")" != *repeat_delay* ]]
  [[ "$(< "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/sddm/hyprland.lua")" != *repeat_rate* ]]
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/compositor/providers/hyprland/keyboard.lua" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/hypr/keyboard.lua"
  ! grep -qE 'systemctl (start|restart)' "$CFG_TEST_CALLS"
}

@test "editor-owned Lazygit input follows managed-file ownership without reading personal state" {
  run cfg_test_helpers 'cfg_user_file "$CAPABILITIES_DIR/workflow/editor/lazygit.yml" .config/lazygit/config.yml'
  [ "$status" -eq 0 ]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/editor/lazygit.yml" "$CFG_TEST_HOME/.config/lazygit/config.yml"
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_user_file "$CAPABILITIES_DIR/workflow/editor/lazygit.yml" .config/lazygit/config.yml'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  printf '# private settings\n' > "$CFG_TEST_HOME/.config/lazygit/config.yml"
  run cfg_test_helpers 'cfg_user_file "$CAPABILITIES_DIR/workflow/editor/lazygit.yml" .config/lazygit/config.yml'
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.config/lazygit/config.yml")" = '# private settings' ]
  [ ! -e "$CFG_TEST_HOME/.config/lazygit/state.yml" ]
}

node_step() {
  printf 'CFG_STEPS=(workflow/node)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

node_runtime_fixture() {
  mkdir -p "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin"
  printf '# user nvm\n' > "$CFG_TEST_HOME/.nvm/nvm.sh"
  printf '#!/usr/bin/bash\nprintf "v24.22.0\\n"\n' > "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/node"
  printf '#!/usr/bin/bash\nprintf "10.0.0\\n"\n' > "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/npm"
  chmod 0755 "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/"{node,npm}
}

node_unrelated_nvm() {
  mkdir -p "$CFG_TEST_HOME/.nvm/.git"
  printf '%s\n' "${1:-cccccccccccccccccccccccccccccccccccccccc}" > "$CFG_TEST_HOME/.nvm/.git/fixture-head"
  printf '# user nvm\n' > "$CFG_TEST_HOME/.nvm/nvm.sh"
}

node_nothing_published() {
  [ ! -e "$CFG_TEST_HOME/.nvm" ]
  ! compgen -G "$CFG_TEST_HOME/.nvm.mirroros.*" > /dev/null
}

@test "node runtime is provisioned as the user from the declaration and a rerun has no effects" {
  node_step
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/node-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/node: changed'* ]]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/node/environment.zsh" "$CFG_TEST_HOME/.config/mirroros/node/environment.zsh"
  [ "$("$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/node" --version)" = v24.22.0 ]
  [ "$(grep -c '^curl ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^nvm-installer PROFILE=/dev/null VERSION=v0.40.8 ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^nvm install v24.22.0$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -B1 '^curl ' "$CFG_TEST_CALLS" | head -1)" = 'runuser -u alice' ]
  grep -q '^pacman -S --needed --noconfirm -- extra/git$' "$CFG_TEST_CALLS"
  ! grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  node_staging="$(compgen -G "$CFG_TEST_HOME/.nvm.mirroros.*" || true)"
  [ -z "$node_staging" ]
  grep -q $'^nvm\thttps://github.com/nvm-sh/nvm\tv0.40.8\ta885b885fef16fac4bc544188fb25e9e37ae83e8\tv0.40.8$' "$CFG_TEST_DIR/node-run/sources.tsv"
  grep -q $'^node\thttps://nodejs.org/dist\tv24.22.0\t\tv24.22.0$' "$CFG_TEST_DIR/node-run/sources.tsv"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/node: unchanged'* ]]
  ! grep -qE '^(curl|nvm-installer|nvm install) ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "node provisioning stops before executing a downloaded installer with a wrong checksum" {
  node_step
  export CFG_TEST_INSTALLER_TAMPERED=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/tampered"
  [ "$status" -eq 5 ]
  grep -q 'installer checksum mismatch; nothing was executed' "$CFG_TEST_DIR/tampered/configure.log"
  ! grep -q '^nvm-installer ' "$CFG_TEST_CALLS"
  node_nothing_published
}

@test "failed download installer or identity check never publishes NVM or leaves staging" {
  node_step
  export CFG_TEST_CURL_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/download-failure"
  [ "$status" -eq 5 ]
  grep -q 'cannot download the NVM v0.40.8 installer' "$CFG_TEST_DIR/download-failure/configure.log"
  node_nothing_published
  unset CFG_TEST_CURL_FAIL
  export CFG_TEST_NVM_INSTALLER_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/installer-failure"
  [ "$status" -eq 5 ]
  grep -q 'installer failed' "$CFG_TEST_DIR/installer-failure/configure.log"
  node_nothing_published
  unset CFG_TEST_NVM_INSTALLER_FAIL
  export CFG_TEST_NVM_COMMIT=dddddddddddddddddddddddddddddddddddddddd
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/identity-failure"
  [ "$status" -eq 5 ]
  grep -q 'does not match release v0.40.8' "$CFG_TEST_DIR/identity-failure/configure.log"
  node_nothing_published
  ! grep -q '^nvm install ' "$CFG_TEST_CALLS"
}

@test "a destination created during installation is preserved and the owned staging is removed" {
  node_step
  export CFG_TEST_NVM_CONCURRENT=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/concurrent"
  [ "$status" -eq 5 ]
  grep -q 'appeared during installation; preserved unchanged' "$CFG_TEST_DIR/concurrent/configure.log"
  [ "$(< "$CFG_TEST_HOME/.nvm/untouched")" = 'concurrent content' ]
  [ "$(find "$CFG_TEST_HOME/.nvm" -type f | wc -l)" -eq 1 ]
  ! compgen -G "$CFG_TEST_HOME/.nvm.mirroros.*" > /dev/null
}

@test "an unrelated modified or linked NVM installation is never overwritten" {
  node_step
  node_unrelated_nvm
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/unrelated"
  [ "$status" -eq 5 ]
  grep -q 'is not the unmodified NVM v0.40.8; preserved unchanged' "$CFG_TEST_DIR/unrelated/configure.log"
  [ "$(< "$CFG_TEST_HOME/.nvm/nvm.sh")" = '# user nvm' ]
  [ "$(< "$CFG_TEST_HOME/.nvm/.git/fixture-head")" = cccccccccccccccccccccccccccccccccccccccc ]
  node_unrelated_nvm a885b885fef16fac4bc544188fb25e9e37ae83e8
  printf ' M nvm.sh\n' > "$CFG_TEST_HOME/.nvm/.git/fixture-status"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/modified"
  [ "$status" -eq 5 ]
  [ "$(< "$CFG_TEST_HOME/.nvm/nvm.sh")" = '# user nvm' ]
  rm -r "$CFG_TEST_HOME/.nvm"
  mkdir "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$CFG_TEST_HOME/.nvm"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/linked"
  [ "$status" -eq 5 ]
  [ -L "$CFG_TEST_HOME/.nvm" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  ! grep -qE '^(curl|nvm-installer|nvm install) ' "$CFG_TEST_CALLS"
}

@test "an existing runtime is accepted without touching its unrelated NVM and an identified NVM only gains Node" {
  node_step
  node_unrelated_nvm
  node_runtime_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/satisfied"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/node: changed'* ]]
  [ "$(< "$CFG_TEST_HOME/.nvm/nvm.sh")" = '# user nvm' ]
  ! grep -qE '^(curl|nvm-installer|nvm install) ' "$CFG_TEST_CALLS"
  grep -q $'^nvm\thttps://github.com/nvm-sh/nvm\t\t\t$' "$CFG_TEST_DIR/satisfied/sources.tsv"
  rm -r "$CFG_TEST_HOME/.nvm"
  node_unrelated_nvm a885b885fef16fac4bc544188fb25e9e37ae83e8
  cat > "$CFG_TEST_HOME/.nvm/nvm.sh" <<'NVM'
nvm() {
  printf 'nvm install %s\n' "$2" >> "$CFG_TEST_CALLS"
  mkdir -p "$NVM_DIR/versions/node/$2/bin"
  printf '#!/usr/bin/bash\nprintf "%%s\\n" %s\n' "$2" > "$NVM_DIR/versions/node/$2/bin/node"
  printf '#!/usr/bin/bash\nprintf 10\n' > "$NVM_DIR/versions/node/$2/bin/npm"
  chmod 0755 "$NVM_DIR/versions/node/$2/bin/"{node,npm}
}
NVM
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/identified"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^nvm install v24.22.0$' "$CFG_TEST_CALLS")" -eq 1 ]
  ! grep -qE '^(curl|nvm-installer) ' "$CFG_TEST_CALLS"
}

@test "a failed Node.js installation keeps the verified NVM and the rerun resumes without a download" {
  node_step
  export CFG_TEST_NODE_INSTALL_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/node-failure"
  [ "$status" -eq 5 ]
  grep -q 'Node.js v24.22.0 installation failed' "$CFG_TEST_DIR/node-failure/configure.log"
  [ -s "$CFG_TEST_HOME/.nvm/nvm.sh" ]
  [ ! -e "$CFG_TEST_HOME/.nvm/versions" ]
  unset CFG_TEST_NODE_INSTALL_FAIL
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  ! grep -qE '^(curl|nvm-installer) ' "$CFG_TEST_CALLS"
  [ "$(grep -c '^nvm install v24.22.0$' "$CFG_TEST_CALLS")" -eq 1 ]
}

@test "a user-owned environment file is preserved while provisioning follows the MirrorOS declaration" {
  node_step
  mkdir -p "$CFG_TEST_HOME/.config/mirroros/node"
  printf '# mine\nMIRROROS_NODE_VERSION=v1.0.0\n' > "$CFG_TEST_HOME/.config/mirroros/node/environment.zsh"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.config/mirroros/node/environment.zsh")" = $'# mine\nMIRROROS_NODE_VERSION=v1.0.0' ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/node" ]
  [ ! -e "$CFG_TEST_HOME/.nvm/versions/node/v1.0.0" ]
}

@test "the Node.js version has one declaration that rejects malformed values" {
  run cfg_test_helpers 'cfg_node_version'
  [ "$status" -eq 0 ]
  [ "$output" = v24.22.0 ]
  ! grep -rn 'v24\.' "$CFG_SOURCE_ROOT/capabilities/workflow/node/apply" "$CFG_SOURCE_ROOT/capabilities/workflow/node/install-nvm"
  for value in '^24' 'v24' 'latest' ''; do
    printf '# managed by MirrorOS configure\nMIRROROS_NODE_VERSION=%s\n' "$value" > "$CFG_TEST_DIR/code/capabilities/workflow/node/environment.zsh"
    run cfg_test_helpers 'cfg_node_version'
    [ "$status" -ne 0 ]
  done
}

@test "zsh startup puts the selected Node.js on PATH and loads NVM only through nvm_load" {
  command -v zsh > /dev/null || skip 'zsh is not installed'
  node_runtime_fixture
  printf 'touch "%s/nvm-loaded"\n' "$CFG_TEST_DIR" > "$CFG_TEST_HOME/.nvm/nvm.sh"
  printf 'true\n' > "$CFG_TEST_HOME/.nvm/bash_completion"
  zsh -n "$CFG_SOURCE_ROOT/capabilities/workflow/node/environment.zsh"
  run env -i HOME="$CFG_TEST_HOME" PATH=/usr/bin:/bin zsh -f -c 'source "$1"; print -r -- "${path[2]}"; (( $+functions[nvm_load] ))' zsh "$CFG_SOURCE_ROOT/capabilities/workflow/node/environment.zsh"
  [ "$status" -eq 0 ]
  [ "$output" = "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin" ]
  [ ! -e "$CFG_TEST_DIR/nvm-loaded" ]
  run env -i HOME="$CFG_TEST_HOME" PATH=/usr/bin:/bin zsh -f -c 'source "$1"; nvm_load' zsh "$CFG_SOURCE_ROOT/capabilities/workflow/node/environment.zsh"
  [ "$status" -eq 0 ]
  [ -e "$CFG_TEST_DIR/nvm-loaded" ]
}

shell_step() {
  printf 'CFG_STEPS=(workflow/shell)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

shell_accounts() {
  printf 'alice:x:1000:1000::%s:%s\n' "$CFG_TEST_HOME" "${1:-/usr/bin/bash}" > "$MIRROROS_CONFIGURE_ROOT/etc/passwd"
  printf '/bin/bash\n/usr/bin/zsh\n' > "$MIRROROS_CONFIGURE_ROOT/etc/shells"
}

shell_zplug_fixture() {
  mkdir -p "$CFG_TEST_HOME/.local/share/zplug/.git"
  printf '%s\n' "${2:-https://github.com/zplug/zplug.git}" > "$CFG_TEST_HOME/.local/share/zplug/.git/fixture-remote"
  printf '%s\n' "${1:-1111111111111111111111111111111111111111}" > "$CFG_TEST_HOME/.local/share/zplug/.git/fixture-head"
  printf '# fixture\n' > "$CFG_TEST_HOME/.local/share/zplug/init.zsh"
}

shell_nothing_published() {
  [ ! -e "$CFG_TEST_HOME/.local/share/zplug" ]
  ! compgen -G "$CFG_TEST_HOME/.local/share/.mirroros-*" > /dev/null
}

@test "shell provisions Zsh files identified plugin sources and the login shell as the user and a rerun has no effects" {
  shell_accounts
  shell_step
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/shell-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/shell: changed'* ]]
  for file in zshenv zshrc zprofile; do
    cmp "$CFG_SOURCE_ROOT/capabilities/workflow/shell/$file" "$CFG_TEST_HOME/.$file"
  done
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/shell/starship.toml" "$CFG_TEST_HOME/.config/starship.toml"
  grep -q '^add_newline = false$' "$CFG_TEST_HOME/.config/starship.toml"
  for commit in cc6906ea7ea18a5058e8b4862d4086148434ddde 91cafe4a09b6670cb8e761aa413e5f7b9e00816f \
    e6683f20e5c38d3e5447f45845d04ddda75d0f23 85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5 \
    989b23277ab33e8d5e82df6aed936e846db9d8b8 964ddf789b022b6958b27d02d7fa54f552de21e9; do
    [ "$(grep -c "^git .* fetch --quiet --depth 1 --no-tags origin $commit\$" "$CFG_TEST_CALLS")" -eq 1 ]
  done
  zplug="$CFG_TEST_HOME/.local/share/zplug"
  [ "$(< "$zplug/.git/fixture-head")" = cc6906ea7ea18a5058e8b4862d4086148434ddde ]
  [ "$(< "$zplug/repos/robbyrussell/oh-my-zsh/.git/fixture-head")" = 964ddf789b022b6958b27d02d7fa54f552de21e9 ]
  [ "$(< "$zplug/repos/robbyrussell/oh-my-zsh/.git/fixture-remote")" = https://github.com/ohmyzsh/ohmyzsh ]
  [ -e "$zplug/init.zsh" ]
  ! grep -q '^git .* ls-remote ' "$CFG_TEST_CALLS"
  [ "$(grep -c '^usermod --shell /usr/bin/zsh -- alice$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(cut -d: -f7 "$MIRROROS_CONFIGURE_ROOT/etc/passwd")" = /usr/bin/zsh ]
  grep -q $'^zplug\thttps://github.com/zplug/zplug\t\tcc6906ea7ea18a5058e8b4862d4086148434ddde\t$' "$CFG_TEST_DIR/shell-run/sources.tsv"
  grep -q $'^oh-my-zsh\thttps://github.com/ohmyzsh/ohmyzsh\t\t964ddf789b022b6958b27d02d7fa54f552de21e9\t$' "$CFG_TEST_DIR/shell-run/sources.tsv"
  grep -q '^pacman -S --needed --noconfirm -- extra/starship extra/zsh extra/fzf extra/zoxide extra/atuin extra/fd extra/bat extra/tree extra/ripgrep$' "$CFG_TEST_CALLS"
  ! compgen -G "$CFG_TEST_HOME/.local/share/.mirroros-*" > /dev/null
  ! grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/shell: unchanged'* ]]
  ! grep -qE '^(usermod) |^git .* (fetch|checkout|init) ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "plugin sources that already exist are accepted or preserved and never reset" {
  shell_accounts
  shell_step
  shell_zplug_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/accepted"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.local/share/zplug/.git/fixture-head")" = 1111111111111111111111111111111111111111 ]
  [ "$(grep -c ' fetch --quiet --depth 1 ' "$CFG_TEST_CALLS")" -eq 5 ]
  grep -q $'^zplug\thttps://github.com/zplug/zplug\t\t1111111111111111111111111111111111111111\t$' "$CFG_TEST_DIR/accepted/sources.tsv"
  rm -r "$CFG_TEST_HOME/.local/share/zplug"
  shell_zplug_fixture 1111111111111111111111111111111111111111 https://example.invalid/unrelated
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/foreign"
  [ "$status" -eq 5 ]
  grep -q 'is not a clone of https://github.com/zplug/zplug; preserved unchanged' "$CFG_TEST_DIR/foreign/configure.log"
  [ "$(< "$CFG_TEST_HOME/.local/share/zplug/.git/fixture-remote")" = https://example.invalid/unrelated ]
  ! grep -q ' fetch ' "$CFG_TEST_CALLS"
  rm -r "$CFG_TEST_HOME/.local/share/zplug"
  mkdir "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$CFG_TEST_HOME/.local/share/zplug"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/linked-root"
  [ "$status" -eq 5 ]
  [ -L "$CFG_TEST_HOME/.local/share/zplug" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  ! grep -q ' fetch ' "$CFG_TEST_CALLS"
}

@test "a failed fetch or a mismatched commit publishes nothing and leaves no staging" {
  shell_accounts
  shell_step
  export CFG_TEST_GIT_FETCH_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/fetch-failure"
  [ "$status" -eq 5 ]
  grep -q 'cannot fetch zplug commit cc6906ea7ea18a5058e8b4862d4086148434ddde' "$CFG_TEST_DIR/fetch-failure/configure.log"
  shell_nothing_published
  unset CFG_TEST_GIT_FETCH_FAIL
  export CFG_TEST_GIT_DETACH_HEAD=ffffffffffffffffffffffffffffffffffffffff
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/identity-failure"
  [ "$status" -eq 5 ]
  grep -q 'zplug does not match identified commit' "$CFG_TEST_DIR/identity-failure/configure.log"
  shell_nothing_published
  [ "$(cut -d: -f7 "$MIRROROS_CONFIGURE_ROOT/etc/passwd")" = /usr/bin/bash ]
}

@test "the login shell changes only from Bash and never without a listed installed shell" {
  shell_accounts /usr/bin/fish
  run cfg_test_helpers 'cfg_login_shell /usr/bin/zsh; cfg_login_shell_present /usr/bin/zsh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned: login shell /usr/bin/fish; left untouched'* ]]
  [ "$(cut -d: -f7 "$MIRROROS_CONFIGURE_ROOT/etc/passwd")" = /usr/bin/fish ]
  shell_accounts /usr/bin/zsh
  run cfg_test_helpers 'cfg_login_shell /usr/bin/zsh'
  [ "$status" -eq 0 ]
  ! grep -q '^usermod ' "$CFG_TEST_CALLS"
  shell_accounts
  printf '/bin/bash\n' > "$MIRROROS_CONFIGURE_ROOT/etc/shells"
  run cfg_test_helpers 'cfg_login_shell /usr/bin/zsh'
  [ "$status" -eq 4 ]
  [[ "$output" == *'/usr/bin/zsh is not listed in /etc/shells'* ]]
  [ "$(cut -d: -f7 "$MIRROROS_CONFIGURE_ROOT/etc/passwd")" = /usr/bin/bash ]
  shell_accounts
  export CFG_TEST_USERMOD_FAIL=1
  run cfg_test_helpers 'cfg_login_shell /usr/bin/zsh'
  [ "$status" -ne 0 ]
  [ "$(cut -d: -f7 "$MIRROROS_CONFIGURE_ROOT/etc/passwd")" = /usr/bin/bash ]
  run cfg_test_helpers 'cfg_login_shell_present /usr/bin/zsh'
  [ "$status" -ne 0 ]
  ! grep -qE 'sudo|chsh' "$CFG_TEST_CALLS"
}

@test "user-owned Zsh startup files and links are preserved while provisioning continues" {
  shell_accounts
  shell_step
  mkdir -p "$CFG_TEST_HOME/.config"
  printf 'add_newline = true\n' > "$CFG_TEST_HOME/.config/starship.toml"
  printf '# my zshrc\n' > "$CFG_TEST_HOME/.zshrc"
  printf '# elsewhere\n' > "$CFG_TEST_DIR/target-zshenv"
  ln -s "$CFG_TEST_DIR/target-zshenv" "$CFG_TEST_HOME/.zshenv"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.config/starship.toml")" = 'add_newline = true' ]
  [ "$(< "$CFG_TEST_HOME/.zshrc")" = '# my zshrc' ]
  [ -L "$CFG_TEST_HOME/.zshenv" ]
  [ "$(< "$CFG_TEST_DIR/target-zshenv")" = '# elsewhere' ]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/shell/zprofile" "$CFG_TEST_HOME/.zprofile"
  [ -e "$CFG_TEST_HOME/.local/share/zplug/init.zsh" ]
}

@test "Zsh startup files keep the approved features and perform no provisioning or host sourcing" {
  command -v zsh > /dev/null || skip 'zsh is not installed'
  shell_dir="$CFG_SOURCE_ROOT/capabilities/workflow/shell"
  for file in zshenv zshrc zprofile; do zsh -n "$shell_dir/$file"; done
  ! grep -nE 'zplug (install|update|check)|git clone|curl |wget |nvm\.sh|startx|export TERM=|zcustom|\.dotfiles' \
    "$shell_dir/zshenv" "$shell_dir/zshrc" "$shell_dir/zprofile"
  for feature in 'zsh-users/zsh-syntax-highlighting' 'zsh-users/zsh-autosuggestions' 'jeffreytse/zsh-vi-mode' \
    'starship init zsh' 'zoxide init zsh' 'atuin init zsh' 'fzf-history-widget' "bindkey '^ ' autosuggest-accept" \
    'reverse-menu-complete' 'FZF_CTRL_T_OPTS' 'FZF_ALT_C_OPTS' 'piw()' 'for omz_plugin in git common-aliases' \
    'add-zsh-hook preexec mirroros_alias_hint'; do
    grep -qF -- "$feature" "$shell_dir/zshrc"
  done
  ! grep -qE '^zplug .*from:oh-my-zsh' <(grep -v 'lib/completion' "$shell_dir/zshrc")
  ! grep -qiE 'alias-tips|python' "$shell_dir/zshrc" "$shell_dir/install-plugins" "$shell_dir/packages"
  # The hint function runs without processes: it names the longest matching alias and stays silent otherwise.
  sed -n '/^mirroros_alias_hint() {$/,/^}$/p' "$shell_dir/zshrc" > "$CFG_TEST_DIR/hint.zsh"
  run env -i HOME="$CFG_TEST_HOME" PATH=/nonexistent "$(command -v zsh)" -f -c 'source "$1"; alias gst="git status" gss="git status --short" ll="ls -lFh" v=vim nvim=vim
    mirroros_alias_hint "git status -sb" "git status -sb"; mirroros_alias_hint "git status --short -b" "git status --short -b"
    mirroros_alias_hint "vim file" "vim file"; mirroros_alias_hint "git statusx" "git statusx"
    mirroros_alias_hint ll "ls -lFh"; mirroros_alias_hint "echo hi" "echo hi"' zsh "$CFG_TEST_DIR/hint.zsh"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g')" = $'Alias tip: gst\nAlias tip: gss\nAlias tip: v' ]
  mkdir -p "$CFG_TEST_HOME/.config/zsh/env.d" "$CFG_TEST_HOME/.config/mirroros/node"
  printf 'export MIRROROS_TEST_ENV=loaded\n' > "$CFG_TEST_HOME/.config/zsh/env.d/test.zsh"
  cp "$shell_dir/zshenv" "$CFG_TEST_HOME/.zshenv"
  cp "$shell_dir/zprofile" "$CFG_TEST_HOME/.zprofile"
  cp "$CFG_SOURCE_ROOT/capabilities/workflow/node/environment.zsh" "$CFG_TEST_HOME/.config/mirroros/node/environment.zsh"
  run env -i HOME="$CFG_TEST_HOME" PATH=/usr/bin:/bin zsh -c 'print -r -- "$MIRROROS_TEST_ENV"'
  [ "$status" -eq 0 ]
  [ "$output" = loaded ]
  run env -i HOME="$CFG_TEST_HOME" PATH=/usr/bin:/bin zsh -l -c 'print -r -- "$PATH"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin"* ]]
}

tmux_step() {
  printf 'CFG_STEPS=(workflow/tmux)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

# A negated command in the middle of a test does not fail it under errexit; this one does.
refute() { if "$@"; then return 1; fi; }

tmux_plugin_fixture() {
  local name=$1 origin=$2 commit=${3:-1111111111111111111111111111111111111111} destination
  destination="$CFG_TEST_HOME/.config/tmux/plugins/$name"
  mkdir -p "$destination/.git"
  printf '%s\n' "$origin" > "$destination/.git/fixture-remote"
  printf '%s\n' "$commit" > "$destination/.git/fixture-head"
}

# Every identified source as an existing clone of its expected origin; tmux-thumbs also has its compiled binaries
# unless the caller asks for them to be missing.
tmux_plugins_fixture() {
  local entry name origin
  for entry in tpm:tmux-plugins/tpm tmux-sensible:tmux-plugins/tmux-sensible tmux-yank:tmux-plugins/tmux-yank \
    tmux-resurrect:tmux-plugins/tmux-resurrect tmux-continuum:tmux-plugins/tmux-continuum \
    tmux-thumbs:fcsonline/tmux-thumbs tmux-fzf:sainnhe/tmux-fzf tmux-fzf-url:wfxr/tmux-fzf-url; do
    name=${entry%%:*}
    origin=https://github.com/${entry#*:}
    tmux_plugin_fixture "$name" "$origin"
  done
  printf '[package]\nversion = "0.8.0"\n' > "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/Cargo.toml"
  if [[ "${1:-binaries}" == binaries ]]; then
    mkdir -p "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release"
    printf '#!/usr/bin/bash\nprintf "thumbs %s\\n"\n' "${2:-0.8.0}" > "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release/thumbs"
    printf '#!/usr/bin/bash\nexit 0\n' > "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release/tmux-thumbs"
    chmod 0755 "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release/"{thumbs,tmux-thumbs}
  fi
}

@test "tmux provisions native files plugin sources thumbs and Sesh as the user and a rerun has no effects" {
  shell_accounts
  tmux_step
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/tmux-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/tmux: changed'* ]]
  for file in tmux.conf tmux.bindings.conf tmux.navigator.conf tmux.theme.conf; do
    cmp "$CFG_SOURCE_ROOT/capabilities/workflow/tmux/$file" "$CFG_TEST_HOME/.config/tmux/$file"
  done
  for commit in e261deb1b47614eed3400089ce7197dc68acc4eb 25cb91f42d020f675bb0a2ce3fbd3a5d96119efa \
    acfd36e4fcba99f8310a7dfb432111c242fe7392 cff343cf9e81983d3da0c8562b01616f12e8d548 \
    0698e8f4b17d6454c71bf5212895ec055c578da0 ae91d5f7c0d989933e86409833c46a1eca521b6a \
    2839d6bd0e13b7c5e385e131e4c217917fa73555 7c4838e95fde660b7f2aaf514323ac8498e0d4f4; do
    [ "$(grep -c "^git .* fetch --quiet --depth 1 --no-tags origin $commit\$" "$CFG_TEST_CALLS")" -eq 1 ]
  done
  [ "$(< "$CFG_TEST_HOME/.config/tmux/plugins/tpm/.git/fixture-head")" = e261deb1b47614eed3400089ce7197dc68acc4eb ]
  [ "$(grep -c '^cargo build --release --locked --target-dir=target$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ -x "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release/thumbs" ]
  [ "$(grep -c '^makepkg --force --noconfirm --nocolor$' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF "pacman -U --needed --noconfirm -- $CFG_TEST_HOME/.cache/mirroros/sesh/sesh-bin-2.33.0-1.1-x86_64.pkg.tar.zst" "$CFG_TEST_CALLS"
  grep -qxF 'pacman -S --needed --noconfirm -- extra/tmux extra/wl-clipboard core/inetutils extra/rust core/base-devel' "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_INSTALLED/sesh-bin")" = 2.33.0-1.1 ]
  grep -q $'^tpm\thttps://github.com/tmux-plugins/tpm\t\te261deb1b47614eed3400089ce7197dc68acc4eb\t$' "$CFG_TEST_DIR/tmux-run/sources.tsv"
  grep -q $'^tmux-thumbs\thttps://github.com/fcsonline/tmux-thumbs\t\tae91d5f7c0d989933e86409833c46a1eca521b6a\t$' "$CFG_TEST_DIR/tmux-run/sources.tsv"
  grep -q $'^sesh\thttps://github.com/joshmedeski/sesh/releases/download/v2.33.0/sesh_Linux_x86_64.tar.gz\tv2.33.0\t863935c8caa3cc40cac6adcd344ac9742e51739f\t2.33.0-1.1$' "$CFG_TEST_DIR/tmux-run/sources.tsv"
  grep -q $'^sesh-bin\t2.33.0-1.1\tlocal$' "$CFG_TEST_DIR/tmux-run/packages.tsv"
  refute compgen -G "$CFG_TEST_HOME/.config/tmux/plugins/.mirroros-*" > /dev/null
  refute compgen -G "$CFG_TEST_HOME/.cache/mirroros/sesh/.build.*" > /dev/null
  [ -f "$CFG_TEST_HOME/.cache/mirroros/sesh/sesh-bin-2.33.0-1.1-x86_64.pkg.tar.zst" ]
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/tmux-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/tmux: unchanged'* ]]
  refute grep -qE '^(cargo|makepkg|pacman -U) |^git .* (fetch|checkout|init) ' "$CFG_TEST_CALLS"
  grep -q $'^sesh-bin\t2.33.0-1.1\tlocal$' "$CFG_TEST_DIR/tmux-rerun/packages.tsv"
  cfg_test_no_install
}

@test "tmux plugin sources that already exist are accepted or preserved and never reset" {
  shell_accounts
  tmux_step
  tmux_plugins_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/accepted"
  [ "$status" -eq 0 ]
  refute grep -qE '^git .* (fetch|checkout|init) |^cargo ' "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_HOME/.config/tmux/plugins/tpm/.git/fixture-head")" = 1111111111111111111111111111111111111111 ]
  grep -q $'^tpm\thttps://github.com/tmux-plugins/tpm\t\t1111111111111111111111111111111111111111\t$' "$CFG_TEST_DIR/accepted/sources.tsv"
  rm -r "$CFG_TEST_HOME/.config/tmux/plugins"
  tmux_plugin_fixture tpm https://example.invalid/unrelated
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/foreign"
  [ "$status" -eq 5 ]
  grep -q 'is not a clone of https://github.com/tmux-plugins/tpm; preserved unchanged' "$CFG_TEST_DIR/foreign/configure.log"
  [ "$(< "$CFG_TEST_HOME/.config/tmux/plugins/tpm/.git/fixture-remote")" = https://example.invalid/unrelated ]
  refute grep -q ' fetch ' "$CFG_TEST_CALLS"
  rm -r "$CFG_TEST_HOME/.config/tmux/plugins"
  mkdir "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$CFG_TEST_HOME/.config/tmux/plugins"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/linked-root"
  [ "$status" -eq 5 ]
  [ -L "$CFG_TEST_HOME/.config/tmux/plugins" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  refute grep -q ' fetch ' "$CFG_TEST_CALLS"
}

@test "tmux-thumbs is compiled only when its binaries are missing or differ and an interrupted build resumes" {
  shell_accounts
  tmux_step
  tmux_plugins_fixture missing
  run env CFG_TEST_CARGO_FAIL=1 "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/failed-build"
  [ "$status" -eq 5 ]
  grep -q 'cannot compile tmux-thumbs' "$CFG_TEST_DIR/failed-build/configure.log"
  [ ! -e "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target" ]
  refute grep -q ' fetch ' "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/resumed"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cargo ' "$CFG_TEST_CALLS")" -eq 2 ]
  : > "$CFG_TEST_CALLS"
  tmux_plugins_fixture binaries 0.1.0
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/stale-binary"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cargo ' "$CFG_TEST_CALLS")" -eq 1 ]
  rm -r "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target"
  : > "$CFG_TEST_CALLS"
  run env CFG_TEST_THUMBS_VERSION=0.1.0 "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/mismatch"
  [ "$status" -eq 5 ]
  grep -q 'do not match the cloned version after the build' "$CFG_TEST_DIR/mismatch/configure.log"
  [ "$(grep -c '^cargo ' "$CFG_TEST_CALLS")" -eq 1 ]
}

@test "Sesh is built by the user from the recipe only when missing or different and failures install nothing" {
  shell_accounts
  tmux_step
  tmux_plugins_fixture
  run env CFG_TEST_MAKEPKG_UNSUPPORTED=1 "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/unsupported"
  [ "$status" -eq 5 ]
  grep -q 'the recipe cannot be built on this system' "$CFG_TEST_DIR/unsupported/configure.log"
  run env CFG_TEST_MAKEPKG_FAIL=1 "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 5 ]
  grep -q 'makepkg failed' "$CFG_TEST_DIR/failed/configure.log"
  refute grep -q '^pacman -U ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_INSTALLED/sesh-bin" ]
  refute compgen -G "$CFG_TEST_HOME/.cache/mirroros/sesh/.build.*" > /dev/null
  refute compgen -G "$CFG_TEST_HOME/.cache/mirroros/sesh/*.pkg.tar.*" > /dev/null
  run env CFG_TEST_INSTALL_FAIL=1 "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/install-failed"
  [ "$status" -eq 5 ]
  grep -q '^pacman -U ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_INSTALLED/sesh-bin" ]
  printf '2.30.0-1\n' > "$CFG_TEST_INSTALLED/sesh-bin"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/replaced"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^pacman -U ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(< "$CFG_TEST_INSTALLED/sesh-bin")" = 2.33.0-1.1 ]
  [ "$(grep -c '^makepkg --force ' "$CFG_TEST_CALLS")" -eq 1 ]
}

@test "the recipe version is read as data and malformed recipes are rejected" {
  run cfg_test_helpers 'cfg_recipe_version "$CAPABILITIES_DIR/workflow/tmux/sesh/PKGBUILD"'
  [ "$status" -eq 0 ]
  [ "$output" = 2.33.0-1.1 ]
  printf 'pkgver=$(touch "%s/executed")\npkgrel=1\n' "$CFG_TEST_DIR" > "$CFG_TEST_DIR/PKGBUILD"
  run cfg_test_helpers 'cfg_recipe_version "$CFG_TEST_DIR/PKGBUILD"'
  [ "$status" -ne 0 ]
  [ ! -e "$CFG_TEST_DIR/executed" ]
  printf 'pkgver=1.0\n' > "$CFG_TEST_DIR/PKGBUILD"
  run cfg_test_helpers 'cfg_recipe_version "$CFG_TEST_DIR/PKGBUILD"'
  [ "$status" -ne 0 ]
}

@test "user-owned Tmux files and links are preserved while provisioning continues" {
  shell_accounts
  tmux_step
  mkdir -p "$CFG_TEST_HOME/.config/tmux"
  printf 'user content\n' > "$CFG_TEST_HOME/.config/tmux/tmux.conf"
  printf 'linked content\n' > "$CFG_TEST_DIR/linked"
  ln -s "$CFG_TEST_DIR/linked" "$CFG_TEST_HOME/.config/tmux/tmux.bindings.conf"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/preserved"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.config/tmux/tmux.conf")" = 'user content' ]
  [ -L "$CFG_TEST_HOME/.config/tmux/tmux.bindings.conf" ]
  [ "$(< "$CFG_TEST_DIR/linked")" = 'linked content' ]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/tmux/tmux.theme.conf" "$CFG_TEST_HOME/.config/tmux/tmux.theme.conf"
  grep -q 'user-owned: .config/tmux/tmux.conf; left untouched' "$CFG_TEST_DIR/preserved/configure.log"
}

@test "native Tmux files keep the approved defaults and exclude Floax Sessionx and host paths" {
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/tmux" file
  for file in tmux.conf tmux.bindings.conf tmux.navigator.conf tmux.theme.conf; do
    head -n 3 "$directory/$file" | grep -q 'managed by MirrorOS configure'
  done
  grep -q '^set -g prefix \^A$' "$directory/tmux.conf"
  grep -q '^set -g mouse on$' "$directory/tmux.conf"
  [ "$(grep -c "^set -g @plugin " "$directory/tmux.conf")" -eq 8 ]
  grep -q '^run '"'"'~/.config/tmux/plugins/tpm/tpm'"'"'$' "$directory/tmux.conf"
  grep -q '^bind o run-shell "sesh connect ' "$directory/tmux.bindings.conf"
  grep -q '^bind-key -n S-Enter send-keys -H 1b 5b 31 33 3b 32 75' "$directory/tmux.bindings.conf"
  grep -q 'bind-key -n C-h if-shell "\$is_vim"' "$directory/tmux.navigator.conf"
  refute grep -rniE 'floax|catppuccin/tmux|/home/|\.zcustom|TERM=|startx' "$directory"/tmux*.conf
  [ "$(grep -hv '^#' "$directory"/tmux*.conf | grep -ci 'sessionx')" -eq 0 ]
  refute grep -rnE 'git clone|install_plugins|bin/install' "$directory"/tmux*.conf
  refute grep -q 'run-shell' "$directory/tmux.conf"
}

@test "native Tmux bindings navigation and theme parse in an isolated server" {
  command -v tmux > /dev/null || skip 'tmux is not installed'
  [[ "$(tmux -V)" == 'tmux 3.8'* ]] || skip 'the theme uses Tmux 3.8 options'
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/tmux" socket="mirroros-contract-$$"
  export TMUX_TMPDIR="$CFG_TEST_DIR"
  run env -u TMUX HOME="$CFG_TEST_HOME" tmux -L "$socket" -f /dev/null start-server \; set -g exit-empty off \; \
    source-file "$directory/tmux.bindings.conf" \; source-file "$directory/tmux.navigator.conf" \; \
    source-file "$directory/tmux.theme.conf" \; list-keys -T prefix
  local parse_status=$status parse_output=$output
  env -u TMUX tmux -L "$socket" kill-server || true
  [ "$parse_status" -eq 0 ]
  [[ "$parse_output" == *'sesh connect'* ]]
}

@test "managed user files take the requested mode and a mode drift is repaired" {
  printf '# managed by MirrorOS configure\nwrapper\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .local/bin/tool 0755'
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "$CFG_TEST_HOME/.local/bin/tool")" = 755 ]
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .local/bin/tool 0755'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  chmod 0644 "$CFG_TEST_HOME/.local/bin/tool"
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .local/bin/tool 0755'
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "$CFG_TEST_HOME/.local/bin/tool")" = 755 ]
  [ -e "$CFG_TEST_DIR/helper-output/.changed" ]
  run cfg_test_helpers 'cfg_user_file "$CFG_TEST_DIR/source" .local/bin/other 0700'
  [ "$status" -eq 6 ]
  [ ! -e "$CFG_TEST_HOME/.local/bin/other" ]
}

@test "user links are created only for absent paths and every other path stays user-owned" {
  mkdir -p "$CFG_TEST_HOME/code/nvim"
  run cfg_test_helpers 'cfg_user_link code/nvim .config/nvim'
  [ "$status" -eq 0 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/nvim")" = "$CFG_TEST_HOME/code/nvim" ]
  [ -e "$CFG_TEST_DIR/helper-output/.changed" ]
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_user_link code/nvim .config/nvim'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  run cfg_test_helpers 'cfg_user_link_present .config/nvim'
  [ "$status" -eq 0 ]
  rm "$CFG_TEST_HOME/.config/nvim"
  mkdir -p "$CFG_TEST_HOME/.config/nvim"
  printf 'mine\n' > "$CFG_TEST_HOME/.config/nvim/init.lua"
  run cfg_test_helpers 'cfg_user_link code/nvim .config/nvim'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned'* ]]
  [ ! -L "$CFG_TEST_HOME/.config/nvim" ]
  [ "$(< "$CFG_TEST_HOME/.config/nvim/init.lua")" = mine ]
  refute test -e "$CFG_TEST_HOME/.config/nvim/nvim"
  rm -r "$CFG_TEST_HOME/.config/nvim"
  ln -s /elsewhere "$CFG_TEST_HOME/.config/nvim"
  run cfg_test_helpers 'cfg_user_link code/nvim .config/nvim'
  [ "$status" -eq 0 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/nvim")" = /elsewhere ]
  run cfg_test_helpers 'cfg_user_link /code/nvim .config/nvim'
  [ "$status" -eq 6 ]
}

editor_step() {
  printf 'CFG_STEPS=(workflow/editor)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

editor_clone_fixture() {
  mkdir -p "$CFG_TEST_HOME/code/nvim/.git"
  printf '%s\n' "${1:-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}" > "$CFG_TEST_HOME/code/nvim/.git/fixture-head"
  printf '%s\n' https://github.com/viespejo/nvim-lua-new > "$CFG_TEST_HOME/code/nvim/.git/fixture-remote"
  printf 'master\n' > "$CFG_TEST_HOME/code/nvim/.git/fixture-branch"
}

@test "editor provisions Lazygit the wrapper and the selected Neovim configuration as the user and a rerun has no effects" {
  editor_step
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/editor: changed'* ]]
  grep -qxF 'pacman -S --needed --noconfirm -- extra/lazygit extra/tree-sitter-cli extra/unzip extra/go' "$CFG_TEST_CALLS"
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/editor/lazygit.yml" "$CFG_TEST_HOME/.config/lazygit/config.yml"
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/editor/vim" "$CFG_TEST_HOME/.local/bin/vim"
  [ "$(stat -c %a "$CFG_TEST_HOME/.local/bin/vim")" = 755 ]
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
  [ "$(readlink "$CFG_TEST_HOME/.config/nvim")" = "$CFG_TEST_HOME/code/nvim" ]
  [ "$(grep -c '^git ls-remote ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^nvim --headless' "$CFG_TEST_CALLS")" -eq 3 ]
  grep -qxF "nvim --headless +Lazy! restore +qa" "$CFG_TEST_CALLS"
  grep -qxF "nvim --headless -c lua require('config.prepare_tools').run() -c qa" "$CFG_TEST_CALLS"
  grep -qxF "nvim --headless -c lua require('config.treesitter').run() -c qa" "$CFG_TEST_CALLS"
  [ "$(sort -u <<< "$(grep '^nvim-path ' "$CFG_TEST_CALLS")")" = "nvim-path $CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin" ]
  [ "$(< "$CFG_TEST_HOME/.local/state/mirroros/editor/nvim-prepared")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
  grep -q $'^nvim\thttps://github.com/viespejo/nvim-lua-new\tmaster\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t$' "$CFG_TEST_DIR/editor-run/sources.tsv"
  refute compgen -G "$CFG_TEST_HOME/.local/state/mirroros/editor/.mirroros-*" > /dev/null
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/editor: unchanged'* ]]
  refute grep -qE '^nvim |^git .* (fetch|checkout|init|merge) ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "a failed preparation leaves no stamp so the rerun resumes and a new selected commit prepares again" {
  editor_step
  export CFG_TEST_NVIM_FAIL=tools
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-failed"
  unset CFG_TEST_NVIM_FAIL
  [ "$status" -eq 5 ]
  grep -q 'preparing the approved tools failed' "$CFG_TEST_DIR/editor-failed/configure.log"
  [ ! -e "$CFG_TEST_HOME/.local/state/mirroros/editor/nvim-prepared" ]
  [ "$(grep -c '^nvim --headless' "$CFG_TEST_CALLS")" -eq 2 ]
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-resumed"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.local/state/mirroros/editor/nvim-prepared")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
  [ "$(grep -c '^nvim --headless' "$CFG_TEST_CALLS")" -eq 5 ]
  export CFG_TEST_GIT_SELECTED=cccccccccccccccccccccccccccccccccccccccc
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-advanced"
  unset CFG_TEST_GIT_SELECTED
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/editor: changed'* ]]
  [ "$(< "$CFG_TEST_HOME/.local/state/mirroros/editor/nvim-prepared")" = cccccccccccccccccccccccccccccccccccccccc ]
  [ "$(grep -c '^nvim --headless' "$CFG_TEST_CALLS")" -eq 8 ]
}

@test "a dirty Neovim clone stops before preparation and a user-owned configuration is never prepared" {
  editor_step
  editor_clone_fixture aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  printf ' M init.lua\n' > "$CFG_TEST_HOME/code/nvim/.git/fixture-status"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-dirty"
  [ "$status" -eq 5 ]
  grep -q 'modified or untracked repository files' "$CFG_TEST_DIR/editor-dirty/configure.log"
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
  refute grep -q '^nvim ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.config/nvim" ]
  rm "$CFG_TEST_HOME/code/nvim/.git/fixture-status"
  mkdir -p "$CFG_TEST_HOME/.config/nvim"
  printf 'mine\n' > "$CFG_TEST_HOME/.config/nvim/init.lua"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/editor-owned"
  [ "$status" -eq 0 ]
  [ ! -L "$CFG_TEST_HOME/.config/nvim" ]
  [ "$(< "$CFG_TEST_HOME/.config/nvim/init.lua")" = mine ]
  refute grep -q '^nvim ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.local/state/mirroros/editor/nvim-prepared" ]
}

@test "editor declares only its own prerequisites and keeps the external tool lists out of MirrorOS" {
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/editor"
  refute grep -qE '^(neovim|base-devel|rust|git|fzf|curl)( |$)' "$directory/packages"
  refute grep -rniE 'stylua|lua-language-server|prettier|vscode-langservers|shfmt' \
    "$directory/apply" "$directory/prepare-nvim" "$directory/packages"
  refute grep -nE 'sudo|systemctl|pacman|npm ' "$directory/prepare-nvim"
  refute grep -rnE '/home/|\.zcustom' "$directory/vim" "$directory/apply" "$directory/prepare-nvim"
  grep -q 'managed by MirrorOS configure' "$directory/vim"
}

pi_step() {
  printf 'CFG_STEPS=(workflow/pi)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

# The declared runtime reports its version but runs the real Node.js, which executes the version selector.
pi_node_fixture() {
  local bin="$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin"
  mkdir -p "$bin"
  printf '# user nvm\n' > "$CFG_TEST_HOME/.nvm/nvm.sh"
  CFG_TEST_REAL_NODE="$(command -v node)"
  export CFG_TEST_REAL_NODE
  cat > "$bin/node" <<'NODE'
#!/usr/bin/bash
[[ "${1:-}" != --version ]] || { printf 'v24.22.0\n'; exit 0; }
exec "$CFG_TEST_REAL_NODE" "$@"
NODE
  chmod 0755 "$bin/node"
  ln -s "$CFG_TEST_DIR/bin/npm" "$bin/npm"
  ln -s "$CFG_TEST_DIR/bin/npx" "$bin/npx"
}

pi_clone_fixture() {
  mkdir -p "$CFG_TEST_HOME/code/pi-config/.git"
  printf '%s\n' "${1:-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}" > "$CFG_TEST_HOME/code/pi-config/.git/fixture-head"
  printf '%s\n' https://github.com/viespejo/pi-config > "$CFG_TEST_HOME/code/pi-config/.git/fixture-remote"
  printf 'master\n' > "$CFG_TEST_HOME/code/pi-config/.git/fixture-branch"
  printf '{"devDependencies":{"@earendil-works/pi-coding-agent":"1.3.0"}}\n' > "$CFG_TEST_HOME/code/pi-config/package.json"
  printf '{"lockfileVersion":3}\n' > "$CFG_TEST_HOME/code/pi-config/package-lock.json"
  mkdir -p "$CFG_TEST_HOME"/code/pi-config/extensions/{openai-codex-work-provider/src,gemini-cli-provider/src,permission-gate,planning,usage,vertex-anthropic,vertex-maas}
  for extension in answer context files prefill-templates todo; do
    printf '// fixture\n' > "$CFG_TEST_HOME/code/pi-config/extensions/$extension.ts"
  done
}

@test "pi provisions the exact declared version and the locked dependencies as the user and a rerun has no effects" {
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  grep -qxF 'pacman -S --needed --noconfirm -- extra/ffmpeg' "$CFG_TEST_CALLS"
  [ "$(grep -c '^git ls-remote --exit-code ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(< "$CFG_TEST_HOME/code/pi-config/.git/fixture-head")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
  [ "$(readlink "$CFG_TEST_HOME/.local/bin/pi-editor")" = "$CFG_TEST_HOME/code/pi-config/scripts/pi-editor" ]
  refute grep -q '^npm view ' "$CFG_TEST_CALLS"
  [ "$(grep -c '^npm install --global ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF "npm install --global --prefix $CFG_TEST_HOME/.nvm/versions/node/v24.22.0 --ignore-scripts --no-audit --no-fund @earendil-works/pi-coding-agent@1.3.0" "$CFG_TEST_CALLS"
  [ "$(grep -c '^npm ci ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF 'npm ci --ignore-scripts --omit=dev --omit=peer --no-audit --no-fund' "$CFG_TEST_CALLS"
  grep -qxF "npm-cwd $CFG_TEST_HOME/code/pi-config" "$CFG_TEST_CALLS"
  [ "$(grep -m1 -B1 '^npm ' "$CFG_TEST_CALLS" | head -1)" = 'runuser -u alice' ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  [ -f "$CFG_TEST_HOME/.local/state/mirroros/pi/pi-config-dependencies" ]
  grep -q $'^pi\thttps://registry.npmjs.org/@earendil-works/pi-coding-agent\texact_dependency\t\t1.3.0$' "$CFG_TEST_DIR/pi-run/sources.tsv"
  grep -q $'^pi-config\thttps://github.com/viespejo/pi-config\tmaster\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t$' "$CFG_TEST_DIR/pi-run/sources.tsv"
  refute compgen -G "$CFG_TEST_HOME/.local/state/mirroros/pi/.mirroros-*" > /dev/null
  refute compgen -G "${TMPDIR:-/tmp}/mirroros-pi.*" > /dev/null
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: unchanged'* ]]
  refute grep -qE '^npm (install|ci|view) |^git .* (fetch|checkout|init|merge) ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "an absent Pi dependency selects the latest stable release with a single registry query" {
  pi_step
  pi_node_fixture
  export CFG_TEST_PI_PACKAGE_JSON='{"name":"pi-config"}'
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-absent"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^npm view ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF "npm install --global --prefix $CFG_TEST_HOME/.nvm/versions/node/v24.22.0 --ignore-scripts --no-audit --no-fund @earendil-works/pi-coding-agent@1.3.0" "$CFG_TEST_CALLS"
  grep -q $'^pi\thttps://registry.npmjs.org/@earendil-works/pi-coding-agent\tstable_registry\t\t1.3.0$' "$CFG_TEST_DIR/pi-absent/sources.tsv"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-absent-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: unchanged'* ]]
  [ "$(grep -c '^npm view ' "$CFG_TEST_CALLS")" -eq 1 ]
  refute grep -qE '^npm (install|ci) ' "$CFG_TEST_CALLS"
}

@test "a range or malformed Pi declaration fails without registry fallback or npm effects" {
  pi_step
  pi_node_fixture
  export CFG_TEST_PI_PACKAGE_JSON='{"devDependencies":{"@earendil-works/pi-coding-agent":"^1.3.0"}}'
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-range"
  [ "$status" -eq 5 ]
  grep -q 'must be an exact valid version, not a range' "$CFG_TEST_DIR/pi-range/configure.log"
  printf '{"devDependencies":\n' > "$CFG_TEST_HOME/code/pi-config/package.json"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-malformed"
  [ "$status" -eq 5 ]
  grep -q 'malformed JSON' "$CFG_TEST_DIR/pi-malformed/configure.log"
  refute grep -q '^npm ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  [ ! -e "$CFG_TEST_HOME/.local/state/mirroros/pi/pi-config-dependencies" ]
}

@test "a failed Pi installation or dependency installation is resumed by the rerun" {
  pi_step
  pi_node_fixture
  export CFG_TEST_NPM_INSTALL_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-install-failed"
  unset CFG_TEST_NPM_INSTALL_FAIL
  [ "$status" -eq 5 ]
  grep -q 'installing Pi 1.3.0 failed' "$CFG_TEST_DIR/pi-install-failed/configure.log"
  refute grep -q '^npm ci ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.local/state/mirroros/pi/pi-config-dependencies" ]
  export CFG_TEST_NPM_CI_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-ci-failed"
  unset CFG_TEST_NPM_CI_FAIL
  [ "$status" -eq 5 ]
  grep -q 'runtime dependencies failed' "$CFG_TEST_DIR/pi-ci-failed/configure.log"
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  [ ! -e "$CFG_TEST_HOME/.local/state/mirroros/pi/pi-config-dependencies" ]
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-resumed"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^npm install --global ' "$CFG_TEST_CALLS")" -eq 2 ]
  [ "$(grep -c '^npm ci ' "$CFG_TEST_CALLS")" -eq 2 ]
  [ -f "$CFG_TEST_HOME/.local/state/mirroros/pi/pi-config-dependencies" ]
}

@test "a changed lockfile reinstalls only the dependencies and a changed declared version only Pi and the dependencies" {
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-first"
  [ "$status" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  printf '{"lockfileVersion":3,"changed":true}\n' > "$CFG_TEST_HOME/code/pi-config/package-lock.json"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-lock"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  [ "$(grep -c '^npm ci ' "$CFG_TEST_CALLS")" -eq 1 ]
  refute grep -q '^npm install ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  printf '{"devDependencies":{"@earendil-works/pi-coding-agent":"1.4.0"}}\n' > "$CFG_TEST_HOME/code/pi-config/package.json"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-version"
  [ "$status" -eq 0 ]
  grep -qxF "npm install --global --prefix $CFG_TEST_HOME/.nvm/versions/node/v24.22.0 --ignore-scripts --no-audit --no-fund @earendil-works/pi-coding-agent@1.4.0" "$CFG_TEST_CALLS"
  [ "$(grep -c '^npm ci ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -q '"version":"1.4.0"' "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/lib/node_modules/@earendil-works/pi-coding-agent/package.json"
}

@test "a dirty pi-config clone stops before any npm effect and a user-owned pi-editor path is preserved" {
  pi_step
  pi_node_fixture
  pi_clone_fixture aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  printf ' M scripts/pi-editor\n' > "$CFG_TEST_HOME/code/pi-config/.git/fixture-status"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-dirty"
  [ "$status" -eq 5 ]
  grep -q 'modified or untracked repository files' "$CFG_TEST_DIR/pi-dirty/configure.log"
  [ "$(< "$CFG_TEST_HOME/code/pi-config/.git/fixture-head")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
  refute grep -q '^npm ' "$CFG_TEST_CALLS"
  rm "$CFG_TEST_HOME/code/pi-config/.git/fixture-status"
  mkdir -p "$CFG_TEST_HOME/.local/bin"
  printf 'mine\n' > "$CFG_TEST_HOME/.local/bin/pi-editor"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-owned"
  [ "$status" -eq 0 ]
  [ ! -L "$CFG_TEST_HOME/.local/bin/pi-editor" ]
  [ "$(< "$CFG_TEST_HOME/.local/bin/pi-editor")" = mine ]
}

@test "pi keeps npm lifecycle scripts disabled runs only as the user and never reads private Pi state" {
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/pi"
  [ "$(< "$directory/packages")" = 'ffmpeg extra' ]
  refute grep -nE 'sudo|systemctl|pacman' "$directory/install-pi"
  [ "$(grep -cE '^[^#]*npm (install|ci) ' "$directory/install-pi")" -eq 2 ]
  [ "$(grep -cE 'ignore-scripts' "$directory/install-pi")" -ge 2 ]
  refute grep -rnE '/home/|\.zcustom|auth\.json|\.pi/agent' "$directory/apply" "$directory/install-pi"
}

# Complete identity of a tree: entries with type, mode, size, mtime and link target, plus file digests.
pi_snapshot() {
  { find "$1" -printf '%p %y %m %s %T@ %l\n' | LC_ALL=C sort; find "$1" -type f -exec sha256sum {} + | LC_ALL=C sort; } | sha256sum
}

pi_init_payload() {
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$CFG_SOURCE_ROOT/capabilities/workflow/pi/defaults" -cf - . |
    gzip -n | base64 -w0
}

pi_init_skills() {
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$CFG_SOURCE_ROOT/capabilities/workflow/pi/skills" -cf - . |
    gzip -n | base64 -w0
}

# Runs init-pi alone as the fixture user with a directory of command shims first on PATH.
pi_init_direct() {
  local payload skills external manual specs
  payload="$(pi_init_payload)"
  skills="$(pi_init_skills)"
  external="$(base64 -w0 < "$CFG_SOURCE_ROOT/capabilities/workflow/pi/external-skills")"
  manual="$(base64 -w0 < "$CFG_SOURCE_ROOT/capabilities/workflow/pi/manual-skill.mjs")"
  mapfile -t specs < "$CFG_SOURCE_ROOT/capabilities/workflow/pi/npm-packages"
  run env HOME="$CFG_TEST_HOME" PATH="$1:$PATH" bash --noprofile --norc -s -- apply v24.22.0 "$payload" "$skills" "$external" "$manual" "${specs[@]}" \
    < "$CFG_TEST_DIR/code/capabilities/workflow/pi/init-pi"
}

@test "a fresh Pi initialization publishes the defaults, prompts and extension links as the user and a rerun has no effects" {
  local defaults="$CFG_SOURCE_ROOT/capabilities/workflow/pi/defaults" agent="$CFG_TEST_HOME/.pi/agent" file link before
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-init"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  for file in settings.json keybindings.json APPEND_SYSTEM.md; do cmp "$defaults/$file" "$agent/$file"; done
  [ "$(find "$agent/prompts" -type f | wc -l)" -eq 7 ]
  for file in "$defaults"/prompts/*.md; do cmp "$file" "$agent/prompts/$(basename "$file")"; done
  for link in answer.ts:extensions/answer.ts context.ts:extensions/context.ts files.ts:extensions/files.ts \
    prefill-templates.ts:extensions/prefill-templates.ts todo.ts:extensions/todo.ts \
    openai-codex-work:extensions/openai-codex-work-provider/src src:extensions/gemini-cli-provider/src \
    permission-gate:extensions/permission-gate planning:extensions/planning usage:extensions/usage \
    vertex-anthropic:extensions/vertex-anthropic vertex-maas:extensions/vertex-maas node_modules:node_modules; do
    [ "$(readlink "$agent/extensions/${link%%:*}")" = "$CFG_TEST_HOME/code/pi-config/${link#*:}" ]
    [ -e "$agent/extensions/${link%%:*}" ]
  done
  [ "$(find "$agent/extensions" -mindepth 1 | wc -l)" -eq 13 ]
  [ "$(find "$agent/npm/node_modules" -name package.json | wc -l)" -eq 6 ]
  [ -f "$agent/npm/package.json" ]
  [ "$(stat -c %a "$agent/npm/node_modules/pi-mermaid/bin/run")" = 755 ]
  [ "$(stat -c %a "$agent/npm/node_modules/pi-mermaid/package.json")" = 644 ]
  [ ! -e "$CFG_TEST_HOME/.pi/.work" ]
  [ "$(grep -c '^npm install --prefix ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^npm-isolation .* true$' "$CFG_TEST_CALLS")" -eq 1 ]
  for skill in aikido-mcp atlassian-mcp; do
    [ "$(readlink "$agent/skills/$skill")" = "$CFG_TEST_HOME/.local/share/mirroros/pi/skills/$skill" ]
    diff -r "$CFG_SOURCE_ROOT/capabilities/workflow/pi/skills/$skill" "$agent/skills/$skill"
  done
  [ "$(find "$agent/skills" -mindepth 1 -maxdepth 1 | wc -l)" -eq 6 ]
  [ "$(stat -c %a "$agent/skills/aikido-mcp/SKILL.md")" = 644 ]
  for skill in teach wait-what show-me archify; do
    [ -d "$agent/skills/$skill" ]
    [ ! -L "$agent/skills/$skill" ]
    [ "$(grep -c '^disable-model-invocation: true$' "$agent/skills/$skill/SKILL.md")" -eq 1 ]
    [ "$(stat -c %a "$agent/skills/$skill" "$agent/skills/$skill/SKILL.md" | tr '\n' ' ')" = '755 644 ' ]
  done
  [ ! -e "$agent/skills/grill-me" ]
  [ "$(< "$agent/skills/teach/LICENSE")" = 'upstream license' ]
  [ "$(< "$agent/skills/show-me/LICENSE")" = 'upstream license' ]
  [ "$(< "$agent/skills/archify/LICENSE")" = 'archify license' ]
  [ "$(< "$agent/skills/teach/MISSION-FORMAT.md")" = format ]
  [ "$(stat -c %a "$agent/skills/archify/bin/archify-tool")" = 755 ]
  [ "$(sed -n '2,3p' "$agent/skills/wait-what/SKILL.md" | tr '\n' '|')" = 'name: wait-what|description: Fixture skill wait-what|' ]
  [ "$(grep -c '^git .*ls-remote --symref ' "$CFG_TEST_CALLS")" -eq 3 ]
  [ "$(grep -c '^npx --yes --package=skills@1.7.2 ' "$CFG_TEST_CALLS")" -eq 3 ]
  [ "$(grep -c '^npx-isolation true$' "$CFG_TEST_CALLS")" -eq 3 ]
  refute grep -q "^npx-cwd $CFG_TEST_HOME/.pi/" "$CFG_TEST_CALLS"
  grep -qF $'skills:mattpocock/skills\thttps://github.com/mattpocock/skills.git\trefs/heads/main\t49dd158d1076134a641b33efb035946536778336' "$CFG_TEST_DIR/pi-init/sources.tsv"
  grep -qF $'skills:humanlayer/skills\thttps://github.com/humanlayer/skills.git\trefs/heads/main\t653b6411c1f70c275a18e37673b042ff99f67ceb' "$CFG_TEST_DIR/pi-init/sources.tsv"
  grep -qF $'skills:tt-a1i/archify\thttps://github.com/tt-a1i/archify.git\trefs/heads/main\tba701d20a55ed6f139484d9ead7ff45671fe40eb' "$CFG_TEST_DIR/pi-init/sources.tsv"
  grep -qF $'skills-cli\thttps://registry.npmjs.org/skills\tdeclared\t\t1.7.2' "$CFG_TEST_DIR/pi-init/sources.tsv"
  refute compgen -G "$CFG_TEST_HOME/.local/share/mirroros/pi/skills/.staging.*" > /dev/null
  [ "$(stat -c %a "$CFG_TEST_HOME/.pi" "$agent" "$agent/settings.json" | tr '\n' ' ')" = '755 755 644 ' ]
  [ ! -e "$CFG_TEST_HOME/.pi/.mirroros-pi-staging" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  [ ! -e "$agent/auth.json" ]
  [ ! -e "$agent/models-store.json" ]
  [ ! -e "$agent/sessions" ]
  refute grep -q "^npm-cwd $CFG_TEST_HOME/.pi" "$CFG_TEST_CALLS"
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  before="$(pi_snapshot "$CFG_TEST_HOME/.pi")"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-init-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: unchanged'* ]]
  [ "$(pi_snapshot "$CFG_TEST_HOME/.pi")" = "$before" ]
  grep -q 'existing path preserved' "$CFG_TEST_DIR/pi-init-rerun/configure.log"
  refute grep -qE '^npm ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "an existing Pi directory with unknown files is preserved byte for byte and nothing runs inside it" {
  local pi="$CFG_TEST_HOME/.pi" before
  pi_step
  pi_node_fixture
  mkdir -p "$pi/agent/npm" "$pi/unknown"
  printf '{"mine":true}\n' > "$pi/agent/settings.json"
  printf '{"name":"mine"}\n' > "$pi/agent/npm/package.json"
  printf '\000\001unknown\n' > "$pi/unknown/blob"
  ln -s "$CFG_TEST_DIR/outside" "$pi/agent/extensions"
  before="$(pi_snapshot "$pi")"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-existing"
  [ "$status" -eq 0 ]
  [ "$(pi_snapshot "$pi")" = "$before" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  refute grep -q "^npm-cwd $pi" "$CFG_TEST_CALLS"
  refute grep -qE '^(npm install --prefix|npm-isolation|npx |git .*ls-remote --symref)' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.local/share/mirroros/pi" ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  grep -q 'existing path preserved' "$CFG_TEST_DIR/pi-existing/configure.log"
  rm -rf "$pi"
  mkdir "$pi"
  before="$(pi_snapshot "$pi")"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-empty"
  [ "$status" -eq 0 ]
  [ "$(pi_snapshot "$pi")" = "$before" ]
  [ -z "$(ls -A "$pi")" ]
}

@test "a Pi path that is a symlink or a dangling symlink is preserved and never followed" {
  local pi="$CFG_TEST_HOME/.pi" before
  pi_step
  pi_node_fixture
  mkdir -p "$CFG_TEST_DIR/elsewhere/agent"
  printf 'keep\n' > "$CFG_TEST_DIR/elsewhere/agent/settings.json"
  ln -s "$CFG_TEST_DIR/elsewhere" "$pi"
  before="$(pi_snapshot "$pi"; pi_snapshot "$CFG_TEST_DIR/elsewhere")"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-link"
  [ "$status" -eq 0 ]
  [ -L "$pi" ]
  [ "$(readlink "$pi")" = "$CFG_TEST_DIR/elsewhere" ]
  [ "$(pi_snapshot "$pi"; pi_snapshot "$CFG_TEST_DIR/elsewhere")" = "$before" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  rm -f "$pi"
  ln -s "$CFG_TEST_DIR/missing" "$pi"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-dangling"
  [ "$status" -eq 0 ]
  [ -L "$pi" ]
  [ "$(readlink "$pi")" = "$CFG_TEST_DIR/missing" ]
  [ ! -e "$CFG_TEST_DIR/missing" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
}

@test "a failed Pi initialization publishes nothing and the rerun initializes" {
  local pi="$CFG_TEST_HOME/.pi" defaults="$CFG_TEST_DIR/code/capabilities/workflow/pi/defaults"
  pi_step
  pi_node_fixture
  sed -i 's/"enabled": false/"enabled": true/' "$defaults/settings.json"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-voice"
  [ "$status" -eq 5 ]
  grep -q 'voice and text-to-speech must stay disabled' "$CFG_TEST_DIR/pi-voice/configure.log"
  [ ! -e "$pi" ]
  [ ! -L "$pi" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  cp "$CFG_SOURCE_ROOT/capabilities/workflow/pi/defaults/settings.json" "$defaults/settings.json"
  rm -rf "$CFG_TEST_HOME/code/pi-config/extensions/planning"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-missing"
  [ "$status" -eq 5 ]
  grep -q 'pi-config lacks extensions/planning' "$CFG_TEST_DIR/pi-missing/configure.log"
  [ ! -e "$pi" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  mkdir "$CFG_TEST_HOME/code/pi-config/extensions/planning"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-retry"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/pi/defaults/settings.json" "$pi/agent/settings.json"
  [ -e "$pi/agent/extensions/planning" ]
}

@test "a failed or mismatched Pi package installation publishes nothing, delivers no skills and the rerun initializes" {
  local pi="$CFG_TEST_HOME/.pi" skills="$CFG_TEST_HOME/.local/share/mirroros/pi"
  pi_step
  pi_node_fixture
  export CFG_TEST_NPM_PACKAGES_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-packages-failed"
  unset CFG_TEST_NPM_PACKAGES_FAIL
  [ "$status" -eq 5 ]
  grep -q 'the Pi packages could not be installed' "$CFG_TEST_DIR/pi-packages-failed/configure.log"
  [ ! -e "$pi" ]
  [ ! -e "$skills" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  export CFG_TEST_NPM_PACKAGE_SKIP=pi-mermaid
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-packages-missing"
  unset CFG_TEST_NPM_PACKAGE_SKIP
  [ "$status" -eq 5 ]
  grep -q 'the selected Pi package pi-mermaid is not installed' "$CFG_TEST_DIR/pi-packages-missing/configure.log"
  [ ! -e "$pi" ]
  [ ! -e "$skills" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-packages-retry"
  [ "$status" -eq 0 ]
  [ -f "$pi/agent/npm/node_modules/pi-mermaid/package.json" ]
  [ -L "$pi/agent/skills/atlassian-mcp" ]
}

@test "a failed external Pi skill resolution, installation or validation publishes nothing, delivers no skills and the rerun initializes" {
  local pi="$CFG_TEST_HOME/.pi" skills="$CFG_TEST_HOME/.local/share/mirroros/pi" case_name message
  pi_step
  pi_node_fixture
  for case_name in 'CFG_TEST_SKILLS_RESOLVE_FAIL=1|could not be resolved' 'CFG_TEST_SKILLS_FETCH_FAIL=1|could not be fetched at' \
    'CFG_TEST_SKILLS_INSTALL_FAIL=1|upstream skills could not be installed' 'CFG_TEST_SKILLS_ALTER=1|differs from its upstream source' \
    'CFG_TEST_SKILLS_NO_LICENSE=1|has no license file' $'CFG_TEST_SKILL_EXTRA_HEADER=disable-model-invocation: maybe\n|unsupported frontmatter'; do
    export "${case_name%%|*}"
    run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-failure"
    unset "${case_name%%=*}"
    message=${case_name#*|}
    [ "$status" -eq 5 ]
    grep -q "$message" "$CFG_TEST_DIR/pi-skill-failure/configure.log"
    grep -q 'nothing was published' "$CFG_TEST_DIR/pi-skill-failure/configure.log"
    [ ! -e "$pi" ]
    [ ! -e "$skills" ]
    refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
    rm -rf "$CFG_TEST_DIR/pi-skill-failure"
  done
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-retry"
  [ "$status" -eq 0 ]
  [ -f "$pi/agent/skills/archify/SKILL.md" ]
  [ -L "$pi/agent/skills/atlassian-mcp" ]
}

@test "an external Pi skill name that repeats an owned or declared name is rejected before publication" {
  local pi="$CFG_TEST_HOME/.pi" file="$CFG_TEST_DIR/code/capabilities/workflow/pi/external-skills"
  pi_step
  pi_node_fixture
  printf 'https://github.com/tt-a1i/archify.git archify aikido-mcp\n' > "$file"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-duplicate"
  [ "$status" -eq 5 ]
  grep -q 'aikido-mcp is declared twice' "$CFG_TEST_DIR/pi-skill-duplicate/configure.log"
  [ ! -e "$pi" ]
  printf 'https://github.com/tt-a1i/archify.git ../archify archify\n' > "$file"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-traversal"
  [ "$status" -eq 5 ]
  [ ! -e "$pi" ]
  printf 'https://example.org/x/y.git archify archify\n' > "$file"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-host"
  [ "$status" -eq 5 ]
  [ ! -e "$pi" ]
  refute grep -q '^npx ' "$CFG_TEST_CALLS"
}

@test "owned Pi skills never replace a different existing delivery and an identical one is accepted" {
  local pi="$CFG_TEST_HOME/.pi" root="$CFG_TEST_HOME/.local/share/mirroros/pi/skills" before
  pi_step
  pi_node_fixture
  mkdir -p "$root/aikido-mcp"
  printf 'mine\n' > "$root/aikido-mcp/SKILL.md"
  before="$(pi_snapshot "$root")"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-conflict"
  [ "$status" -eq 5 ]
  grep -q 'exists with different content' "$CFG_TEST_DIR/pi-skill-conflict/configure.log"
  [ "$(pi_snapshot "$root")" = "$before" ]
  [ ! -e "$pi" ]
  refute compgen -G "$root/.staging.*" > /dev/null
  rm -rf "$root/aikido-mcp"
  mkdir -p "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$root/aikido-mcp"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-link"
  [ "$status" -eq 5 ]
  [ "$(readlink "$root/aikido-mcp")" = "$CFG_TEST_DIR/elsewhere" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  [ ! -e "$pi" ]
  rm -f "$root/aikido-mcp"
  cp -r "$CFG_SOURCE_ROOT/capabilities/workflow/pi/skills/aikido-mcp" "$root/aikido-mcp"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-skill-identical"
  [ "$status" -eq 0 ]
  [ "$(readlink "$pi/agent/skills/aikido-mcp")" = "$root/aikido-mcp" ]
  [ "$(readlink "$pi/agent/skills/atlassian-mcp")" = "$root/atlassian-mcp" ]
  diff -r "$CFG_SOURCE_ROOT/capabilities/workflow/pi/skills/atlassian-mcp" "$root/atlassian-mcp"
}

@test "an interrupted Pi initialization leaves no staging and no ~/.pi" {
  local shim="$CFG_TEST_DIR/shim"
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-before-interrupt"
  [ "$status" -eq 0 ]
  rm -rf "$CFG_TEST_HOME/.pi"
  mkdir -p "$shim"
  printf '#!/usr/bin/bash\nkill -TERM "$PPID"\nexit 1\n' > "$shim/tar"
  chmod 0755 "$shim/tar"
  pi_init_direct "$shim"
  [ "$status" -eq 5 ]
  [ ! -e "$CFG_TEST_HOME/.pi" ]
  refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
  rm -f "$shim/tar"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-after-interrupt"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  [ -f "$CFG_TEST_HOME/.pi/agent/settings.json" ]
}

@test "a Pi directory created concurrently is never overwritten, before or during publication" {
  local shim="$CFG_TEST_DIR/shim" pi="$CFG_TEST_HOME/.pi" command real
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/pi-before-race"
  [ "$status" -eq 0 ]
  mkdir -p "$shim"
  for command in tar mv; do
    rm -rf "$pi"
    real="$(command -v "$command")"
    printf '#!/usr/bin/bash\nmkdir -p "$HOME/.pi"\nprintf "mine\\n" > "$HOME/.pi/mine"\nexec %s "$@"\n' "$real" > "$shim/$command"
    chmod 0755 "$shim/$command"
    pi_init_direct "$shim"
    [ "$status" -eq 0 ]
    [[ "$output" == *'unchanged preserved'* ]]
    [ "$(ls -A "$pi")" = mine ]
    [ "$(< "$pi/mine")" = mine ]
    refute compgen -G "$CFG_TEST_HOME/.pi.mirroros.*" > /dev/null
    rm -f "$shim/$command"
  done
}

@test "init-pi decides initialize-only before any write and the Pi defaults are portable and keep voice disabled" {
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/pi" guard write
  refute grep -nE 'sudo|systemctl|pacman' "$directory/init-pi"
  refute grep -rniE '/home/|\.zcustom|token|secret|password|api[_-]?key|bearer' "$directory/defaults"
  refute grep -rq 'managed by MirrorOS' "$directory/defaults"
  guard="$(grep -n '^if present; then' "$directory/init-pi" | head -1 | cut -d: -f1)"
  write="$(grep -nE '^[^#]*(mkdir|mktemp|exec 9|flock)' "$directory/init-pi" | head -1 | cut -d: -f1)"
  [ -n "$guard" ]
  [ -n "$write" ]
  [ "$guard" -lt "$write" ]
  [ "$(find "$directory/defaults/prompts" -type f | wc -l)" -eq 7 ]
  [ "$(grep -cE '^[^#]*npm install ' "$directory/init-pi")" -eq 1 ]
  grep -qE 'npm install --prefix .* --ignore-scripts --legacy-peer-deps --no-audit --no-fund' "$directory/init-pi"
  grep -q 'NPM_CONFIG_IGNORE_SCRIPTS=true' "$directory/init-pi"
  [ "$(wc -l < "$directory/external-skills")" -eq 3 ]
  refute grep -vE '^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.git [A-Za-z0-9._/-]+( [a-z0-9]+(-[a-z0-9]+)*)+$' "$directory/external-skills"
  [ "$(grep -cE '^[^#]*npx ' "$directory/init-pi")" -eq 1 ]
  grep -qE 'skills_cli_version=[0-9]+\.[0-9]+\.[0-9]+$' "$directory/init-pi"
  grep -q 'NPM_CONFIG_IGNORE_SCRIPTS=true' "$directory/init-pi"
  [ "$(wc -l < "$directory/npm-packages")" -eq 6 ]
  refute grep -vE '^(@[a-z0-9._-]+/)?[a-z0-9._-]+@[0-9]+\.[0-9]+\.[0-9]+$' "$directory/npm-packages"
  run node --eval 'const fs = require("node:fs");
const declared = fs.readFileSync(process.argv[2], "utf8").trim().split("\n").map((s) => s.replace(/(?<=.)@[^/]*$/, "")).sort();
const selected = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).packages
  .map((e) => (typeof e === "string" ? e : e.source).slice(4)).sort();
process.exit(JSON.stringify(declared) === JSON.stringify(selected) ? 0 : 1)' "$directory/defaults/settings.json" "$directory/npm-packages"
  [ "$status" -eq 0 ]
  [ "$(cd "$directory/skills" && find . -type f | LC_ALL=C sort | xargs sha256sum | sha256sum)" = \
    "$(printf '%s\n' \
      'e91628ab05d758ae7f4eb9434dda2b6af2e9507f562ba81519a094998da427ba  ./aikido-mcp/README.md' \
      '6900d5436d1aa1e57b7b60b0f8b3f1813556eff1e77ddaabe4b6081847fc6f9b  ./aikido-mcp/SKILL.md' \
      '7cc7c7d4de1ba934eeecc53527750f7b8cc93704f4613c8bafdc596dfb9bac03  ./atlassian-mcp/SKILL.md' | sha256sum)" ]
  run node --eval 'const s = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
process.exit(s.voice.enabled === false && s.voice.ttsEnabled === false ? 0 : 1)' "$directory/defaults/settings.json"
  [ "$status" -eq 0 ]
}

# A complete declared installation as it would exist after an earlier provisioning; $1 is the VERSION content.
gcloud_installation_fixture() {
  local directory="$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0"
  mkdir -p "$directory/bin"
  printf '%s\n' "$1" > "$directory/VERSION"
  printf '#!/usr/bin/bash\nprintf "Google Cloud SDK %%s\\n" "%s"\n' "$1" > "$directory/bin/gcloud"
  chmod 0755 "$directory/bin/gcloud"
}

gcloud_nothing_published() {
  [ ! -e "$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0" ]
  [ ! -e "$CFG_TEST_HOME/.local/bin/gcloud" ]
  refute compgen -G "$CFG_TEST_HOME/.local/opt/.google-cloud-sdk.mirroros.*" > /dev/null
  [ ! -e "$CFG_TEST_HOME/.pi" ]
}

@test "gcloud is installed once as the user from the verified archive and a rerun downloads nothing" {
  local sdk="$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0" config
  pi_step
  pi_node_fixture
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  [ -x "$sdk/bin/gcloud" ]
  [ "$(< "$sdk/VERSION")" = 589.0.0 ]
  [ "$(readlink "$CFG_TEST_HOME/.local/bin/gcloud")" = "$sdk/bin/gcloud" ]
  [ "$(grep -c '^curl .*--proto =https .*https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-589.0.0-linux-x86_64.tar.gz$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -B1 '^curl ' "$CFG_TEST_CALLS" | head -1)" = 'runuser -u alice' ]
  [ "$(grep -c '^stat -c %s -- ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^md5sum --check --status$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^sha256sum --check --status$' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -q $'^gcloud\thttps://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-589.0.0-linux-x86_64.tar.gz\tsha256:f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f\t\t589.0.0$' "$CFG_TEST_DIR/gcloud-run/sources.tsv"
  [ "$(grep -c '^gcloud --version CONFIG=' "$CFG_TEST_CALLS")" -eq 1 ]
  config="$(sed -n 's/^gcloud --version CONFIG=//p' "$CFG_TEST_CALLS")"
  [ -n "$config" ]
  [[ "$config" != "$CFG_TEST_HOME"/* ]]
  [ ! -e "$config" ]
  [ ! -e "$CFG_TEST_HOME/.config/gcloud" ]
  refute compgen -G "$CFG_TEST_HOME/.local/opt/.google-cloud-sdk.mirroros.*" > /dev/null
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: unchanged'* ]]
  refute grep -qE '^(curl|stat -c|md5sum --check|sha256sum --check) ' "$CFG_TEST_CALLS"
  [ "$(grep -c '^gcloud --version CONFIG=' "$CFG_TEST_CALLS")" -eq 1 ]
  refute grep -q $'^gcloud\t' "$CFG_TEST_DIR/gcloud-rerun/sources.tsv"
  cfg_test_no_install
}

@test "a wrong gcloud archive size, MD5 or SHA256 stops before extraction and the rerun installs" {
  local pair check label
  pi_step
  pi_node_fixture
  for pair in size:size md5:MD5 sha256:SHA256; do
    check="${pair%%:*}" label="${pair#*:}"
    : > "$CFG_TEST_CALLS"
    export CFG_TEST_GCLOUD_TAMPER="$check"
    run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-$check"
    [ "$status" -eq 5 ]
    grep -q "archive $label mismatch; nothing was extracted" "$CFG_TEST_DIR/gcloud-$check/configure.log"
    gcloud_nothing_published
    case "$check" in
      size) refute grep -qE '^(md5sum|sha256sum) ' "$CFG_TEST_CALLS" ;;
      md5) grep -q '^md5sum --check' "$CFG_TEST_CALLS"; refute grep -q '^sha256sum --check' "$CFG_TEST_CALLS" ;;
      sha256) grep -q '^md5sum --check' "$CFG_TEST_CALLS"; grep -q '^sha256sum --check' "$CFG_TEST_CALLS" ;;
    esac
    refute grep -q '^gcloud ' "$CFG_TEST_CALLS"
  done
  unset CFG_TEST_GCLOUD_TAMPER
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-resumed"
  [ "$status" -eq 0 ]
  [ -x "$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0/bin/gcloud" ]
}

@test "a failed gcloud download, another archive version or an unexpected archive layout publishes nothing" {
  pi_step
  pi_node_fixture
  export CFG_TEST_CURL_FAIL=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-download"
  [ "$status" -eq 5 ]
  grep -q 'cannot download the Google Cloud CLI 589.0.0 archive' "$CFG_TEST_DIR/gcloud-download/configure.log"
  gcloud_nothing_published
  unset CFG_TEST_CURL_FAIL
  export CFG_TEST_GCLOUD_VERSION=588.0.0
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-version"
  [ "$status" -eq 5 ]
  grep -q 'does not contain Google Cloud CLI 589.0.0; nothing was published' "$CFG_TEST_DIR/gcloud-version/configure.log"
  gcloud_nothing_published
  unset CFG_TEST_GCLOUD_VERSION
  export CFG_TEST_GCLOUD_LAYOUT=extra
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-layout"
  [ "$status" -eq 5 ]
  grep -q 'unexpected Google Cloud CLI archive layout; nothing was published' "$CFG_TEST_DIR/gcloud-layout/configure.log"
  gcloud_nothing_published
}

@test "a gcloud destination created during installation is preserved and the owned staging is removed" {
  local sdk="$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0"
  pi_step
  pi_node_fixture
  export CFG_TEST_GCLOUD_CONCURRENT=1
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-concurrent"
  [ "$status" -eq 5 ]
  grep -q 'appeared during installation; preserved unchanged' "$CFG_TEST_DIR/gcloud-concurrent/configure.log"
  [ "$(< "$sdk/untouched")" = 'concurrent content' ]
  [ "$(find "$sdk" -type f | wc -l)" -eq 1 ]
  refute compgen -G "$CFG_TEST_HOME/.local/opt/.google-cloud-sdk.mirroros.*" > /dev/null
  [ ! -e "$CFG_TEST_HOME/.local/bin/gcloud" ]
}

@test "an unrelated or linked gcloud installation is never overwritten and a user-owned launcher is preserved" {
  local sdk="$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0"
  pi_step
  pi_node_fixture
  gcloud_installation_fixture 588.0.0
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-unrelated"
  [ "$status" -eq 5 ]
  grep -q 'is not the Google Cloud CLI 589.0.0 installation; preserved unchanged' "$CFG_TEST_DIR/gcloud-unrelated/configure.log"
  [ "$(< "$sdk/VERSION")" = 588.0.0 ]
  [ ! -e "$CFG_TEST_HOME/.local/bin/gcloud" ]
  rm -r "$sdk"
  mkdir "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$sdk"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-linked"
  [ "$status" -eq 5 ]
  [ -L "$sdk" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  refute grep -qE '^(curl|stat -c|md5sum --check|sha256sum --check) ' "$CFG_TEST_CALLS"
  rm "$sdk"
  gcloud_installation_fixture 589.0.0
  mkdir -p "$CFG_TEST_HOME/.local/bin"
  printf 'mine\n' > "$CFG_TEST_HOME/.local/bin/gcloud"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/gcloud-owned"
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/.local/bin/gcloud")" = mine ]
  [ ! -L "$CFG_TEST_HOME/.local/bin/gcloud" ]
  grep -q 'user-owned: .local/bin/gcloud' "$CFG_TEST_DIR/gcloud-owned/configure.log"
  refute grep -qE '^(curl|stat -c|md5sum --check|sha256sum --check) ' "$CFG_TEST_CALLS"
  refute grep -q $'^gcloud\t' "$CFG_TEST_DIR/gcloud-owned/sources.tsv"
}

@test "install-gcloud runs only as the user, never executes upstream installers or account commands and declares one archive identity" {
  local directory="$CFG_SOURCE_ROOT/capabilities/workflow/pi" code
  code="$(grep -vE '^[[:space:]]*#' "$directory/install-gcloud")"
  refute grep -qE 'sudo|systemctl|pacman|install\.sh|gcloud (init|auth|components|config)' <<< "$code"
  [ "$(grep -c 'curl ' <<< "$code")" -eq 1 ]
  grep -q -- "--proto '=https' --tlsv1.2" <<< "$code"
  grep -qE '^archive_size=[0-9]+$' <<< "$code"
  grep -qE '^archive_md5=[0-9a-f]{32}$' <<< "$code"
  grep -qE '^archive_sha256=[0-9a-f]{64}$' <<< "$code"
  grep -q '^archive_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-\$version-linux-x86_64.tar.gz"$' <<< "$code"
  refute grep -qE 'cfg_run|cfg_exec|runuser' "$directory/apply"
  refute grep -qE '^[^#]*(profile|bashrc|zshrc)' <<< "$code"
  bash -n "$directory/install-gcloud"
}

# shellcheck disable=SC2016 # cfg_test_helpers expands these command strings in its own Bash process.
@test "tracked system files detect local edits that keep the managed header and never overwrite them" {
  local dest="$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/example.service"
  local record="$MIRROROS_CONFIGURE_ROOT/var/lib/mirroros/configure/delivered/etc/systemd/user/example.service.sha256"
  printf '# managed by MirrorOS configure\nfirst\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644; cfg_tracked_file_present /etc/systemd/user/example.service'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$dest"
  [ "$(< "$record")" = "$(sha256sum < "$CFG_TEST_DIR/source" | cut -d' ' -f1)" ]
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  printf '# managed by MirrorOS configure\nsecond\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644'
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$dest"
  printf '# managed by MirrorOS configure\nlocal edit\n' > "$dest"
  printf '# managed by MirrorOS configure\nthird\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644'
  [ "$status" -eq 4 ]
  [[ "$output" == *'differs from its last MirrorOS delivery'* ]]
  [ "$(< "$dest")" = $'# managed by MirrorOS configure\nlocal edit' ]
  run cfg_test_helpers 'cfg_tracked_file_present /etc/systemd/user/example.service'
  [ "$status" -ne 0 ]
  cp "$CFG_TEST_DIR/source" "$dest"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644; cfg_tracked_file_present /etc/systemd/user/example.service'
  [ "$status" -eq 0 ]
  rm -r "$MIRROROS_CONFIGURE_ROOT/var/lib/mirroros"
  printf 'unknown\n' > "$dest"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644'
  [ "$status" -eq 4 ]
  [ "$(< "$dest")" = unknown ]
  rm "$dest"
  ln -s "$CFG_TEST_DIR/source" "$dest"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/systemd/user/example.service 0644'
  [ "$status" -eq 4 ]
  [[ "$output" == *'not a regular file delivered by MirrorOS'* ]]
  [ -L "$dest" ]
}

@test "tracked system files migrate only an exact listed earlier delivery that has no record" {
  local dest="$MIRROROS_CONFIGURE_ROOT/etc/example.conf" legacy
  local record="$MIRROROS_CONFIGURE_ROOT/var/lib/mirroros/configure/delivered/etc/example.conf.sha256"
  mkdir -p "${dest%/*}"
  printf '# managed by MirrorOS configure\nold\n' > "$dest"
  legacy="$(sha256sum < "$dest" | cut -d' ' -f1)"
  printf '# managed by MirrorOS configure\nnew\n' > "$CFG_TEST_DIR/source"
  run cfg_test_helpers 'cfg_tracked_file "$CFG_TEST_DIR/source" /etc/example.conf 0644'
  [ "$status" -eq 4 ]
  [ "$(< "$dest")" = $'# managed by MirrorOS configure\nold' ]
  run cfg_test_helpers "cfg_tracked_file \"\$CFG_TEST_DIR/source\" /etc/example.conf 0644 0000 $legacy; cfg_tracked_file_present /etc/example.conf"
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$dest"
  [ "$(< "$record")" = "$(sha256sum < "$CFG_TEST_DIR/source" | cut -d' ' -f1)" ]
  # Once a record exists, the legacy content is no longer an accepted previous delivery.
  printf '# managed by MirrorOS configure\nold\n' > "$dest"
  run cfg_test_helpers "cfg_tracked_file \"\$CFG_TEST_DIR/source\" /etc/example.conf 0644 $legacy"
  [ "$status" -eq 4 ]
  [ "$(< "$dest")" = $'# managed by MirrorOS configure\nold' ]
}

@test "user units are enabled offline as the user by their wants link and user overrides are preserved" {
  local wants="$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants"
  run cfg_test_helpers 'cfg_user_unit_enable example.service /etc/systemd/user/example.service graphical-session.target
cfg_user_unit_enabled example.service graphical-session.target'
  [ "$status" -eq 0 ]
  [ "$(readlink "$wants/example.service")" = /etc/systemd/user/example.service ]
  grep -q '^runuser -u alice' "$CFG_TEST_CALLS"
  refute grep -qE '^(systemctl|sudo) ' "$CFG_TEST_CALLS"
  rm "$CFG_TEST_DIR/helper-output/.changed"
  run cfg_test_helpers 'cfg_user_unit_enable example.service /etc/systemd/user/example.service graphical-session.target'
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  rm "$wants/example.service"
  ln -s /dev/null "$CFG_TEST_HOME/.config/systemd/user/example.service"
  run cfg_test_helpers 'cfg_user_unit_enable example.service /etc/systemd/user/example.service graphical-session.target
cfg_user_unit_enabled example.service graphical-session.target'
  [ "$status" -eq 0 ]
  [[ "$output" == *'user-owned: .config/systemd/user/example.service'* ]]
  [ ! -e "$wants/example.service" ] && [ ! -L "$wants/example.service" ]
  rm "$CFG_TEST_HOME/.config/systemd/user/example.service"
  ln -s /usr/lib/systemd/user/other.service "$wants/example.service"
  run cfg_test_helpers 'cfg_user_unit_enable example.service /etc/systemd/user/example.service graphical-session.target'
  [ "$status" -eq 0 ]
  [ "$(readlink "$wants/example.service")" = /usr/lib/systemd/user/other.service ]
  run cfg_test_helpers 'cfg_user_unit_enable ../x.service /etc/systemd/user/example.service graphical-session.target'
  [ "$status" -eq 6 ]
}
