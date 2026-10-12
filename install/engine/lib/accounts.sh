#!/usr/bin/bash
# shellcheck disable=SC2034 # LAST_ARGV and LAST_STATUS are read by stage_fail in common.sh.
# Account operations of the installation engine. The password reaches the target only on the stdin of
# chpasswd inside the chroot, through a pipe fed by the printf builtin; it is never in argv, in the
# environment, in a file, or in engine.log, and the log names the command only.

# Sets the password of one account. The logged command line never shows the input.
set_account_password() {
  local account="$1"
  LAST_ARGV=(arch-chroot "$TARGET" chpasswd)
  printf '$ arch-chroot %s chpasswd (password input withheld)\n' "$TARGET" >> "$ENGINE_LOG"
  printf '%s:%s\n' "$account" "$PASSWORD" | arch-chroot "$TARGET" chpasswd >> "$ENGINE_LOG" 2>&1 3>&- 4>&- || {
    LAST_STATUS=$?
    stage_fail
  }
}

# The shadow hash field of an account in the target.
shadow_field() {
  awk -F: -v account="$1" '$1 == account { print $2; exit }' "${TARGET}/etc/shadow"
}

op_create_user() {
  local name groups=() shell group joined passwd_line hash
  name="$(param user_name)"
  shell="$(param shell)"
  param_lines groups groups
  [[ "$name" =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || check_fail 'the user name is not valid'
  [[ "$shell" =~ ^[a-z]+$ ]] || check_fail 'the shell is not valid'
  joined="$(join_by_comma "${groups[@]}")"
  chroot_run useradd --create-home --groups "$joined" --shell "/usr/bin/${shell}" "$name"
  set_account_password "$name"
  passwd_line="$(grep -- "^${name}:" "${TARGET}/etc/passwd" || true)"
  [[ "$passwd_line" == *":/usr/bin/${shell}" ]] || check_fail 'the user entry has not the planned shell'
  for group in "${groups[@]}"; do
    grep -qE -- "^${group}:.*[:,]${name}(,|\$)" "${TARGET}/etc/group" || check_fail "the user is not in the group ${group}"
  done
  hash="$(shadow_field "$name")"
  [[ -n "$hash" && "$hash" != '!'* && "$hash" != '*'* ]] || check_fail 'the user has no password entry'
}

op_configure_root_account() {
  local mode hash
  mode="$(param mode)"
  case "$mode" in
    locked)
      chroot_run passwd -l root
      hash="$(shadow_field root)"
      [[ "$hash" == '!'* ]] || check_fail 'the root account is not locked'
      ;;
    password)
      set_account_password root
      hash="$(shadow_field root)"
      [[ -n "$hash" && "$hash" != '!'* && "$hash" != '*'* ]] || check_fail 'the root account has no password entry'
      ;;
    *) check_fail "the root account mode ${mode} is not valid" ;;
  esac
}
