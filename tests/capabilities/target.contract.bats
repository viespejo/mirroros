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

# The declared runtime reports its version but runs the real Node.js, which executes the Pi version selector.
target_pi_node_fixture() {
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

@test "the ten-step configuration converges in the target and reruns without transactions" {
  cp "$CFG_SOURCE_ROOT/capabilities/configure-steps" "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$CFG_TEST_TARGET_ROOT/usr/share/wayland-sessions" "$CFG_TEST_TARGET_ROOT/usr/lib/systemd/user" \
    "$CFG_TEST_HOME/.local/share/applications"
  printf '[Unit]\nDescription=packaged hypridle\n' > "$CFG_TEST_TARGET_ROOT/usr/lib/systemd/user/hypridle.service"
  printf '[Desktop Entry]\nExec=foot\n' > "$CFG_TEST_HOME/.local/share/applications/foot.desktop"
  printf '[Desktop Entry]\nExec=uwsm start hyprland.desktop\n' > "$CFG_TEST_TARGET_ROOT/usr/share/wayland-sessions/hyprland-uwsm.desktop"
  printf '/bin/bash\n/usr/bin/zsh\n' > "$CFG_TEST_TARGET_ROOT/etc/shells"
  target_pi_node_fixture
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'== 10/10 desktop/login =='* ]]
  bash "$CFG_SOURCE_ROOT/capabilities/desktop/shell/install-runtime" check "$CFG_SOURCE_ROOT/capabilities/desktop/shell" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/shell"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/shell/systemd/mirroros-shell.service" \
    "$CFG_TEST_TARGET_ROOT/etc/systemd/user/mirroros-shell.service"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/lock/systemd/10-mirroros.conf" \
    "$CFG_TEST_TARGET_ROOT/etc/systemd/user/hypridle.service.d/10-mirroros.conf"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-shell.service")" = \
    /etc/systemd/user/mirroros-shell.service ]
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hypridle.service")" = \
    /usr/lib/systemd/user/hypridle.service ]
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/lock/hypridle.conf" "$CFG_TEST_HOME/.config/hypr/hypridle.conf"
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/lock/hyprlock.conf" "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/quickshell" "$CFG_TEST_CALLS"
  run grep -qE 'systemctl (start|restart|reload|daemon-reload|--user)' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT usermod --shell /usr/bin/zsh -- alice" "$CFG_TEST_CALLS"
  [ "$(cut -d: -f7 <<< "$(grep '^alice:' "$CFG_TEST_TARGET_ROOT/etc/passwd")")" = /usr/bin/zsh ]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/shell/zshrc" "$CFG_TEST_HOME/.zshrc"
  [ "$(< "$CFG_TEST_HOME/.local/share/zplug/.git/fixture-head")" = cc6906ea7ea18a5058e8b4862d4086148434ddde ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.local" ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/node" ]
  [ -f "$CFG_TEST_HOME/.config/mirroros/node/environment.zsh" ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  [ -L "$CFG_TEST_HOME/.local/bin/pi-editor" ]
  [ -f "$CFG_TEST_HOME/.config/foot/foot.ini" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/terminal/foot.ini" "$CFG_TEST_HOME/.config/foot/foot.ini"
  [ -e "$CFG_TEST_INSTALLED/noto-fonts-emoji" ]
  [ -f "$CFG_TEST_HOME/.config/hypr/hyprland.lua" ]
  grep -qF 'kb_options = "compose:ralt"' "$CFG_TEST_HOME/.config/hypr/hyprland.lua"
  grep -qF 'kb_options = "compose:ralt"' "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/sddm/hyprland.lua"
  [ -f "$CFG_TEST_HOME/.config/mirroros/bash/starship.bash" ]
  [ -f "$CFG_TEST_TARGET_ROOT/etc/sddm.conf.d/10-mirroros-login.conf" ]
  [ -f "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/sddm/hyprland.lua" ]
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c ': unchanged$')" -eq 10 ]
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

@test "target editor-native defaults route through chroot and target HOME without services" {
  run cfg_test_helpers '
    CONFIGURE_CONTEXT=target
    CONFIGURE_ROOT=$CFG_TEST_TARGET_ROOT
    cfg_user_file "$CAPABILITIES_DIR/workflow/editor/lazygit.yml" .config/lazygit/config.yml
  '
  [ "$status" -eq 0 ]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/editor/lazygit.yml" "$CFG_TEST_TARGET_ROOT/home/alice/.config/lazygit/config.yml"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice" "$CFG_TEST_CALLS"
  ! grep -qE 'systemctl (start|restart)' "$CFG_TEST_CALLS"
}

@test "target node provisioning runs unprivileged in the chroot home and reruns without effects" {
  printf 'CFG_STEPS=(workflow/node)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/node: changed'* ]]
  [ "$("$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/node" --version)" = v24.22.0 ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.nvm" ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- apply v24.22.0" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- check v24.22.0" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/git" "$CFG_TEST_CALLS"
  grep -q $'^node\thttps://nodejs.org/dist\tv24.22.0\t\tv24.22.0$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  ! grep -qE 'systemctl (start|restart|enable)' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/node: unchanged'* ]]
  ! grep -qE '^(curl|nvm-installer|nvm install) ' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "target tmux provisioning builds as the user inside the chroot installs only the package with privileges and reruns without effects" {
  printf 'CFG_STEPS=(workflow/tmux)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/tmux: changed'* ]]
  cmp "$CFG_SOURCE_ROOT/capabilities/workflow/tmux/tmux.conf" "$CFG_TEST_HOME/.config/tmux/tmux.conf"
  [ -x "$CFG_TEST_HOME/.config/tmux/plugins/tmux-thumbs/target/release/thumbs" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.config" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.cache" ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- apply" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- build " "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/tmux extra/wl-clipboard core/inetutils extra/rust core/base-devel" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -U --needed --noconfirm -- $CFG_TEST_HOME/.cache/mirroros/sesh/sesh-bin-2.33.0-1.1-x86_64.pkg.tar.zst" "$CFG_TEST_CALLS"
  grep -q $'^sesh-bin\t2.33.0-1.1\tlocal$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/packages.tsv
  grep -q $'^sesh\thttps://github.com/joshmedeski/sesh/releases/download/v2.33.0/sesh_Linux_x86_64.tar.gz\tv2.33.0\t863935c8caa3cc40cac6adcd344ac9742e51739f\t2.33.0-1.1$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ "$(grep -cE 'systemctl (start|restart|enable)' "$CFG_TEST_CALLS")" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/tmux: unchanged'* ]]
  [ "$(grep -cE '^(cargo|makepkg|pacman -U) |^git .* (fetch|checkout|init) ' "$CFG_TEST_CALLS")" -eq 0 ]
  cfg_test_no_install
}

