#!/usr/bin/bash
# Canary-search negative control. Plants a synthetic canary in a temporary directory under build/ and
# requires the harness search to detect it, then confirms that a clean directory passes.
# The planted value is never printed or copied into any summary, and it is removed afterwards.
set -Eeuo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "${LIB_DIR}/../../.." && pwd -P)"
# shellcheck disable=SC1091 # Resolved from BASH_SOURCE at run time.
source "${LIB_DIR}/secrets.sh"

[[ -d "${REPOSITORY_ROOT}/build" ]] || mkdir -m 700 -- "${REPOSITORY_ROOT}/build"
CONTROL_DIR="$(mktemp -d "${REPOSITORY_ROOT}/build/canary-control.XXXXXX")"
trap 'rm -rf -- "$CONTROL_DIR"' EXIT

proto_secrets_generate
mkdir -m 700 -- "${CONTROL_DIR}/clean" "${CONTROL_DIR}/planted"
printf 'unrelated evidence line\n' > "${CONTROL_DIR}/clean/log.txt"
printf 'unrelated evidence line\n' > "${CONTROL_DIR}/planted/log.txt"
printf 'noise before %s noise after\n' "$PROTO_ROOT_PASSWORD" >> "${CONTROL_DIR}/planted/log.txt"

clean_status=0
proto_secrets_canary_search "${CONTROL_DIR}/clean" || clean_status=$?
planted_status=0
proto_secrets_canary_search "${CONTROL_DIR}/planted" || planted_status=$?

printf 'clean directory search status: %s (expected 0)\n' "$clean_status"
printf 'planted directory search status: %s (expected 1)\n' "$planted_status"
if [[ "$clean_status" -eq 0 && "$planted_status" -eq 1 ]]; then
  printf '%s\n' 'Negative control passed: the canary search detects a planted synthetic canary.'
else
  printf '%s\n' 'Negative control FAILED: the canary search is not reliable.' >&2
  exit 1
fi
