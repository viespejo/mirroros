# Login sources and ownership

## Provider and theme

SDDM from the Arch `extra` repository remains the login provider; its packaged PAM service authenticates and starts
the session. The MirrorOS theme in `sddm/mirroros/` is independently written presentation code bounded by
[ADR 0014](../../../docs/adr/0014-native-login-and-boot-presentation.md): it imports only `QtQuick` and its own
`LoginModel.js`, and submits login only through SDDM's `sddm.login(user, password, sessionIndex)` proxy method. It
runs no process, reads no system file, logs nothing and has no avatar, power menu, clock or settings. PAM, accounts
and autologin are unchanged (`10-mirroros-login.conf` keeps autologin empty).

Interfaces used, from the [SDDM theming documentation](https://github.com/sddm/sddm/blob/develop/docs/THEMING.md)
and the SDDM `v0.21.0` source (SDDM 0.21.0-7 observed in the Arch repositories; not a pin):

- `metadata.desktop` `QtVersion=6` selects the Qt 6 greeter; `theme.conf` and `theme.conf.user` are read as the
  `config` object, with non-empty `.user` values overriding the defaults.
- `userModel` (`name`, `realName`, `lastUser`), `sessionModel` (`file`), `keyboard` (`layouts`, `currentLayout`) and
  the `loginFailed`/`loginSucceeded` signals.

Omarchy revision `1801adc1983b06f6ab218f8060e430cb3477d8d0` (`default/sddm/omarchy/Main.qml`) is an idea reference
for a small centered theme with last-user selection; no Omarchy code or asset is copied, so no attribution entry
applies.

## Behavior

- Dark background, centered [shared wordmark](../../visual/branding/sources.md) scaled proportionally within 42% of
  the width and 22% of the height, never above its rendered size; the lock screen's rectangular password field and
  colors; the keyboard layout below the field.
- The selected account is always shown. The last successful user is selected while still listed, otherwise the
  first listed user. With more than one account a discreet `▾` control (Tab, then Enter or Space; arrows and Enter
  in the list; Esc closes it) changes the account.
- The session is the single entry whose file is exactly
  `/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop`, the link the Hyprland provider creates and checks
  with `cfg_session_is_only`. There is no session selector or name matching.
- With no account or no unambiguous session the theme shows an actionable message and submission is disabled.
- Enter submits a non-empty password once; further submissions and account changes wait for SDDM's answer. A
  failure clears the password, keeps focus in the field and shows a generic "Authentication failed" without PAM
  messages. Typing clears the failure state; an account change clears the password.

## Keyboard layout

SDDM 0.21's Wayland keyboard backend intentionally publishes no layouts, so the native model is empty under the
Hyprland greeter compositor. The theme shows the native layout name when one is published and otherwise the label
of the layout resolved by configure (`XKBLAYOUT`, `KEYMAP` or `us` from `/etc/vconsole.conf`, the same resolution as
the greeter's `keyboard.lua`), which `install-theme` writes to `theme.conf.user`. The label is the layout's XKB
description from the configured system's `base.lst` (`Spanish`, `English (US)`), matching hyprlock's `$LAYOUT` at
the same 16-pixel size; the layout code is used when no description is listed. The label is informational; the greeter
compositor applies the actual layout. A later layout change is shown after the next configure run, which republishes
the theme.

Under [ADR 0015](../../../docs/adr/0015-greeter-keyboard-layout-switching.md) the greeter compositor offers the
resolved layout first and the other MirrorOS layouts after it; `SUPER+I` and `SUPER+SHIFT+I` switch them. Its
indicator helper writes the active layout's description to `/var/lib/sddm/mirroros-greeter-layout`
(`layoutState`). The theme reads only that file, with a local `XMLHttpRequest` enabled by
`GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1` in `10-mirroros-login.conf`, polls it every 300 ms, and shows it
together with the `layoutHint` (`Super+I`). After ten consecutive missing or invalid reads it stops polling and
keeps the configure label. The password field draws hyprlock-sized dots (12 pixels) inside a 304x54 outline, which
matches hyprlock's 300x50 field with its outer 2-pixel outline.

## Ownership

| Item | Location | Owner |
|---|---|---|
| Theme | `/usr/share/sddm/themes/mirroros/` with `.mirroros-manifest` | MirrorOS, tracked tree |
| Theme selection | `/etc/sddm.conf.d/10-mirroros-login.conf` (`Current=mirroros`) | MirrorOS, tracked file |
| Service | `sddm.service` | Package; enabled only, never started by configure |

`install-theme` publishes the complete theme before the configuration selects it, through a verified staging tree
and an atomic exchange; its manifest digest is recorded as `mirroros-sddm-theme` in `sources.tsv`. An edited,
unknown or linked theme directory is preserved and fails the step before the theme is selected.

The login configuration is a tracked delivery. The exact configuration shipped before the theme (empty `Current=`,
SHA256 `e8a1257fbfde6463e2cfaf1ee54b8211599f0a5f43ac30faa4d8376d920a930e`) migrates once; any other unrecorded or
edited content, including an unmanaged file, is preserved and fails the step with an actionable conflict. This
replaces the earlier "user-owned, left untouched" handling of that file, so an incompatible local selection is
reported instead of silently keeping the old greeter.

## Open limits

- Automated UI checks use synthetic SDDM models; real authentication, failed login, account switching, logout and
  layout-sensitive passwords are attended VM checks (plan 02-20 Task 3).
- Multi-output greeter layout and HiDPI scaling are unqualified.
