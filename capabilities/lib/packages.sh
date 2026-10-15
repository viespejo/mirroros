#!/usr/bin/bash
# shellcheck disable=SC2034 # The last read field deliberately consumes unused declaration columns.
cfg_packages_present() {
  local name repository extra
  cfg_context
  while read -r name repository extra || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    [[ "${CFG_INSTALLED[$name]:-0}" == 1 ]] || return 1
  done < "$1"
}

cfg_packages_ensure() {
  local name repository extra mode=-S installed_version
  local missing=()
  cfg_context
  while read -r name repository extra || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    if [[ "${CFG_INSTALLED[$name]:-0}" != 1 ]]; then missing+=("$repository/$name"); fi
  done < "$1"
  if (( ${#missing[@]} )); then
    if (( CFG_REFRESH )) && [[ ! -e "$CFG_OUTPUT/.transaction" ]]; then mode=-Syu; fi
    if [[ "$CONFIGURE_CONTEXT" == target ]]; then
      cfg_run env SNAP_PAC_SKIP=y pacman "$mode" --needed --noconfirm -- "${missing[@]}"
    else
      cfg_run pacman "$mode" --needed --noconfirm -- "${missing[@]}"
    fi
    : > "$CFG_OUTPUT/.transaction"
    cfg_changed
    while read -r name repository extra || [[ -n "$name" ]]; do
      [[ -n "$name" && "$name" != \#* ]] || continue
      installed_version="$(cfg_exec pacman -Q -- "$name")"
      [[ "$installed_version" == "$name "* ]] || return 5
      CFG_INSTALLED["$name"]=1
      # Record the installed version, including after a refresh, not the preflight candidate.
      cfg_package_record "$name" "${installed_version#* }" "$repository"
    done < "$1"
  fi
}
