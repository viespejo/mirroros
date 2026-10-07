#!/usr/bin/bash
# Pinned AUR build recipe for btrfs-limine (Story 2.1, Track 2). Non-production.
# Runs as an unprivileged user inside the target chroot (see stage.sh). Builds the two Limine
# snapshot tools reviewed in README.md ("Limine snapshot tooling: provenance review"), each pinned
# twice: the AUR packaging commit is checked out, and the movable #tag= of the PKGBUILD source is
# replaced by the reviewed upstream #commit=. Packages land in ${MIRROROS_BUILD_DIR}/out.
set -euo pipefail

BUILD_DIR="${MIRROROS_BUILD_DIR:?}"

# Arguments: AUR package name, AUR commit, upstream commit.
build_package() {
  local name="$1"
  local aur_commit="$2"
  local upstream_commit="$3"
  local directory="${BUILD_DIR}/aur/${name}"

  git clone --quiet "https://aur.archlinux.org/${name}.git" "$directory"
  git -C "$directory" checkout --quiet "$aur_commit"
  if [[ "$(git -C "$directory" rev-parse HEAD)" != "$aur_commit" ]]; then
    printf 'build: %s is not at the pinned AUR commit\n' "$name" >&2
    return 1
  fi
  sed -i -E "s|#tag=[^\"' )]+|#commit=${upstream_commit}|" "${directory}/PKGBUILD"
  if ! grep -q "#commit=${upstream_commit}" "${directory}/PKGBUILD"; then
    printf 'build: %s PKGBUILD does not use the pinned upstream commit\n' "$name" >&2
    return 1
  fi
  printf 'build: %s at AUR %s, upstream %s\n' "$name" "$aur_commit" "$upstream_commit"
  (cd -- "$directory" && PKGDEST="${BUILD_DIR}/out" makepkg --syncdeps --noconfirm --needed)
}

mkdir -p -- "${BUILD_DIR}/aur" "${BUILD_DIR}/out"
build_package limine-mkinitcpio-hook 94ffde9c60808595b287edf9d4219da202a85a7a 35dab4b732861f5e8d307a1a7873856a877913aa
build_package limine-snapper-sync b3c82aded52032687a76922f2dee9497600818f2 b4c0da2d4532a993809219f9e5d51a1fa85fcb93
