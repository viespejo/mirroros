#!/usr/bin/env bats
load ../support
load hardware-support

setup() {
  hardware_setup
  printf 'CFG_STEPS=(system/fingerprint)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  FP_STEP=$CFG_SOURCE_ROOT/capabilities/system/fingerprint
  FP_GATE='auth [success=1 default=ignore] pam_exec.so quiet /usr/share/mirroros/hardware/lid-closed'
}
teardown() { cfg_test_teardown; }

# /etc/pam.d/sudo exactly as shipped by sudo 1.9.17.p2-6.
fp_packaged_sudo() {
  mkdir -p "$HW_TEST_ROOT/etc/pam.d"
  printf '#%%PAM-1.0\nauth\t\tinclude\t\tsystem-auth\naccount\t\tinclude\t\tsystem-auth\nsession\t\tinclude\t\tsystem-auth\nsession\t\toptional\tpam_systemd.so class=none\n' \
    > "$HW_TEST_ROOT/etc/pam.d/sudo"
  [ "$(sha256sum < "$HW_TEST_ROOT/etc/pam.d/sudo")" = '7ec1c668c10e0f83d00e25f336872212fe04ce2c2563e1d661d34d28852f4649  -' ]
}

# The rule immediately before pam_fprintd, ignoring comments and blank lines, is the clamshell gate.
fp_gate_precedes() {
  [ "$(grep -Ev '^[[:space:]]*(#|$)' "$1" | grep -B1 -m1 'pam_fprintd\.so' | head -n1)" = "$FP_GATE" ]
}

fp_assert_delivery() {
  local command
  for package in fprintd libfprint; do [ -f "$CFG_TEST_INSTALLED/$package" ]; done
  [ ! -e "$CFG_TEST_INSTALLED/libfprint-git" ]
  for command in lid-closed fingerprint-reader fingerprint-setup fingerprint-invite; do
    cmp "$FP_STEP/$command" "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command"
    [ "$(stat -c %a "$HW_TEST_ROOT/usr/share/mirroros/hardware/$command")" = 755 ]
  done
  cmp "$FP_STEP/OMARCHY-LICENSE" "$HW_TEST_ROOT/usr/share/mirroros/hardware/licenses/omarchy-fingerprint"
  cmp "$FP_STEP/polkit-1" "$HW_TEST_ROOT/etc/pam.d/polkit-1"
  cmp "$FP_STEP/sudo" "$HW_TEST_ROOT/etc/pam.d/sudo"
  for stack in polkit-1 sudo; do
    [ "$(stat -c %a "$HW_TEST_ROOT/etc/pam.d/$stack")" = 644 ]
    fp_gate_precedes "$HW_TEST_ROOT/etc/pam.d/$stack"
    grep -qxF 'auth sufficient pam_fprintd.so' "$HW_TEST_ROOT/etc/pam.d/$stack"
  done
  grep -qxP 'auth\t\tinclude\t\tsystem-auth' "$HW_TEST_ROOT/etc/pam.d/sudo"
  grep -qxF 'password include system-auth' "$HW_TEST_ROOT/etc/pam.d/polkit-1"
  cmp "$FP_STEP/mirroros-fingerprint-invite.service" "$HW_TEST_ROOT/etc/systemd/user/mirroros-fingerprint-invite.service"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/mirroros-fingerprint-invite.service")" = \
    /etc/systemd/user/mirroros-fingerprint-invite.service ]
  # Configure never starts fprintd, runs the delivered commands or touches other PAM stacks.
  ! grep -Eq 'fprintd|systemctl (start|restart|reload|--user)|/hardware/(lid-closed|fingerprint-)' "$CFG_TEST_CALLS"
  [ ! -e "$HW_TEST_ROOT/etc/pam.d/system-auth" ]
}

fp_assert_rerun() {
  : > "$CFG_TEST_CALLS"
  run hardware_run --output "$CFG_TEST_DIR/second"
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/fingerprint: unchanged'* ]]
  cfg_test_no_install
}

@test "running context creates both stacks when sudo is absent and reruns unchanged" {
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/fingerprint: changed'* ]]
  fp_assert_delivery
  fp_assert_rerun
}

@test "the packaged sudo stack is replaced and the previous delivery is kept on rerun" {
  fp_packaged_sudo
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  fp_assert_delivery
  fp_assert_rerun
  cmp "$FP_STEP/sudo" "$HW_TEST_ROOT/etc/pam.d/sudo"
}

@test "a locally edited sudo stack stops the step with exit 4 and is never overwritten" {
  fp_packaged_sudo
  printf 'auth\t\trequired\tpam_faillock.so\n' >> "$HW_TEST_ROOT/etc/pam.d/sudo"
  cp "$HW_TEST_ROOT/etc/pam.d/sudo" "$CFG_TEST_DIR/edited-sudo"
  run hardware_run --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step system/fingerprint:'* ]]
  grep -qF 'Conflict: /etc/pam.d/sudo differs from its last MirrorOS delivery' "$CFG_TEST_DIR/conflict/configure.log"
  cmp "$CFG_TEST_DIR/edited-sudo" "$HW_TEST_ROOT/etc/pam.d/sudo"
}

@test "a delivered sudo stack edited afterwards stops the step and is kept" {
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  printf '# local change\n' >> "$HW_TEST_ROOT/etc/pam.d/sudo"
  run hardware_run --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ]
  grep -qxF '# local change' "$HW_TEST_ROOT/etc/pam.d/sudo"
}

@test "the running check fails when the gate does not immediately precede pam_fprintd" {
  stack=$CFG_TEST_DIR/code/capabilities/system/fingerprint/polkit-1
  grep -vxF 'auth sufficient pam_fprintd.so' "$stack" > "$CFG_TEST_DIR/stack"
  printf 'auth sufficient pam_fprintd.so\n' >> "$CFG_TEST_DIR/stack"
  cp "$CFG_TEST_DIR/stack" "$stack"
  run hardware_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step system/fingerprint:'* ]]
}

@test "target context delivers the stacks without live activation and reruns unchanged" {
  cfg_test_target_context
  fp_packaged_sudo
  run hardware_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  fp_assert_delivery
  ! grep -Eq '^(systemctl|busctl) ' "$CFG_TEST_CALLS"
  fp_assert_rerun
}
