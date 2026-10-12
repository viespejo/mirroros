#!/usr/bin/bash
# Pinned AUR build of the Limine snapshot tools. Runs as root inside the verified build container,
# before mkarchiso (see container.sh). Written for MirrorOS; the reviewed provenance is recorded in
# docs/adr/0003-storage-and-recovery-baseline.md and image/builder/aur/limine-tools.json.
#
# Usage: aur-build.sh OUTPUT_DIR MAKEDEPENDS_CSV NAME:AUR_COMMIT:UPSTREAM_COMMIT...
#
# Each package is pinned twice: the AUR packaging commit is checked out and verified, and the
# movable #tag= of the PKGBUILD source is replaced by the reviewed upstream #commit= and verified.
# makepkg runs as an unprivileged user without sudoers and without --syncdeps; every dependency is
# installed by this script as root before the build. OUTPUT_DIR receives the built packages and
# packages.tsv (name, version, file, AUR commit, upstream commit; tab separated).
set -Eeuo pipefail

BUILD_USER='mirrorosbuild'
BUILD_ROOT="${MIRROROS_AUR_BUILD_ROOT:-/var/tmp/mirroros-limine-build}"

fail() {
  printf 'aur-build: %s\n' "$1" >&2
  exit 1
}

# Runs as the unprivileged build user: AUR_NAME AUR_COMMIT UPSTREAM_COMMIT.
build_as_user() {
  local name="$1"
  local aur_commit="$2"
  local upstream_commit="$3"
  local directory="${BUILD_ROOT}/aur/${name}"
  local source_directory
  local pinned=0

  git clone --quiet "https://aur.archlinux.org/${name}.git" "$directory"
  git -C "$directory" checkout --quiet "$aur_commit"
  [[ "$(git -C "$directory" rev-parse HEAD)" == "$aur_commit" ]] || fail "${name} is not at the pinned AUR commit"
  sed -i -E "s|#tag=[^\"' )]+|#commit=${upstream_commit}|" "${directory}/PKGBUILD"
  grep -q "#commit=${upstream_commit}" "${directory}/PKGBUILD" || fail "${name} PKGBUILD does not use the pinned upstream commit"
  if grep -q '#tag=' "${directory}/PKGBUILD"; then
    fail "${name} PKGBUILD still contains a movable tag source"
  fi
  printf 'aur-build: %s at AUR %s, upstream %s\n' "$name" "$aur_commit" "$upstream_commit"
  mkdir -p -- "${BUILD_ROOT}/out/${name}"
  (cd -- "$directory" && PKGDEST="${BUILD_ROOT}/out/${name}" makepkg --noconfirm --noprogressbar)
  for source_directory in "${directory}"/src/*/; do
    if [[ -e "${source_directory}.git" ]] && \
      [[ "$(git -C "$source_directory" rev-parse HEAD)" == "$upstream_commit" ]]; then
      pinned=1
    fi
  done
  [[ "$pinned" -eq 1 ]] || fail "${name} was not built from the pinned upstream commit"
}

main() {
  local output_directory="${1:?output directory}"
  local makedepends_csv="${2:?makedepends}"
  local entry
  local name
  local aur_commit
  local upstream_commit
  local package_file
  local package_version
  local -a makedepends=()
  local -a package_files=()

  shift 2
  [[ "$#" -gt 0 ]] || fail 'no package was requested'
  IFS=',' read -r -a makedepends <<< "$makedepends_csv"
  for entry in "${makedepends[@]}"; do
    [[ "$entry" =~ ^[a-z0-9@._+-]+$ ]] || fail "invalid dependency name: ${entry}"
  done
  for entry in "$@"; do
    IFS=':' read -r name aur_commit upstream_commit <<< "$entry"
    [[ "$name" =~ ^[a-z0-9@._+-]+$ && "$aur_commit" =~ ^[a-f0-9]{40}$ && "$upstream_commit" =~ ^[a-f0-9]{40}$ ]] || \
      fail "invalid package pin: ${entry}"
  done
  [[ "$EUID" -eq 0 ]] || fail 'must run as root to install build dependencies'

  pacman -S --needed --noconfirm "${makedepends[@]}"
  if ! id -u "$BUILD_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /usr/bin/bash --user-group "$BUILD_USER"
  fi
  rm -rf -- "$BUILD_ROOT" "$output_directory"
  install -d -m 0755 -o "$BUILD_USER" -g "$BUILD_USER" -- "$BUILD_ROOT" "${BUILD_ROOT}/aur" "${BUILD_ROOT}/out"
  install -d -m 0755 -- "$output_directory"

  for entry in "$@"; do
    IFS=':' read -r name aur_commit upstream_commit <<< "$entry"
    runuser -u "$BUILD_USER" -- /usr/bin/bash "$0" --build-as-user "$name" "$aur_commit" "$upstream_commit"
    mapfile -t package_files < <(find "${BUILD_ROOT}/out/${name}" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print)
    [[ "${#package_files[@]}" -eq 1 ]] || fail "${name} did not produce exactly one package"
    package_file="${package_files[0]}"
    package_version="$(pacman -Qp -- "$package_file")"
    [[ "$package_version" == "${name} "* ]] || fail "${name} produced an unexpected package: ${package_version}"
    package_version="${package_version#"${name} "}"
    install -m 0644 -- "$package_file" "${output_directory}/${package_file##*/}"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$package_version" "${package_file##*/}" "$aur_commit" "$upstream_commit" >> "${output_directory}/packages.tsv"
  done
}

if [[ "${1:-}" == '--build-as-user' ]]; then
  shift
  build_as_user "$@"
else
  main "$@"
fi
