#!/usr/bin/bash
# shellcheck disable=SC2034 # Constants are read by the flow, the scenarios, and the contract points.
# Frontend contract check: mock plan data. Everything here is fictitious. No real disk or system
# state is read or changed. Non-production.

MOCK_TARGET_ID='mock-disk-0'
MOCK_TARGET='mock-disk-0 (fictitious, 64 GiB, no real device)'
MOCK_DIGEST='sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
MOCK_REVIEW_PROMPT="Apply the mock plan to ${MOCK_TARGET_ID} with digest ${MOCK_DIGEST}?"

mock_target_summary() {
  printf '%s\n' \
    "Target: ${MOCK_TARGET}" \
    'Layout: one EFI partition and one root partition (fictitious)'
}

mock_defaults() {
  printf '%s\n' \
    'hostname: mirror (source: built-in default)' \
    'locale: en_US.UTF-8 (source: detected from the live medium)' \
    'timezone: UTC (source: maintainer selection, mock)' \
    'filesystem: ext4 (source: ADR 0003 baseline, mock)'
}

# Destructive operations, one per line, without the textual marker; the flow adds it.
mock_destructive_operations() {
  printf '%s\n' \
    "erase the partition table of ${MOCK_TARGET_ID}" \
    "format partition 2 of ${MOCK_TARGET_ID} as ext4"
}

# Arguments: destination file. Writes the complete mock plan.
mock_plan_write() {
  local path="$1"
  local operation

  {
    printf '%s\n' 'MirrorOS mock installation plan (fictitious data; nothing is read or changed)'
    printf '\n%s\n' '[Target]'
    mock_target_summary
    printf '\n%s\n' '[Defaults and provenance]'
    mock_defaults
    printf '\n%s\n' '[Operations]'
    while IFS= read -r operation; do
      printf 'DESTRUCTIVE: %s\n' "$operation"
    done < <(mock_destructive_operations)
    printf '%s\n' \
      'create the user account (mock)' \
      'install the base package set (mock)' \
      'write the boot configuration (mock)'
    printf '\n%s\n' '[Digest]'
    printf 'Plan digest: %s\n' "$MOCK_DIGEST"
    printf '%s\n' '(the rest of this plan is filler so that the pager has to scroll)'
    printf 'filler line %02d: no operation\n' {1..30}
  } > "$path"
}
