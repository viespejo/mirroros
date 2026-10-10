load lifecycle-discovery

setup() {
  lifecycle_setup
}

teardown() {
  lifecycle_teardown
}

@test "install help succeeds on stdout and describes its contract" {
  lifecycle_invoke install --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'Purpose:'
  lifecycle_assert_stdout_contains 'Prerequisites:'
  lifecycle_assert_stdout_contains 'Inputs:'
  lifecycle_assert_stdout_contains 'Consequential effects:'
  lifecycle_assert_stdout_contains 'Evidence:'
  lifecycle_assert_stdout_contains 'Normalized exit outcomes:'
  lifecycle_assert_stdout_contains 'Documentation: docs/procedures/install.md'
  lifecycle_assert_stdout_contains 'Help uses no privilege, requires no ShellCheck, Bats, or Gitleaks, and changes no state.'
  for outcome in '0: success' '2: invalid input' '3: explicit user cancellation' \
    '4: execution completed' '5: execution or upstream-operation failure' \
    '6: internal contract or invariant failure'; do
    lifecycle_assert_stdout_contains "$outcome"
  done
}

@test "install without arguments starts the guided installer, which refuses a missing terminal" {
  lifecycle_invoke install
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'not an interactive terminal'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "install rejects unsupported arguments distinctly" {
  lifecycle_invoke install --bogus
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "install rejects help combined with extra arguments" {
  lifecycle_invoke install --help extra
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_stderr_does_not_contain 'is pending'
  lifecycle_assert_no_success_output
}

@test "install works when invoked by path outside the repository copy" {
  lifecycle_invoke install --help
  lifecycle_assert_status 0
  lifecycle_assert_invoked_outside_copy
}

@test "install reports a missing helper as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke install --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}

@test "install reports an unloadable helper as a damaged checkout" {
  printf '%s\n' 'if then' > "$LIFECYCLE_COPY_ROOT/operations/lib/lifecycle-discovery.sh"
  lifecycle_invoke install --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore the helper from Git or re-clone the repository.'
}

@test "install discover --help prints its own help on stdout without touching the system" {
  lifecycle_invoke install discover --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'Usage: install discover [--target <id>] [--output <dir>]'
  lifecycle_assert_stdout_contains 'Normalized exit outcomes:'
  lifecycle_assert_stdout_contains 'Documentation: docs/procedures/install.md'
}

@test "install discover rejects unsupported and malformed arguments before any inspection" {
  lifecycle_invoke install discover --bogus
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument: --bogus'
  lifecycle_assert_no_success_output

  lifecycle_invoke install discover --target
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains '--target requires a value'

  lifecycle_invoke install discover --help extra
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument: --help'
}

@test "install discover refuses a non-empty output directory without writing" {
  mkdir -p "${LIFECYCLE_TEST_ROOT}/occupied"
  printf '%s\n' keep > "${LIFECYCLE_TEST_ROOT}/occupied/previous.txt"
  lifecycle_invoke install discover --target reference-vm --output "${LIFECYCLE_TEST_ROOT}/occupied"
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'must be an absent or empty directory'
  [[ "$(find "${LIFECYCLE_TEST_ROOT}/occupied" -mindepth 1 | wc -l)" -eq 1 ]]
}

@test "install discover works through a symlink as on the live medium" {
  ln -s "${LIFECYCLE_COPY_ROOT}/operations/install" "${LIFECYCLE_TEST_ROOT}/mirroros-install"
  run "${LIFECYCLE_TEST_ROOT}/mirroros-install" discover --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: install discover'* ]]
}

@test "install discover reports a missing orchestrator as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/install/discovery/discover"
  lifecycle_invoke install discover --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore install/discovery from Git or re-clone the repository.'
}

@test "install plan --help prints its own help on stdout without touching the system" {
  lifecycle_invoke install plan --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'Usage: install plan --facts <file> [--choices <file>] [--output <dir>]'
  lifecycle_assert_stdout_contains 'Normalized exit outcomes:'
  lifecycle_assert_stdout_contains 'Documentation: docs/procedures/install.md'
}

@test "install plan rejects missing, unsupported, and malformed arguments before any work" {
  lifecycle_invoke install plan
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains '--facts is required.'
  lifecycle_assert_no_success_output

  lifecycle_invoke install plan --bogus
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument: --bogus'

  lifecycle_invoke install plan --facts
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains '--facts requires a file.'
}

@test "install plan reports a missing orchestrator as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/install/plan/plan"
  lifecycle_invoke install plan --help
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore install/plan from Git or re-clone the repository.'
}

@test "install help describes the guided installer and starts nothing" {
  lifecycle_invoke install --help
  lifecycle_assert_status 0
  lifecycle_assert_stderr_empty
  lifecycle_assert_stdout_contains 'guided live installer'
  lifecycle_assert_stdout_contains '--plan <file>'
  lifecycle_assert_stdout_contains 'install-run.json'
}

@test "install apply is not a public command" {
  lifecycle_invoke install apply
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_no_success_output

  lifecycle_invoke install apply --help
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
}

@test "install rejects bypass and unsupported options before any prompt or discovery" {
  lifecycle_invoke install --yes
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument(s)'
  lifecycle_assert_no_success_output

  lifecycle_invoke install --output "$LIFECYCLE_TEST_ROOT/run" --non-interactive
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'unsupported argument: --non-interactive'
  [ ! -e "$LIFECYCLE_TEST_ROOT/run" ]

  lifecycle_invoke install --plan
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains '--plan requires a file.'
}

@test "install --plan and --output without a terminal exit 2 and confirm nothing" {
  lifecycle_invoke install --output "$LIFECYCLE_TEST_ROOT/run"
  lifecycle_assert_status 2
  lifecycle_assert_stderr_contains 'not an interactive terminal'
  lifecycle_assert_no_success_output
  [ ! -e "$LIFECYCLE_TEST_ROOT/run" ]
}

@test "install reports a missing guided installer as a damaged checkout" {
  rm -f -- "$LIFECYCLE_COPY_ROOT/install/confirmation/confirm-plan"
  lifecycle_invoke install
  lifecycle_assert_status 6
  lifecycle_assert_stderr_contains 'incomplete or damaged checkout'
  lifecycle_assert_stderr_contains 'Restore install/confirmation from Git or re-clone the repository.'
}
