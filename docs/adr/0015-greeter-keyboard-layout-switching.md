# ADR 0015: Greeter Keyboard Layout Switching

## Identifier and title

- **Identifier:** `0015`
- **Title:** Greeter Keyboard Layout Switching

## Status

`Accepted`

## Date

`2026-10-26`

## Context and question

[ADR 0014](0014-native-login-and-boot-presentation.md) admits one presentation-only SDDM theme that shows the
keyboard layout resolved by configure. Attended VM review in plan 02-20 showed that a single fixed greeter layout
does not serve a system with several accounts using different layouts: a password containing a layout-specific
character such as `ñ` cannot be typed when the greeter offers only another layout. The managed Hyprland session also
started in the first entry of its static list (`us,es`), and its lock reset the layout to that entry and offered no
way to switch it.

Facts verified with the packaged versions (`hyprland 0.56.2-4`, `sddm 0.21.0-7`):

- SDDM 0.21 has only an XCB keyboard backend. Under its Wayland greeter the theme's `keyboard` model publishes no
  layouts, and assigning its current layout has no effect.
- An SDDM QML theme cannot execute processes or call the compositor.
- The Hyprland greeter compositor can hold several layouts and switch them (`hyprctl switchxkblayout`), and its Lua
  configuration provides key bindings and a start event, but no layout-change event; the active layout is published
  only through its IPC socket.
- The SDDM user's home, `/var/lib/sddm`, is created by the package as `0750 sddm:sddm`; the greeter compositor and
  `sddm-greeter` both run as that user.

The question is how the greeter can offer the system's layouts and show the active one without giving the theme
authority over keyboard configuration or adding a daemon.

## Constraints and decision criteria

- The [ADR 0014](0014-native-login-and-boot-presentation.md) boundaries stay in force: no project-owned
  authentication, PAM change, autologin, supervisor or daemon; the theme executes no process.
- The keyboard layout remains the compositor's responsibility ([ADR 0011](0011-hyprland-compositor-provider.md)).
- Configure-resolved layout data is parsed as data; layout names shown to users are validated before display.
- NFR37: the smallest mechanism that meets the recurring need.

## Alternatives considered

1. **Keep one fixed greeter layout.** No new mechanism, but accounts whose passwords need another layout cannot log
   in from the greeter.
2. **Switch layouts in the greeter compositor without an indicator.** Simple, but the theme would keep showing the
   initial layout after a switch, which misleads password entry.
3. **A watcher process that follows the compositor's IPC events.** Accurate, but a long-running greeter-side process
   is a daemon outside the accepted boundary.
4. **A per-account layout chosen by the theme.** SDDM stores no per-account layout and the theme cannot command the
   compositor; this would need a new login provider or helper service.
5. **Compositor-owned switching with a one-shot indicator helper and a theme-read state file (selected).**

## Evidence

- Plan 02-20 attended smoke review: single-layout greeter and lock-screen layout findings, and the maintainer's
  multi-account requirement.
- Package inspection in a disposable Arch container: SDDM's keyboard backends, the Hyprland Lua API stubs
  (`/usr/share/hypr/stubs/hl.meta.lua`: `hl.bind`, `hl.on("hyprland.start")`, `hl.exec_cmd`), `hyprctl devices -j`
  fields (`active_keymap`, `main`) and the SDDM `sysusers.d`/`tmpfiles.d` entries.
- Qt restricts local-file `XMLHttpRequest` reads unless `QML_XHR_ALLOW_FILE_READ=1` is set for the process.

## Decision

- **Layout list.** The managed session and the greeter compositor use one shared list: the layout resolved from
  `/etc/vconsole.conf` first, then the declared MirrorOS layouts without duplicates. Both therefore start in the
  configured layout.
- **Lock screen.** Locking still selects the first layout (now the configured one) and restores the previous
  layout after unlocking, and the session's `SUPER+I` and `SUPER+SHIFT+I` bindings also work while locked. Keeping the active layout when locking was rejected: in the
  plan 02-20 VM, hyprlock followed only the first layout change after locking, so later changes left its
  indicator showing a layout other than the one used for typing. *Amended during plan 02-20 qualification
  (2026-10-26): the session's layout bindings no longer work while locked; the lock always uses the configured
  layout.*
- **Switching.** The greeter compositor binds `SUPER+I` and `SUPER+SHIFT+I`, as in the session. Each binding, and the
  compositor's start event, runs one short-lived MirrorOS helper that switches the layout when asked and writes the
  active layout's XKB description to `/var/lib/sddm/mirroros-greeter-layout`. The helper exits after one action;
  nothing keeps running.
- **Indicator.** The SDDM theme may read exactly that state file through `XMLHttpRequest`. It validates the content
  as a short layout label and otherwise shows the configure-resolved label. Configure sets only
  `QML_XHR_ALLOW_FILE_READ=1` in the greeter environment for this purpose.
- **Unchanged boundaries.** The theme still executes no process, writes no file, uses no network, and authenticates
  only through `sddm.login`. The helper has no authentication role and reads no credential. No per-account layout
  is stored.

This ADR extends only the keyboard-layout boundary of [ADR 0014](0014-native-login-and-boot-presentation.md); all its
other decisions remain authoritative.

## Consequences and trade-offs

- The theme's keyboard indicator now depends on a compositor-written file; a missing or invalid file falls back to the
  configure label.
- The theme polls the file briefly; the read is local and stops after repeated absence.
- Local-file reads are allowed for the whole greeter process, not only for this path; the theme is the only greeter
  QML loaded and reads only the state file.
- Users choose their layout manually before typing; there is no automatic per-account layout.
- Changing the declared list or the resolved layout takes effect at the next greeter or session start.

## Replacement or reversal boundary

Reconsider this decision if SDDM gains a functional Wayland keyboard model, if the greeter needs a long-running
helper, per-account state or write access from the theme, or if the login provider changes. Reverting restores the
[ADR 0014](0014-native-login-and-boot-presentation.md) single-layout indicator.

## Required validation

- Automated tests cover the shared ordering, the helper with a `hyprctl` double, the theme's state handling and
  fallback, and configure delivery of the helper and greeter environment.
- Plan 02-20 VM qualification covers switching in the greeter, a layout-sensitive password, and the lock screen
  starting in the configured layout without switching.

## References

- [Architecture](../architecture.md)
- [ADR 0011](0011-hyprland-compositor-provider.md), [ADR 0014](0014-native-login-and-boot-presentation.md)
- [Greeter and Plymouth interview plan](../technical-interviews/greeter-plymouth_plan.md)
- [SDDM theming](https://github.com/sddm/sddm/blob/develop/docs/THEMING.md)

## Superseded by

`None`
