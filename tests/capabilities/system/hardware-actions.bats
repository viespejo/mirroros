#!/usr/bin/env bats
load ../support
load hardware-support

setup() { hardware_setup; }
teardown() { cfg_test_teardown; }

@test "volume accepts bounded integer deltas and caps every volume write at 100 percent" {
  for action in raise lower +1 -1 +100 -100; do
    run hardware_command audio/volume "$action"
    [ "$status" -eq 0 ]
  done
  [ "$(grep -c '^wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@' "$CFG_TEST_CALLS")" -eq 6 ]
  grep -qxF 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+' "$CFG_TEST_CALLS"
  grep -qxF 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 1%-' "$CFG_TEST_CALLS"
  [ "$(grep -c 'call -- osd showSource volume' "$CFG_TEST_CALLS")" -eq 6 ]
}

@test "mic mute reads the resulting muted state and shows a crossed icon without a level" {
  export HW_MIC_RESULT=muted
  run hardware_command audio/volume mic-mute
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle' "$CFG_TEST_CALLS"
  [ "$(grep -cxF 'wpctl get-volume @DEFAULT_AUDIO_SOURCE@' "$CFG_TEST_CALLS")" -eq 2 ]
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"microphone-muted","message":"Mic muted"}' "$CFG_TEST_CALLS"
  [[ "$output" != *'OSD unavailable'* ]]
  ! grep -qE '"value"|showSource' "$CFG_TEST_CALLS"
}

@test "mic mute reads the resulting unmuted state and shows a normal icon without a level" {
  run hardware_command audio/volume mic-mute
  [ "$status" -eq 0 ]
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"microphone","message":"Mic on"}' "$CFG_TEST_CALLS"
  ! grep -qE '"value"|showSource' "$CFG_TEST_CALLS"
  run hardware_command audio/volume mute-toggle
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' "$CFG_TEST_CALLS"
}

@test "failed or invalid microphone readback reports unavailable without retrying the toggle" {
  for result in unavailable invalid; do
    export HW_MIC_RESULT=$result
    : > "$CFG_TEST_CALLS"
    rm -f "$CFG_TEST_DIR/mic-toggled"
    run hardware_command audio/volume mic-mute
    [ "$status" -eq 4 ]
    [[ "$output" == *'Microphone state unavailable'* ]]
    [ "$(grep -cxF 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle' "$CFG_TEST_CALLS")" -eq 1 ]
    grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"microphone","message":"Microphone unavailable"}' "$CFG_TEST_CALLS"
    ! grep -qE '"value"|showSource|Mic muted|Mic on' "$CFG_TEST_CALLS"
  done
}

@test "missing microphone uses an unambiguous fixed-message OSD call without a write" {
  export HW_AUDIO_UNAVAILABLE=1
  run hardware_command audio/volume mic-mute
  [ "$status" -eq 4 ]
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"microphone","message":"Microphone unavailable"}' "$CFG_TEST_CALLS"
  [[ "$output" != *'OSD unavailable'* ]]
  ! grep -q 'wpctl set-' "$CFG_TEST_CALLS"
  ! grep -qE '"value"|showSource' "$CFG_TEST_CALLS"
}

@test "invalid volume inputs have no provider or OSD effect" {
  for action in +0 -0 +101 +01 '+1;reboot' unknown '1%' --help; do
    run hardware_command audio/volume "$action"
    [ "$status" -eq 2 ]
  done
  run hardware_command audio/volume raise extra
  [ "$status" -eq 2 ]
  run hardware_command audio/volume
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "missing audio reports unavailable and requests measured-source OSD without a write" {
  export HW_AUDIO_UNAVAILABLE=1
  run hardware_command audio/volume raise
  [ "$status" -eq 4 ]
  [[ "$output" == *'Audio unavailable'* ]]
  grep -q 'call -- osd showSource volume' "$CFG_TEST_CALLS"
  ! grep -q 'wpctl set-' "$CFG_TEST_CALLS"
}

@test "OSD failure does not conceal a successful volume action" {
  export HW_OSD_UNAVAILABLE=1
  run hardware_command audio/volume lower
  [ "$status" -eq 0 ]
  [[ "$output" == *'OSD unavailable'* ]]
}

@test "brightness accepts bounded changes and min max for display backlights only" {
  for action in +5% +1% 5%- 1%- max min; do
    run hardware_command power/brightness "$action"
    [ "$status" -eq 0 ]
  done
  [ "$(grep -c '^brightnessctl --class=backlight --min-value=1 set ' "$CFG_TEST_CALLS")" -eq 6 ]
  grep -qxF 'brightnessctl --class=backlight --min-value=1 set 100%' "$CFG_TEST_CALLS"
  grep -qxF 'brightnessctl --class=backlight --min-value=1 set 1%' "$CFG_TEST_CALLS"
  [ "$(grep -c 'call osd showSource brightness' "$CFG_TEST_CALLS")" -eq 6 ]
}

@test "invalid brightness arguments have no effect and absent hardware returns unavailable" {
  for action in +0% 0%- +101% +01% '-5%' '5%;reboot' unknown; do
    run hardware_command power/brightness "$action"
    [ "$status" -eq 2 ]
  done
  run hardware_command power/brightness max extra
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
  export HW_BRIGHTNESS_UNAVAILABLE=1
  run hardware_command power/brightness +5%
  [ "$status" -eq 4 ]
  [[ "$output" == *'Brightness unavailable'* ]]
  ! grep -q 'brightnessctl .*set ' "$CFG_TEST_CALLS"
}

@test "brightness accepts absolute percentages and suppresses every OSD call with --no-osd" {
  for action in 1% 42% 100%; do
    run hardware_command power/brightness "$action"
    [ "$status" -eq 0 ]
  done
  grep -qxF 'brightnessctl --class=backlight --min-value=1 set 42%' "$CFG_TEST_CALLS"
  [ "$(grep -c 'call osd showSource brightness' "$CFG_TEST_CALLS")" -eq 3 ]
  : > "$CFG_TEST_CALLS"
  for action in 42% +5% 5%- max; do
    run hardware_command power/brightness --no-osd "$action"
    [ "$status" -eq 0 ]
  done
  [ "$(grep -c '^brightnessctl --class=backlight --min-value=1 set ' "$CFG_TEST_CALLS")" -eq 4 ]
  ! grep -q '^qs ' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  for args in '0%' '101%' '+5%-' '--no-osd' '--no-osd --no-osd 5%' '5% --no-osd' '--osd 5%'; do
    read -r -a argv <<< "$args"
    run hardware_command power/brightness "${argv[@]}"
    [ "$status" -eq 2 ]
  done
  [ ! -s "$CFG_TEST_CALLS" ]
  HW_BRIGHTNESS_UNAVAILABLE=1 run hardware_command power/brightness --no-osd 50%
  [ "$status" -eq 4 ]
  ! grep -q '^qs ' "$CFG_TEST_CALLS"
}

@test "media validates actions and reports unavailable players" {
  for action in play-pause next previous; do
    run hardware_command audio/media "$action"
    [ "$status" -eq 0 ]
  done
  : > "$CFG_TEST_CALLS"
  run hardware_command audio/media 'next;reboot'
  [ "$status" -eq 2 ]
  run hardware_command audio/media next extra
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
  export HW_MEDIA_UNAVAILABLE=1
  run hardware_command audio/media next
  [ "$status" -eq 4 ]
  [[ "$output" == *'Media control unavailable'* ]]
}
