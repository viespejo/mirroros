#!/usr/bin/env bats
# Contract for the live-console integration of the guided installer: automatic welcome gating, permissions,
# packages, and unchanged behavior of unrelated startup. No real console or assistant is used.

REPOSITORY_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
STARTUP="${REPOSITORY_ROOT}/install/confirmation/live-startup"
AIROOTFS="${REPOSITORY_ROOT}/image/archiso/airootfs"
PROFILEDEF="${REPOSITORY_ROOT}/image/archiso/profiledef.sh"

setup() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros startup.XXXXXX")"
  DOUBLE_BIN="${TEST_ROOT}/bin"
  CALL_LOG="${TEST_ROOT}/calls.log"
  mkdir -p "$DOUBLE_BIN"
  : > "$CALL_LOG"
}

teardown() {
  rm -rf -- "$TEST_ROOT"
}

# make_double <name> <body>: a PATH double that logs its name and runs the body.
make_double() {
  printf '#!/usr/bin/bash\n%s\n' "$2" > "${DOUBLE_BIN}/$1"
  chmod 755 "${DOUBLE_BIN}/$1"
}

# run_startup <tty-name> <seed-label-or-empty> <assistant-status>: run the helper under a real pty.
run_startup() {
  make_double tty "echo $1"
  make_double blkid "[[ \"\$2\" == '$2' && -n '$2' ]]"
  make_double mirroros-install "echo assistant >> '${CALL_LOG}'; exit $3"
  STARTUP_STATUS=0
  PATH="${DOUBLE_BIN}:${PATH}" script -qefc "$STARTUP" /dev/null >/dev/null 2>&1 || STARTUP_STATUS=$?
}

@test "startup opens the assistant on tty1 and returns zero whatever the assistant status" {
  run_startup /dev/tty1 '' 3
  [ "$STARTUP_STATUS" -eq 0 ]
  [ "$(grep -c assistant "$CALL_LOG")" -eq 1 ]
}

@test "startup does nothing on other consoles" {
  run_startup /dev/tty2 '' 0
  [ "$STARTUP_STATUS" -eq 0 ]
  [ ! -s "$CALL_LOG" ]
  run_startup /dev/pts/0 '' 0
  [ ! -s "$CALL_LOG" ]
}

@test "startup does nothing without an interactive terminal" {
  make_double tty "echo /dev/tty1"
  make_double blkid "exit 1"
  make_double mirroros-install "echo assistant >> '${CALL_LOG}'"
  run env PATH="${DOUBLE_BIN}:${PATH}" "$STARTUP" < /dev/null
  [ "$status" -eq 0 ]
  [ ! -s "$CALL_LOG" ]
}

@test "startup is suppressed only by the read-only qualification seed medium" {
  run_startup /dev/tty1 cidata 0
  [ ! -s "$CALL_LOG" ]
  run_startup /dev/tty1 CIDATA 0
  [ ! -s "$CALL_LOG" ]
  run_startup /dev/tty1 other 0
  [ "$(grep -c assistant "$CALL_LOG")" -eq 1 ]
}

@test "startup defines no bypass options and is not setuid" {
  ! grep -Eq -- '--(yes|force|skip|no-tty|assume)' "$STARTUP"
  grep -Fq 'mirroros-install || true' "$STARTUP"
  [ ! -u "$STARTUP" ]
  [ -x "$STARTUP" ]
  bash -n "$STARTUP"
}

@test "the root login path hooks the helper after the existing automated script" {
  local zlogin="${AIROOTFS}/root/.zlogin"
  grep -Fq '~/.automated_script.sh' "$zlogin"
  grep -Fq '/usr/local/lib/mirroros/install/confirmation/live-startup' "$zlogin"
  [ "$(grep -n '~/.automated_script.sh' "$zlogin" | cut -d: -f1)" -lt \
    "$(grep -n 'live-startup' "$zlogin" | head -1 | cut -d: -f1)" ]
  ! grep -Eq 'accessibility=|SINGLE_LINE_ZLE' "$zlogin"
}

