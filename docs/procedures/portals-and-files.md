# Portals and file manager procedure

Story 4.5 delivers the desktop portal stack, the Secret service and the Strata file manager through configure
(plan 02-35, no ADR). Results come from the reference VM only; no hardware qualification is claimed.

## Ownership and environment

| Interface or role | Owner | Delivered by |
|---|---|---|
| Portal frontend `org.freedesktop.portal.Desktop` | `xdg-desktop-portal` | `desktop/portal` |
| FileChooser | Strata (`strata --portal`), `gtk` when `strata.portal` is absent | `desktop/files` (backend files), Hyprland provider (preference) |
| Screenshot, ScreenCast | `xdg-desktop-portal-hyprland` with `hyprland-share-picker` and `grim` | Hyprland provider |
| Settings and other GTK interfaces | `xdg-desktop-portal-gtk`, dark answer from the system dconf default | `desktop/portal` |
| Secret and `org.freedesktop.secrets` | `gnome-keyring` | `desktop/portal` |
| `org.freedesktop.FileManager1`, `inode/directory` | Strata | `desktop/files`, `desktop/portal` (`/etc/xdg/mimeapps.list`) |

The preferences are `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`: `default=hyprland;gtk`,
`org.freedesktop.impl.portal.FileChooser=strata;gtk` and `org.freedesktop.impl.portal.Secret=gnome-keyring`. That file
replaces the `hyprland` package's copy whole; no generic `portals.conf` is delivered. The share picker defaults are the
user file `~/.config/hypr/xdph.conf` (`allow_token_by_default = true`), and portal dialogs float and center through
the provider's window rules. uwsm exports `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `DISPLAY` and
`HYPRLAND_INSTANCE_SIGNATURE` to the user manager; the frontend and backends are D-Bus-activated user units, and
MirrorOS adds no environment propagation. Provenance: [portal sources](../../capabilities/desktop/portal/sources.md),
[file manager sources](../../capabilities/desktop/files/sources.md) and the
[Hyprland provider record](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md#story-45-portal-additions).

## Applying and checking the session

Run `sudo mirroros-configure` as usual (see the [configure procedure](configure.md)). Configure checks declared state
only and never starts, restarts or reloads portal or user services; a running frontend keeps its old configuration,
so portal changes take effect at the next login. After logging out and back in, run as the session user:

```bash
/usr/share/mirroros/portal/portal-check
```

It is read-only. It checks the activation environment, the effective preference file, the routed backend and bus
name of FileChooser, Screenshot, ScreenCast, Settings and Secret, the dark Settings answer, the gnome-keyring owner of
`org.freedesktop.secrets` with the `login` collection unlocked, the FileManager1 owner, `grim` and the share-picker
defaults. Lines start with `ok:`, `notice:` or `FAIL:`. User-level preference files, `.portal` files, FileManager1
services, `xdph.conf` copies and `inode/directory` choices are notices, not failures. Exit 0 is a pass; exit 1 names
the failing element and the expected owner. It never prints secret values, item labels or attributes.

## Nautilus migration

Configure never uninstalls packages. On a system that still has Nautilus, `desktop/files` fails with outcome 4
because two packaged services declare `org.freedesktop.FileManager1`. The terminal shows the generic postcondition
message; `configure.log` names both service files with their packages and the action:

```bash
sudo pacman -Rns nautilus
```

Then rerun configure. `-s` also removes Nautilus dependencies that nothing else requires. In the reference VM this
removed 91 packages, including `xdg-user-dirs` (reinstalled by the rerun, now declared), `ffmpeg` (a Strata optional
dependency, still declared by `workflow/pi`) and `localsearch`. Without `localsearch` the GTK file chooser logs
`Could not init tracker3 search engine` on each opening, as on an Omarchy fresh install; Strata is the selected
chooser, so the GTK chooser appears only as the fallback. Review the transaction before confirming it.

## Keyring

The `sddm` package ships optional `pam_gnome_keyring.so` lines in `/etc/pam.d/sddm`; a password login through SDDM
unlocks the `login` keyring and starts the daemon. MirrorOS never edits PAM. Chromium-family browsers use
`org.freedesktop.secrets` directly; sandboxed applications use the Secret portal.

- The keyring and its contents are runtime state under `~/.local/share/keyrings`. No password or secret is delivered,
  read, logged, stored in the repository or recorded in evidence.
- The screen lock (hyprlock) does not lock the keyring; it stays unlocked until logout.
- `passwd` does not re-encrypt the `login` keyring. After a password change the keyring keeps the old password, so it
  is no longer unlocked at login and applications that need a secret ask for it. Recovery, not exercised in the
  laboratory, is a user decision: either install a keyring manager such as `extra/seahorse` (not delivered by
  MirrorOS), unlock the Login keyring with the old password and change its password to the new one; or, from a text
  console while logged out, move `~/.local/share/keyrings/login.keyring` aside, accepting that its saved secrets are
  lost, and log in again so that a new `login` keyring is created with the new password.

## Strata updates

Strata is built from the reviewed recipe in `capabilities/desktop/files/strata/` and installed as the pacman package
`strata-bin`. The packaged `install-source.toml` marker makes Strata's update check show a notice only; it never
replaces the binary. Ignore any AUR helper command in that notice. To update, follow the recipe update steps in the
[file manager sources](../../capabilities/desktop/files/sources.md#recipe): select a new stable tag, verify its asset
and attestation, update the recipe, rerun `strata-theme-contract.test.mjs` against the new upstream source and rerun
configure.

## Theme bridge

Strata reads Omarchy's theme state only. `desktop/files` therefore creates
`~/.local/state/omarchy/current/theme` and `theme.name`, linking to the current MirrorOS theme, only while
`~/.local/state/omarchy` is absent. An identical bridge is unchanged. Any other existing content there is reported as
a conflict, preserved, and fails the step with outcome 4: move it aside deliberately, or keep it and accept that
Strata follows it instead of the MirrorOS theme, which leaves the step failing. Strata's own `settings.toml` is never
written; the first-launch integration offer is suppressed once through `strata --dismiss-portal-prompt`, which only
creates `~/.config/strata/portal-opt-in-v1`.

## FileChooser outcome and revert

The FileChooser is `strata;gtk`, selected by the maintainer after the DEC-006 laboratory evaluation. Five criteria
passed; the quiet criterion failed under its literal reading and was explicitly accepted (sporadic GTK4 warnings,
Strata tracing `WARN` lines, and a `strata@` activation unit failing when the session ends inside its 120 s idle
window). There is no live failover: if the Strata backend fails, file selection fails for every portal client; the
frontend falls back to `gtk` only when `strata.portal` is absent.

The chooser's URL download cannot be disabled and is accepted (DEC-004): in an open request, an `http(s)` URL pasted
in **Name** is fetched and returned as a file in a user-only `/tmp/strata-download-*` folder that persists until
upstream's sweep. Do not paste URLs you do not want fetched.

To revert to the GTK chooser:

- Product change: set `org.freedesktop.impl.portal.FileChooser=gtk` in the Hyprland provider's
  `hyprland-portals.conf` through review, update `tests/capabilities/desktop/portal/portal-preferences.test.mjs` and
  the records, rerun configure, log in again and run `portal-check`. Removing Strata's portal files from the recipe
  is a separate recipe change.
- Local, user-level: create `~/.config/xdg-desktop-portal/hyprland-portals.conf` with the complete `[preferred]`
  section and `org.freedesktop.impl.portal.FileChooser=gtk`, because the first file found replaces the system file
  whole; log in again. `portal-check` reports it as a user override notice. Remove it to return to the product
  preference.

Do not move or delete the packaged `strata.portal`: pacman owns it.

## Laboratory evidence

Reference VM `mirroros-ref`, Hyprland 0.57.1, xdg-desktop-portal 1.22.1, -gtk 1.15.3, -hyprland 1.5.0, gnome-keyring
1:51.1, strata-bin 1.2.1-1.1, laboratory Chromium (removed afterwards). Candidates `d5a12ba`, `edaad28` and
`2c56a10`; records in `evidence/portals/lab-02-35/checkpoint.md` (ignored, not committed).

- Phase A, `FileChooser=gtk` (2026-11-12):
  - configure failed on the two FileManager1 owners as designed; after `sudo pacman -Rns nautilus` the rerun passed
    and a second rerun reported all 21 steps unchanged;
  - `portal-check` exited 0 after a new login;
  - a disposable Chromium password filled after logout and login without an unlock prompt and was deleted;
  - Google Meet window and full-screen sharing worked with a floating picker and the shell sharing snooze;
  - the GTK chooser worked for open, multiple upload, Save as and folder selection, floating and centered on the
    monitor at 875×600 rather than over its parent (accepted as Omarchy-equivalent);
  - `SUPER+SHIFT+F`, `SUPER+ALT+SHIFT+F` (zsh, tmux active pane, `$HOME` fallback), `SUPER+K` and the shell's
    background folder action opened Strata in the MirrorOS palette.
- Phase B, `FileChooser=strata;gtk` (2026-11-13): routing with `version` 4 and fallback to `gtk`; all dedicated
  `portal-test.py` requests with correct URIs and cancellation `1`; Chromium; keyboard-only use in Columns, Icons and
  List; coexistence with sharing and FileManager1, and backend exit after the idle timeout. Quiet failed as described
  above.
- Amendments made during the campaign: `xdph.conf` with `allow_token_by_default = true` (Chromium otherwise prompted
  twice), `grim` for the Screenshot backend, and the 875×600 GTK chooser size (it otherwise exceeded the
  1536×864 logical screen).

Limits and findings:

- Workspace sharing timed out waiting for PipeWire buffers and region selection looped in the VM;
  `hyprland-share-picker` 1.5.0 crashed twice (upstream). Chromium's source tabs are only a hint; the xdg-desktop-
  portal-hyprland picker decides.
- dbus-broker warns that `io.github.lgse.Strata.FileManager1.service` is not named after its D-Bus name; activation
  works.
- The GTK3 chooser dialog and other GTK3/Qt applications stay light, and text is large at runtime scale 1.25; both
  are Story 4.8 findings.
- The DEC-030 quiet-check exception is narrowed to named portal diagnostics; see the
  [desktop shell procedure](desktop-shell.md#open-failures-and-limits).
