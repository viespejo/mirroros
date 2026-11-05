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

@test "mic mute uses its source and a fixed message without a fabricated level" {
  run hardware_command audio/volume mic-mute
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle' "$CFG_TEST_CALLS"
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"microphone","message":"Microphone mute toggled"}' "$CFG_TEST_CALLS"
  [[ "$output" != *'OSD unavailable'* ]]
  ! grep -qE '"value"|showSource' "$CFG_TEST_CALLS"
  run hardware_command audio/volume mute-toggle
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' "$CFG_TEST_CALLS"
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
