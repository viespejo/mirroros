#!/usr/bin/env bats
load ../support
load hardware-support

# PipeWire object ids, object serials and pactl indexes are deliberately distinct (DEC-043).
setup() {
  hardware_setup
  mkdir -p "$CFG_TEST_DIR/pactl"
  cat > "$CFG_TEST_DIR/pw-dump.json" <<'JSON'
[
  {"id": 31, "type": "PipeWire:Interface:Device", "info": {"props": {"device.name": "alsa_card.pci"}}},
  {"id": 46, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "alsa_output.speaker", "media.class": "Audio/Sink", "object.serial": 66}}},
  {"id": 63, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "alsa_output.headphones", "media.class": "Audio/Sink", "object.serial": 282}}},
  {"id": 64, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "alsa_output.headphones", "media.class": "Stream/Output/Audio"}}},
  {"id": 71, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "alsa_input.mic", "media.class": "Audio/Source", "object.serial": 301}}},
  {"id": 77, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "bluez_output.headset.1", "media.class": "Audio/Sink", "object.serial": 300}}}
]
JSON
  cat > "$CFG_TEST_DIR/pactl/sinks.json" <<'JSON'
[
  {"index": 66, "name": "alsa_output.speaker", "description": "Speaker", "properties": {}, "ports": [{"name": "speaker", "availability": "availability unknown"}]},
  {"index": 282, "name": "alsa_output.headphones", "description": "Headphones", "properties": {}, "ports": [{"name": "headphones", "availability": "not available"}]},
  {"index": 290, "name": "auto_null", "description": "Dummy Output", "properties": {}, "ports": []},
  {"index": 295, "name": "effect_input.filter", "description": "Filter", "properties": {"node.virtual": "true"}, "ports": []},
  {"index": 300, "name": "bluez_output.headset.1", "description": "Headset", "properties": {}, "ports": [{"name": "headset", "availability": "available"}]}
]
JSON
  cat > "$CFG_TEST_DIR/pactl/sources.json" <<'JSON'
[
  {"index": 301, "name": "alsa_input.mic", "description": "Microphone", "properties": {}, "ports": [{"name": "mic", "availability": "available"}, {"name": "headset-mic", "availability": "not available"}]},
  {"index": 302, "name": "alsa_input.headset", "description": "Headset mic", "properties": {}, "ports": [{"name": "headset-mic", "availability": "not available"}]}
]
JSON
  cat > "$CFG_TEST_DIR/pactl/sink-inputs.json" <<'JSON'
[
  {"index": 501, "properties": {"application.name": "Firefox"}},
  {"index": 502, "properties": {"node.link-group": "filter-chain-1", "node.virtual": "true"}},
  {"index": 503, "properties": {"application.name": "EasyEffects"}},
  {"index": 504, "properties": {"application.name": "loopback", "node.virtual": "true"}},
  {"index": 505, "properties": {"application.name": "mpv"}}
]
JSON
  cat > "$CFG_TEST_DIR/pactl/source-outputs.json" <<'JSON'
[
  {"index": 601, "properties": {"application.name": "Chromium"}},
  {"index": 602, "properties": {"application.name": "echo-cancel", "node.link-group": "echo-cancel-1"}}
]
JSON
}
teardown() { cfg_test_teardown; }

@test "default output resolves the PipeWire object id by node name and moves only application streams" {
  run hardware_command audio/audio-device default output alsa_output.headphones
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-default 63' "$CFG_TEST_CALLS"
  ! grep -Eq '^wpctl set-default (282|64|66)$' "$CFG_TEST_CALLS"
  grep -qxF 'pactl move-sink-input 501 alsa_output.headphones' "$CFG_TEST_CALLS"
  grep -qxF 'pactl move-sink-input 505 alsa_output.headphones' "$CFG_TEST_CALLS"
  [ "$(grep -c '^pactl move-sink-input ' "$CFG_TEST_CALLS")" -eq 2 ]
  ! grep -q '^pactl set-default' "$CFG_TEST_CALLS"
  ! grep -q '^qs ' "$CFG_TEST_CALLS"
}

@test "default input moves capture streams but leaves filter internals in place" {
  run hardware_command audio/audio-device default input alsa_input.mic
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-default 71' "$CFG_TEST_CALLS"
  grep -qxF 'pactl move-source-output 601 alsa_input.mic' "$CFG_TEST_CALLS"
  ! grep -q 'move-source-output 602' "$CFG_TEST_CALLS"
  ! grep -q 'move-sink-input' "$CFG_TEST_CALLS"
}

