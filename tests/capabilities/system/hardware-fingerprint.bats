#!/usr/bin/env bats
load ../support
load hardware-support

# The commands run from an installed copy (0755, side by side) as in /usr/share/mirroros/hardware.
setup() {
  hardware_setup
  for tool in fprintd-list fprintd-enroll fprintd-verify fprintd-delete uwsm; do
    cp "$CFG_TEST_DIR/bin/fingerprint-tool" "$CFG_TEST_DIR/bin/$tool"
  done
  # Sentinels: the commands must never escalate or change packages or services.
  cp "$CFG_TEST_DIR/bin/hardware-tool" "$CFG_TEST_DIR/bin/sudo"
  export FP_DIR=$CFG_TEST_DIR/hardware
  mkdir -p "$FP_DIR" "$CFG_TEST_DIR/acpi" "$CFG_TEST_DIR/input" "$CFG_TEST_DIR/usb"
  for command in lid-closed fingerprint-reader fingerprint-setup fingerprint-invite; do
    install -m 0755 "$CFG_SOURCE_ROOT/capabilities/system/fingerprint/$command" "$FP_DIR/$command"
  done
  export MIRROROS_ACPI_LID_PATH=$CFG_TEST_DIR/acpi MIRROROS_INPUT_CLASS_PATH=$CFG_TEST_DIR/input
  export MIRROROS_USB_DEVICES_PATH=$CFG_TEST_DIR/usb MIRROROS_FINGERPRINT_INVITE_WAIT_SECONDS=0 USER=alice
}
teardown() { cfg_test_teardown; }

fp_acpi_lid() { mkdir -p "$CFG_TEST_DIR/acpi/LID0"; printf 'state:      %s\n' "$1" > "$CFG_TEST_DIR/acpi/LID0/state"; }
fp_lid_switch() { mkdir -p "$CFG_TEST_DIR/input/input5/capabilities"; printf '%s\n' "$1" > "$CFG_TEST_DIR/input/input5/capabilities/sw"; }
# A USB device with vendor $1, optional product $2 and optional interface driver $3.
fp_usb() {
  local dev=$CFG_TEST_DIR/usb/1-$RANDOM
  mkdir -p "$dev"
  printf '%s\n' "$1" > "$dev/idVendor"
  [[ -z "${2:-}" ]] || printf '%s\n' "$2" > "$dev/product"
  if [[ -n "${3:-}" ]]; then
    mkdir -p "$dev/1-3:1.0" "$CFG_TEST_DIR/drivers/$3"
    ln -s "$CFG_TEST_DIR/drivers/$3" "$dev/1-3:1.0/driver"
  fi
}
fp_reader() { fp_usb 06cb 'Synaptics Sensors'; }
fp_no_escalation() { ! grep -Eq '^(sudo|pacman|systemctl) ' "$CFG_TEST_CALLS"; }

