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

battery_fixture() {
  # $1 state, $2 percentage, $3 energy-rate; sysfs thresholds and AC presence come from the caller.
  export MIRROROS_POWER_SUPPLY_PATH=$CFG_TEST_DIR/power_supply
  export HW_UPOWER_DEVICES=$'/org/freedesktop/UPower/devices/battery_hidpp_battery_4\n/org/freedesktop/UPower/devices/line_power_AC\n/org/freedesktop/UPower/devices/battery_BAT0\n'
  mkdir -p "$CFG_TEST_DIR/upower" "$MIRROROS_POWER_SUPPLY_PATH/BAT0" "$MIRROROS_POWER_SUPPLY_PATH/AC"
  printf '  native-path:          hidpp_battery_4\n  power supply:         no\n  mouse\n    percentage:          20%%\n' \
    > "$CFG_TEST_DIR/upower/battery_hidpp_battery_4"
  printf '  native-path:          BAT0\n  power supply:         yes\n  battery\n    present:             yes\n    state:               %s\n    energy:              40 Wh\n    energy-full:         50.2 Wh\n    energy-rate:         %s W\n    percentage:          %s%%\n    capacity:            88%%\n' \
    "$1" "$3" "$2" > "$CFG_TEST_DIR/upower/battery_BAT0"
  printf 'Mains\n' > "$MIRROROS_POWER_SUPPLY_PATH/AC/type"
  printf '%s\n' "${HW_AC_ONLINE:-0}" > "$MIRROROS_POWER_SUPPLY_PATH/AC/online"
  printf '412\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/cycle_count"
}

@test "battery-status reports machine-readable discharge details from the system battery only" {
  battery_fixture discharging 80 8
  run hardware_command power/battery-status
  [ "$status" -eq 0 ]
  [ "$output" = $'percentage\t80\nstate\tdischarging\nrate\t8\nsize\t50\ncycles\t412\ntime\t300' ]
  ! grep -q 'battery_hidpp_battery_4' <<< "$output"
}

@test "battery-status prefers the instantaneous sysfs rate and counts charging time to the charge limit" {
  battery_fixture charging 60 5
  printf '2000000\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/power_now"
  printf '75\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_start_threshold"
  printf '90\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_end_threshold"
  run hardware_command power/battery-status
  [ "$status" -eq 0 ]
  grep -qxF $'rate\t2' <<< "$output"
  grep -qxF $'threshold\t75-90' <<< "$output"
  grep -qxF $'state\tcharging' <<< "$output"
  # (50.2 Wh * 0.90 - 40 Wh) / 2 W = 2.59 h, rounded to the nearest minute.
  grep -qxF $'time\t155' <<< "$output"
}

@test "battery-status parses UPower in the C locale under a decimal-comma session" {
  battery_fixture discharging 80 8.5
  export HW_UPOWER_LOCALE_COMMA=1 LC_NUMERIC=es_ES.UTF-8
  run hardware_command power/battery-status
  [ "$status" -eq 0 ]
  grep -qxF $'size\t50' <<< "$output"
  grep -qxF $'rate\t8.5' <<< "$output"
  # 40 Wh / 8.5 W = 4.71 h, rounded to the nearest minute.
  grep -qxF $'time\t282' <<< "$output"
}

@test "battery-status prefers the kernel charge thresholds over UPower policy values" {
  battery_fixture fully-charged 94 0
  printf '    charge-start-threshold:        95%%\n    charge-end-threshold:          80%%\n' \
    >> "$CFG_TEST_DIR/upower/battery_BAT0"
  printf '95\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_start_threshold"
  printf '100\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_end_threshold"
  run hardware_command power/battery-status
  [ "$status" -eq 0 ]
  grep -qxF $'threshold\t95-100' <<< "$output"
  rm "$MIRROROS_POWER_SUPPLY_PATH"/BAT0/charge_control_*_threshold
  run hardware_command power/battery-status
  [ "$status" -eq 0 ]
  grep -qxF $'threshold\t95-80' <<< "$output"
}

@test "battery-status reports holding on AC at an active charge limit" {
  export HW_AC_ONLINE=1
  for case in 'pending-charge 80 0' 'fully-charged 95 0' 'charging 95 0.1'; do
    read -r state percentage rate <<< "$case"
    battery_fixture "$state" "$percentage" "$rate"
    printf '95\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_end_threshold"
    run hardware_command power/battery-status
    [ "$status" -eq 0 ]
    grep -qxF $'state\tholding' <<< "$output"
    grep -qxF $'threshold\t95' <<< "$output"
  done
  battery_fixture fully-charged 100 0
  printf '100\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_end_threshold"
  run hardware_command power/battery-status
  grep -qxF $'state\tfully-charged' <<< "$output"
  HW_AC_ONLINE=0 battery_fixture pending-charge 80 0
  printf '95\n' > "$MIRROROS_POWER_SUPPLY_PATH/BAT0/charge_control_end_threshold"
  run hardware_command power/battery-status
  grep -qxF $'state\tpending-charge' <<< "$output"
}

@test "battery-status without a system battery or UPower is unavailable without fabricated values" {
  battery_fixture discharging 80 8
  export HW_UPOWER_DEVICES=$'/org/freedesktop/UPower/devices/battery_hidpp_battery_4\n'
  run hardware_command power/battery-status
  [ "$status" -eq 4 ]
  [[ "$output" == *'Battery unavailable'* ]]
  [[ "$output" != *percentage* ]]
  HW_UPOWER_FAIL=1 run hardware_command power/battery-status
  [ "$status" -eq 4 ]
  run hardware_command power/battery-status --shell
  [ "$status" -eq 2 ]
}
