#!/usr/bin/bash
# Private preferences for temporary acceptance tooling, not product provisioning.

validate_preferences() {
  local gateway=$1 username=$2
  local username_pattern='^[A-Za-z0-9_.@\\-]+$'
  [[ "$gateway" == https://?* && "$gateway" != *[@?#]* && ! "$gateway" =~ [[:space:][:cntrl:]] ]] || { fail 'Expected an HTTPS gateway without credentials, query, fragment or whitespace.'; return 2; }
  [[ "$username" =~ $username_pattern ]] || { fail 'Unsupported username format; no preferences saved.'; return 2; }
}

private_preferences_dir() {
  local directory=$1
  if [[ ! -e "$directory" && ! -L "$directory" ]]; then
    mkdir -m 700 -- "$directory" || return 2
  fi
  [[ -d "$directory" && ! -L "$directory" ]] || { fail 'Unsafe preferences directory.'; return 2; }
  [[ "$(stat -c %u "$directory")" == "$EUID" && "$(stat -c %a "$directory")" == 700 ]] || { fail 'Preferences directory must be owned by you with mode 0700.'; return 2; }
}

load_preferences() {
  local path=$1
  [[ -f "$path" && ! -L "$path" ]] || { fail 'Unsafe preferences file.'; return 2; }
  [[ "$(stat -c %u "$path")" == "$EUID" && "$(stat -c %a "$path")" == 600 && "$(stat -c %h "$path")" == 1 ]] || { fail 'Preferences file must be private, owned and not hard-linked.'; return 2; }
  jq -e 'type == "object" and keys == ["gateway", "schema_version", "username"] and .schema_version == 1 and (.gateway | type == "string") and (.username | type == "string") and ([.gateway, .username] | all(.[]; (explode | all(.[]; . >= 32 and . != 127))))' "$path" >/dev/null 2>&1 || { fail 'Invalid preference schema; review locally.'; return 2; }
  gateway=$(jq -r '.gateway' "$path") || return 2
  username=$(jq -r '.username' "$path") || return 2
  validate_preferences "$gateway" "$username"
}

save_preferences() {
  local directory=$1 uuid=$2 gateway=$3 username=$4 temporary path
  [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { fail 'Invalid profile identity.'; return 2; }
  validate_preferences "$gateway" "$username" || return 2
  private_preferences_dir "$directory" || return 2
  path="$directory/$uuid.json"
  [[ ! -e "$path" && ! -L "$path" ]] || { fail 'Existing preferences were not overwritten.'; return 2; }
  temporary=$(mktemp "$directory/.new.XXXXXXXX") || return 2
  # Private values flow through stdin, never jq arguments or shell evaluation.
  if ! printf '%s\n%s\n' "$gateway" "$username" | jq -Rn '[inputs] | {schema_version: 1, gateway: .[0], username: .[1]}' > "$temporary"; then
    rm -f -- "$temporary"
    fail 'Could not prepare preferences.'; return 2
  fi
  if ! mv -nT -- "$temporary" "$path"; then
    rm -f -- "$temporary"
    fail 'Could not publish preferences.'; return 2
  fi
  if [[ -e "$temporary" ]]; then
    rm -f -- "$temporary"
    fail 'Concurrent preferences detected; no overwrite performed.'; return 2
  fi
}
