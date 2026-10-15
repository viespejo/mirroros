load support

setup() {
  cfg_test_setup
  cfg_test_target_context
  cfg_test_step
}
teardown() { cfg_test_teardown; }

target_run() { "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice "$@"; }

target_modern_xkb() {
  mv "$CFG_TEST_TARGET_ROOT/usr/share/X11/xkb" "$CFG_TEST_TARGET_ROOT/usr/share/xkeyboard-config-2"
  ln -s /usr/share/xkeyboard-config-2 "$CFG_TEST_TARGET_ROOT/usr/share/X11/xkb"
}

target_assert_rejected() {
  [ "$status" -eq 2 ]
  cfg_test_no_install
  [[ "$output" != *'== 1/'* ]]
  [ ! -e "$CFG_TEST_INSTALLED/example" ]
}

target_hide_live_tool() {
  local missing=$1 tool executable
  mkdir -p "$CFG_TEST_DIR/live-bin"
  for tool in bash env flock install awk grep cmp dirname mkdir chmod chown ln readlink rm mv cat date find sort stat mktemp id pacman runuser arch-chroot mountpoint; do
    [[ "$tool" != "$missing" ]] || continue
    executable="$(command -v "$tool")"
    ln -s "$executable" "$CFG_TEST_DIR/live-bin/$tool"
  done
  export PATH="$CFG_TEST_DIR/live-bin"
}

@test "target context rejects relative missing non-mount and root directories before convergence" {
  for root in relative "$CFG_TEST_DIR/missing" /; do
    run "$CFG_TEST_ENTRY" --target-root "$root" --user alice
    target_assert_rejected
    [ ! -e "$CFG_TEST_TARGET_ROOT/run/mirroros/configure.lock" ]
  done
  export CFG_TEST_MOUNTED=0
  run target_run
  target_assert_rejected
  [[ "$output" == *'must be a mount point'* ]]
  [ ! -d "$CFG_TEST_TARGET_ROOT/var/log/mirroros/configure" ]
}

@test "target root aliases of slash are rejected too" {
  run "$CFG_TEST_ENTRY" --target-root /./ --user alice
  target_assert_rejected
  [[ "$output" == *'must not be /'* ]]
}

@test "target user is mandatory despite SUDO_USER and cannot be root or absent from passwd" {
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT"
  target_assert_rejected
  [[ "$output" == *'Target user is missing'* ]]
  run target_run --user root
  target_assert_rejected
  [[ "$output" == *'must not be root'* ]]
  run target_run --user nonexistent
  target_assert_rejected
  [[ "$output" == *'does not exist'* ]]
  # The id double knows alice, but the target passwd is authoritative too.
  printf 'root:x:0:0::/root:/usr/bin/bash\n' > "$CFG_TEST_TARGET_ROOT/etc/passwd"
  run target_run
  target_assert_rejected
  [[ "$output" == *'does not exist'* ]]
}

@test "target root cannot be combined with the running-context test root even if empty" {
  export MIRROROS_CONFIGURE_ROOT=''
  run target_run
  target_assert_rejected
  [[ "$output" == *'cannot be combined'* ]]
  [ ! -e "$CFG_TEST_TARGET_ROOT/run/mirroros/configure.lock" ]
}

@test "target validation collects every independent problem" {
  export MIRROROS_CONFIGURE_ROOT="$CFG_TEST_TARGET_ROOT"
  run "$CFG_TEST_ENTRY" --target-root relative
  target_assert_rejected
  for message in 'cannot be combined' 'absolute path' 'existing directory' 'mount point' 'Target user is missing'; do
    [[ "$output" == *"$message"* ]]
  done
}

@test "arch-chroot missing on the live medium is a usage failure without target access" {
  target_hide_live_tool arch-chroot
  run target_run
  export PATH="$CFG_TEST_ORIGINAL_PATH"
  target_assert_rejected
  [[ "$output" == *'Missing live-medium tool: arch-chroot'* ]]
  ! grep -q '^arch-chroot ' "$CFG_TEST_CALLS"
}

@test "flock missing on the live medium is a usage failure before convergence" {
  target_hide_live_tool flock
  run target_run
  export PATH="$CFG_TEST_ORIGINAL_PATH"
  target_assert_rejected
  [[ "$output" == *'Missing live-medium tool: flock'* ]]
  [ ! -e "$CFG_TEST_TARGET_ROOT/run/mirroros/configure.lock" ]
}

@test "missing target tools are all reported through target command lookups" {
  export CFG_TEST_MISSING_TOOLS='pacman runuser systemctl install id'
  run target_run
  target_assert_rejected
  for tool in pacman runuser systemctl install id; do
    [[ "$output" == *"Missing base tool: $tool"* ]]
    grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT bash -c command -v" "$CFG_TEST_CALLS"
  done
  [ ! -e "$CFG_TEST_TARGET_ROOT/run/mirroros/configure.lock" ]
}

@test "target keyboard validation reads the modern XKB directory behind the absolute compatibility alias" {
  target_modern_xkb
  printf 'KEYMAP=es\n' > "$CFG_TEST_TARGET_ROOT/etc/vconsole.conf"
  run target_run
  [ "$status" -eq 0 ]
}

@test "running keyboard validation also accepts the modern XKB directory" {
  target_modern_xkb
  run env MIRROROS_CONFIGURE_ROOT="$CFG_TEST_TARGET_ROOT" "$CFG_TEST_ENTRY" --user alice
  [ "$status" -eq 0 ]
}

@test "modern XKB data still rejects unknown layouts before convergence" {
  target_modern_xkb
  printf 'KEYMAP=not-a-layout\n' > "$CFG_TEST_TARGET_ROOT/etc/vconsole.conf"
  run target_run
  target_assert_rejected
  [[ "$output" == *'is not a known XKB layout'* ]]
}

@test "missing target XKB data never falls through the absolute alias to live data" {
  target_modern_xkb
  rm "$CFG_TEST_TARGET_ROOT/usr/share/xkeyboard-config-2/rules/base.lst"
  run target_run
  target_assert_rejected
  [[ "$output" == *'XKB layout data is missing'* ]]
}

@test "all package and user queries use arch-chroot and transactions skip snap-pac" {
  run target_run
  [ "$status" -eq 0 ]
  for command in 'id -u -- alice' 'pacman -Sp' 'pacman -Q' 'pacman -Qu' 'env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/example'; do
    grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT $command" "$CFG_TEST_CALLS"
  done
  [[ "$output" == *'== 1/1 example =='* ]]
  [ -e "$CFG_TEST_INSTALLED/example" ]
}

@test "target files user HOME links and units converge without starting the display manager" {
  printf '# managed by MirrorOS configure\nexample\n' > "$CFG_TEST_DIR/source"
  cfg_test_step example 'cfg_packages_ensure "$STEP_DIR/packages"
cfg_system_file "$CFG_TEST_DIR/source" /etc/mirroros-example 0644
cfg_system_link /etc/mirroros-example /etc/mirroros-link
cfg_user_file "$CFG_TEST_DIR/source" .config/example
cfg_require cfg_user_file_present .config/example
cfg_bashrc_block .config/example
cfg_require cfg_bashrc_block_present
cfg_unit_enable sddm.service
cfg_default_target graphical.target
cfg_require cfg_display_manager_is sddm.service
cfg_require cfg_only_display_manager sddm.service'
  run target_run
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/source" "$CFG_TEST_TARGET_ROOT/etc/mirroros-example"
  cmp "$CFG_TEST_DIR/source" "$CFG_TEST_TARGET_ROOT/home/alice/.config/example"
  [ "$(readlink "$CFG_TEST_TARGET_ROOT/etc/mirroros-link")" = /etc/mirroros-example ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice" "$CFG_TEST_CALLS"
  for command in is-enabled enable get-default set-default list-unit-files; do
    grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT systemctl $command" "$CFG_TEST_CALLS"
  done
  ! grep -qE 'systemctl (start|restart)' "$CFG_TEST_CALLS"
  ! grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT install " "$CFG_TEST_CALLS"
  ! grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT ln " "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'example: unchanged'* ]]
  cfg_test_no_install
}

