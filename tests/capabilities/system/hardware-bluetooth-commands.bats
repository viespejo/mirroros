#!/usr/bin/env bats
load ../support

# Owned Bluetooth panel commands (DEC-067, DEC-068, DEC-070, DEC-074): trust only on pair, no swallowed failures,
# bounded BlueZ calls, step-distinct exit codes and no device identity in output.
ADDRESS=01:23:45:67:89:AB

setup() {
  cfg_test_setup
  for tool in bluetoothctl rfkill timeout; do
    cp "$CFG_SOURCE_ROOT/tests/capabilities/system/doubles/bluetooth-$tool" "$CFG_TEST_DIR/bin/$tool"
    chmod 0755 "$CFG_TEST_DIR/bin/$tool"
  done
  bt=$CFG_TEST_DIR/bt
  mkdir -p "$bt"
  : > "$bt/powered"
  export MIRROROS_BLUETOOTH_POWER_WAIT_SECONDS=0
}
teardown() { cfg_test_teardown; }

bluetooth() { /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/bluetooth/$1" "${@:2}"; }
# The device actions issued, in order, without the read-only show/list probes.
actions() { awk '$1 == "bluetoothctl" && $2 != "show" && $2 != "list" { print $2 }' "$CFG_TEST_CALLS" | paste -sd' '; }
no_identity() { [[ "$output" != *"$ADDRESS"* && "$output" != *'Secret Headset'* && "$output" != *host-0* ]]; }
# A function, not an inline `! grep`, so a match fails the test under errexit.
absent() { ! grep -q "$1" "$CFG_TEST_CALLS"; }
all_timed() { absent '^bluetoothctl-untimed '; }

@test "bluetooth-device rejects invalid actions, addresses and arity without calling BlueZ" {
  for args in '' 'pair' "toggle $ADDRESS" "trust $ADDRESS" 'pair 01:23:45:67:89' 'pair 01:23:45:67:89:AG' \
    "pair $ADDRESS;id" "pair $ADDRESS extra"; do
    # shellcheck disable=SC2086 # Each case is a deliberate word list.
    run bluetooth bluetooth-device $args
    [ "$status" -eq 2 ]
  done
  run bluetooth bluetooth-device pair "$ADDRESS extra"
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "bluetooth-device pair runs pair, trust and connect with bounded calls and silent output" {
  run bluetooth bluetooth-device pair "$ADDRESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(actions)" = 'pair trust connect' ]
  [ -e "$bt/paired" ] && [ -e "$bt/trusted" ] && [ -e "$bt/connected" ]
  grep -qxF "timeout 20s bluetoothctl pair $ADDRESS" "$CFG_TEST_CALLS"
  grep -qxF "timeout 10s bluetoothctl trust $ADDRESS" "$CFG_TEST_CALLS"
  grep -qxF "timeout 20s bluetoothctl connect $ADDRESS" "$CFG_TEST_CALLS"
  all_timed
}

@test "bluetooth-device pair stops at a failed pair without trust or connect" {
  export HW_BT_FAIL=pair
  run bluetooth bluetooth-device pair "$ADDRESS"
  [ "$status" -eq 4 ]
  [ "$(actions)" = pair ]
  [ ! -e "$bt/trusted" ] && [ ! -e "$bt/connected" ]
  no_identity
  all_timed
}

@test "bluetooth-device pair reports trust and connect failures with distinct codes" {
  export HW_BT_FAIL=trust
  run bluetooth bluetooth-device pair "$ADDRESS"
  [ "$status" -eq 5 ]
  [ "$(actions)" = 'pair trust' ]
  no_identity
  : > "$CFG_TEST_CALLS"
  export HW_BT_FAIL=connect
  run bluetooth bluetooth-device pair "$ADDRESS"
  [ "$status" -eq 6 ]
  [ "$(actions)" = 'pair trust connect' ]
  no_identity
}

@test "bluetooth-device connect never changes trust and reports failure" {
  run bluetooth bluetooth-device connect "$ADDRESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(actions)" = connect ]
  [ ! -e "$bt/trusted" ]
  : > "$CFG_TEST_CALLS"
  export HW_BT_FAIL=connect
  run bluetooth bluetooth-device connect "$ADDRESS"
  [ "$status" -eq 6 ]
  absent '^bluetoothctl trust'
  no_identity
  all_timed
}

