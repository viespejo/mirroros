lifecycle_discovery_print_help() {
  local command_name="$1"
  local purpose="$2"
  local prerequisites="$3"
  local inputs="$4"
  local effects="$5"
  local evidence="$6"

  printf 'MirrorOS %s — lifecycle discovery\n' "$command_name"
  if [[ "$command_name" == configure ]]; then
    printf 'Availability: running installed system; installer context Pending (plan 02-16).\n'
  else
    printf 'Availability: help only; domain behavior pending.\n'
  fi
  printf 'Purpose: %s\n' "$purpose"
  printf 'Prerequisites: %s\n' "$prerequisites"
  printf 'Inputs: %s\n' "$inputs"
  printf 'Consequential effects: %s\n' "$effects"
  printf 'Evidence: %s\n' "$evidence"
  printf '%s\n' 'Normalized exit outcomes:'
  if [[ "$command_name" == configure ]]; then
    printf '%s\n' '  0: success (help, or all configure postconditions passed)'
  else
    printf '%s\n' '  0: success (here, help was displayed; this is not domain-operation success)'
  fi
  printf '%s\n' \
    '  2: invalid input or unmet precondition' \
    '  3: explicit user cancellation' \
    '  4: execution completed, but verification is not ready' \
    '  5: execution or upstream-operation failure' \
    '  6: internal contract or invariant failure, including a damaged checkout'
  printf '%s\n' 'Help uses no privilege, requires no ShellCheck, Bats, or Gitleaks, and changes no state.'
  printf 'Documentation: docs/procedures/%s.md\n' "$command_name"
}

lifecycle_discovery_main() {
  local command_name="$1"
  local purpose="$2"
  local prerequisites="$3"
  local inputs="$4"
  local effects="$5"
  local evidence="$6"

  shift 6

  if [[ "$#" -eq 1 && "$1" == '--help' ]]; then
    lifecycle_discovery_print_help \
      "$command_name" "$purpose" "$prerequisites" "$inputs" "$effects" "$evidence"
    return 0
  fi

  if [[ "$#" -gt 0 ]]; then
    printf 'MirrorOS %s: unsupported argument(s):' "$command_name" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 2
  fi

  printf 'MirrorOS %s is pending; see docs/procedures/%s.md.\n' \
    "$command_name" "$command_name" >&2
  return 2
}
