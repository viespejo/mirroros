#!/usr/bin/env bats
load ../support
load hardware-support

setup() {
  hardware_setup
  # Sentinels: configure must never run the delivered VPN commands or OpenConnect itself (DEC-085, DEC-086).
  for tool in vpn-connect vpn-profile openconnect; do
    cp "$CFG_TEST_DIR/bin/hardware-tool" "$CFG_TEST_DIR/bin/$tool"
  done
}
teardown() { cfg_test_teardown; }

# A function, not an inline `! grep`, so a match fails the test under errexit.
hardware_assert_no_vpn_run() { ! grep -Eq '^(vpn-connect|vpn-profile|openconnect) |/hardware/vpn-(connect|profile)( |$)' "$CFG_TEST_CALLS"; }

hardware_assert_delivery() {
  local command unit
  [ -f "$CFG_TEST_INSTALLED/alsa-utils" ]
  for package in libpulse jq pavucontrol; do [ -f "$CFG_TEST_INSTALLED/$package" ]; done
  for command in volume media audio-device brightness battery-status power-profile power-watch; do
    [ -x "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command" ]
  done
  for unit in pipewire.service pipewire-pulse.service wireplumber.service; do
    [ -L "$CFG_TEST_HOME/.config/systemd/user/default.target.wants/$unit" ]
  done
  [ -L "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-power-watch.service" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/system/power/60-mirroros-power-key.conf" "$HW_TEST_ROOT/etc/systemd/logind.conf.d/60-mirroros-power-key.conf"
  cmp "$CFG_SOURCE_ROOT/capabilities/system/audio/bluetooth-a2dp-autoconnect.conf" "$CFG_TEST_HOME/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf"
  [ -f "$HW_TEST_ROOT/usr/share/mirroros/hardware/licenses/omarchy-audio" ]
  [ -f "$CFG_TEST_DIR/units/bluetooth.service.enabled" ]
  [ -f "$CFG_TEST_DIR/units/power-profiles-daemon.service.enabled" ]
  [ -f "$CFG_TEST_INSTALLED/bluez-tools" ]
  for command in bluetooth-device bluetooth-power; do
    [ "$(stat -c %a "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command")" = 755 ]
  done
  [ "$(stat -c %a "$HW_TEST_ROOT/usr/share/mirroros/hardware/licenses/omarchy-bluetooth")" = 644 ]
  unit=$HW_TEST_ROOT/etc/systemd/user/mirroros-bt-agent.service
  cmp "$CFG_SOURCE_ROOT/capabilities/system/bluetooth/mirroros-bt-agent.service" "$unit"
  grep -qxF 'KillSignal=SIGHUP' "$unit"
  grep -qxF 'TimeoutStopSec=2s' "$unit"
  [ "$(stat -c %a "$unit")" = 644 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-bt-agent.service")" = /etc/systemd/user/mirroros-bt-agent.service ]
  for package in networkmanager-openconnect openconnect; do [ -f "$CFG_TEST_INSTALLED/$package" ]; done
  for command in vpn-connect vpn-profile; do
    cmp "$CFG_SOURCE_ROOT/capabilities/system/vpn/$command" "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command"
    [ "$(stat -c %a "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command")" = 755 ]
  done
  hardware_assert_no_vpn_run
}

hardware_assert_rerun() {
  : > "$CFG_TEST_CALLS"
  run hardware_run --output "$CFG_TEST_DIR/second"
  [ "$status" -eq 0 ]
  for step in audio bluetooth power vpn; do [[ "$output" == *"system/$step: unchanged"* ]]; done
  ! grep -Eq '^systemctl (start|restart|reload|enable) ' "$CFG_TEST_CALLS"
  ! grep -Eq '^pacman -S(yu)? ' "$CFG_TEST_CALLS"
  hardware_assert_no_vpn_run
}

@test "hardware steps in running context activate only governed system services and rerun unchanged" {
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  hardware_assert_delivery
  grep -qxF 'systemctl start bluetooth.service' "$CFG_TEST_CALLS"
  grep -qxF 'systemctl start power-profiles-daemon.service' "$CFG_TEST_CALLS"
  grep -qxF 'systemctl reload systemd-logind' "$CFG_TEST_CALLS"
  grep -q 'HandlePowerKey' "$CFG_TEST_CALLS"
  ! grep -Eq 'systemctl (--user|restart)|systemctl (start|reload) .*(hypr|shell|desktop)' "$CFG_TEST_CALLS"
  grep -q 'Battery unavailable' "$CFG_TEST_DIR/first/configure.log"
  grep -q 'Bluetooth hardware unavailable' "$CFG_TEST_DIR/first/configure.log"
  hardware_assert_rerun
}

@test "hardware steps in target context deliver declared state without live activation and rerun unchanged" {
  cfg_test_target_context
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  hardware_assert_delivery
  ! grep -Eq 'systemctl (start|restart|reload|is-active)|^busctl |^bluetoothctl ' "$CFG_TEST_CALLS"
  grep -q 'arch-chroot .*nmcli' "$CFG_TEST_CALLS" || grep -q '^nmcli --offline' "$CFG_TEST_CALLS"
  hardware_assert_rerun
}

@test "absent Bluetooth subsystem is unavailable without activation and reruns unchanged" {
  rmdir "$HW_TEST_ROOT/sys/class/bluetooth"
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  hardware_assert_delivery
  ! grep -q 'systemctl start bluetooth.service' "$CFG_TEST_CALLS"
  grep -q 'Bluetooth hardware unavailable: kernel subsystem absent' "$CFG_TEST_DIR/first/configure.log"
  hardware_assert_rerun
}

@test "a user-owned Bluetooth agent unit is left untouched and logged" {
  mkdir -p "$CFG_TEST_HOME/.config/systemd/user"
  printf '[Service]\nExecStart=/usr/bin/true\n' > "$CFG_TEST_HOME/.config/systemd/user/mirroros-bt-agent.service"
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  grep -q 'user-owned: .config/systemd/user/mirroros-bt-agent.service; left untouched' "$CFG_TEST_DIR/first/configure.log"
  [ ! -e "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-bt-agent.service" ]
  grep -qxF 'ExecStart=/usr/bin/true' "$CFG_TEST_HOME/.config/systemd/user/mirroros-bt-agent.service"
  hardware_assert_rerun
}

@test "failed effective power-key policy identifies power step and never reports ready" {
  export HW_POLICY_FAIL=1
  run hardware_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step system/power:'* ]]
  [[ "$output" != *'system/power: changed'* ]]
  [[ "$output" != *'system/vpn: changed'* ]]
}

@test "failed Bluetooth activation propagates without running dependent steps" {
  export CFG_TEST_START_FAIL=bluetooth.service
  run hardware_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 5 ]
  [[ "$output" == *'step system/bluetooth:'* ]]
  [ ! -e "$HW_TEST_ROOT/usr/share/mirroros/hardware/power-watch" ]
}