@test "the unchanged five-step skeleton converges in the target and reruns without transactions" {
  cp "$CFG_SOURCE_ROOT/capabilities/configure-steps" "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$CFG_TEST_TARGET_ROOT/usr/share/wayland-sessions"
  printf '[Desktop Entry]\nExec=uwsm start hyprland.desktop\n' > "$CFG_TEST_TARGET_ROOT/usr/share/wayland-sessions/hyprland-uwsm.desktop"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'== 5/5 desktop/login =='* ]]
  [ -f "$CFG_TEST_HOME/.config/foot/foot.ini" ]
  [ -f "$CFG_TEST_HOME/.config/hypr/hyprland.lua" ]
  [ -f "$CFG_TEST_HOME/.config/mirroros/bash/starship.bash" ]
  [ -f "$CFG_TEST_TARGET_ROOT/etc/sddm.conf.d/10-mirroros-login.conf" ]
  [ -f "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/sddm/hyprland.lua" ]
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c ': unchanged$')" -eq 5 ]
  cfg_test_no_install
  ! grep -qE 'systemctl (start|restart)' "$CFG_TEST_CALLS"
}

@test "target refresh skips snap-pac on the first full upgrade and subsequent install" {
  cfg_test_step second
  printf 'second extra\n' > "$CFG_TEST_DIR/code/capabilities/second/packages"
  printf 'CFG_STEPS=(example second)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run target_run --refresh
  [ "$status" -eq 0 ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -Syu --needed --noconfirm -- extra/example" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/second" "$CFG_TEST_CALLS"
}

@test "target evidence stays below target root and reads embedded code identity" {
  run target_run
  [ "$status" -eq 0 ]
  record="$(find "$CFG_TEST_TARGET_ROOT/var/log/mirroros/configure" -name configure-run.tsv)"
  [ -f "$record" ]
  grep -q $'run\tcontext\ttarget' "$record"
  grep -q $'run\tcode_identity\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$record"
  grep -q $'run\tdirty\tyes' "$record"
  grep -q $'run\toutcome\t0' "$record"
  [ "$(stat -c %a "${record%/*}")" = 700 ]
  printf '{"commit":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","dirty":false}\n' > "$CFG_TEST_DIR/code/identity.json"
  run target_run --output "$CFG_TEST_DIR/clean-evidence"
  [ "$status" -eq 0 ]
  grep -q $'run\tdirty\tno' "$CFG_TEST_DIR/clean-evidence/configure-run.tsv"
  grep -q $'run\tcode_identity\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' "$CFG_TEST_DIR/clean-evidence/configure-run.tsv"
}

@test "missing or malformed embedded identity remains unavailable without a runtime dependency" {
  for identity in missing malformed; do
    rm -f "$CFG_TEST_DIR/code/identity.json"
    if [[ "$identity" == malformed ]]; then printf '{"commit":"bad","dirty":"bad"}\n' > "$CFG_TEST_DIR/code/identity.json"; fi
    run target_run --output "$CFG_TEST_DIR/$identity"
    [ "$status" -eq 0 ]
    grep -q $'run\tcode_identity\tunavailable' "$CFG_TEST_DIR/$identity/configure-run.tsv"
    grep -q $'run\tdirty\tunavailable' "$CFG_TEST_DIR/$identity/configure-run.tsv"
  done
}

@test "target marker positions follow the declared step order" {
  cfg_test_step second
  printf 'CFG_STEPS=(example second)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'== 1/2 example =='* ]]
  [[ "$output" == *'== 2/2 second =='* ]]
}

@test "every configure step progress line fits 80 columns including its position" {
  source "$CFG_SOURCE_ROOT/capabilities/configure-steps"
  local step line position=0 total=${#CFG_STEPS[@]}
  for step in "${CFG_STEPS[@]}"; do
    position=$((position + 1))
    line="Configure step: $position/$total $step"
    [ "${#line}" -le 80 ]
  done
}
