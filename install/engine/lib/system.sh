#!/usr/bin/bash
# System configuration operations of the installation engine: the hash-checked configuration assets, locale,
# time, console, hostname, sudo, sysrq, pacman options, and services. Values come from the plan's parameters
# and from the engine constants recorded below; no mutable source is read.

# The allowlisted assets (the same fixed paths as install/plan/configuration-assets.mjs).
declare -A ASSET_SOURCE=(
  [configure_zram]='usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf'
  [configure_memory_reclaim]='usr/lib/sysctl.d/60-mirroros-memory.conf'
)

copy_asset() {
  local source destination expected actual
  source="${CODE_ROOT}/install/plan/assets/${ASSET_SOURCE[$CURRENT_OP]}"
  destination="$(param destination)"
  expected="$(param source_sha256)"
  [[ "$destination" == "/${ASSET_SOURCE[$CURRENT_OP]}" ]] || asset_fail "The destination of ${CURRENT_OP} is not the allowlisted one."
  [[ -r "$source" ]] || asset_fail "The configuration asset of ${CURRENT_OP} is missing."
  actual="$(sha256sum -- "$source")"
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || asset_fail "The configuration asset of ${CURRENT_OP} does not match the hash of the plan."
  put_file 0644 "$destination" < "$source"
  actual="$(sha256sum -- "${TARGET}${destination}")"
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || check_fail "the delivered ${CURRENT_OP} file differs from the plan hash"
}

op_configure_zram() {
  copy_asset
}

op_configure_memory_reclaim() {
  copy_asset
}

op_configure_locale_time_console() {
  local locales=() locale category keymap timezone link
  param_lines locales locales
  for locale in "${locales[@]}"; do
    [[ "$locale" =~ ^[A-Za-z_]+\.UTF-8$ ]] || check_fail "the locale ${locale} is not valid"
    # The shipped locale.gen keeps trailing blanks on its commented entries, so the comparison ignores them.
    awk -v wanted="${locale} UTF-8" '{ line = $0; sub(/[[:space:]]+$/, "", line) } line == "#" wanted { print wanted; next } { print }' "${TARGET}/etc/locale.gen" \
      | put_file 0644 /etc/locale.gen
    grep -q -- "^${locale} UTF-8\$" "${TARGET}/etc/locale.gen" || check_fail "the locale ${locale} is not enabled in locale.gen"
  done
  chroot_run locale-gen
  {
    printf 'LANG=%s\n' "$(param locale_categories.LANG)"
    for category in LC_TIME LC_NUMERIC LC_MONETARY LC_MEASUREMENT; do
      printf '%s=%s\n' "$category" "$(param "locale_categories.${category}")"
    done
  } | put_file 0644 /etc/locale.conf
  keymap="$(param console_keymap)"
  [[ "$keymap" =~ ^[A-Za-z0-9_.+-]+$ ]] || check_fail 'the console keymap is not valid'
  printf 'KEYMAP=%s\n' "$keymap" | put_file 0644 /etc/vconsole.conf
  timezone="$(param timezone)"
  [[ "$timezone" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] || check_fail 'the time zone is not valid'
  ln -sf -- "/usr/share/zoneinfo/${timezone}" "${TARGET}/etc/localtime"
  [[ "$(param hardware_clock)" == utc ]] || check_fail 'the hardware clock is not utc'
  chroot_run hwclock --systohc
  grep -q -- "^LANG=$(param lang)\$" "${TARGET}/etc/locale.conf" || check_fail 'locale.conf does not hold the planned language'
  grep -q -- "^KEYMAP=${keymap}\$" "${TARGET}/etc/vconsole.conf" || check_fail 'vconsole.conf does not hold the planned keymap'
  link="$(readlink -- "${TARGET}/etc/localtime")"
  [[ "$link" == "/usr/share/zoneinfo/${timezone}" ]] || check_fail 'the time zone link differs from the plan'
}

op_configure_hostname_network() {
  local hostname
  hostname="$(param hostname)"
  [[ "$hostname" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || check_fail 'the hostname is not valid'
  printf '%s\n' "$hostname" | put_file 0644 /etc/hostname
  [[ "$(< "${TARGET}/etc/hostname")" == "$hostname" ]] || check_fail 'the hostname file differs from the plan'
}

# Replaces any commented or active line of one pacman option inside [options] and places the planned line first.
set_pacman_option() {
  local option="$1" key="${1%% *}" file="${TARGET}/etc/pacman.conf"
  [[ "$key" =~ ^[A-Za-z]+$ ]] || check_fail "the pacman option ${option} is not valid"
  awk -v key="$key" -v line="$option" '
    /^\[/ { inopt = ($0 == "[options]") }
    inopt && $0 ~ ("^#?[ \t]*" key "([ \t]*=.*)?[ \t]*$") { next }
    { print }
    $0 == "[options]" { print line }
  ' "$file" | put_file 0644 /etc/pacman.conf
}

op_configure_sudo_sysrq_pacman() {
  local options=() option sudoers sysrq
  sudoers="$(param sudoers)"
  sysrq="$(param sysrq)"
  [[ "$sudoers" =~ ^%[a-z_][a-z0-9_-]*\ ALL=\(ALL:ALL\)\ ALL$ ]] || check_fail 'the sudoers line is not the allowed form'
  [[ "$sysrq" =~ ^kernel\.sysrq\ =\ [0-9]+$ ]] || check_fail 'the sysrq line is not valid'
  printf '%s\n' "$sudoers" | put_file 0440 /etc/sudoers.d/10-mirroros-wheel
  chroot_run visudo -cf /etc/sudoers.d/10-mirroros-wheel
  printf '%s\n' "$sysrq" | put_file 0644 /etc/sysctl.d/90-sysrq.conf
  param_lines pacman_options options
  for option in "${options[@]}"; do
    set_pacman_option "$option"
  done
  for option in "${options[@]}"; do
    grep -qxF -- "$option" "${TARGET}/etc/pacman.conf" || check_fail "the pacman option ${option} is not active in the target"
  done
}

# Services of the plan plus the engine constants of the storage option.
op_enable_services() {
  local services=() service extra=()
  param_lines services services
  case "$STORAGE_OPTION" in
    ext4-systemd-boot) extra=(systemd-boot-update.service) ;;
    *) check_fail "no service set is defined for ${STORAGE_OPTION}" ;;
  esac
  record_constant enable_services.option_services "${extra[*]}"
  for service in "${services[@]}" "${extra[@]}"; do
    [[ "$service" =~ ^[A-Za-z0-9@._-]+$ ]] || check_fail "the service name ${service} is not valid"
    chroot_run systemctl enable "$service"
  done
  for service in "${services[@]}" "${extra[@]}"; do
    chroot_run systemctl is-enabled "$service"
  done
}
