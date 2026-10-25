#!/usr/bin/bash
# shellcheck disable=SC2034 # Validated package and guard state is consumed by other sourced helpers.
cfg_problem() { CFG_ERRORS+=("$1"); }

cfg_parse() {
  local invalid=0
  while (( $# )); do
    case "$1" in
      --user|--output|--target-root)
        if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
          printf 'MirrorOS configure: %s requires a value.\n' "$1" >&2
          invalid=1
          shift
          continue
        fi
        case "$1" in
          --user) TARGET_USER="$2"; CFG_USER_GIVEN=1 ;;
          --output) CFG_OUTPUT="$2" ;;
          --target-root) CONFIGURE_CONTEXT=target; CONFIGURE_ROOT="$2" ;;
        esac
        shift 2 ;;
      --refresh) CFG_REFRESH=1; shift ;;
      *) printf 'MirrorOS configure: unsupported argument(s); use --help.\n' >&2; invalid=1; shift ;;
    esac
  done
  if [[ "$CONFIGURE_CONTEXT" == target && "$CFG_USER_GIVEN" == 0 ]]; then TARGET_USER=''; fi
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
  listing="$(cfg_path /usr/share/xkeyboard-config-2/rules/base.lst)"
  if [[ ! -r "$listing" && ! -L "$(cfg_path /usr/share/X11/xkb)" ]]; then
    listing="$(cfg_path /usr/share/X11/xkb/rules/base.lst)"
  fi
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
  # The managed session declares its own layout list (DEC-017); console and greeter keep the resolved layout above.
  local step session layouts
  [[ -r "$listing" ]] || return 0
  for step in "${CFG_STEPS[@]}"; do
    [[ "$step" == desktop/compositor/providers/hyprland ]] || continue
    session="$(sed -nE 's/.*kb_layout = "([a-z,]+)".*/\1/p' "$CAPABILITIES_DIR/$step/hyprland.lua")"
    IFS=, read -r -a layouts <<< "$session"
    (( ${#layouts[@]} )) || { cfg_problem "The managed session declares no keyboard layout list; restore $step/hyprland.lua."; continue; }
    for layout in "${layouts[@]}"; do
      awk -v layout="$layout" '
        /^! layout/ { section=1; next }
        /^!/ { section=0 }
        section && $1 == layout { found=1 }
        END { exit !found }
      ' "$listing" || cfg_problem "Session keyboard layout $layout is not a known XKB layout; install xkeyboard-config before rerunning."
    done
  done
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
  local missing=0 upgrades='' query_status=0 tools_ok=1 resolved_match=0 context_ok=1
  if ! uid="$(id -u)" || [[ "$uid" != 0 ]]; then cfg_problem 'Run configure as root using sudo.'; fi
  if [[ "$CONFIGURE_CONTEXT" == target ]]; then
    if [[ ${MIRROROS_CONFIGURE_ROOT+x} ]]; then
      cfg_problem '--target-root cannot be combined with MIRROROS_CONFIGURE_ROOT.'
      context_ok=0
    fi
    if [[ "$CONFIGURE_ROOT" != /* ]]; then
      cfg_problem '--target-root must be an absolute path.'
      context_ok=0
    fi
    if [[ ! -d "$CONFIGURE_ROOT" ]]; then
      cfg_problem '--target-root must be an existing directory.'
      context_ok=0
    elif [[ "$CONFIGURE_ROOT" -ef / ]]; then
      cfg_problem '--target-root must not be /.'
      context_ok=0
    fi
    for tool in arch-chroot flock mountpoint; do
      if ! command -v "$tool" > /dev/null 2>&1; then
        cfg_problem "Missing live-medium tool: $tool; restore the installation medium."
        tools_ok=0
        context_ok=0
      fi
    done
    if command -v mountpoint > /dev/null 2>&1 && ! mountpoint -q -- "$CONFIGURE_ROOT"; then
      cfg_problem '--target-root must be a mount point.'
      context_ok=0
    fi
    if (( context_ok )); then
      CONFIGURE_ROOT="${CONFIGURE_ROOT%/}"
      CFG_TARGET_VALID=1
    fi
  fi
  if (( context_ok )); then
    for tool in bash pacman runuser systemctl install id awk grep cmp dirname mkdir chmod chown \
      ln readlink rm mv cat date find sort stat mktemp usermod; do
      # shellcheck disable=SC2016 # The target Bash resolves its own tool path from the positional argument.
      if ! cfg_exec bash -c 'command -v "$1"' bash "$tool" > /dev/null 2>&1; then
        cfg_problem "Missing base tool: $tool; restore the base installation."
        tools_ok=0
      fi
    done
    if [[ "$CONFIGURE_CONTEXT" == running ]] && ! command -v flock > /dev/null 2>&1; then
      cfg_problem 'Missing base tool: flock; restore the base installation.'
      tools_ok=0
    fi
  fi
  if [[ -z "$TARGET_USER" ]]; then
    cfg_problem 'Target user is missing; use --user <name> (mandatory with --target-root).'
  elif [[ "$TARGET_USER" == root ]]; then
    cfg_problem 'Target user must not be root; use --user <non-root-user>.'
  elif [[ ! "$TARGET_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ ]]; then
    cfg_problem 'Target user does not exist or has an invalid name; use --user <name>.'
  elif (( context_ok )); then
    if ! user_uid="$(cfg_exec id -u -- "$TARGET_USER" 2>/dev/null)" ||
      { [[ "$CONFIGURE_CONTEXT" == target ]] && ! awk -F: -v user="$TARGET_USER" '$1 == user { found=1 } END { exit !found }' "$(cfg_path /etc/passwd)"; }; then
      cfg_problem 'Target user does not exist or has an invalid name; use --user <name>.'
    elif [[ "$user_uid" == 0 ]]; then
      cfg_problem 'Target user must not be root; use --user <non-root-user>.'
    fi
  fi
  if [[ "$uid" == 0 && "$tools_ok" == 1 && "$context_ok" == 1 ]]; then cfg_lock; fi
  if [[ -n "$CFG_OUTPUT" ]]; then
    if [[ -L "$CFG_OUTPUT" || ( -e "$CFG_OUTPUT" && ! -d "$CFG_OUTPUT" ) ]]; then
      cfg_problem '--output must be an absent or empty directory, not a symbolic link.'
    elif [[ -d "$CFG_OUTPUT" ]] && [[ -n "$(find "$CFG_OUTPUT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      cfg_problem '--output must be absent or empty; select a new directory.'
    fi
  fi
  if (( context_ok )); then cfg_keyboard_validate; fi
  if (( context_ok )) && ! compgen -G "$(cfg_path /var/lib/pacman/sync)/*.db" > /dev/null; then
    cfg_problem 'Sync databases are absent; run sudo pacman -Syu before configuring.'
  fi
  if (( context_ok )) && cfg_exec bash -c 'command -v pacman' > /dev/null 2>&1; then
    for step in "${CFG_STEPS[@]}"; do
      while read -r name repository extra || [[ -n "$name" ]]; do
        [[ -n "$name" && "$name" != \#* ]] || continue
        if [[ ! "$name" =~ ^[a-zA-Z0-9@._+-]+$ || ! "$repository" =~ ^(core|extra|multilib)$ || -n "$extra" ]]; then
          cfg_problem "Invalid package declaration in $step/packages; use <name> <official-repository>."
          continue
        fi
        if ! resolved="$(cfg_exec pacman -Sp --print-format '%r %n %v' -- "$repository/$name" 2>/dev/null)"; then
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
        if cfg_exec pacman -Q -- "$name" > /dev/null 2>&1; then
          CFG_INSTALLED["$name"]=1
        else
          CFG_INSTALLED["$name"]=0
          missing=1
        fi
      done < "$CAPABILITIES_DIR/$step/packages"
    done
    if (( missing && ! CFG_REFRESH )); then
      upgrades="$(cfg_exec pacman -Qu 2>&1)" || query_status=$?
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
