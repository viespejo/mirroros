#!/usr/bin/env bats
load ../support
load hardware-support

setup() { hardware_setup; }
teardown() { cfg_test_teardown; }

watch_refreshes() {
  /usr/bin/bash -Eeuo pipefail -c '
    source "$1/capabilities/system/power/power-watch"
    power_watch_profile() { printf "profile autodetect\n" >> "$CFG_TEST_CALLS"; }
    last_source=""
    warned=0
    source /dev/stdin
  ' bash "$CFG_SOURCE_ROOT" <<< "$1"
}

@test "power profiles autodetect defaults to performance on AC and balanced on battery" {
  run hardware_command power/power-profile set
  [ "$status" -eq 0 ]
  [[ "$output" == *'ac: performance'* ]]
  [ "$(< "$CFG_TEST_DIR/active-profile")" = performance ]
  export HW_ON_BATTERY=true
  run hardware_command power/power-profile set autodetect
  [ "$status" -eq 0 ]
  [[ "$output" == *'battery: balanced'* ]]
  [ ! -d "$XDG_STATE_HOME/mirroros/power-profiles" ]
}

@test "AC falls back to balanced when performance is not exposed" {
  export HW_PROFILES='aa{sv} 1 1 "Profile" s "balanced"'
  run hardware_command power/power-profile set ac
  [ "$status" -eq 0 ]
  [[ "$output" == *'ac: balanced'* ]]
  ! grep -q 'set-property' "$CFG_TEST_CALLS"
}

@test "explicit profiles are remembered independently and reused without unnecessary D-Bus writes" {
  run hardware_command power/power-profile set ac power-saver
  [ "$status" -eq 0 ]
  [ "$(< "$XDG_STATE_HOME/mirroros/power-profiles/ac")" = power-saver ]
  [ "$(stat -c %a "$XDG_STATE_HOME/mirroros/power-profiles/ac")" = 600 ]
  run hardware_command power/power-profile set battery balanced
  [ "$status" -eq 0 ]
  [ "$(< "$XDG_STATE_HOME/mirroros/power-profiles/battery")" = balanced ]
  run hardware_command power/power-profile set ac
  [ "$status" -eq 0 ]
  [[ "$output" == *'ac: power-saver'* ]]
  : > "$CFG_TEST_CALLS"
  run hardware_command power/power-profile set ac
  [ "$status" -eq 0 ]
  ! grep -q 'set-property' "$CFG_TEST_CALLS"
}

@test "invalid power-profile arguments have no effect" {
  for args in 'get' 'set usb' 'set ac turbo' 'set battery ../balanced' 'set ac balanced extra'; do
    read -r -a argv <<< "$args"
    run hardware_command power/power-profile "${argv[@]}"
    [ "$status" -eq 2 ]
  done
  run hardware_command power/power-profile
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
  [ ! -d "$XDG_STATE_HOME/mirroros/power-profiles" ]
}

@test "unavailable profiles and denied switches never persist a choice" {
  export HW_PROFILES='aa{sv} 1 1 "Profile" s "balanced"'
  run hardware_command power/power-profile set ac performance
  [ "$status" -eq 4 ]
  [ ! -d "$XDG_STATE_HOME/mirroros/power-profiles" ]
  unset HW_PROFILES
  export HW_SET_FAIL=1
  run hardware_command power/power-profile set ac performance
  [ "$status" -eq 4 ]
  [ ! -d "$XDG_STATE_HOME/mirroros/power-profiles" ]
}

@test "unavailable and malformed remembered profiles are preserved and reported" {
  mkdir -p "$XDG_STATE_HOME/mirroros/power-profiles"
  printf 'performance\n' > "$XDG_STATE_HOME/mirroros/power-profiles/ac"
  export HW_PROFILES='aa{sv} 1 1 "Profile" s "balanced"'
  run hardware_command power/power-profile set ac
  [ "$status" -eq 4 ]
  [ "$(< "$XDG_STATE_HOME/mirroros/power-profiles/ac")" = performance ]
  printf 'invalid;reboot\n' > "$XDG_STATE_HOME/mirroros/power-profiles/ac"
  run hardware_command power/power-profile set ac
  [ "$status" -eq 4 ]
  ! grep -q 'set-property' "$CFG_TEST_CALLS"
}

@test "unavailable UPower or PPD returns an honest failure without profile state" {
  export HW_BUS_FAIL=1
  run hardware_command power/power-profile set
  [ "$status" -eq 4 ]
  [[ "$output" == *'Power profiles unavailable'* ]]
  [ ! -d "$XDG_STATE_HOME/mirroros/power-profiles" ]
}

@test "watcher applies profiles once at login and once per power-source transition" {
  run watch_refreshes 'power_watch_refresh
power_watch_refresh
export HW_ON_BATTERY=true
power_watch_refresh
power_watch_refresh
export HW_ON_BATTERY=false
power_watch_refresh'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^profile autodetect$' "$CFG_TEST_CALLS")" -eq 3 ]
  ! grep -q '^notify-send ' "$CFG_TEST_CALLS"
}

@test "watcher sends one warning at 10 percent and rearms after leaving low discharge" {
  run watch_refreshes 'export HW_BATTERY_PRESENT=true HW_ON_BATTERY=true HW_BATTERY_PERCENT=10
power_watch_refresh
power_watch_refresh
export HW_BATTERY_PERCENT=9.5
power_watch_refresh
export HW_BATTERY_PERCENT=11
power_watch_refresh
export HW_BATTERY_PERCENT=10
power_watch_refresh'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^notify-send --urgency=critical --expire-time=30000 ' "$CFG_TEST_CALLS")" -eq 2 ]
}

@test "charging rearms warnings and low AC or absent batteries never warn" {
  run watch_refreshes 'export HW_BATTERY_PRESENT=true HW_ON_BATTERY=true HW_BATTERY_PERCENT=5
power_watch_refresh
export HW_BATTERY_STATE=1 HW_ON_BATTERY=false
power_watch_refresh
export HW_BATTERY_STATE=2 HW_ON_BATTERY=true
power_watch_refresh
export HW_BATTERY_PRESENT=false
power_watch_refresh'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^notify-send ' "$CFG_TEST_CALLS")" -eq 2 ]
  [[ "$output" == *'Battery unavailable'* ]]
}

@test "malformed battery data does not fabricate a notification" {
  run watch_refreshes 'export HW_BATTERY_PRESENT=true HW_ON_BATTERY=true HW_BATTERY_PERCENT=invalid
power_watch_refresh'
  [ "$status" -eq 0 ]
  [[ "$output" == *'invalid percentage'* ]]
  ! grep -q '^notify-send ' "$CFG_TEST_CALLS"
}

@test "watcher monitor failure propagates for service restart" {
  export HW_MONITOR_FAIL=1
  # Avoid running the installed profile path; only exercise main's monitor lifecycle.
  run /usr/bin/bash -Eeuo pipefail -c 'source "$1/capabilities/system/power/power-watch"
power_watch_profile() { :; }
power_watch_main' bash "$CFG_SOURCE_ROOT"
  [ "$status" -eq 17 ]
}

@test "failed notification retries without rearming a successful low episode" {
  run watch_refreshes 'export HW_BATTERY_PRESENT=true HW_ON_BATTERY=true HW_BATTERY_PERCENT=5 HW_NOTIFY_FAIL=1
power_watch_refresh
export HW_NOTIFY_FAIL=0
power_watch_refresh
power_watch_refresh'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^notify-send ' "$CFG_TEST_CALLS")" -eq 2 ]
}