@test "profile permissions list every executable entry point as 0:0:755 and add no setuid" {
  local path
  while IFS= read -r path; do
    path="${path#"${REPOSITORY_ROOT}/"}"
    grep -Fq "[\"/usr/local/lib/mirroros/${path}\"]=\"0:0:755\"" "$PROFILEDEF"
  done < <(find "${REPOSITORY_ROOT}/operations/install" "${REPOSITORY_ROOT}/operations/configure" \
    "${REPOSITORY_ROOT}/install" "${REPOSITORY_ROOT}/hardware/discovery" "${REPOSITORY_ROOT}/hardware/rules" \
    "${REPOSITORY_ROOT}/targets" "${REPOSITORY_ROOT}/capabilities" -type f -perm /111)
  ! grep -Eq '"[0-9]+:[0-9]+:[4-7][0-7]{3}"' "$PROFILEDEF"
  [ "$(readlink "${AIROOTFS}/usr/local/bin/mirroros-install")" = /usr/local/lib/mirroros/operations/install ]
}

@test "the package list has exactly one gum line and no jq" {
  [ "$(grep -c -x 'gum' "${REPOSITORY_ROOT}/image/archiso/packages.x86_64")" -eq 1 ]
  ! grep -Eq '^jq$' "${REPOSITORY_ROOT}/image/archiso/packages.x86_64"
}

@test "the installed memory policy is not live image content" {
  ! grep -Eq '^zram-generator$' "${REPOSITORY_ROOT}/image/archiso/packages.x86_64"
  [ ! -e "${AIROOTFS}/usr/lib/systemd/zram-generator.conf.d" ]
  [ ! -e "${AIROOTFS}/usr/lib/sysctl.d/60-mirroros-memory.conf" ]
  [ ! -e "${AIROOTFS}/etc/systemd/zram-generator.conf" ]
  ! grep -rq 'zswap' "${REPOSITORY_ROOT}/image/archiso" --include='*.cfg' --include='*.conf' --include='profiledef.sh'
  [ -f "${REPOSITORY_ROOT}/install/plan/assets/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf" ]
  [ -f "${REPOSITORY_ROOT}/install/plan/assets/usr/lib/sysctl.d/60-mirroros-memory.conf" ]
}

@test "the console keeps the reference kernel-default font and the live image sets no font" {
  [ ! -e "${AIROOTFS}/etc/vconsole.conf" ]
  ! grep -rq 'FONT=' "${AIROOTFS}/etc"
}

@test "automatic time synchronization stays enabled" {
  local wants="${AIROOTFS}/etc/systemd/system/sysinit.target.wants"
  [ "$(readlink "${wants}/systemd-timesyncd.service")" = /usr/lib/systemd/system/systemd-timesyncd.service ]
  [ "$(readlink "${wants}/systemd-time-wait-sync.service")" = /usr/lib/systemd/system/systemd-time-wait-sync.service ]
}

@test "only tty1 has an autologin override and other consoles keep the default login" {
  local overrides
  overrides="$(find "${AIROOTFS}/etc/systemd/system" -maxdepth 1 -name 'getty@*' -o -maxdepth 1 -name 'serial-getty@*')"
  [ "$overrides" = "${AIROOTFS}/etc/systemd/system/getty@tty1.service.d" ]
}

@test "no prototype or Omarchy configurator is referenced at runtime" {
  ! grep -rEq --exclude='*.md' \
    '^[[:space:]]*(source|\.|exec|import|require)\b.*(tmp/mirroros-ux-demo|prototypes/frontend|/root/configurator)' \
    "${REPOSITORY_ROOT}/install/confirmation" "${REPOSITORY_ROOT}/operations/install" "${AIROOTFS}/root"
}
