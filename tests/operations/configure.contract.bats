load ../capabilities/support

setup() { cfg_test_setup; }
teardown() { cfg_test_teardown; }

@test "configure help describes both execution contexts without mutation" {
  run "$CFG_TEST_ENTRY" --help
  [ "$status" -eq 0 ]
  for text in 'Purpose:' 'Prerequisites:' 'Inputs:' 'Consequential effects:' 'Evidence:' \
    'Normalized exit outcomes:' 'Documentation: docs/procedures/configure.md' \
    '--user' '--target-root <mounted-dir> (requires --user)' '--refresh' '--output' 'runuser' 'configure-run.tsv' 'installer target root'; do
    [[ "$output" == *"$text"* ]]
  done
  [[ "$output" != *'help only'* ]]
  [[ "$output" != *'Pending, plan 02-16'* ]]
  [ ! -s "$CFG_TEST_CALLS" ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/run/mirroros/configure.lock" ]
}

@test "configure rejects unsupported arguments including combined help" {
  for argument in --bogus --help; do
    run "$CFG_TEST_ENTRY" "$argument" extra
    [ "$status" -eq 2 ]
    [[ "$output" == *'unsupported argument(s)'* ]]
    [[ "$output" != *'is pending'* ]]
  done
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "configure requires values for user output and target root" {
  for argument in --user --output --target-root; do
    run "$CFG_TEST_ENTRY" "$argument"
    [ "$status" -eq 2 ]
    [[ "$output" == *'requires a value'* ]]
  done
}

@test "configure without root returns 2 before convergence" {
  export CFG_TEST_UID=1000
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'root using sudo'* ]]
  cfg_test_no_install
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/run/mirroros/configure.lock" ]
}

@test "configure refuses missing nonexistent and root users" {
  unset SUDO_USER
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Target user is missing'* ]]
  for user in nonexistent root; do
    run "$CFG_TEST_ENTRY" --user "$user"
    [ "$status" -eq 2 ]
    [[ "$output" == *'Target user'* ]]
  done
  cfg_test_no_install
}

@test "configure explicit user overrides SUDO_USER and works outside the checkout" {
  export SUDO_USER=root
  cd "$CFG_TEST_DIR"
  run "$CFG_TEST_ENTRY" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'next boot'* ]]
}

@test "configure resolves a launcher symlink outside the checkout" {
  ln -s "$CFG_TEST_ENTRY" "$CFG_TEST_DIR/mirroros-configure"
  cd "$CFG_TEST_DIR"
  run "$CFG_TEST_DIR/mirroros-configure" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'installer target root'* ]]
  run "$CFG_TEST_DIR/mirroros-configure" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'next boot'* ]]
}

@test "configure missing or unloadable lifecycle helper gives damaged-checkout outcome" {
  helper="$CFG_TEST_DIR/code/operations/lib/lifecycle-discovery.sh"
  rm "$helper"
  run "$CFG_TEST_ENTRY" --help
  [ "$status" -eq 6 ]
  [[ "$output" == *'incomplete or damaged checkout'* ]]
  printf 'if then\n' > "$helper"
  run "$CFG_TEST_ENTRY" --help
  [ "$status" -eq 6 ]
  [[ "$output" == *'Restore the helper from Git or re-clone'* ]]
}

@test "configure missing capability helper or listed step gives outcome 6" {
  cfg_test_step missing
  rm "$CFG_TEST_DIR/code/capabilities/missing/apply"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 6 ]
  [[ "$output" == *'incomplete or damaged checkout'* ]]
  rm "$CFG_TEST_DIR/code/capabilities/lib/files.sh"
  run "$CFG_TEST_ENTRY" --help
  [ "$status" -eq 6 ]
}