@test "target editor provisioning prepares Neovim as the user inside the chroot and reruns without effects" {
  printf 'CFG_STEPS=(workflow/editor)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/editor: changed'* ]]
  [ "$(stat -c %a "$CFG_TEST_HOME/.local/bin/vim")" = 755 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/nvim")" = "$CFG_TEST_HOME/code/nvim" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.config" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.local" ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- apply v24.22.0 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- check v24.22.0 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/lazygit extra/tree-sitter-cli extra/unzip extra/go" "$CFG_TEST_CALLS"
  grep -q $'^nvim\thttps://github.com/viespejo/nvim-lua-new\tmaster\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ "$(grep -c '^nvim --headless' "$CFG_TEST_CALLS")" -eq 3 ]
  [ "$(grep -cE 'systemctl (start|restart|enable)' "$CFG_TEST_CALLS")" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/editor: unchanged'* ]]
  [ "$(grep -cE '^nvim |^git .* (fetch|checkout|init|merge) ' "$CFG_TEST_CALLS")" -eq 0 ]
  cfg_test_no_install
}

@test "target Pi provisioning installs as the user inside the chroot and reruns without effects" {
  printf 'CFG_STEPS=(workflow/pi)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  target_pi_node_fixture
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: changed'* ]]
  [ "$(readlink "$CFG_TEST_HOME/.local/bin/pi-editor")" = "$CFG_TEST_HOME/code/pi-config/scripts/pi-editor" ]
  [ -x "$CFG_TEST_HOME/.nvm/versions/node/v24.22.0/bin/pi" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.local" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.npm" ]
  [ -f "$CFG_TEST_HOME/.pi/agent/settings.json" ]
  [ "$(readlink "$CFG_TEST_HOME/.pi/agent/extensions/planning")" = "$CFG_TEST_HOME/code/pi-config/extensions/planning" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.pi" ]
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- check" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- apply v24.22.0 " "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- check v24.22.0 1.3.0" "$CFG_TEST_CALLS"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/ffmpeg" "$CFG_TEST_CALLS"
  grep -q $'^pi\thttps://registry.npmjs.org/@earendil-works/pi-coding-agent\texact_dependency\t\t1.3.0$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ "$(grep -c '^npm install --global ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^npm ci ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^npm install --prefix ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^npm-isolation .* true$' "$CFG_TEST_CALLS")" -eq 1 ]
  [ -f "$CFG_TEST_HOME/.pi/agent/npm/node_modules/pi-web-access/package.json" ]
  [ "$(readlink "$CFG_TEST_HOME/.pi/agent/skills/aikido-mcp")" = "$CFG_TEST_HOME/.local/share/mirroros/pi/skills/aikido-mcp" ]
  [ -f "$CFG_TEST_HOME/.local/share/mirroros/pi/skills/atlassian-mcp/SKILL.md" ]
  [ "$(grep -c '^disable-model-invocation: true$' "$CFG_TEST_HOME/.pi/agent/skills/archify/SKILL.md")" -eq 1 ]
  [ ! -L "$CFG_TEST_HOME/.pi/agent/skills/teach" ]
  grep -q $'^skills:tt-a1i/archify\thttps://github.com/tt-a1i/archify.git\trefs/heads/main\tba701d20a55ed6f139484d9ead7ff45671fe40eb\t$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.local" ]
  grep -q $'^npm:pi-mermaid\thttps://registry.npmjs.org/pi-mermaid\tdeclared\t\t0.3.0$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ -x "$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0/bin/gcloud" ]
  [ "$(readlink "$CFG_TEST_HOME/.local/bin/gcloud")" = "$CFG_TEST_HOME/.local/opt/google-cloud-sdk-589.0.0/bin/gcloud" ]
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- apply" "$CFG_TEST_CALLS"
  [ "$(grep -c '^curl .*google-cloud-cli-589.0.0-linux-x86_64.tar.gz$' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -q $'^gcloud\thttps://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-589.0.0-linux-x86_64.tar.gz\tsha256:f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f\t\t589.0.0$' "$CFG_TEST_TARGET_ROOT"/var/log/mirroros/configure/*/sources.tsv
  [ "$(grep -cE 'systemctl (start|restart|enable)' "$CFG_TEST_CALLS")" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  run target_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'workflow/pi: unchanged'* ]]
  [ "$(grep -cE '^curl |^npm (install|ci|view) |^npx |^git .* (fetch|checkout|init|merge) |^git .*ls-remote --symref ' "$CFG_TEST_CALLS")" -eq 0 ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/root/.pi" ]
  cfg_test_no_install
}
