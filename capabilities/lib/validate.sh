#!/usr/bin/bash
# shellcheck disable=SC2034 # Validated package and guard state is consumed by other sourced helpers.
cfg_problem() { CFG_ERRORS+=("$1"); }

cfg_parse() {
  local invalid=0
  while (( $# )); do
    case "$1" in
      --user|--output)
        if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
          printf 'MirrorOS configure: %s requires a value.\n' "$1" >&2
          invalid=1
          shift
          continue
        fi
        case "$1" in --user) TARGET_USER="$2" ;; --output) CFG_OUTPUT="$2" ;; esac
        shift 2 ;;
      --refresh) CFG_REFRESH=1; shift ;;
      *) printf 'MirrorOS configure: unsupported argument(s); use --help.\n' >&2; invalid=1; shift ;;
    esac
  done
  (( invalid == 0 ))
}

cfg_keyboard_validate() {
  local line key value layout='' keymap='' listing
  if [[ -f "$(cfg_path /etc/vconsole.conf)" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^[[:space:]]*(XKBLAYOUT|KEYMAP)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Parse values as data, never source vconsole.conf.
      value="${value%%#*}"
      value="${value//\"/}"
      value="${value//\'/}"
      value="${value//[[:space:]]/}"
      case "$key" in XKBLAYOUT) layout="$value" ;; KEYMAP) keymap="$value" ;; esac
    done < "$(cfg_path /etc/vconsole.conf)"
  fi
  CFG_LAYOUT="${layout:-${keymap:-us}}"
  listing="$(cfg_path /usr/share/X11/xkb/rules/base.lst)"
  if [[ ! -r "$listing" ]]; then
    cfg_problem 'XKB layout data is missing; install the MirrorOS base package xkeyboard-config before rerunning.'
  elif ! awk -v layout="$CFG_LAYOUT" '
    /^! layout/ { section=1; next }
    /^!/ { section=0 }
    section && $1 == layout { found=1 }
    END { exit !found }
  ' "$listing"; then
    cfg_problem "Keyboard layout $CFG_LAYOUT is not a known XKB layout; set XKBLAYOUT in /etc/vconsole.conf to a supported layout."
  fi
}

cfg_lock() {
  local directory
  directory="$(cfg_path /run/mirroros)"
  if ! mkdir -p -- "$directory" || ! exec {CFG_LOCK_FD}> "$directory/configure.lock"; then
    cfg_problem 'Cannot open the configure lock under /run/mirroros; check permissions.'
  elif ! flock -n "$CFG_LOCK_FD"; then
    cfg_problem 'Another configure run holds the lock; wait for it to finish.'
  fi
}

cfg_validate() {
  local tool uid='' user_uid='' step name repository extra resolved actual_name version actual_repository
  local missing=0 upgrades='' query_status=0 tools_ok=1 resolved_match=0
  if ! uid="$(id -u)" || [[ "$uid" != 0 ]]; then cfg_problem 'Run configure as root using sudo.'; fi
  for tool in bash pacman flock runuser systemctl install id awk grep cmp dirname mkdir chmod chown \
    ln readlink rm mv cat date find sort stat mktemp; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      cfg_problem "Missing base tool: $tool; restore the base installation."
      tools_ok=0
    fi
  done
  if [[ -z "$TARGET_USER" ]]; then
    cfg_problem 'Target user is missing; use sudo or --user <name>.'
  elif [[ ! "$TARGET_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ ]] || ! user_uid="$(id -u -- "$TARGET_USER" 2>/dev/null)"; then
    cfg_problem 'Target user does not exist or has an invalid name; use --user <name>.'
  elif [[ "$user_uid" == 0 || "$TARGET_USER" == root ]]; then
    cfg_problem 'Target user must not be root; use --user <non-root-user>.'
  fi
  if [[ "$uid" == 0 && "$tools_ok" == 1 ]]; then cfg_lock; fi
  if [[ -n "$CFG_OUTPUT" ]]; then
    if [[ -L "$CFG_OUTPUT" || ( -e "$CFG_OUTPUT" && ! -d "$CFG_OUTPUT" ) ]]; then
      cfg_problem '--output must be an absent or empty directory, not a symbolic link.'
    elif [[ -d "$CFG_OUTPUT" ]] && [[ -n "$(find "$CFG_OUTPUT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      cfg_problem '--output must be absent or empty; select a new directory.'
    fi
  fi
  cfg_keyboard_validate
  if ! compgen -G "$(cfg_path /var/lib/pacman/sync)/*.db" > /dev/null; then
    cfg_problem 'Sync databases are absent; run sudo pacman -Syu before configuring.'
  fi
  if command -v pacman > /dev/null 2>&1; then
    for step in "${CFG_STEPS[@]}"; do
      while read -r name repository extra || [[ -n "$name" ]]; do
        [[ -n "$name" && "$name" != \#* ]] || continue
        if [[ ! "$name" =~ ^[a-zA-Z0-9@._+-]+$ || ! "$repository" =~ ^(core|extra|multilib)$ || -n "$extra" ]]; then
          cfg_problem "Invalid package declaration in $step/packages; use <name> <official-repository>."
          continue
        fi
        if ! resolved="$(pacman -Sp --print-format '%r %n %v' -- "$repository/$name" 2>/dev/null)"; then
          cfg_problem "Package $name was not found in $repository; check sync databases and the declaration."
        else
          actual_repository='' actual_name='' version='' resolved_match=0
          # pacman can print dependencies too; select the exact declared package.
          while read -r actual_repository actual_name version; do
            [[ "$actual_name" == "$name" && "$actual_repository" == "$repository" && -n "$version" ]] || continue
            CFG_RESOLVED["$name"]="$name $version $actual_repository"
            resolved_match=1
          done <<< "$resolved"
          if (( ! resolved_match )); then
            cfg_problem "Package $name does not resolve to declared repository $repository."
          fi
        fi
        if pacman -Q -- "$name" > /dev/null 2>&1; then
          CFG_INSTALLED["$name"]=1
        else
          CFG_INSTALLED["$name"]=0
          missing=1
        fi
      done < "$CAPABILITIES_DIR/$step/packages"
    done
    if (( missing && ! CFG_REFRESH )); then
      upgrades="$(pacman -Qu 2>&1)" || query_status=$?
      # pacman uses status 1 for an empty query; unexpected failures are not an empty guard.
      if (( query_status > 1 )) || { (( query_status == 1 )) && [[ -n "$upgrades" ]]; }; then
        CFG_GUARD=failed
        cfg_problem 'Cannot query pending upgrades; check pacman before rerunning.'
      elif grep -qvE '^$|\[ignored\]' <<< "$upgrades"; then
        CFG_GUARD=blocked
        cfg_problem 'Packages are missing while upgrades are pending; run sudo pacman -Syu or rerun with --refresh.'
      else
        CFG_GUARD=passed
      fi
    elif (( missing )); then
      CFG_GUARD=refresh
    fi
  fi
  if (( ${#CFG_ERRORS[@]} )); then
    printf 'MirrorOS configure: validation failed:\n' >&2
    printf '  - %s\n' "${CFG_ERRORS[@]}" >&2
    return 2
  fi
}
