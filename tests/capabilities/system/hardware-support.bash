#!/usr/bin/bash
# shellcheck disable=SC2034 # Shared fixture state is consumed by Bats callers.

hardware_setup() {
  cfg_test_setup
  export HW_TEST_ROOT=$MIRROROS_CONFIGURE_ROOT
  export XDG_STATE_HOME=$CFG_TEST_HOME/.local/state HOME=$CFG_TEST_HOME
  cp "$CFG_SOURCE_ROOT/tests/capabilities/system/doubles/"* "$CFG_TEST_DIR/bin/"
  for tool in wpctl brightnessctl playerctl qs notify-send bluetoothctl nmcli upower; do
    cp "$CFG_TEST_DIR/bin/hardware-tool" "$CFG_TEST_DIR/bin/$tool"
  done
  chmod 0755 "$CFG_TEST_DIR/bin/"*
  mkdir -p "$HW_TEST_ROOT/usr/lib/NetworkManager/VPN" "$HW_TEST_ROOT/sys/class/backlight" "$HW_TEST_ROOT/sys/class/bluetooth"
  printf 'service=org.freedesktop.NetworkManager.openconnect\n' > "$HW_TEST_ROOT/usr/lib/NetworkManager/VPN/nm-openconnect-service.name"
  printf '#!/usr/bin/bash\nexit 0\n' > "$HW_TEST_ROOT/usr/lib/nm-openconnect-service"
  chmod 0755 "$HW_TEST_ROOT/usr/lib/nm-openconnect-service"
  printf 'CFG_STEPS=(system/audio system/bluetooth system/power system/vpn)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}

hardware_run() {
  if [[ -n "${CFG_TEST_TARGET_ROOT:-}" ]]; then
    "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice "$@"
  else
    "$CFG_TEST_ENTRY" "$@"
  fi
}

hardware_command() { /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/$1" "${@:2}"; }