@test "unknown node, wrong media class, PipeWire or WirePlumber failure exit unavailable without moves or OSD" {
  for args in 'output alsa_output.missing' 'input alsa_output.speaker' 'output alsa_input.mic'; do
    read -r -a argv <<< "$args"
    : > "$CFG_TEST_CALLS"
    run hardware_command audio/audio-device default "${argv[@]}"
    [ "$status" -eq 4 ]
    ! grep -Eq '^wpctl set-default|^pactl move|^qs ' "$CFG_TEST_CALLS"
  done
  : > "$CFG_TEST_CALLS"
  HW_PW_FAIL=1 run hardware_command audio/audio-device default output alsa_output.speaker
  [ "$status" -eq 4 ]
  ! grep -Eq '^wpctl set-default|^pactl move' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  HW_WPCTL_FAIL=1 run hardware_command audio/audio-device default output alsa_output.speaker
  [ "$status" -eq 4 ]
  [[ "$output" == *'WirePlumber rejected'* ]]
  ! grep -Eq '^pactl move|^qs ' "$CFG_TEST_CALLS"
}

@test "availability reports per-device port availability for outputs and inputs" {
  run hardware_command audio/audio-device availability output
  [ "$status" -eq 0 ]
  [ "$output" = $'alsa_output.speaker\t1\nalsa_output.headphones\t0\nauto_null\t1\neffect_input.filter\t1\nbluez_output.headset.1\t1' ]
  run hardware_command audio/audio-device availability input
  [ "$status" -eq 0 ]
  [ "$output" = $'alsa_input.mic\t1\nalsa_input.headset\t0' ]
  HW_PACTL_FAIL=1 run hardware_command audio/audio-device availability output
  [ "$status" -eq 4 ]
}

@test "cycle skips unavailable, dummy and virtual outputs and keeps the target mute state" {
  export HW_DEFAULT_SINK=alsa_output.speaker HW_SINK_MUTE=yes
  run hardware_command audio/audio-device cycle
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-default 77' "$CFG_TEST_CALLS"
  ! grep -Eq 'set-default (63|282|300)|auto_null|effect_input' "$CFG_TEST_CALLS"
  ! grep -q 'set-mute' "$CFG_TEST_CALLS"
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"volume-muted","message":"Headset"}' "$CFG_TEST_CALLS"
}

@test "cycle wraps to the first available output through the name-based default path" {
  export HW_DEFAULT_SINK=bluez_output.headset.1 HW_SINK_VOLUME=80
  run hardware_command audio/audio-device cycle
  [ "$status" -eq 0 ]
  grep -qxF 'wpctl set-default 46' "$CFG_TEST_CALLS"
  grep -qxF 'pactl move-sink-input 501 alsa_output.speaker' "$CFG_TEST_CALLS"
  grep -qxF 'qs ipc -p /usr/share/mirroros/shell call -- osd show {"icon":"volume-high","message":"Speaker"}' "$CFG_TEST_CALLS"
}

@test "cycle failure to set the default shows no success OSD" {
  export HW_DEFAULT_SINK=bluez_output.headset.1 HW_WPCTL_FAIL=1
  run hardware_command audio/audio-device cycle
  [ "$status" -eq 4 ]
  ! grep -q '^qs ' "$CFG_TEST_CALLS"
}

@test "cycle without an available output reports unavailable" {
  printf '[]\n' > "$CFG_TEST_DIR/pactl/sinks.json"
  run hardware_command audio/audio-device cycle
  [ "$status" -eq 4 ]
  grep -qF '"message":"No audio output"' "$CFG_TEST_CALLS"
  ! grep -q '^wpctl set-default' "$CFG_TEST_CALLS"
}

@test "invalid audio-device arguments have no provider effect" {
  for args in '' 'default' 'default output' 'default speaker alsa_output.speaker' 'default output 46 alsa_output.speaker' \
      'default output bad;name' 'availability' 'availability sinks' 'cycle extra' 'unknown'; do
    read -r -a argv <<< "$args"
    run hardware_command audio/audio-device "${argv[@]}"
    [ "$status" -eq 2 ]
  done
  run hardware_command audio/audio-device default output 'bad name'
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}
