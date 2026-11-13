# File manager source and ownership

Story 4.5 selects [Strata](https://github.com/lgse/strata), a keyboard-first GTK 4 file manager, in place of the
earlier package-only Nautilus placeholder (plan 02-35, DEC-008 and DEC-013). No ADR is required (DEC-022).

## Identity

| Item | Value |
|---|---|
| Release | `v1.2.1` (latest stable on 2026-11-11; release candidates and nightlies are not used) |
| Tag | annotated tag object `9c2cb2fca69969774c9a4b0bbd2b61009a79a6d7`, commit `491e6ba9735e821f9f49910ffd2582076196865c` (`chore: release v1.2.1`) |
| Build commit | `fb7eb0c4ee8bcb681651e56e91031ed95422e8ff`, the archive's `SOURCE_COMMIT` and the tag commit's only parent; the tag commit changes only `Cargo.toml` and `Cargo.lock` |
| Asset | `strata-1.2.1-x86_64-unknown-linux-gnu.tar.gz`, SHA-256 `a63710ce626078ecc107105223680179a4437b8cb9fbce34d74e3d42c80330d0`, matching the release's `.sha256` |
| Attestation | `gh attestation verify --bundle … -R lgse/strata` passed on the host: SLSA v1 provenance signed through `https://token.actions.githubusercontent.com` for `.github/workflows/release.yml@refs/heads/main`, workflow SHA `fb7eb0c4ee8b…`, trigger `workflow_dispatch`, timestamp 2026-11-10T05:39:38Z. The bundle was fetched from the GitHub attestations API because `gh`'s direct query timed out on the host network |
| Recipe base | first-party `packaging/aur/PKGBUILD.in` at the tag commit; `strata-bin` is not published on the AUR |

A local `makepkg -d` build of the recipe from the verified asset produced `/usr/bin/strata` byte-identical to the
archive's binary (SHA-256 `248115869c4042976ab7edd138d498f2ff4530eacbb8cac4bb45a9eeb8582078`).

## Licenses

Strata is MIT. The release binary bundles UnRAR, whose license (`LicenseRef-UnRAR`) forbids using the code to
recreate the RAR compression algorithm; it is accepted as non-free and installed with the package as
`/usr/share/licenses/strata-bin/UnRAR.txt`, beside `LICENSE` and the upstream `THIRD_PARTY_LICENSES.md`. See
[attribution](../../../docs/attribution.md).

## Recipe

`strata/PKGBUILD` is a MirrorOS derivative of the first-party template rendered for the stable channel, built by the
selected user through `build-strata` (adapted from `workflow/tmux/build-sesh`, cache `~/.cache/mirroros/strata`) and
installed by configure with `cfg_local_package_ensure strata-bin`; the source is recorded with `cfg_source_record`.
`makepkg` runs without `-s`, so `packages` declares `base-devel` and the template's runtime `depends`, resolved by
validation before any mutation. Changes from the template:

- x86_64 only, `pkgrel=1.1`; `options=('!strip' '!debug')` and the upstream `depends`/`optdepends` are unchanged;
- the archive's `io.github.lgse.Strata.FileManager1.service` is installed in `/usr/share/dbus-1/services/` instead
  of `/usr/share/strata/`, so the package owns `org.freedesktop.FileManager1`;
- the archive's FileChooser backend files are installed (DEC-003): `portal/strata.portal` as
  `/usr/share/xdg-desktop-portal/portals/strata.portal` and the rendered
  `/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service` with
  `Exec=/usr/bin/strata --portal`. Whether the backend is selected is the Hyprland provider's
  `hyprland-portals.conf`; the evidence-based outcome is `strata;gtk` (see [FileChooser outcome](#filechooser-outcome));
- the archive's `portal/portals.conf`, `udiskie/unlock` and documentation are not installed: portal preferences are
  MirrorOS-owned and no udiskie integration is delivered.

To update, select a new stable tag, verify its asset and attestation, rerender the template, rerun
`tests/capabilities/desktop/files/strata-theme-contract.test.mjs` against the new upstream source, and bump
`pkgver`/`pkgrel` with this record.

## Updates and runtime integrations

The release binary is built with Strata's updater and `STRATA_INTEGRATIONS=runtime`. The recipe installs the
first-party `/usr/share/strata/install-source.toml` marker unchanged (`manager = "pacman"`, `package = "strata-bin"`),
which makes Strata treat the installation as package-managed: its update check only shows a notice and never
replaces the pacman-owned binary. The notice may suggest an AUR helper command; MirrorOS updates Strata only through
this recipe, so that suggestion must not be followed.

Runtime integrations stay user-initiated: Strata's settings can install per-user FileChooser, FileManager1, Omarchy
shortcut or udiskie files under `~/.local/share` and `~/.config`, and `strata --install-portal` writes per-user portal
preferences. Configure never runs them. Omarchy shortcut writing is gated on the `omarchy` command,
`/usr/share/omarchy/version` or `~/.local/share/omarchy/version` (`portal_setup/omarchy.rs`); MirrorOS provides none
of them, and the theme bridge below lives under `~/.local/state`. Per-user overrides are reported as notices by
`/usr/share/mirroros/portal/portal-check` (desktop/portal).

The FileChooser's URL download cannot be disabled and is accepted (DEC-004): in file-open requests, a direct
`http(s)` URL pasted in **Name** is downloaded to a user-only `strata-download-*` temporary folder (swept after a
day) and returned to the application; credentials and redirects are rejected, and Save and folder requests do not
download (`docs/portal-file-chooser.md` in the release archive). The Strata FileChooser is selected, so this applies
to every application's file-open dialog. In the laboratory a local `http://` URL pasted in **Name** was fetched with one
`GET` and returned as `file:///tmp/strata-download-<random>/<name>` (directory 0700, file 0600), which stays after the
chooser closes until upstream's sweep; no external network was used.

## FileChooser outcome

Plan 02-35 evaluated `FileChooser=strata;gtk` on the reference VM against the six DEC-006 criteria (phase B,
2026-11-13) and the maintainer selected `strata;gtk` (Task 6). Activation and routing (with fallback to `gtk` when
`strata.portal` is moved aside), the dedicated `scripts/portal-test.py` client, Chromium, keyboard-only use in the
three views and coexistence with sharing and FileManager1 passed. The quiet criterion failed under its literal
reading: the chooser backend adds sporadic GTK4 warnings (`Duplicate call to gdk_frame_timings_presented()`,
`gtk_svg_advance: time went backward`, about 2 per 20 openings), Strata tracing `WARN` lines at journal priority info
for unreadable or deleted directories, and a `strata@` D-Bus activation unit ending `status=1/FAILURE` when the session
ends inside the backend's 120 s idle window. The maintainer explicitly accepted these as a deviation from DEC-006's
"any failure yields `gtk`" rule; they are recorded in the DEC-030 narrowed exception. The GTK `tracker3` warning of
the GTK chooser no longer appears while Strata is the chooser.

There is no live failover: if the Strata backend fails to start, file selection fails for every portal client until
the preference is reverted; the frontend falls back to `gtk` only when `strata.portal` is absent. The revert procedure
is in the [portals and files procedure](../../../docs/procedures/portals-and-files.md#filechooser-outcome-and-revert).

Findings recorded without change: dbus-broker warns on every reload that `io.github.lgse.Strata.FileManager1.service`
is not named after its D-Bus name `org.freedesktop.FileManager1` (the recipe keeps the archive's file name;
activation works); and the chooser persists its last view (`browser_mode`) in Strata's own `settings.toml`, which is
Strata runtime user state, never written by MirrorOS.

## First-launch offer

`prepare-strata` runs `strata --dismiss-portal-prompt` once as the user, with fixed argv, while
`${XDG_CONFIG_HOME:-~/.config}/strata/portal-opt-in-v1` is absent. At the recipe tag this mode
(`crates/strata-desktop/src/portal_setup.rs`, `dismiss_prompt`) only creates that marker (`1`, mode 0600) without
initializing GTK, so it needs no display or bus; in target context the XDG default is used. Strata's `settings.toml`
is never written (DEC-007). An existing marker is left untouched.

## Theme bridge

Strata follows Omarchy's theme state only: `$HOME/.local/state/omarchy/current/theme.name` and
`.../current/theme/colors.toml` (`src/ui/theme/omarchy_state.rs`, which ignores `XDG_STATE_HOME`), live and by default
on first launch. As a deliberate, documented exception to keeping Omarchy paths out of MirrorOS, `prepare-strata`
creates the minimal bridge (DEC-007):

| Path | Target |
|---|---|
| `~/.local/state/omarchy/current/theme` | `<MirrorOS state>/mirroros/current/theme` |
| `~/.local/state/omarchy/current/theme.name` | `<MirrorOS state>/mirroros/current/theme/theme.name` |

The MirrorOS state home is resolved as `visual/theme/prepare-current` resolves it (user manager environment in
running context, XDG default in target context). The bridge is created atomically only while
`~/.local/state/omarchy` is absent; an identical bridge is unchanged; any other existing state is reported as a
conflict, preserved, and fails the step. Because both entries follow the current theme link, a theme selection
changes Strata's palette and name together. `tests/capabilities/desktop/files/strata-theme-contract.test.mjs` pins
the paths and the Quattro keys Strata maps against this revision.

## Nautilus migration

Nautilus is no longer declared, and configure never uninstalls packages. Both packages activate
`org.freedesktop.FileManager1`, so on a system that still has Nautilus the step fails through
`cfg_dbus_service_owner_unique`, naming every packaged owner and the action `sudo pacman -Rns nautilus`; a rerun
after that action passes. `xdg-user-dirs` is declared explicitly (previously only a dependency of
`xdg-user-dirs-gtk`, pulled in by Nautilus). The system `inode/directory` default is desktop/portal's
`/etc/xdg/mimeapps.list` (DEC-014); a user choice is a `portal-check` notice, never a configure failure.

## files-cwd

`files-cwd`, delivered to `/usr/share/mirroros/files/files-cwd` and bound to SUPER+Alt+Shift+F by the Hyprland
provider, is adapted from Omarchy `bin/omarchy-cmd-terminal-cwd` at `origin/quattro`
`2d33fd5973eb349c3f7e3ae56e6c293516cc4e18` (MIT, [`OMARCHY-LICENSE`](OMARCHY-LICENSE); DEC-016). Kept: the newest
child of the focused window, the session-leader-on-a-pty rule and the `/etc/shells` check. Changes: tmux support, read
from the terminal's foreground process group so it covers Foot running tmux directly, through the provider's
`bash -c 'tmux attach || tmux new'` binding, or from the shell (the client's tty selects
`#{pane_current_path}`); no kitty or Strata/Folio source; it opens Strata with `uwsm app` and has a `--print` mode
for tests. Missing or deleted directories open `$HOME`.
