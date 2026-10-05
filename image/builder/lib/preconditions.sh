#!/usr/bin/bash

# shellcheck disable=SC2034 # Read by the build orchestrator after argument parsing.
BUILD_NO_CACHE=0

preconditions_parse_arguments() {
  # shellcheck disable=SC2034 # Read by the build orchestrator after argument parsing.
  BUILD_NO_CACHE=0

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  if [[ "$#" -eq 1 && "$1" == '--no-cache' ]]; then
    # shellcheck disable=SC2034 # Read by the build orchestrator after argument parsing.
    BUILD_NO_CACHE=1
    return 0
  fi

  printf 'MirrorOS build: unsupported argument(s):' >&2
  printf ' %q' "$@" >&2
  printf '\nAccepted forms: operations/build, operations/build --no-cache, operations/build --help.\n' >&2
  return 2
}

preconditions_check_user() {
  local effective_uid="$1"

  if [[ "$effective_uid" -eq 0 ]]; then
    printf '%s\n' \
      'MirrorOS build: do not run as root; run as a normal user with direct Docker access.' >&2
    return 2
  fi
}

preconditions_check_tools() {
  local tool

  for tool in docker cosign gitleaks git node flock timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'MirrorOS build: required tool is missing: %s. Install it and retry; no host remediation is attempted.\n' \
        "$tool" >&2
      return 2
    fi
  done
}

preconditions_check_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  printf '%s\n' \
    'MirrorOS build: Docker is unavailable to this user. Start/configure Docker access yourself, then retry; no sudo fallback or host remediation is attempted.' >&2
  return 2
}
