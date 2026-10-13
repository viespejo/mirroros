#!/usr/bin/bash
# Shared helpers of the postconditions checker. The checker reports its observations as a NUL-delimited stream of
# key and value pairs on the standard output of the collector; nothing here writes a file.

declare -A OBSERVED=()

# Emits one observation. A key is emitted at most once; an observation that cannot be made is simply not
# emitted, and the evaluator reports the check that needed it.
obs() {
  [[ -z "${OBSERVED[$1]+set}" ]] || return 0
  OBSERVED["$1"]=1
  printf '%s\0%s\0' "$1" "$2"
}
