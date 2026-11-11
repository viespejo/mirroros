#!/usr/bin/env bats
# The owned reminder command with systemd-run, systemctl, notify-send, pw-play, qs and date doubles; nothing is
# scheduled, notified or played.

setup() {
  TEST_DIR="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/reminders/reminder"
  export CALLS="$TEST_DIR/calls" XDG_RUNTIME_DIR="$TEST_DIR/run" TZ=UTC NOW=1700000000
  DIR="$XDG_RUNTIME_DIR/mirroros/reminders"
  mkdir -p "$TEST_DIR/bin" "$XDG_RUNTIME_DIR"
  : > "$CALLS"
  # Each double records its argv as one JSON array; <NAME>_STATUS selects its exit status.
  cat > "$TEST_DIR/bin/record" <<'EOF'
#!/usr/bin/bash
name="${0##*/}"
if [[ "$name" == date ]]; then
  [[ "$*" != +%s ]] || { printf '%s\n' "$NOW"; exit 0; }
  exec /usr/bin/date "$@"
fi
jq -cn '$ARGS.positional' --args -- "$name" "$@" >> "$CALLS"
[[ "$name $2" != 'systemctl list-timers' ]] || printf '%s\n' "${TIMERS_JSON:-[]}"
status="${name//-/_}"
status="${status^^}_STATUS"
exit "${!status:-0}"
EOF
  chmod 0755 "$TEST_DIR/bin/record"
  for double in systemd-run systemctl notify-send pw-play qs date; do
    ln -s record "$TEST_DIR/bin/$double"
  done
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() { rm -rf -- "$TEST_DIR"; }

# The recorded calls of one command, one JSON array per line, without the command name.
calls_of() { jq -c --arg name "$1" 'select(.[0] == $name) | .[1:]' "$CALLS"; }
# The recorded command names in order.
call_names() { jq -r '.[0]' "$CALLS"; }
# A timer list entry due <seconds> after NOW.
timer() { printf '{"unit":"%s.timer","next":%s000000}' "$1" "$(( NOW + $2 ))"; }

@test "usage and invalid minutes schedule nothing and exit non-zero" {
  local argv
  for argv in '' 0 00 -5 1.5 abc '5m' 'show bogus' 'show -j extra' 'clear now' 'deliver' '-i extra'; do
    # shellcheck disable=SC2086 # Each case is a deliberately split argv.
    run "$SCRIPT" $argv
    [ "$status" -eq 2 ]
    [[ "$output" == *'Usage: reminder'* ]]
  done
  run "$SCRIPT" ''
  [ "$status" -eq 2 ]
  [ ! -s "$CALLS" ]
  [ ! -e "$DIR" ]
}

@test "a reminder without a message schedules a uniquely named transient timer and a transient confirmation" {
  run "$SCRIPT" 5
  [ "$status" -eq 0 ]
  [ "$(call_names | paste -sd ' ')" = 'systemd-run qs notify-send' ]
  local run unit
  run="$(calls_of systemd-run)"
  unit="$(jq -r '.[4] | sub("^--unit="; "")' <<< "$run")"
  [[ "$unit" =~ ^mirroros-reminder-5m-1700000000-[0-9]+$ ]]
  [ "$run" = "$(jq -cn --arg unit "$unit" '["--user","--quiet","--collect","--on-active=5m","--unit=\($unit)",
    "/usr/share/mirroros/reminders/reminder","deliver",$unit]')" ]
  [ "$(calls_of qs)" = '["ipc","-p","/usr/share/mirroros/shell","call","reminders","refresh"]' ]
  [ "$(calls_of notify-send)" = \
    '["-a","reminder","-h","boolean:transient:true","--","Reminder set for 5 minutes","You'\''ll be reminded at 22:18"]' ]
  [ ! -e "$DIR" ]
}

@test "leading zeros are normalized and one minute uses the singular" {
  run "$SCRIPT" 01
  [ "$status" -eq 0 ]
  [[ "$(calls_of systemd-run)" == *'"--on-active=1m","--unit=mirroros-reminder-1m-1700000000-'* ]]
  [ "$(calls_of notify-send | jq -r '.[5]')" = 'Reminder set for 1 minute' ]
}

@test "a message is written verbatim to a private runtime file and never reaches the unit" {
  local message=$'say "hi" \'there\' $(touch pwned); rm -rf marker\nsecond line'
  run "$SCRIPT" 1 "$message"
  [ "$status" -eq 0 ]
  local unit
  unit="$(calls_of systemd-run | jq -r '.[-1]')"
  [ "$(< "$DIR/$unit.message")" = "$message" ]
  [ "$(stat -c %a "$DIR/$unit.message")" = 600 ]
  [ "$(stat -c %a "$DIR")" = 700 ]
  run grep -qE 'hi|pwned|marker|second' <<< "$(calls_of systemd-run)"
  [ "$status" -eq 1 ]
  [ ! -e pwned ] && [ ! -e "$TEST_DIR/pwned" ]
  [ "$(calls_of notify-send | jq -r '.[5]')" = "$message in 1 minute" ]
}

@test "the remaining words form the message" {
  run "$SCRIPT" 2 check the oven
  [ "$status" -eq 0 ]
  [ "$(cat "$DIR"/mirroros-reminder-2m-*.message)" = 'check the oven' ]
  [ "$(calls_of notify-send | jq -r '.[5]')" = 'check the oven in 2 minutes' ]
}

@test "a failed schedule removes the message file and sends no confirmation" {
  SYSTEMD_RUN_STATUS=1 run "$SCRIPT" 3 tea
  [ "$status" -ne 0 ]
  [ -z "$(find "$DIR" -type f)" ]
  [ -z "$(calls_of notify-send)" ]
}

@test "show --json lists only future reminder timers in the upstream shape" {
  # shellcheck disable=SC2089 # JSON data for the systemctl double, never run as a command.
  local unscheduled='{"unit":"mirroros-reminder-3m-1-1.timer","next":null}'
  mkdir -p "$DIR"
  printf 'Tea' > "$DIR/mirroros-reminder-5m-1699999990-41.message"
  TIMERS_JSON="[$(timer mirroros-reminder-5m-1699999990-41 300),$(timer mirroros-reminder-1m-1699999990-42 90),$(
    timer mirroros-reminder-2m-1699999000-43 -10),$(timer other 60),$unscheduled]"
  # shellcheck disable=SC2090 # The double prints this JSON verbatim.
  export TIMERS_JSON
  run "$SCRIPT" show --json
  [ "$status" -eq 0 ]
  jq -e '.count == 2 and .active == true and .tooltip == "2 reminders" and (.reminders | length) == 2' <<< "$output"
  jq -e '.reminders[0] == {unit:"mirroros-reminder-5m-1699999990-41",timer:"mirroros-reminder-5m-1699999990-41.timer",
    minutes:5,message:"Tea",label:"Tea",remaining:"5m",remainingSeconds:300,at:1700000300,atTime:"22:18"}' <<< "$output"
  jq -e '.reminders[1] | .minutes == 1 and .message == "" and .label == "1-min reminder" and .remaining == "1m 30s"
    and .atTime == "22:14"' <<< "$output"
  [ "$(calls_of systemctl)" = '["--user","list-timers","--all","--output=json","mirroros-reminder-*.timer"]' ]
  run "$SCRIPT" list -j
  [ "$status" -eq 0 ]
  jq -e '.count == 2' <<< "$output"
}

