# Desktop portal sources and ownership

Story 4.5 delivers the desktop portal stack, the Secret service and the desktop's default application associations
as a neutral capability (DEC-012). No upstream code or configuration is copied; every file here is original MirrorOS
configuration. Configure records the installed package versions in `packages.tsv`.

| Package | Repository | License (SPDX) | Role |
|---|---|---|---|
| `xdg-desktop-portal` | Arch **extra** | `LGPL-2.1-or-later` | Portal frontend (`org.freedesktop.portal.Desktop`), D-Bus-activated user unit |
| `xdg-desktop-portal-gtk` | Arch **extra** | `LGPL-2.0-or-later` | GTK backend: FileChooser (per the Story 4.5 outcome), Settings and other GTK interfaces |
| `gnome-keyring` | Arch **extra** | `GPL-2.0-or-later AND LGPL-2.1-or-later` | `org.freedesktop.secrets` and the `Secret` portal backend |
| `dconf` | Arch **extra** | `LGPL-2.1-or-later` | System defaults database read by the GTK backend's Settings answer |

The Hyprland backend (`xdg-desktop-portal-hyprland`, Screenshot and ScreenCast with `hyprland-share-picker`), the
portal preferences in `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` and the portal-dialog window rules belong
to the Hyprland provider; see its [UPSTREAM.md](../compositor/providers/hyprland/UPSTREAM.md). The file manager,
its FileManager1 and FileChooser integrations and its desktop entry belong to `desktop/files`.

## Session environment

uwsm exports `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_TYPE`, `DISPLAY` and
`HYPRLAND_INSTANCE_SIGNATURE` to the user manager, and the frontend and backends run as D-Bus-activated user units in
that environment (verified in the reference VM during planning). MirrorOS adds no environment propagation code.
Configure never starts, restarts or reloads a user or portal service: a running frontend keeps its configuration, so
portal changes take effect at the next login (DEC-019).

## Keyring boundary

gnome-keyring is unlocked and started at SDDM login by the `pam_gnome_keyring.so` lines that the `sddm` package
ships in `/etc/pam.d/sddm` (`auth`, `password use_authtok`, `session auto_start`). MirrorOS does not add, edit or
replace any PAM file (DEC-011); configure only reads those lines once SDDM is installed, and reports them as
unavailable earlier in the step order because `desktop/login` installs SDDM. A missing integration is a finding
routed through review, not a MirrorOS PAM change.

The keyring and its contents are runtime state under the user's home: no password, secret, collection or item is
delivered, read, logged or stored in the repository or in evidence. `passwd` does not re-encrypt the `login`
keyring; after a password change the keyring keeps the old password until it is changed or recreated, as the
[portals and files procedure](../../../docs/procedures/portals-and-files.md) describes. The screen lock does not lock
the keyring. `gcr-ssh-agent`, KeePassXC and cloud password managers are out of scope.

## Default applications

`/etc/xdg/mimeapps.list` is the single owner of the desktop's system default associations (DEC-014). This plan
declares only `inode/directory=io.github.lgse.Strata.desktop`; later Story 4.5 plans add their lines to this file
instead of creating another association file. A user `mimeapps.list` keeps precedence and is a user choice:
`portal-check` reports it as a notice and configure never fails on it. In running context configure checks the
system association with `xdg-mime query default inode/directory` in an environment without user directories, once
the Strata desktop entry exists.

## Dark Settings answer

`/etc/dconf/profile/user` (`user-db:user`, `system-db:local`) and
`/etc/dconf/db/local.d/00-mirroros-appearance` (`org/gnome/desktop/interface color-scheme='prefer-dark'`) make the
GTK backend's Settings portal answer dark (`1`) unless the user sets a value (DEC-010). Configure compiles
`/etc/dconf/db/local` with `dconf update` through `cfg_exec` only when one of those files changed or the database is
missing, a bounded native-tool exception documented in [capabilities/README.md](../../README.md). It never writes
user dconf or GSettings. GTK3 and Qt dark preferences and a theme-derived `color-scheme` belong to Story 4.8.

## portal-check

`/usr/share/mirroros/portal/portal-check` (0755, tracked delivery) is the read-only session verifier run as the user
after a new login (DEC-019). It checks the uwsm-exported activation environment; the effective preference file in
the frontend's search order (`~/.config`, `/etc/xdg`, `/usr/share`; `<desktop>-portals.conf` before `portals.conf`,
the first file found winning whole); for FileChooser, Screenshot, ScreenCast, Settings and Secret, the routed
backend's `.portal` declaration and its owned or activatable bus name; the Settings `color-scheme` answer `1`;
`org.freedesktop.secrets` owned by `gnome-keyring-daemon` with the `login` collection's `Locked` property false; and
the `org.freedesktop.FileManager1` owner or single activatable service being Strata. User-level preference files,
`.portal` files, FileManager1 services and `inode/directory` choices are notices on stdout. It exits 0 on pass and 1
on failure, naming the element and the expected owner, and it never prints secret values, item labels or attributes.
Epic 5 independent verification may reuse it.
