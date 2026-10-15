#!/usr/bin/bash
# shellcheck disable=SC2034 # CFG_EVIDENCE is shared with the orchestrator and common helpers.
cfg_clean() {
  local value="$*"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  printf '%s' "$value"
}

cfg_record() {
  local value separator=''
  for value in "$@"; do
    printf '%s%s' "$separator" "$(cfg_clean "$value")"
    separator=$'\t'
  done
  printf '\n'
}

cfg_evidence_init() {
  local name record version repository uuid
  [[ -r /proc/sys/kernel/random/uuid ]] || return 6
  uuid="$(< /proc/sys/kernel/random/uuid)"
  [[ -n "$uuid" ]] || return 6
  CFG_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$uuid"
  if [[ -z "$CFG_OUTPUT" ]]; then
    CFG_OUTPUT="$(cfg_path /var/log/mirroros/configure)/$CFG_RUN_ID"
  fi
  # Never overwrite a previous run or follow an output-directory symlink.
  [[ ! -L "$CFG_OUTPUT" ]] || return 1
  if [[ -e "$CFG_OUTPUT" ]]; then
    [[ -d "$CFG_OUTPUT" && -z "$(find "$CFG_OUTPUT" -mindepth 1 -maxdepth 1 -print -quit)" ]] || return 1
  fi
  (umask 077; install -d -m 0700 -- "$CFG_OUTPUT") || return 1
  # The real context root is owned by root; disposable test roots retain the test user's ownership.
  chown --reference="$(cfg_path /)" -- "$CFG_OUTPUT" || return 1
  : > "$CFG_OUTPUT/configure.log"
  : > "$CFG_OUTPUT/configure-run.tsv"
  cfg_record name version repository > "$CFG_OUTPUT/packages.tsv"
  CFG_EVIDENCE=1
  for name in "${!CFG_RESOLVED[@]}"; do
    read -r name version repository <<< "${CFG_RESOLVED[$name]}"
    if [[ "${CFG_INSTALLED[$name]:-0}" == 1 ]]; then
      record="$(pacman -Q -- "$name")" || return 1
      version="${record#* }"
    fi
    cfg_package_record "$name" "$version" "$repository"
  done
}

cfg_package_record() {
  local name="$1" version="$2" repository="$3" line
  local temporary="$CFG_OUTPUT/.packages.tsv"
  # Replace a preflight candidate with the installed version after a transaction.
  : > "$temporary"
  while IFS= read -r line; do
    [[ "${line%%$'\t'*}" != "$name" ]] || continue
    printf '%s\n' "$line" >> "$temporary"
  done < "$CFG_OUTPUT/packages.tsv"
  cfg_record "$name" "$version" "$repository" >> "$temporary"
  mv -- "$temporary" "$CFG_OUTPUT/packages.tsv"
}

cfg_evidence_finish() {
  local outcome="$1" reason="$2" identity=unavailable dirty=unavailable step mode=default
  local temporary="$CFG_OUTPUT/.configure-run.tsv"
  if command -v git > /dev/null 2>&1 && [[ -e "$CODE_ROOT/.git" ]]; then
    identity="$(git -C "$CODE_ROOT" rev-parse HEAD 2>/dev/null)" || identity=unavailable
    dirty="$(git -C "$CODE_ROOT" status --porcelain 2>/dev/null)" || dirty=unavailable
    if [[ "$dirty" != unavailable ]]; then
      if [[ -n "$dirty" ]]; then dirty=yes; else dirty=no; fi
    fi
  fi
  (( CFG_REFRESH == 0 )) || mode=refresh
  {
    cfg_record record key value
    cfg_record run run_id "$CFG_RUN_ID"
    cfg_record run context "$CONFIGURE_CONTEXT"
    cfg_record run target_user "$TARGET_USER"
    cfg_record run code_identity "$identity"
    cfg_record run dirty "$dirty"
    cfg_record run start "$CFG_STARTED"
    cfg_record run end "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    cfg_record run outcome "$outcome"
    cfg_record run failed_step "$([[ "$outcome" == 0 ]] || printf '%s' "$CFG_CURRENT")"
    cfg_record run reason "$reason"
    cfg_record run package_mode "$mode"
    cfg_record run guard_result "$CFG_GUARD"
    cfg_record record step status postcondition
    for step in "${CFG_STEPS[@]}"; do
      cfg_record step "$step" "${CFG_STATUS[$step]}" "${CFG_POST[$step]}"
    done
  } > "$temporary"
  mv -- "$temporary" "$CFG_OUTPUT/configure-run.tsv"
}
