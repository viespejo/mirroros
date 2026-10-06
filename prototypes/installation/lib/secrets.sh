#!/usr/bin/bash
# Prototype harness: synthetic per-run credentials and the canary search.
# The values live only in shell variables and in 0600 files under build/. They are never passed as
# command-line arguments.

PROTO_USER_PASSWORD=''
PROTO_ROOT_PASSWORD=''

proto_secrets_random() {
  local hex

  hex="$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')" || return 1
  [[ "$hex" =~ ^[0-9a-f]{32}$ ]] || return 1
  printf '%s' "$hex"
}

proto_secrets_generate() {
  local user_part
  local root_part

  if ! user_part="$(proto_secrets_random)" || ! root_part="$(proto_secrets_random)"; then
    printf '%s\n' 'MirrorOS prototype: could not generate the synthetic credentials.' >&2
    return 5
  fi
  PROTO_USER_PASSWORD="canary-user-${user_part}"
  PROTO_ROOT_PASSWORD="canary-root-${root_part}"
}

# Writes the two values, one per line (user first, root second), to a 0600 file.
proto_secrets_write_file() {
  local path="$1"

  (
    umask 077
    {
      printf '%s\n' "$PROTO_USER_PASSWORD"
      printf '%s\n' "$PROTO_ROOT_PASSWORD"
    } > "$path"
  )
}

# Searches the given directories for any of the two values. Patterns reach grep through a
# process-substitution descriptor, never as arguments.
# Statuses: 0 no value found, 1 a value was found, 2 the search failed.
proto_secrets_canary_search() {
  local status=0

  [[ -n "$PROTO_USER_PASSWORD" && -n "$PROTO_ROOT_PASSWORD" ]] || return 2
  grep -rlaF --no-messages -f <(
    printf '%s\n' "$PROTO_USER_PASSWORD"
    printf '%s\n' "$PROTO_ROOT_PASSWORD"
  ) -- "$@" > /dev/null || status=$?
  case "$status" in
    0) return 1 ;;
    1) return 0 ;;
    *) return 2 ;;
  esac
}
