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
  grep -q $'example\t1.0-1\textra' "$CFG_TEST_DIR/evidence/packages.tsv"
  [ "$(find "$CFG_TEST_DIR/evidence" -type f | wc -l)" -eq 3 ]
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
    ln -s "$(command -v "$tool")" "$CFG_TEST_DIR/bin/$tool"
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
