load builder-support

AUR_COMMIT_A='94ffde9c60808595b287edf9d4219da202a85a7a'
UPSTREAM_COMMIT_A='35dab4b732861f5e8d307a1a7873856a877913aa'

setup() {
  builder_setup
  AUR_SCRIPT="${BUILDER_TEST_SOURCE_ROOT}/image/builder/lib/aur-build.sh"
  AUR_DOUBLES="${BUILDER_TEST_ROOT}/aur doubles"
  AUR_CALLS="${BUILDER_TEST_ROOT}/aur calls.log"
  AUR_ROOT="${BUILDER_TEST_ROOT}/aur build root"
  mkdir -p "$AUR_DOUBLES" "$AUR_ROOT"
  cat > "${AUR_DOUBLES}/git" <<'EOF'
#!/usr/bin/bash
printf 'git %s\n' "$*" >> "${AUR_CALLS:?}"
case "$1" in
  clone)
    mkdir -p -- "${@: -1}"
    printf '%s\n' 'source=("pkg::git+https://example.invalid/pkg.git#tag=1.0.0")' > "${@: -1}/PKGBUILD"
    ;;
  -C)
    if [[ "$3" == 'rev-parse' ]]; then
      if [[ "$2" == */src/* ]]; then
        printf '%s\n' "${AUR_DOUBLE_UPSTREAM_HEAD:-$AUR_EXPECTED_UPSTREAM}"
      else
        printf '%s\n' "${AUR_DOUBLE_AUR_HEAD:-$AUR_EXPECTED_AUR}"
      fi
    fi
    ;;
esac
exit 0
EOF
  cat > "${AUR_DOUBLES}/makepkg" <<'EOF'
#!/usr/bin/bash
printf 'makepkg %s\n' "$*" >> "${AUR_CALLS:?}"
cp -- PKGBUILD "${AUR_CALLS}.pkgbuild"
mkdir -p -- src/pkg
: > src/pkg/.git
printf 'package\n' > "${PKGDEST:?}/limine-test-1.0-1-x86_64.pkg.tar.zst"
exit "${AUR_DOUBLE_MAKEPKG_STATUS:-0}"
EOF
  chmod +x "${AUR_DOUBLES}/git" "${AUR_DOUBLES}/makepkg"
}

teardown() {
  builder_teardown
}

run_as_builder() {
  AUR_CALLS="$AUR_CALLS" \
    AUR_EXPECTED_AUR="$AUR_COMMIT_A" AUR_EXPECTED_UPSTREAM="$UPSTREAM_COMMIT_A" \
    MIRROROS_AUR_BUILD_ROOT="$AUR_ROOT" PATH="${AUR_DOUBLES}:${PATH}" \
    run /usr/bin/bash "$AUR_SCRIPT" --build-as-user limine-test "$AUR_COMMIT_A" "$UPSTREAM_COMMIT_A"
}

@test "an unprivileged build verifies both pins and replaces the movable tag" {
  run_as_builder
  [ "$status" -eq 0 ]
  grep -Fq "git -C ${AUR_ROOT}/aur/limine-test checkout --quiet ${AUR_COMMIT_A}" "$AUR_CALLS"
  grep -Fq "#commit=${UPSTREAM_COMMIT_A}" "${AUR_CALLS}.pkgbuild"
  ! grep -Fq '#tag=' "${AUR_CALLS}.pkgbuild"
  [ -f "${AUR_ROOT}/out/limine-test/limine-test-1.0-1-x86_64.pkg.tar.zst" ]
}

@test "makepkg runs without dependency synchronization" {
  run_as_builder
  [ "$status" -eq 0 ]
  local makepkg_call
  makepkg_call="$(grep '^makepkg ' "$AUR_CALLS")"
  [[ "$makepkg_call" != *'--syncdeps'* && "$makepkg_call" != *' -s'* && "$makepkg_call" != *'--asdeps'* ]]
  [[ "$makepkg_call" == *'--noconfirm'* ]]
}

@test "an AUR commit mismatch fails before makepkg runs" {
  AUR_DOUBLE_AUR_HEAD="$(printf '%040d' 1)" run_as_builder
  [ "$status" -ne 0 ]
  [[ "$output" == *'not at the pinned AUR commit'* ]]
  ! grep -Fq 'makepkg ' "$AUR_CALLS"
}

@test "a build that is not at the pinned upstream commit fails" {
  AUR_DOUBLE_UPSTREAM_HEAD="$(printf '%040d' 2)" run_as_builder
  [ "$status" -ne 0 ]
  [[ "$output" == *'not built from the pinned upstream commit'* ]]
}

@test "a makepkg failure fails the build" {
  AUR_DOUBLE_MAKEPKG_STATUS=7 run_as_builder
  [ "$status" -ne 0 ]
}

@test "the privileged entry point validates every pin and requires root" {
  run /usr/bin/bash "$AUR_SCRIPT" "${BUILDER_TEST_ROOT}/out" 'base-devel,git' 'limine-test:main:abc'
  [ "$status" -ne 0 ]
  [[ "$output" == *'invalid package pin'* ]]
  run /usr/bin/bash "$AUR_SCRIPT" "${BUILDER_TEST_ROOT}/out" 'base-devel,git;reboot' "limine-test:${AUR_COMMIT_A}:${UPSTREAM_COMMIT_A}"
  [ "$status" -ne 0 ]
  [[ "$output" == *'invalid dependency name'* ]]
  run /usr/bin/bash "$AUR_SCRIPT" "${BUILDER_TEST_ROOT}/out" 'base-devel,git'
  [ "$status" -ne 0 ]
  [[ "$output" == *'no package was requested'* ]]
  if [[ "$EUID" -ne 0 ]]; then
    run /usr/bin/bash "$AUR_SCRIPT" "${BUILDER_TEST_ROOT}/out" 'base-devel,git' "limine-test:${AUR_COMMIT_A}:${UPSTREAM_COMMIT_A}"
    [ "$status" -ne 0 ]
    [[ "$output" == *'must run as root'* ]]
  fi
}

@test "the build script grants no sudo access and does not weaken signature verification" {
  ! grep -Eq 'sudoers|NOPASSWD|SigLevel|--syncdeps|--nodeps|--skippgpcheck|--skipchecksums|--skipinteg' "$AUR_SCRIPT"
  grep -Fq 'runuser -u "$BUILD_USER"' "$AUR_SCRIPT"
}

@test "the Limine stage runs before mkarchiso and records the pinned packages" {
  builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 0 ]
  local stage_line
  local build_line
  stage_line="$(grep -n 'mirroros-aur-build /var/tmp/mirroros-limine-packages' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  build_line="$(grep -n 'mkarchiso -v' "$BUILDER_CALL_LOG" | cut -d: -f1)"
  [ -n "$stage_line" ]
  [ "$stage_line" -lt "$build_line" ]
  grep -Fq 'base-devel,git,gradle' "$BUILDER_CALL_LOG"
  grep -Fq ":${AUR_COMMIT_A}:${UPSTREAM_COMMIT_A}" "$BUILDER_CALL_LOG"
  local bundle
  bundle="$(find "${BUILDER_REPOSITORY_ROOT}/dist" -mindepth 1 -maxdepth 1 -type d -print | sort | tail -n 1)"
  [ -f "${bundle}/artifact-metadata.json" ]
  run node --input-type=module -e "
    import { readFileSync } from 'node:fs';
    const metadata = JSON.parse(readFileSync(process.argv[1], 'utf8'));
    const names = metadata.prebuilt_packages.packages.map(entry => entry.name).join(',');
    process.stdout.write(names + ' ' + metadata.prebuilt_packages.manifest_path);
  " "${bundle}/artifact-metadata.json"
  [ "$status" -eq 0 ]
  [ "$output" = 'limine-mkinitcpio-hook,limine-snapper-sync /usr/local/lib/mirroros/packages/packages.json' ]
}

@test "a Limine build failure fails the whole build without running mkarchiso" {
  BUILDER_LIMINE_STATUS=1 builder_invoke
  [ "$BUILDER_COMMAND_STATUS" -eq 5 ]
  ! grep -Fq 'mkarchiso -v' "$BUILDER_CALL_LOG"
  [ -z "$(find "${BUILDER_REPOSITORY_ROOT}/dist" -name artifact-metadata.json -print 2>/dev/null)" ]
}

@test "built packages are never tracked by Git" {
  run git -C "$BUILDER_TEST_SOURCE_ROOT" ls-files -- 'image/archiso/airootfs/usr/local/lib/mirroros/packages' '*.pkg.tar.zst'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