@test "an ACPI lid reports closed and open without asking logind" {
  fp_acpi_lid closed
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 0 ]
  fp_acpi_lid open
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "without an ACPI lid a lid switch asks logind with a two-second bound and errors read as open" {
  fp_lid_switch '0 1'
  export HW_LID_LOGIND=closed
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 0 ]
  grep -qxF 'busctl --timeout=2 get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed' "$CFG_TEST_CALLS"
  export HW_LID_LOGIND=open
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 1 ]
  export HW_LID_LOGIND=timeout
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "no ACPI lid and no lid switch read as open without any command" {
  fp_lid_switch '0'
  run "$FP_DIR/lid-closed"
  [ "$status" -eq 1 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "a reader is detected by vendor without a kernel driver or by its product string" {
  run "$FP_DIR/fingerprint-reader"
  [ "$status" -eq 1 ]
  fp_usb 06cb 'Synaptics touchpad bridge' usbhid
  fp_usb 046d 'USB Receiver'
  run "$FP_DIR/fingerprint-reader"
  [ "$status" -eq 1 ]
  fp_usb 06cb '' usbfs
  run "$FP_DIR/fingerprint-reader"
  [ "$status" -eq 0 ]
  rm -rf "$CFG_TEST_DIR/usb"/*
  fp_usb 04f3 'ELAN:ARM-M4'
  run "$FP_DIR/fingerprint-reader"
  [ "$status" -eq 0 ]
}

@test "setup without a reader stops before fprintd" {
  run "$FP_DIR/fingerprint-setup" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'No fingerprint sensor detected.'* ]]
  [[ "$output" == *'Press any key to close.'* ]]
  ! grep -q '^fprintd-' "$CFG_TEST_CALLS"
}

@test "setup enrolls and verifies the session user's print without escalation" {
  fp_reader
  run "$FP_DIR/fingerprint-setup" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'Step 1 done.'* ]]
  [[ "$output" == *"That one didn't read."* ]]
  [[ "$output" == *'✓ Matched.'* ]]
  [[ "$output" == *'ready for sudo and authorization prompts'* ]]
  [[ "$output" != *'Using device'* ]]
  grep -qxF 'fprintd-enroll ' "$CFG_TEST_CALLS"
  grep -qxF 'fprintd-verify ' "$CFG_TEST_CALLS"
  [ -e "$CFG_TEST_DIR/fingerprint-prints" ]
  fp_no_escalation
}

@test "setup reports failed enrollment and failed verification" {
  fp_reader
  HW_ENROLL_FAIL=1 run "$FP_DIR/fingerprint-setup" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'Enrollment failed.'* ]]
  ! grep -q '^fprintd-verify' "$CFG_TEST_CALLS"
  HW_VERIFY_FAIL=1 run "$FP_DIR/fingerprint-setup" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'✗ No match.'* ]]
  [[ "$output" == *'Verification failed.'* ]]
  fp_no_escalation
}

@test "with existing prints setup deletes, enrolls again or leaves them" {
  fp_reader
  : > "$CFG_TEST_DIR/fingerprint-prints"
  run "$FP_DIR/fingerprint-setup" <<< q
  [ "$status" -eq 0 ]
  [ -e "$CFG_TEST_DIR/fingerprint-prints" ]
  ! grep -Eq '^fprintd-(delete|enroll)' "$CFG_TEST_CALLS"
  run "$FP_DIR/fingerprint-setup" <<< r
  [ "$status" -eq 0 ]
  grep -qxF 'fprintd-delete alice' "$CFG_TEST_CALLS"
  grep -qxF 'fprintd-enroll ' "$CFG_TEST_CALLS"
  [ -e "$CFG_TEST_DIR/fingerprint-prints" ]
  : > "$CFG_TEST_CALLS"
  run "$FP_DIR/fingerprint-setup" <<< d
  [ "$status" -eq 0 ]
  [[ "$output" == *'password only'* ]]
  [ ! -e "$CFG_TEST_DIR/fingerprint-prints" ]
  ! grep -q '^fprintd-enroll' "$CFG_TEST_CALLS"
  fp_no_escalation
}

@test "the invitation is sent once and its action opens setup in a terminal" {
  fp_reader
  HW_NOTIFY_ACTION=setup run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  [ -e "$XDG_STATE_HOME/mirroros/fingerprint-invited" ]
  grep -qxF 'notify-send --wait -u critical -A setup=Set up Fingerprint reader Use your fingerprint for sudo and authorization prompts.' "$CFG_TEST_CALLS"
  grep -qxF 'uwsm app -- foot -e /usr/share/mirroros/hardware/fingerprint-setup' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  HW_NOTIFY_ACTION=setup run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "a dismissed invitation launches nothing and is not sent again" {
  fp_reader
  run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  grep -q '^notify-send ' "$CFG_TEST_CALLS"
  ! grep -q '^uwsm ' "$CFG_TEST_CALLS"
  [ -e "$XDG_STATE_HOME/mirroros/fingerprint-invited" ]
}

@test "no invitation without a reader, with prints, or without fprintd" {
  run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  fp_reader
  : > "$CFG_TEST_DIR/fingerprint-prints"
  run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  rm "$CFG_TEST_DIR/fingerprint-prints"
  HW_FPRINT_LIST_FAIL=1 run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  ! grep -Eq '^(notify-send|busctl|uwsm) ' "$CFG_TEST_CALLS"
  [ ! -e "$XDG_STATE_HOME/mirroros/fingerprint-invited" ]
}

@test "without a notification server the invitation gives up without its marker" {
  fp_reader
  HW_NOTIFICATIONS=false run "$FP_DIR/fingerprint-invite"
  [ "$status" -eq 0 ]
  grep -q 'NameHasOwner s org.freedesktop.Notifications' "$CFG_TEST_CALLS"
  ! grep -q '^notify-send ' "$CFG_TEST_CALLS"
  [ ! -e "$XDG_STATE_HOME/mirroros/fingerprint-invited" ]
}
