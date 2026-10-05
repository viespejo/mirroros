load lifecycle-discovery

setup() {
  lifecycle_setup
}

teardown() {
  lifecycle_teardown
}

@test "test help succeeds on stdout and describes its contract" {
  lifecycle_invoke test --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'Purpose:'
  lifecycle_assert_stdout_contains 'Prerequisites:'
  lifecycle_assert_stdout_contains 'Inputs:'
  lifecycle_assert_stdout_contains 'Consequential effects:'
  lifecycle_assert_stdout_contains 'Evidence:'
  lifecycle_assert_stdout_contains 'Normalized exit outcomes:'
  lifecycle_assert_stdout_contains 'Documentation: docs/procedures/test.md'
  lifecycle_assert_stdout_contains 'Help uses no privilege, requires no ShellCheck, Bats, or Gitleaks, and changes no state.'
  for outcome in '0: success' '2: invalid input' '3: explicit user cancellation' \
    '4: execution completed' '5: execution or upstream-operation failure' \
    '6: internal contract or invariant failure'; do
    lifecycle_assert_stdout_contains "$outcome"
  done
}

@test "test without arguments names the missing bundle directory without success wording" {
  lifecycle_invoke test
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'the bundle directory argument is missing'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "test rejects more than one argument before creating files or invoking tools" {
  lifecycle_invoke test one two
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_no_success_output
}

@test "test refuses a missing bundle directory with spaces in its path" {
  lifecycle_invoke test 'relative bundle dir/with spaces'
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'not an accessible directory'
  lifecycle_assert_stderr_contains 'relative bundle dir/with spaces'
  lifecycle_assert_no_success_output
}

@test "test reports a missing qualifier as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/vm/reference/qualify-bootstrap"
  lifecycle_invoke test some-bundle
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore vm/reference/qualify-bootstrap from Git or re-clone the repository.'
}

@test "test reports an unparseable qualifier as a damaged checkout" {
  printf '%s\n' 'if then' > "$LIFECYCLE_COPY_ROOT/vm/reference/qualify-bootstrap"
  chmod 755 "$LIFECYCLE_COPY_ROOT/vm/reference/qualify-bootstrap"
  lifecycle_invoke test some-bundle
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
}

@test "test reports a missing reference library as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/vm/reference/lib/preconditions.sh"
  lifecycle_invoke test some-bundle
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
}

@test "test rejects unsupported arguments distinctly" {
  lifecycle_invoke test --bogus
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "test rejects help combined with extra arguments" {
  lifecycle_invoke test --help extra
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "test works when invoked by path outside the repository copy" {
  lifecycle_invoke test --help
  lifecycle_assert_status 0
  lifecycle_assert_invoked_outside_copy
}

@test "test reports a missing helper as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke test --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}

@test "test reports an unloadable helper as a damaged checkout" {
  printf '%s\n' 'if then' > "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke test --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}
