load lifecycle-discovery

setup() {
  lifecycle_setup
}

teardown() {
  lifecycle_teardown
}

@test "verify help succeeds on stdout and describes its contract" {
  lifecycle_invoke verify --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'Purpose:'
  lifecycle_assert_stdout_contains 'Prerequisites:'
  lifecycle_assert_stdout_contains 'Inputs:'
  lifecycle_assert_stdout_contains 'Consequential effects:'
  lifecycle_assert_stdout_contains 'Evidence:'
  lifecycle_assert_stdout_contains 'Normalized exit outcomes:'
  lifecycle_assert_stdout_contains 'Documentation: docs/procedures/verify.md'
  lifecycle_assert_stdout_contains 'Help uses no privilege, requires no ShellCheck, Bats, or Gitleaks, and changes no state.'
  for outcome in '0: success' '2: invalid input' '3: explicit user cancellation' \
    '4: execution completed' '5: execution or upstream-operation failure' \
    '6: internal contract or invariant failure'; do
    lifecycle_assert_stdout_contains "$outcome"
  done
}

@test "verify without arguments refuses pending work without success wording" {
  lifecycle_invoke verify
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'MirrorOS verify is pending'
  lifecycle_assert_stderr_contains 'docs/procedures/verify.md'
  lifecycle_assert_no_success_output
}

@test "verify rejects unsupported arguments distinctly" {
  lifecycle_invoke verify --bogus
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "verify rejects help combined with extra arguments" {
  lifecycle_invoke verify --help extra
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "verify works when invoked by path outside the repository copy" {
  lifecycle_invoke verify --help
  lifecycle_assert_status 0
  lifecycle_assert_invoked_outside_copy
}

@test "verify reports a missing helper as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke verify --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}

@test "verify reports an unloadable helper as a damaged checkout" {
  printf '%s\n' 'if then' > "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke verify --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}
