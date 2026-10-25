#!/usr/bin/bash
cfg_unit_enabled() {
  cfg_context
  cfg_exec systemctl is-enabled --quiet "$1"
}

cfg_unit_enable() {
  cfg_context
  if ! cfg_unit_enabled "$1"; then
    cfg_run systemctl enable "$1"
    cfg_changed
  fi
}

# Enables a user unit for the selected user only, offline: the user creates the same wants link that
# `systemctl --user enable` would, so no user manager or bus is needed (also inside arch-chroot), nothing is started
# and no other user is affected. A user's own unit, mask or different link is user-owned and left untouched.
# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_unit_enable() {
  local unit="$1" path="$2" target="$3" result
  cfg_context
  [[ "$unit" =~ ^[a-z0-9@._-]+\.service$ && "$path" =~ ^/[a-z0-9@._/-]+$ && "$path" != *..* &&
    "$target" =~ ^[a-z0-9._-]+\.target$ ]] || exit 6
  result="$(cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    set -Eeuo pipefail
    unit=$1 path=$2 target=$3
    dir="$HOME/.config/systemd/user"
    link="$dir/$target.wants/$unit"
    if [[ -e "$dir/$unit" || -L "$dir/$unit" ]]; then
      printf "user-owned: .config/systemd/user/%s; left untouched\n" "$unit"
      exit 0
    fi
    if [[ -L "$link" && "$(readlink -- "$link")" == "$path" ]]; then exit 0; fi
    if [[ -e "$link" || -L "$link" ]]; then
      printf "user-owned: .config/systemd/user/%s.wants/%s; left untouched\n" "$target" "$unit"
      exit 0
    fi
    mkdir -p -- "$dir/$target.wants"
    ln -s -- "$path" "$link"
    printf "changed\n"
  ' bash "$unit" "$path" "$target")"
  if [[ "$result" == changed ]]; then cfg_changed; elif [[ -n "$result" ]]; then cfg_log "$result"; fi
}

# shellcheck disable=SC2016 # HOME is resolved by the user's Bash, never by root.
cfg_user_unit_enabled() {
  cfg_context
  cfg_exec runuser -u "$TARGET_USER" -- bash -c '
    dir="$HOME/.config/systemd/user"
    [[ -e "$dir/$1" || -L "$dir/$1" || -e "$dir/$2.wants/$1" || -L "$dir/$2.wants/$1" ]]
  ' bash "$1" "$2"
}

cfg_default_target_is() {
  cfg_context
  [[ "$(cfg_exec systemctl get-default)" == "$1" ]]
}

cfg_default_target() {
  cfg_context
  if ! cfg_default_target_is "$1"; then
    cfg_run systemctl set-default "$1"
    cfg_changed
  fi
}

cfg_display_manager_is() {
  local resolved
  cfg_context
  resolved="$(readlink -- "$(cfg_path /etc/systemd/system/display-manager.service)")"
  [[ "${resolved##*/}" == "$1" ]]
}

cfg_only_display_manager() {
  local unit state rest service units
  cfg_context
  units="$(cfg_exec systemctl list-unit-files --type=service --no-legend --no-pager)" || return 1
  # Inspect enabled units by their native display-manager alias, not by a fixed provider list.
  while read -r unit state rest; do
    [[ "$state" == enabled || "$state" == enabled-runtime ]] || continue
    [[ "$unit" != "$1" ]] || continue
    service="$(cfg_exec systemctl cat "$unit")" || return 1
    if grep -Eq '^[[:space:]]*Alias=.*display-manager\.service' <<< "$service"; then return 1; fi
  done <<< "$units"
}
