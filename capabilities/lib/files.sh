#!/usr/bin/bash
cfg_managed() {
  grep -Eq '^[[:space:]]*(#|;|--|//).*managed by MirrorOS configure' "$1"
}

cfg_system_file() {
  local src="$1" dest mode="$3" owner group
  owner="$(stat -c %u -- "$(cfg_path /)")"
  group="$(stat -c %g -- "$(cfg_path /)")"
  cfg_context
  dest="$(cfg_path "$2")"
  cfg_managed "$src" || { printf 'Missing managed header: %s\n' "$src" >&2; exit 6; }
  if [[ -L "$dest" ]] || { [[ -e "$dest" ]] && ! cfg_managed "$dest"; }; then
    cfg_log "user-owned: $2; left untouched"
    return 0
  fi
  if [[ -f "$dest" ]] && cmp -s -- "$src" "$dest" &&
    [[ "$(stat -c '%a:%u:%g' -- "$dest")" == "${mode#0}:$owner:$group" ]]; then return 0; fi
  cfg_run_host install -d -m 0755 -- "$(dirname -- "$dest")"
  cfg_run_host install -o "$owner" -g "$group" -m "$mode" -- "$src" "$dest"
  cfg_changed
}

cfg_system_file_present() { cfg_context; [[ -e "$(cfg_path "$1")" ]]; }

cfg_session_is_only() {
  local directory session="$2" entries file target command marker
  cfg_context
  directory="$(cfg_path "$1")"
  shift 2
  entries="$(find "$directory" -mindepth 1 -maxdepth 1 -printf '%f\n')" || return 1
  [[ "$entries" == "$session" ]] || return 1
  file="$directory/$session"
  if [[ -L "$file" ]]; then
    target="$(readlink -- "$file")" || return 1
    if [[ "$target" == /* ]]; then file="$(cfg_path "$target")"; fi
  fi
  [[ -f "$file" && -r "$file" ]] || return 1
  command="$(awk '
    /^\[Desktop Entry\]\r?$/ { section=1; next }
    /^\[/ { section=0 }
    section && /^Exec=/ { sub(/^Exec=/, ""); sub(/\r$/, ""); print }
  ' "$file")" || return 1
  [[ -n "$command" && "$command" != *$'\n'* ]] || return 1
  for marker in "$@"; do
    [[ "$command" == *"$marker"* ]] || return 1
  done
}

cfg_system_link() {
  local target="$1" link
  cfg_context
  link="$(cfg_path "$2")"
  if [[ -L "$link" && "$(readlink -- "$link")" == "$target" ]]; then return 0; fi
  if [[ -e "$link" || -L "$link" ]]; then
    cfg_log "user-owned: $2; left untouched"
    return 0
  fi
  cfg_run_host install -d -m 0755 -- "$(dirname -- "$link")"
  cfg_run_host ln -s -- "$target" "$link"
  cfg_changed
}

# shellcheck disable=SC2016 # Quoted programs expand HOME and variables only inside the user's Bash.
cfg_user_file() {
  local src="$1" relative="$2" legacy='' result
  cfg_context
  [[ "$relative" != /* && "$relative" != *..* ]] || exit 6
  cfg_managed "$src" || exit 6
  if [[ "$relative" == *.lua ]]; then legacy="${relative%.lua}.conf"; fi
  # The user owns path resolution, temporary files, directory creation and every HOME write.
  result="$(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    set -Eeuo pipefail
    umask 022
    relative=$1 legacy=$2
    dest="$HOME/$relative"
    managed() { grep -Eq "^[[:space:]]*(#|;|--|//).*managed by MirrorOS configure" "$1"; }
    if [[ -L "$dest" ]] || { [[ -e "$dest" ]] && ! managed "$dest"; } ||
      { [[ -n "$legacy" ]] && { [[ -L "$HOME/$legacy" ]] || { [[ -e "$HOME/$legacy" ]] && ! managed "$HOME/$legacy"; }; }; }; then
      printf "user-owned: %s; left untouched\n" "$relative"
      exit 0
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    tmp=$(mktemp "$(dirname -- "$dest")/.mirroros-configure.XXXXXX")
    trap '\''rm -f -- "$tmp"'\'' EXIT
    cat > "$tmp"
    if [[ -f "$dest" ]] && cmp -s -- "$tmp" "$dest"; then exit 0; fi
    chmod 0644 "$tmp"
    mv -- "$tmp" "$dest"
    printf "changed\n"
  ' bash "$relative" "$legacy" < "$src")"
  if [[ "$result" == changed ]]; then cfg_changed; elif [[ -n "$result" ]]; then cfg_log "$result"; fi
}

# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_file_present() {
  cfg_context
  cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    [[ -e "$HOME/$1" ]] || { [[ "$1" == *.lua ]] && [[ -e "$HOME/${1%.lua}.conf" ]]; }
  ' bash "$1"
}

# shellcheck disable=SC2016 # The appended source line must retain a literal HOME expansion.
cfg_bashrc_block() {
  local source_path="$1" result
  cfg_context
  [[ "$source_path" != /* && "$source_path" != *..* && "$source_path" =~ ^[a-zA-Z0-9_./-]+$ ]] || exit 6
  result="$(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    set -Eeuo pipefail
    umask 022
    rc="$HOME/.bashrc"
    if [[ -L "$rc" ]]; then
      printf "user-owned: .bashrc; left untouched\n"
      exit 0
    fi
    begin="# BEGIN MirrorOS configure"
    end="# END MirrorOS configure"
    if [[ -e "$rc" || -L "$rc" ]]; then
      begins=$(grep -Fc "$begin" "$rc" || :)
      ends=$(grep -Fc "$end" "$rc" || :)
      if [[ "$begins" == 1 && "$ends" == 1 ]]; then exit 0; fi
      if [[ "$begins" != 0 || "$ends" != 0 ]]; then
        printf "Malformed MirrorOS block in .bashrc; repair its markers before rerunning.\n" >&2
        exit 4
      fi
    fi
    printf '\''\n%s\n[[ ! -r "$HOME/%s" ]] || source "$HOME/%s"\n%s\n'\'' "$begin" "$1" "$1" "$end" >> "$rc"
    printf "changed\n"
  ' bash "$source_path")"
  if [[ "$result" == changed ]]; then cfg_changed; elif [[ -n "$result" ]]; then cfg_log "$result"; fi
}

# shellcheck disable=SC2016 # HOME is resolved by the user's Bash.
cfg_bashrc_block_present() {
  cfg_context
  cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    if [[ -L "$HOME/.bashrc" ]]; then [[ -e "$HOME/.bashrc" ]]; exit; fi
    [[ $(grep -Fc "# BEGIN MirrorOS configure" "$HOME/.bashrc") == 1 &&
       $(grep -Fc "# END MirrorOS configure" "$HOME/.bashrc") == 1 ]]
  '
}