@test "show --json reports no reminders when nothing is pending or systemctl fails" {
  run "$SCRIPT" show --json
  [ "$status" -eq 0 ]
  [ "$output" = '{"count":0,"active":false,"tooltip":"Set Reminder","reminders":[]}' ]
  TIMERS_JSON="[$(timer mirroros-reminder-1m-1699999990-42 60)]" SYSTEMCTL_STATUS=1 run "$SCRIPT" show -j
  [ "$status" -eq 0 ]
  jq -e '.count == 1 and .tooltip == "1 reminder"' <<< "$output"
  TIMERS_JSON='not json' run "$SCRIPT" show --json
  [ "$status" -eq 0 ]
  jq -e '.count == 0' <<< "$output"
}

@test "show sends one transient listing with a line per reminder or none" {
  mkdir -p "$DIR"
  printf 'Tea' > "$DIR/mirroros-reminder-5m-1699999990-41.message"
  TIMERS_JSON="[$(timer mirroros-reminder-5m-1699999990-41 300),$(timer mirroros-reminder-1m-1699999990-42 45)]" \
    run "$SCRIPT" show
  [ "$status" -eq 0 ]
  [ "$(calls_of notify-send)" = "$(jq -cn '["-a","reminder","-h","boolean:transient:true","--","Upcoming reminders",
    "Tea in 5m (22:18)\n1-min reminder in 45s (22:14)"]')" ]
  : > "$CALLS"
  run "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ "$(calls_of notify-send | jq -r '.[-2:] | join("|")')" = 'Upcoming reminders|No outstanding reminders' ]
}