@test "bluetooth-device disconnect does not power on and reports failure" {
  rm "$bt/powered"
  : > "$bt/connected"
  run bluetooth bluetooth-device disconnect "$ADDRESS"
  [ "$status" -eq 0 ]
  [ "$(actions)" = disconnect ]
  absent '^rfkill '
  run bluetooth bluetooth-device disconnect "$ADDRESS"
  [ "$status" -eq 7 ]
  no_identity
  all_timed
}

@test "bluetooth-device forget tolerates a device that is not connected but not a failed remove" {
  : > "$bt/paired"
  run bluetooth bluetooth-device forget "$ADDRESS"
  [ "$status" -eq 0 ]
  [ "$(actions)" = 'disconnect remove' ]
  [ ! -e "$bt/paired" ]
  : > "$CFG_TEST_CALLS"
  export HW_BT_FAIL=remove
  run bluetooth bluetooth-device forget "$ADDRESS"
  [ "$status" -eq 8 ]
  no_identity
  all_timed
}

@test "bluetooth-device powers the adapter on through bluetooth-power and stops when it cannot" {
  rm "$bt/powered"
  : > "$bt/blocked"
  run bluetooth bluetooth-device connect "$ADDRESS"
  [ "$status" -eq 0 ]
  grep -qxF 'rfkill unblock bluetooth' "$CFG_TEST_CALLS"
  [ "$(actions)" = connect ]
  rm "$bt/powered"
  : > "$CFG_TEST_CALLS"
  export HW_RFKILL_FAIL=1
  run bluetooth bluetooth-device pair "$ADDRESS"
  [ "$status" -eq 3 ]
  [ -z "$(actions)" ]
  no_identity
}

@test "bluetooth-power off sets the persistent soft block and on lifts it" {
  run bluetooth bluetooth-power off
  [ "$status" -eq 0 ]
  [ -e "$bt/blocked" ] && [ ! -e "$bt/powered" ]
  run bluetooth bluetooth-power is-on
  [ "$status" -eq 1 ]
  run bluetooth bluetooth-power on
  [ "$status" -eq 0 ]
  [ ! -e "$bt/blocked" ] && [ -e "$bt/powered" ]
  absent '^bluetoothctl power'
  run bluetooth bluetooth-power is-on
  [ "$status" -eq 0 ]
  all_timed
}

@test "bluetooth-power on falls back to bluetoothctl power on and reports an adapter that stays down" {
  rm "$bt/powered"
  export HW_BT_AUTOENABLE=0
  run bluetooth bluetooth-power on
  [ "$status" -eq 0 ]
  grep -qxF 'timeout 5s bluetoothctl power on' "$CFG_TEST_CALLS"
  [ -e "$bt/powered" ]
  rm "$bt/powered"
  export HW_BT_FAIL=power
  run bluetooth bluetooth-power on
  [ "$status" -eq 1 ]
  all_timed
}

@test "bluetooth-power reports rfkill failures, counts any controller and has no toggle" {
  export HW_RFKILL_FAIL=1
  run bluetooth bluetooth-power off
  [ "$status" -eq 3 ]
  run bluetooth bluetooth-power on
  [ "$status" -eq 3 ]
  unset HW_RFKILL_FAIL
  export HW_BT_CONTROLLERS=2
  run bluetooth bluetooth-power is-on
  [ "$status" -eq 0 ]
  export HW_BT_CONTROLLERS=0
  run bluetooth bluetooth-power is-on
  [ "$status" -eq 1 ]
  for args in '' toggle 'on extra' status; do
    # shellcheck disable=SC2086 # Each case is a deliberate word list.
    run bluetooth bluetooth-power $args
    [ "$status" -eq 2 ]
  done
}

@test "Bluetooth commands involve no privilege escalation" {
  local command
  for command in bluetooth-device bluetooth-power; do
    [ -z "$(grep -v '^[[:space:]]*#' "$CFG_SOURCE_ROOT/capabilities/system/bluetooth/$command" | grep -E 'sudo|pkexec|polkit')" ]
  done
}
