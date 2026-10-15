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