@test "clear stops every reminder timer and service, removes their messages and refreshes" {
  mkdir -p "$DIR"
  printf 'a' > "$DIR/mirroros-reminder-5m-1-1.message"
  printf 'b' > "$DIR/mirroros-reminder-9m-2-2.message"
  printf 'keep' > "$DIR/unrelated"
  run "$SCRIPT" clear
  [ "$status" -eq 0 ]
  [ "$(calls_of systemctl)" = '["--user","stop","--","mirroros-reminder-*.timer","mirroros-reminder-*.service"]' ]
  [ "$(find "$DIR" -type f -printf '%f\n')" = unrelated ]
  [ "$(call_names | paste -sd ' ')" = 'systemctl qs notify-send' ]
  [ "$(calls_of notify-send)" = \
    '["-a","reminder","-h","boolean:transient:true","--","All reminders have been cleared"]' ]
  SYSTEMCTL_STATUS=5 run "$SCRIPT" clear
  [ "$status" -eq 0 ]
}

@test "deliver sends a Critical persistent notification with its message, plays the sound and cleans up" {
  mkdir -p "$DIR"
  printf 'Tea\nnow' > "$DIR/mirroros-reminder-5m-1-1.message"
  run "$SCRIPT" deliver mirroros-reminder-5m-1-1
  [ "$status" -eq 0 ]
  [ "$(call_names | paste -sd ' ')" = 'notify-send pw-play qs' ]
  [ "$(calls_of notify-send)" = '["-a","reminder","-u","critical","--","Reminder","Tea\nnow"]' ]
  [ "$(calls_of pw-play)" = '["/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]' ]
  [ "$(calls_of qs)" = '["ipc","-p","/usr/share/mirroros/shell","call","reminders","refresh"]' ]
  [ ! -e "$DIR/mirroros-reminder-5m-1-1.message" ]
}

@test "deliver without a message file states the elapsed minutes" {
  run "$SCRIPT" deliver mirroros-reminder-5m-1-1
  [ "$status" -eq 0 ]
  [ "$(calls_of notify-send | jq -r '.[-1]')" = 'Your 5 minutes are up' ]
  : > "$CALLS"
  run "$SCRIPT" deliver mirroros-reminder-1m-1-1
  [ "$(calls_of notify-send | jq -r '.[-1]')" = 'Your 1 minute is up' ]
}

@test "deliver rejects a unit outside the reminder pattern and sends nothing" {
  local unit
  mkdir -p "$DIR"
  printf 'secret' > "$TEST_DIR/outside.message"
  for unit in ../../outside mirroros-reminder-5m-1 mirroros-reminder-xm-1-1 other-5m-1-1 'mirroros-reminder-5m-1-1/..'; do
    run "$SCRIPT" deliver "$unit"
    [ "$status" -eq 2 ]
  done
  [ ! -s "$CALLS" ]
  [ -e "$TEST_DIR/outside.message" ]
}

@test "a sound failure still notifies and succeeds" {
  PW_PLAY_STATUS=1 run "$SCRIPT" deliver mirroros-reminder-5m-1-1
  [ "$status" -eq 0 ]
  [ -n "$(calls_of notify-send)" ]
  [ -n "$(calls_of qs)" ]
}

@test "a failing shell refresh never fails a subcommand" {
  export QS_STATUS=1
  run "$SCRIPT" 5 tea
  [ "$status" -eq 0 ]
  run "$SCRIPT" clear
  [ "$status" -eq 0 ]
  run "$SCRIPT" deliver mirroros-reminder-5m-1-1
  [ "$status" -eq 0 ]
  [ "$(calls_of notify-send | wc -l)" -eq 3 ]
}

@test "interactive mode opens the shell prompt" {
  run "$SCRIPT" -i
  [ "$status" -eq 0 ]
  [ "$(calls_of qs)" = '["ipc","-p","/usr/share/mirroros/shell","call","reminders","open"]' ]
  : > "$CALLS"
  run "$SCRIPT" --interactive
  [ "$(call_names)" = qs ]
}
