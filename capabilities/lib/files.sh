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
  # shellcheck disable=SC2034 # Per-path state is consumed by units.sh.
  CFG_FILES_CHANGED["$2"]=1
  cfg_changed
}

cfg_system_file_present() { cfg_context; [[ -e "$(cfg_path "$1")" ]]; }

# A system file whose previous delivery is identified by its recorded SHA256, so a local edit that keeps the managed
# header is still detected. An absent destination is created and an identical one is accepted. Any other destination
# (edited, unknown, a link or not a regular file) is a conflict: it is never overwritten and the step fails.
# Optional SHA256 arguments name exact earlier shipped contents, accepted as the previous delivery only when no record
# exists, so a file delivered before tracking migrates without accepting any other local content.
cfg_tracked_record() { cfg_path "/var/lib/mirroros/configure/delivered$1.sha256"; }

cfg_tracked_file() {
  local src="$1" path="$2" mode="$3" dest record owner group want current='' recorded='' legacy
  cfg_context
  [[ "$path" == /* && "$path" != *..* ]] || exit 6
  cfg_managed "$src" || { printf 'Missing managed header: %s\n' "$src" >&2; exit 6; }
  owner="$(stat -c %u -- "$(cfg_path /)")"
  group="$(stat -c %g -- "$(cfg_path /)")"
  dest="$(cfg_path "$path")"
  record="$(cfg_tracked_record "$path")"
  want="$(sha256sum < "$src")"
  want="${want%% *}"
  if [[ -f "$record" ]]; then recorded="$(< "$record")"; fi
  if [[ -L "$dest" || ( -e "$dest" && ! -f "$dest" ) ]]; then
    printf 'Conflict: %s is not a regular file delivered by MirrorOS; move it aside, then rerun configure.\n' "$path" >&2
    exit 4
  fi
  if [[ -f "$dest" ]]; then
    current="$(sha256sum < "$dest")"
    current="${current%% *}"
    if [[ -z "$recorded" ]]; then
      for legacy in "${@:4}"; do [[ "$current" != "$legacy" ]] || recorded="$current"; done
    fi
    if [[ "$current" == "$want" && "$recorded" == "$want" &&
      "$(stat -c '%a:%u:%g' -- "$dest")" == "${mode#0}:$owner:$group" ]]; then return 0; fi
    if [[ "$current" != "$want" && ( -z "$recorded" || "$current" != "$recorded" ) ]]; then
      printf 'Conflict: %s differs from its last MirrorOS delivery (local edit or unknown file); move it aside or restore it, then rerun configure.\n' "$path" >&2
      exit 4
    fi
  fi
  cfg_run_host install -d -m 0755 -- "$(dirname -- "$dest")"
  cfg_run_host install -o "$owner" -g "$group" -m "$mode" -- "$src" "$dest"
  printf '%s\n' "$want" > "$CFG_OUTPUT/.tracked-record"
  cfg_run_host install -d -m 0755 -- "$(dirname -- "$record")"
  cfg_run_host install -o "$owner" -g "$group" -m 0644 -- "$CFG_OUTPUT/.tracked-record" "$record"
  rm -f -- "$CFG_OUTPUT/.tracked-record"
  # shellcheck disable=SC2034 # Per-path state is consumed by units.sh.
  CFG_FILES_CHANGED["$path"]=1
  cfg_changed
}

cfg_tracked_file_present() {
  local dest record current
  cfg_context
  dest="$(cfg_path "$1")"
  record="$(cfg_tracked_record "$1")"
  [[ -f "$dest" && ! -L "$dest" && -f "$record" ]] || return 1
  current="$(sha256sum < "$dest")"
  [[ "${current%% *}" == "$(< "$record")" ]]
}

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
  local src="$1" relative="$2" mode="${3:-0644}" legacy='' result
  cfg_context
  [[ "$relative" != /* && "$relative" != *..* && ( "$mode" == 0644 || "$mode" == 0755 ) ]] || exit 6
  cfg_managed "$src" || exit 6
  if [[ "$relative" == *.lua ]]; then legacy="${relative%.lua}.conf"; fi
  # The user owns path resolution, temporary files, directory creation and every HOME write.
  result="$(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    set -Eeuo pipefail
    umask 022
    relative=$1 legacy=$2 mode=$3
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
    if [[ -f "$dest" ]] && cmp -s -- "$tmp" "$dest" && [[ "$(stat -c %a -- "$dest")" == "${mode#0}" ]]; then exit 0; fi
    chmod "$mode" "$tmp"
    mv -- "$tmp" "$dest"
    printf "changed\n"
  ' bash "$relative" "$legacy" "$mode" < "$src")"
  if [[ "$result" == changed ]]; then cfg_changed; elif [[ -n "$result" ]]; then cfg_log "$result"; fi
}

# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_file_present() {
  cfg_context
  cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    [[ -e "$HOME/$1" ]] || { [[ "$1" == *.lua ]] && [[ -e "$HOME/${1%.lua}.conf" ]]; }
  ' bash "$1"
}

# The link is created only while its path is absent; any other existing path is user-owned and left untouched.
# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_link() {
  local target="$1" relative="$2" result
  cfg_context
  [[ "$target" != /* && "$target" != *..* && "$relative" != /* && "$relative" != *..* ]] || exit 6
  result="$(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    set -Eeuo pipefail
    dest="$HOME/$2" want="$HOME/$1"
    if [[ -L "$dest" && "$(readlink -- "$dest")" == "$want" ]]; then exit 0; fi
    if [[ -e "$dest" || -L "$dest" ]]; then
      printf "user-owned: %s; left untouched\n" "$2"
      exit 0
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    ln -sT -- "$want" "$dest"
    printf "changed\n"
  ' bash "$target" "$relative")"
  if [[ "$result" == changed ]]; then cfg_changed; elif [[ -n "$result" ]]; then cfg_log "$result"; fi
}

# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_link_present() {
  cfg_context
  cfg_exec runuser -u "$TARGET_USER" -- bash -c '[[ -e "$HOME/$1" ]]' bash "$1"
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

# The script text is the reviewed capability file, supplied on stdin to the selected user's Bash in a clean
# startup environment. Its output starts with changed or unchanged; the caller may read the full output.
# shellcheck disable=SC2034 # CFG_USER_SCRIPT_RESULT is consumed by the capability steps that call this helper.
cfg_user_script() {
  local script="$1" result
  shift
  cfg_context
  CFG_USER_SCRIPT_RESULT=''
  result="$(cfg_exec runuser -u "$TARGET_USER" -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- "$@" < "$script")" ||
    return $?
  CFG_USER_SCRIPT_RESULT="$result"
  [[ "${result%%[[:space:]]*}" != changed ]] || cfg_changed
}

cfg_login_shell_current() {
  awk -F: -v user="$TARGET_USER" '$1 == user { print $7; found=1 } END { exit !found }' "$(cfg_path /etc/passwd)"
}

# The login shell changes only from the installer's default Bash; any other choice is user-owned.
cfg_login_shell() {
  local shell="$1" current
  cfg_context
  [[ "$shell" =~ ^/usr/bin/[a-z]+$ ]] || exit 6
  current="$(cfg_login_shell_current)" || { printf 'Target user is missing from passwd.\n' >&2; exit 4; }
  [[ "$current" != "$shell" ]] || return 0
  if [[ "$current" != /usr/bin/bash && "$current" != /bin/bash ]]; then
    cfg_log "user-owned: login shell $current; left untouched"
    return 0
  fi
  grep -qxF "$shell" "$(cfg_path /etc/shells)" || { printf '%s is not listed in /etc/shells; install its package before rerunning.\n' "$shell" >&2; exit 4; }
  cfg_run usermod --shell "$shell" -- "$TARGET_USER"
  cfg_changed
}

cfg_login_shell_present() {
  local current
  cfg_context
  current="$(cfg_login_shell_current)" || return 1
  [[ "$current" == "$1" || ( "$current" != /usr/bin/bash && "$current" != /bin/bash ) ]]
}

# A session bus name must have one packaged activation file. Every /usr/share/dbus-1/services file whose
# [D-BUS Service] section declares Name=<bus-name> is an owner; with more than one, each file and its package are
# reported with the action that removes each unexpected owner, and the result is 4; nothing is removed. Otherwise the
# result is 0 only when the single owner is the expected file.
cfg_dbus_service_owner_unique() {
  local name="$1" expected="$2" file path package owners=()
  cfg_context
  for file in "$(cfg_path /usr/share/dbus-1/services)"/*.service; do
    [[ -f "$file" ]] || continue
    awk -v name="$name" '
      { sub(/\r$/, "") }
      /^\[D-BUS Service\]$/ { section=1; next }
      /^\[/ { section=0 }
      section && $0 == "Name=" name { found=1 }
      END { exit !found }
    ' "$file" || continue
    owners+=("/usr/share/dbus-1/services/${file##*/}")
  done
  if (( ${#owners[@]} > 1 )); then
    printf 'Conflict: %s has %s packaged owners:\n' "$name" "${#owners[@]}" >&2
    for path in "${owners[@]}"; do
      package="$(cfg_exec pacman -Qqo -- "$path" 2>/dev/null)" || package=''
      printf '  %s (%s)\n' "$path" "${package:-not owned by a package}" >&2
      [[ "$path" != "$expected" ]] || continue
      if [[ -n "$package" ]]; then
        printf 'Next action: sudo pacman -Rns %s, then rerun configure.\n' "$package" >&2
      else
        printf 'Next action: move %s aside, then rerun configure.\n' "$path" >&2
      fi
    done
    return 4
  fi
  [[ "${#owners[@]}" == 1 && "${owners[0]}" == "$expected" ]]
}

# The executable basename of the first <key> in the [<section>] of a desktop entry or unit file, after env
# assignments and unit command prefixes, or ":hidden" for a Hidden=true entry.
# shellcheck disable=SC2016 # An awk program, expanded by awk only.
CFG_AGENT_PARSER='
  { sub(/\r$/, "") }
  /^[[:space:]]*\[/ { current = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", current); next }
  current == "[" section "]" && /^Hidden[[:space:]]*=[[:space:]]*true[[:space:]]*$/ { hidden = 1 }
  current == "[" section "]" && !found && $0 ~ ("^" key "[[:space:]]*=") { found = 1; value = substr($0, index($0, "=") + 1) }
  END {
    if (hidden) { print ":hidden"; exit }
    n = split(value, words, /[[:space:]]+/)
    for (i = 1; i <= n; i++) {
      word = words[i]
      if (word == "env" || word ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
      sub(/^[-@+!:]+/, "", word); gsub(/["\047]/, "", word); sub(/.*\//, "", word)
      if (word != "") { print word; exit }
    }
  }'

# The packaged unit file for an enabled user unit name: /etc/systemd/user before /usr/lib/systemd/user.
cfg_agent_unit_file() {
  local candidate
  for candidate in "/etc/systemd/user/$1" "/usr/lib/systemd/user/$1"; do
    [[ -f "$(cfg_path "$candidate")" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

# Reports one competing starter <shown> of <agent>; <owned> is the system path whose package is queried, or empty.
cfg_agent_conflict() {
  local shown="$1" owned="$2" agent="$3" action="$4" package=''
  if [[ -n "$owned" ]]; then package="$(cfg_exec pacman -Qqo -- "$owned" 2>/dev/null)" || package=''; fi
  printf 'Conflict: %s starts %s, a competing agent (%s).\n' "$shown" "$agent" "${package:-not owned by a package}" >&2
  printf 'Next action: %s, then rerun configure.\n' "$action" >&2
}

# A session agent must have one starter. Every active XDG autostart entry (/etc/xdg/autostart, or the selected user's
# ~/.config/autostart, whose entry shadows a system entry of the same name) and every enabled user unit (globally in
# /etc/systemd/user or for the selected user) whose executable basename is listed in <agents-file> is a conflict;
# Hidden=true entries are inactive. Each conflict is reported with its package and the next action, and the result
# is 4; nothing is started, removed, hidden or disabled. The user's files are read by the user's Bash, never by root.
# shellcheck disable=SC2016 # HOME and the parser are expanded only inside the user's Bash.
cfg_session_agent_unique() {
  local list="$1" name rest kind relative unit exe file path wants line conflicts=0 entries=()
  local -A agents=() shadowed=()
  cfg_context
  while read -r name rest || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    agents["$name"]=1
  done < "$list"
  mapfile -t entries < <(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    parse=$1
    for file in "$HOME"/.config/autostart/*.desktop; do
      [[ -f "$file" ]] || continue
      printf "autostart\t.config/autostart/%s\t%s\t%s\n" "${file##*/}" "${file##*/}" \
        "$(awk -v section="Desktop Entry" -v key=Exec "$parse" "$file")"
    done
    for link in "$HOME"/.config/systemd/user/*.wants/*.service; do
      [[ -e "$link" || -L "$link" ]] || continue
      unit=${link##*/} exe=""
      if [[ -f "$HOME/.config/systemd/user/$unit" ]]; then
        exe=$(awk -v section=Service -v key=ExecStart "$parse" "$HOME/.config/systemd/user/$unit")
        [[ -n "$exe" ]] || exe=":none"
      fi
      printf "unit\t%s\t%s\t%s\n" "${link#"$HOME"/}" "$unit" "$exe"
    done
  ' bash "$CFG_AGENT_PARSER")
  for line in "${entries[@]}"; do
    IFS=$'\t' read -r kind relative name exe <<< "$line"
    [[ "$kind" != autostart ]] || shadowed["$name"]=1
  done
  for file in "$(cfg_path /etc/xdg/autostart)"/*.desktop; do
    [[ -f "$file" ]] || continue
    name="${file##*/}"
    [[ "${shadowed[$name]:-0}" == 0 ]] || continue
    exe="$(awk -v section='Desktop Entry' -v key=Exec "$CFG_AGENT_PARSER" "$file")"
    [[ -n "$exe" && "${agents[$exe]:-0}" == 1 ]] || continue
    path="/etc/xdg/autostart/$name"
    cfg_agent_conflict "$path" "$path" "$exe" \
      "add a ~/.config/autostart/$name entry with Hidden=true, or remove its package"
    conflicts=$((conflicts + 1))
  done
  for file in "$(cfg_path /etc/systemd/user)"/*.wants/*.service; do
    [[ -e "$file" || -L "$file" ]] || continue
    unit="${file##*/}" wants="${file%/*}"
    path="$(cfg_agent_unit_file "$unit")" || continue
    exe="$(awk -v section=Service -v key=ExecStart "$CFG_AGENT_PARSER" "$(cfg_path "$path")")"
    [[ -n "$exe" && "${agents[$exe]:-0}" == 1 ]] || continue
    cfg_agent_conflict "/etc/systemd/user/${wants##*/}/$unit" "$path" "$exe" "sudo systemctl --global disable $unit"
    conflicts=$((conflicts + 1))
  done
  for line in "${entries[@]}"; do
    IFS=$'\t' read -r kind relative name exe <<< "$line"
    path=''
    if [[ "$kind" == unit && -z "$exe" ]]; then
      path="$(cfg_agent_unit_file "$name")" || continue
      exe="$(awk -v section=Service -v key=ExecStart "$CFG_AGENT_PARSER" "$(cfg_path "$path")")"
    fi
    [[ -n "$exe" && "${agents[$exe]:-0}" == 1 ]] || continue
    # shellcheck disable=SC2088 # The user's paths are shown relative to their home, never expanded by root.
    if [[ "$kind" == autostart ]]; then
      cfg_agent_conflict "~/$relative" '' "$exe" "remove ~/$relative or set Hidden=true in it"
    else
      cfg_agent_conflict "~/$relative" "$path" "$exe" "systemctl --user disable $name"
    fi
    conflicts=$((conflicts + 1))
  done
  (( conflicts == 0 )) || return 4
}

# The Node.js version is declared once, in the managed Zsh environment file, and parsed as data.
cfg_node_version() {
  local version
  version="$(awk -F= '$1 == "MIRROROS_NODE_VERSION" { print $2; exit }' "$CAPABILITIES_DIR/workflow/node/environment.zsh")" ||
    return 1
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  printf '%s\n' "$version"
}
