#!/usr/bin/env bats
# Preparation contracts execute the container script locally with a renderer double, never Docker or mkarchiso.

setup() {
  REPOSITORY_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
  PROFILE="${REPOSITORY_ROOT}/image/archiso"
  WORK="$(mktemp -d)"
  SOURCE="${WORK}/profile"
  LIVE="${WORK}/live-profile"
  local embedded="${SOURCE}/airootfs/usr/local/lib/mirroros/capabilities"
  mkdir -p "$embedded/visual" "$embedded/system" "${WORK}/bin"
  cp -a "${REPOSITORY_ROOT}/capabilities/visual/branding" "$embedded/visual/"
  cp -a "${REPOSITORY_ROOT}/capabilities/system/boot-splash" "$embedded/system/"
  mkdir -p "${SOURCE}/airootfs/usr/local/lib/mirroros/packages"
  printf 'captured Limine payload\n' > "${SOURCE}/airootfs/usr/local/lib/mirroros/packages/packages.json"
  ln -s "${REPOSITORY_ROOT}/tests/capabilities/doubles/rsvg-convert" "${WORK}/bin/rsvg-convert"
  export CFG_TEST_CALLS="${WORK}/renderer.log"
  export PATH="${WORK}/bin:$PATH"
  source "${REPOSITORY_ROOT}/image/builder/lib/container.sh"
  # shellcheck disable=SC2329 # Called indirectly by the sourced preparation function.
  container_run_stage() { fixture_run_stage "$@"; }
  # shellcheck disable=SC2329 # Called indirectly by the sourced preparation function.
  container_set_failure() { fixture_set_failure "$@"; }
  CONTAINER_ID=fixture
  SOURCE_CAPTURE_EMBEDDED_ISO_PATH=/usr/local/lib/mirroros
}

teardown() {
  rm -rf -- "$WORK"
}

source_identity() {
  (cd "$SOURCE" && find . -type f -print0 | sort -z | xargs -0 sha256sum && find . -printf '%y %m %p %l\n' | sort)
}

# Only replace Docker transport and its absolute profile arguments; execute the production script unchanged.
fixture_run_stage() {
  [[ "$1" == live-splash-preparation && "$2" == 120 && "$3" == docker && "$4" == exec && "$5" == fixture ]] || {
    printf 'Unexpected stage transport: %s\n' "$*" >&2; return 97;
  }
  local -a command=("${@:6}")
  [[ "${command[6]}" == /profile && "${command[7]}" == /live-profile ]] || {
    printf 'Unexpected profile arguments: %s\n' "${command[*]}" >&2; return 97;
  }
  command[6]="$SOURCE"
  command[7]="$LIVE"
  "${command[@]}"
}

fixture_set_failure() {
  printf '%s %s %s\n' "$@" > "${WORK}/failure"
}

@test "live preparation preserves captured inputs and copies the exact shared theme and validated branding" {
  local before
  before="$(source_identity)"
  export CFG_TEST_RSVG_VERSION_DETAILS=1
  run container_prepare_live_splash
  [ "$status" -eq 0 ]
  [ "$(source_identity)" = "$before" ]
  [ ! -e "${SOURCE}/airootfs/usr/share" ]
  local branding="${LIVE}/airootfs/usr/share/mirroros/branding"
  local snapshot="${SOURCE}/airootfs/usr/local/lib/mirroros/capabilities"
  local file
  for file in mirroros.plymouth mirroros.script; do
    cmp "${snapshot}/system/boot-splash/plymouth/$file" "${LIVE}/airootfs/usr/share/plymouth/themes/mirroros/$file"
  done
  cmp "${snapshot}/system/boot-splash/plymouth/plymouthd.conf" "${LIVE}/airootfs/etc/plymouth/plymouthd.conf"
  cmp "${snapshot}/visual/branding/mirroros-symbol.svg" "$branding/mirroros-symbol.svg"
  cmp "${SOURCE}/airootfs/usr/local/lib/mirroros/packages/packages.json" "${LIVE}/airootfs/usr/local/lib/mirroros/packages/packages.json"
  local identity
  identity="$(grep '^render ' "$branding/.mirroros-manifest")"
  bash "${snapshot}/visual/branding/install-assets" check "${snapshot}/visual/branding/mirroros-wordmark.svg" "$branding" "${identity#render }"
  grep -Fxq 'rsvg-convert --width 320 --height 320' "$CFG_TEST_CALLS"
}

@test "failed symbol rendering leaves captured inputs intact and fails the preparation stage" {
  local before
  before="$(source_identity)"
  export CFG_TEST_RSVG_SYMBOL_FAIL=1
  run container_prepare_live_splash
  [ "$status" -eq 5 ]
  [ "$(source_identity)" = "$before" ]
  [ "$(<"${WORK}/failure")" = 'live-splash-preparation 5 1' ]
  [ ! -e "${LIVE}/airootfs/usr/share/mirroros/branding" ]
  [ ! -e "${LIVE}/airootfs/etc/plymouth/plymouthd.conf" ]
}

@test "invalid raster dimensions are rejected by shared branding validation" {
  export CFG_TEST_RSVG_SYMBOL_WIDTH=319
  run container_prepare_live_splash
  [ "$status" -eq 5 ]
  [[ "$output" == *'expected 320x320'* ]]
  [ ! -e "${LIVE}/airootfs/usr/share/mirroros/branding" ]
  [ ! -e "${LIVE}/airootfs/etc/plymouth/plymouthd.conf" ]
}

@test "missing captured theme fails preparation without modifying its source" {
  rm "${SOURCE}/airootfs/usr/local/lib/mirroros/capabilities/system/boot-splash/plymouth/mirroros.script"
  local before
  before="$(source_identity)"
  run container_prepare_live_splash
  [ "$status" -eq 5 ]
  [ "$(source_identity)" = "$before" ]
  [ ! -e "${LIVE}/airootfs/etc/plymouth/plymouthd.conf" ]
}

@test "normal live paths add quiet and splash exactly once without changing boot editor or startup" {
  grep -Fxq plymouth "${PROFILE}/packages.x86_64"
  local file line word
  for file in efiboot/loader/entries/01-archiso-linux.conf grub/grub.cfg grub/loopback.cfg; do
    line="$(grep -E '^(options |[[:space:]]+linux /%INSTALL_DIR%)' "${PROFILE}/${file}")"
    for word in quiet splash; do
      [ "$(printf '%s\n' "$line" | tr ' ' '\n' | grep -cx "$word")" -eq 1 ]
    done
  done
  if grep -Eq '^editor[[:space:]]' "${PROFILE}/efiboot/loader/loader.conf"; then return 1; fi
  grep -Fq '/usr/local/lib/mirroros/install/confirmation/live-startup' "${PROFILE}/airootfs/root/.zlogin"
  grep -Fq 'target=/profile,readonly' "${REPOSITORY_ROOT}/image/builder/lib/container.sh"
  [ ! -e "${PROFILE}/airootfs/usr/share/mirroros/branding/mirroros-symbol.png" ]
}
