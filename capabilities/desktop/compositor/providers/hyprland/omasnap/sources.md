# Omasnap provider sources

## Recipe and source

- Upstream: https://github.com/omacom/omasnap, `v1.26.2`, commit
  `6150151846b0ddc2ca8e6b107324de8b0c7240ae` (MIT; bundled fonts OFL-1.1; Lucide assets ISC).
- Recipe: https://github.com/omacom/omarchy-pkgs/blob/c73cd8aa4d12a9b3ad4b8451b153bd36294bc6b1/pkgbuilds/omasnap/PKGBUILD,
  `1.26.2-4`, retaining Tobi Lütke's maintainer line.
- MirrorOS package: `omasnap 1.26.2-4.4`, x86_64 only, with the explicitly approved local portal and launcher-name patches below. No Omarchy repository is enabled.
- Archive: `https://github.com/omacom/omasnap/archive/refs/tags/v1.26.2.tar.gz`;
  SHA-256 `e173edd4f2e797273c967513f24c360b6f00733792b9708757a82c39fbc43bf9`.
  Downloaded through GitHub's codeload tag endpoint and verified during Task 2; makepkg verifies it again.
- Reviewed recipe differences: release `4` → `4.4`, remove aarch64, remove `check()` and `checkdepends=('clang')`,
  add the self-contained `prepare()` patch and direct runtime dependency `xdg-desktop-portal`.
  Build/package functions and upstream dependencies are otherwise unchanged. The inherited recipe lists MIT and OFL-1.1;
  upstream CMake also installs Lucide-ISC.txt, alongside Neucha-OFL.txt, JetBrainsMono-OFL.txt and Inter-OFL.txt. DEC-004 accepts relying on upstream's
  [test.yml](https://github.com/omacom/omasnap/blob/6150151846b0ddc2ca8e6b107324de8b0c7240ae/.github/workflows/test.yml)
  rather than installing clang for the local smoke suite. This is not a claim that upstream CI was rerun locally.
- `build-omasnap` follows the owned `desktop/files/build-strata`: user-run makepkg, no `-s` or install flag,
  staging cleanup and package output under `${XDG_CACHE_HOME:-$HOME/.cache}/mirroros/omasnap`.
  `cfg_local_package_ensure` installs with privileges only after building and compares the exact recipe version.

## Launcher application name

At the maintainer's request, release `4.3` changes only `Name=Screenshot` to `Name=Omasnap` in the pinned
upstream `omasnap.desktop`, through the recipe's inline prepare patch. Apps and other desktop-entry consumers
therefore show the application's name without a shell-specific alias or a shadow desktop entry. The desktop id,
Exec, Icon, MIME associations and capture behavior stay unchanged; the neutral screenshot command and descriptive
Capture menu actions are not renamed.

Reference VM observation: `/usr/share/applications/omasnap.desktop` is owned by `omasnap 1.26.2-4.2`, with
SHA-256 `6dc0b0d043d60d2e32c6f6a8b0795cf229794e545d0daad9f6adcf2f9c371805` and `Name=Screenshot`.
The pinned repository tree confirms the source path is `omasnap.desktop`. Release `4.4` additionally inserts
`Keywords=screenshot;capture;screen capture;`, retaining descriptive Apps searches while displaying Omasnap.
The contract compares the prepared entry with that source after the Name substitution and Keywords insertion,
preserving every other field. AppSearch already matches desktop-entry keywords; no shell-specific alias is added.

Validation: all nine provider contracts, nine neutral-command contracts and four theme contracts passed with the
checksum-verified v1.26.2 sources. The VM built release `4.3` unprivileged through build-omasnap; its packaged
entry matched the previous installed entry byte-for-byte except for Name. Installation used pacman in a
maintainer-authenticated tmux window, which closed successfully. The running shell retained the old cached label
until mirroros-shell.service was restarted; afterward its Apps snapshot contained Omasnap and no Screenshot row.
The service remained active. No capture, Open With or Save As interaction was repeated for this label-only change.

Release `4.4` validation: all nine provider contracts passed against the pinned sources, and all eight AppLibrary
regressions passed, including keyword searches derived from the recipe. The VM built the package unprivileged;
its desktop entry differed from installed `4.3` only by the Keywords line. Maintainer-authenticated tmux/pacman
installation completed successfully and the window closed automatically. After an explicit shell restart, a
real-QML probe using installed AppLibrary services and the real desktop catalogue returned Omasnap for `omasnap`,
`screenshot`, `capture` and `screen capture`. The service remained active. No capture or Save As retest was performed.

## Approved Save As portal patch

During the attended campaign, the maintainer explicitly amended DEC-004's no-source-patches boundary after an
isolated prototype succeeded. The portal portion of the inline unified diff in PKGBUILD changes only two pinned source files:

- `src/editor-save-as.cpp`: remove `QFileDialog::DontUseNativeDialog` so Save As can use the native chooser.
- `src/main.cpp`: select `QT_QPA_PLATFORMTHEME=xdgdesktopportal` instead of forced `generic`, updating the related
  comment. Removing the first option alone is insufficient because the application overwrites the environment.

This covers neutral-command, shortcut, menu, launcher, direct terminal and Open With paths without a desktop-entry
override, wrapper shadowing or session-wide Qt setting. An explicit Qt command-line platform-theme override can
still bypass it. The patch is embedded because the existing builder receives only the recipe; `patch -Np1 --fuzz=0`
applies it after the unchanged archive checksum check. No shared helper or privilege boundary changes.

Reference VM package observations (2026-11-17): `pacman -Qo` identifies
`/usr/lib/qt6/plugins/platformthemes/libqxdgdesktopportal.so` as owned by `qt6-base 6.12.0-3`;
`xdg-desktop-portal 1.22.1-2` and `strata-bin 1.2.1-1.1` are installed. The plugin therefore requires no additional
Qt package in that VM; the portal frontend is declared directly. Existing portal routing remains owned by the
provider/files capabilities, not patched here. The maintainer reports the isolated one-line prototype with explicit
`-platformtheme xdgdesktopportal` completed the full Strata Save As cycle without perceptible delay. The final
package's portal patch still requires attended retesting across launch paths, cancellation, focus and overwrite.

## Arch dependency observations

Source: official Arch package search API `https://archlinux.org/packages/search/json/?name=<name>`, queried
2026-11-17 for exact package names, x86_64/any. These are observations, not pins, and no facts come from the host's
installed packages. Configure records actual resolved versions. Local ABI/build and session validation remain
pending the authorized Task 3 reference-VM campaign.

| Package | Observed version | Repository | Purpose |
|---|---|---|---|
| base-devel | 1-2 | core | makepkg toolchain |
| hyprland | 0.57.2-1 | extra | Runtime discovery and compositor |
| layer-shell-qt | 6.8.3-1 | extra | Runtime layer surface |
| libdeflate | 1.26-1 | extra | Runtime compression |
| qt6-base | 6.12.0-5 | extra | Runtime Qt |
| tesseract | 5.5.4-1 | extra | Runtime OCR |
| tesseract-data-eng | 4.1.0-5 | extra | English OCR data |
| wayland | 1.26.0-1 | extra | Runtime Wayland |
| wl-clipboard | 2.3.0-1 | extra | Runtime clipboard |
| xdg-utils | 1.2.1-2 | extra | Runtime Show in folder |
| cmake | 4.5.0-1 | extra | Build |
| ninja | 1.13.2-3 | extra | Build |
| pkgconf | 3.0.11-1 | core | Build |
| wayland-protocols | 1.50-1 | extra | Build |

## Integration and ownership

The neutral `desktop/screenshot` command supervises the backend installed at
`/usr/share/mirroros/compositor/screenshot-backend`. The backend maps window → windows, full → fullscreen,
scroll → --scroll, and --edit → --editor overlay, then execs Omasnap. It requires a writable absolute
`XDG_RUNTIME_DIR` and exports `OMASNAP_RECENT_DIR=$XDG_RUNTIME_DIR/omasnap/recent`, overriding persistent values.
The managed `/etc/environment.d/60-mirroros-omasnap.conf` covers direct launches without a desktop-entry override.
Expansion and inheritance through wrapper, launcher, terminal and Open With must be observed after a fresh login
in Task 3; static contracts alone cannot establish them. A fresh user manager is required after adding the file:
graphical logout alone may retain the old manager while SSH/other sessions remain. A coordinated reboot provided
the new manager in the reference VM. Explicit user environment overrides can bypass policy.

`omasnap.conf` uses an INI semicolon management marker and only `[output] filename = screenshot-{date}_{time}`.
`cfg_user_file` preserves unmarked files and links; those overrides may restore application slugs. Autosave,
copy and XDG Pictures defaults stay upstream-owned. No MIME association or clipboard-history behavior changes.

`screenshot-bindings.lua` adapts the PRINT, SUPER+CTRL+ALT+C and SUPER+CTRL+C choices from Omarchy
`520c3ed969d30b58defe03eb19d603f32b4cb002`, `default/hypr/bindings/utilities.lua` (MIT, David Heinemeier Hansson).
It uses MirrorOSKeys and existing `menu open capture` IPC. With explicit maintainer authorization, Task 2 also
extends `prepare-hyprland` and its focused migration tests to recognize the exact previous clipboard entry point
(SHA-256 `558563b2cbf771e1f399e9233fba2482bb6669e86085391f5bcb113489c62a61`); edited files and links remain preserved. The `hl.layer_rule` follows the Omasnap pinned README:
namespace `^omasnap$`, `no_anim=true`, `animation="none"`, without `no_screen_share`.
A second exact rule for `^mirroros-menu$` uses the same animation settings, adapted from Omarchy's
`default/hypr/apps/omarchy-shell.lua` at the same `520c3ed969d30b58defe03eb19d603f32b4cb002` revision (MIT).
The no-delay reference-VM flow reproduced a partially faded menu in both the selector background and exported
PNG using SUPER+CTRL+C and Enter through the SPICE viewer. Applying this menu-only rule removed the residual in
one repeated Screenshot selector/export check; the maintainer approved adoption. This does not establish repeated
reliability or separately retest annotation. No capture timer or global animation change is introduced.
The package installs the
upstream license; Omarchy's MIT notice remains in `../../../shell/LICENSE.omarchy` relative to the provider.

## Shared theme contract

Both this provider and Strata independently ensure `visual/theme/omarchy-bridge` through `cfg_user_script`.
A conflicting bridge is preserved and fails configure. Omasnap's `src/chrome-theme.cpp` reads the HOME-based
`.local/state/omarchy/current/theme/{colors.toml,shell.toml}`, not XDG_STATE_HOME directly. The bridge follows
MirrorOS's resolved state home. Source SHA-256:
`e80656676dc46e87c8f82534ccd40cf3b7f748e2b337e32b766820adf7b0c835`.

Required valid background/foreground come from popups.background/text or the palette's background/foreground;
without them upstream retains its neutral chrome. Optional fallbacks in v1.26.2:

- popups.background-alpha: 1; light_foreground: foreground; accent: foreground; orange: accent.
- controls.normal/hover-cursor/selected-color: foreground. Fill alpha: 0.04/0.08/0.18.
- controls.normal/hover-cursor/selected-border: corresponding button text color; border alpha: 0.4/0.25/1.
- popups.border → hyprland.active-border → hyprland_active_border → accent; popups.border-alpha: 1.
- hyprland_inactive_border: foreground with alpha 75/255.
- tooltip.background/text/border: background/foreground/foreground; background-alpha: 0.97; border-alpha: 1.

No controls section is added to shell.toml. The focused `omasnap-theme-contract.test.mjs` pins all consumed keys,
source hash and bridge paths. Osaka Jade chrome still requires attended visual review.

## Explicit updates

Do not follow tags implicitly. For each update: state the reason, pin recipe repository revision and source commit,
download and verify the archive, review source and recipe diffs (especially the local portal patch and upstream
chooser/focus lifecycle, CLI, environment, recent source/log persistence, desktop Exec, output metadata/defaults,
theme reader and license installation), rebase or remove the explicit patch as needed, update this record,
and rerun provider plus theme contracts with `MIRROROS_OMASNAP_SOURCE=<new source>`. Revisit declared runtime and
build packages from the VM/current Arch repositories. Repeat only affected live checks; do not claim qualification
from an automated contract. See [screenshots procedure](../../../../../../docs/procedures/screenshots.md).
