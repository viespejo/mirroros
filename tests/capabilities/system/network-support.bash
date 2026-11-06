#!/usr/bin/bash
network_setup() {
  cfg_test_setup
  export HW_TEST_ROOT=$MIRROROS_CONFIGURE_ROOT
  mkdir -p "$CFG_TEST_DIR/network-state" "$HW_TEST_ROOT/usr/lib/systemd/system"
  printf '[Unit]\nDescription=Packaged resolver fixture\n' > "$HW_TEST_ROOT/usr/lib/systemd/system/systemd-resolved.service"
  for name in systemctl nmcli busctl timeout; do
    # shellcheck disable=SC2016 # The generated shim resolves its own path and arguments.
    printf '#!/usr/bin/bash\nexec "${BASH_SOURCE[0]%%/*}/network-tool" %s "$@"\n' "$name" > "$CFG_TEST_DIR/bin/$name"
    chmod 0755 "$CFG_TEST_DIR/bin/$name"
  done
  printf 'nameserver 192.0.2.53\n' > "$HW_TEST_ROOT/etc/resolv.conf"
  printf 'CFG_STEPS=(system/network)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
network_run() {
  if [[ -n "${CFG_TEST_TARGET_ROOT:-}" ]]; then
    "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice "$@"
  else "$CFG_TEST_ENTRY" "$@"; fi
}
