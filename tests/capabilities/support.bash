#!/usr/bin/bash
# shellcheck disable=SC2034 # Test state is consumed by Bats files sourcing this support library.
CFG_SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"

cfg_test_setup() {
  CFG_TEST_ORIGINAL_PATH="$PATH"
  CFG_TEST_DIR="$(mktemp -d)"
  export CFG_TEST_DIR
  export MIRROROS_CONFIGURE_ROOT="$CFG_TEST_DIR/root"
  export CFG_TEST_HOME="$CFG_TEST_DIR/home"
  export CFG_TEST_CALLS="$CFG_TEST_DIR/calls"
  export CFG_TEST_INSTALLED="$CFG_TEST_DIR/installed"
  export CFG_TEST_UID=0 SUDO_USER=alice
  mkdir -p "$MIRROROS_CONFIGURE_ROOT"/{etc,run/mirroros,var/lib/pacman/sync,usr/share/X11/xkb/rules} \
    "$CFG_TEST_HOME" "$CFG_TEST_INSTALLED" "$CFG_TEST_DIR/bin" "$CFG_TEST_DIR/code/operations/lib"
  cp "$CFG_SOURCE_ROOT/operations/configure" "$CFG_TEST_DIR/code/operations/"
  cp "$CFG_SOURCE_ROOT/operations/lib/lifecycle-discovery.sh" "$CFG_TEST_DIR/code/operations/lib/"
  cp -R "$CFG_SOURCE_ROOT/capabilities" "$CFG_TEST_DIR/code/"
  cp "$CFG_SOURCE_ROOT/tests/capabilities/doubles/"* "$CFG_TEST_DIR/bin/"
  chmod 0755 "$CFG_TEST_DIR/bin/"*
  export PATH="$CFG_TEST_DIR/bin:$PATH"
  : > "$CFG_TEST_CALLS"
  : > "$MIRROROS_CONFIGURE_ROOT/var/lib/pacman/sync/extra.db"
  printf '! layout\n  us English (US)\n  es Spanish\n! variant\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/X11/xkb/rules/base.lst"
  printf 'CFG_STEPS=()\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  CFG_TEST_ENTRY="$CFG_TEST_DIR/code/operations/configure"
}

cfg_test_teardown() {
  export PATH="$CFG_TEST_ORIGINAL_PATH"
  hash -r
  rm -rf -- "$CFG_TEST_DIR"
}

cfg_test_step() {
  local name="${1:-example}" body="${2:-cfg_packages_ensure \"\$STEP_DIR/packages\"}"
  mkdir -p "$CFG_TEST_DIR/code/capabilities/$name"
  printf 'CFG_STEPS=(%s)\n' "$name" > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  printf 'example extra\n' > "$CFG_TEST_DIR/code/capabilities/$name/packages"
  printf '%s\n' "$body" > "$CFG_TEST_DIR/code/capabilities/$name/apply"
}

cfg_test_helpers() {
  local script="$1"
  bash -Eeuo pipefail -c '
    CAPABILITIES_DIR="$CFG_TEST_DIR/code/capabilities"
    for lib in common validate packages files units evidence repositories; do
      source "$CAPABILITIES_DIR/lib/$lib.sh"
    done
    TARGET_USER=alice
    CFG_OUTPUT="$CFG_TEST_DIR/helper-output"
    mkdir -p "$CFG_OUTPUT"
    source /dev/stdin
  ' <<< "$script"
}

cfg_test_target_context() {
  export CFG_TEST_TARGET_ROOT="$MIRROROS_CONFIGURE_ROOT"
  unset MIRROROS_CONFIGURE_ROOT
  export CFG_TEST_HOME="$CFG_TEST_TARGET_ROOT/home/alice"
  mkdir -p "$CFG_TEST_HOME"
  printf 'root:x:0:0:root:/root:/usr/bin/bash\nalice:x:1000:1000::/home/alice:/usr/bin/bash\n' > "$CFG_TEST_TARGET_ROOT/etc/passwd"
  printf '{"commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","dirty":true}\n' > "$CFG_TEST_DIR/code/identity.json"
}

cfg_test_no_install() { ! grep -Eq '^pacman -S(yu)? ' "$CFG_TEST_CALLS"; }