@test "VPN missing registration or unrecognised plugin fails without creating a corporate profile" {
  printf 'CFG_STEPS=(system/vpn)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  export HW_PLUGIN_FAIL=1
  run hardware_run --output "$CFG_TEST_DIR/plugin-failed"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step system/vpn:'* ]]
  unset HW_PLUGIN_FAIL
  rm "$HW_TEST_ROOT/usr/lib/NetworkManager/VPN/nm-openconnect-service.name"
  run hardware_run --output "$CFG_TEST_DIR/registration-failed"
  [ "$status" -eq 4 ]
  ! grep -Eq 'nmcli (connection|con) (add|up)|openconnect --' "$CFG_TEST_CALLS"
}

@test "locally edited owned command is preserved and fails its step" {
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  printf '\n# local change\n' >> "$HW_TEST_ROOT/usr/share/mirroros/hardware/volume"
  run hardware_run --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step system/audio:'* ]]
  grep -q '# local change' "$HW_TEST_ROOT/usr/share/mirroros/hardware/volume"
}

@test "hardware steps precede the compositor in the declared order" {
  run /usr/bin/bash -c 'source "$1"; printf "%s\n" "${CFG_STEPS[@]}"' bash "$CFG_SOURCE_ROOT/capabilities/configure-steps"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'system/audio\nsystem/bluetooth\nsystem/power\nsystem/network\nsystem/vpn\ndesktop/compositor/providers/hyprland'* ]]
  [ "${#lines[@]}" -eq 20 ]
}
