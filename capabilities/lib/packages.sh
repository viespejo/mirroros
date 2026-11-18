#!/usr/bin/bash
# shellcheck disable=SC2034 # The last read field deliberately consumes unused declaration columns.
cfg_hyprland_ocr_languages() {
  local locale_file status=0
  locale_file="$(cfg_path /etc/locale.conf)"
  # The installer writes a regular file; do not follow a link out of a target root.
  [[ ! -L "$locale_file" && ( ! -e "$locale_file" || -f "$locale_file" ) ]] || return 1
  if [[ -f "$locale_file" ]]; then
    grep -Eq "^[[:space:]]*(LANG|LC_TIME|LC_NUMERIC|LC_MONETARY|LC_MEASUREMENT)=(es_ES\.UTF-8|\"es_ES\.UTF-8\"|'es_ES\.UTF-8')[[:space:]]*$" \
      "$locale_file" || status=$?
    case "$status" in
      0) printf 'eng+spa\n'; return ;;
      1) ;;
      *) return 1 ;;
    esac
  fi
  printf 'eng\n'
}

cfg_effective_packages() {
  local manifest="$1"
  cat -- "$manifest" || return
  if [[ "$manifest" == "$CAPABILITIES_DIR/desktop/compositor/providers/hyprland/packages" &&
    "${CFG_HYPRLAND_OCR_LANGUAGES:-eng}" == eng+spa ]]; then
    printf '\ntesseract-data-spa extra\n'
  fi
}

cfg_packages_present() {
  local name repository extra effective
  cfg_context
  effective="$(cfg_effective_packages "$1")" || return 1
  while read -r name repository extra || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    [[ "${CFG_INSTALLED[$name]:-0}" == 1 ]] || return 1
  done <<< "$effective"
}

cfg_packages_ensure() {
  local name repository extra mode=-S installed_version effective
  local missing=()
  cfg_context
  effective="$(cfg_effective_packages "$1")" || return 5
  while read -r name repository extra || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    if [[ "${CFG_INSTALLED[$name]:-0}" != 1 ]]; then missing+=("$repository/$name"); fi
  done <<< "$effective"
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
    done <<< "$effective"
  fi
}

# A reviewed local recipe is parsed as data by root, built by the selected user, and only the resulting package is
# installed with privileges. Only an installed version different from the recipe's triggers a build.
cfg_recipe_version() {
  local version release
  version="$(awk -F= '$1 == "pkgver" { print $2; exit }' "$1")" || return 1
  release="$(awk -F= '$1 == "pkgrel" { print $2; exit }' "$1")" || return 1
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ && "$release" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1
  printf '%s-%s\n' "$version" "$release"
}

cfg_local_package_present() {
  local version
  cfg_context
  version="$(cfg_recipe_version "$2")" || return 1
  [[ "$(cfg_exec pacman -Q -- "$1" 2>/dev/null)" == "$1 $version" ]]
}

cfg_local_package_ensure() {
  local name="$1" recipe="$2" builder="$3" version path installed
  cfg_context
  version="$(cfg_recipe_version "$recipe")" || { printf 'Invalid package recipe: %s\n' "$recipe" >&2; exit 6; }
  if ! cfg_local_package_present "$name" "$recipe"; then
    cfg_user_script "$builder" build "$(base64 -w0 -- "$recipe")"
    read -r _ path <<< "$CFG_USER_SCRIPT_RESULT"
    [[ "$path" == /* ]] || { printf 'The package build did not report a package file.\n' >&2; return 5; }
    if [[ "$CONFIGURE_CONTEXT" == target ]]; then
      cfg_run env SNAP_PAC_SKIP=y pacman -U --needed --noconfirm -- "$path"
    else
      cfg_run pacman -U --needed --noconfirm -- "$path"
    fi
    cfg_changed
    installed="$(cfg_exec pacman -Q -- "$name")"
    [[ "$installed" == "$name $version" ]] || return 5
  fi
  cfg_package_record "$name" "$version" local
}

# Build before removing an official package, preserving its protected file and attempting recovery on install failure.
# The builder receives the recipe as base64 plus a base64 tar.gz of its directory for reviewed local sources.
cfg_local_package_replace() {
  local official="$1" name="$2" recipe="$3" builder="$4" protected="$5" version sources path installed checked
  local -a pacman_command=(pacman)
  cfg_context
  version="$(cfg_recipe_version "$recipe")" || { printf 'Invalid package recipe: %s\n' "$recipe" >&2; exit 6; }
  if ! cfg_local_package_present "$name" "$recipe"; then
    sources="$(tar -czf - -C "$(dirname -- "$recipe")" . | base64 -w0)" || return $?
    cfg_user_script "$builder" build "$(base64 -w0 -- "$recipe")" "$sources" || return $?
    read -r _ path <<< "$CFG_USER_SCRIPT_RESULT"
    [[ "$path" == /* ]] || { printf 'The package build did not report a package file.\n' >&2; return 5; }
    if [[ "$CONFIGURE_CONTEXT" == target ]]; then pacman_command=(env SNAP_PAC_SKIP=y pacman); fi
    # A query can resolve a provider; remove only an installed package with the exact official name.
    if installed="$(cfg_exec pacman -Q -- "$official" 2>/dev/null)" && [[ "$installed" == "$official "* ]]; then
      # Backup-file mismatches are printed by -Qkk but do not make its exit status non-zero.
      if ! checked="$(cfg_exec env LC_ALL=C pacman -Qkk -- "$official" 2>&1)" ||
        [[ "$checked" == *"$protected"* || "$checked" == *'no mtree file'* ]]; then
        printf 'Cannot replace %s: %s is modified or could not be verified; left unchanged.\n' "$official" "$protected" >&2
        printf '%s\n' "$checked" >&2
        exit 4
      fi
      cfg_run "${pacman_command[@]}" -Rdd --noconfirm -- "$official" || return $?
    fi
    if ! cfg_run "${pacman_command[@]}" -U --needed --noconfirm -- "$path"; then
      printf 'Local package installation failed; attempting to reinstall %s.\n' "$official" >&2
      if ! cfg_run "${pacman_command[@]}" -S --noconfirm -- "$official"; then
        printf 'Recovery failed: reinstall %s before locking the session.\n' "$official" >&2
      fi
      return 5
    fi
    cfg_changed
    installed="$(cfg_exec pacman -Q -- "$name")" || return $?
    [[ "$installed" == "$name $version" ]] || return 5
  fi
  cfg_package_record "$name" "$version" local
}
