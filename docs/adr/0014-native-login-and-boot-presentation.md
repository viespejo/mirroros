# ADR 0014: Native Login and Boot Presentation

## Identifier and title

- **Identifier:** `0014`
- **Title:** Native Login and Boot Presentation

## Status

`Accepted`

## Date

`2026-10-25`

## Context and question

The installed system logs in through SDDM with its built-in theme and boots without a splash. The maintainer wants
a minimal greeter that follows the existing hyprlock screen and a matching static boot splash, both showing the
MirrorOS wordmark of `install/confirmation/banner.txt`
([greeter and Plymouth interview](../technical-interviews/greeter-plymouth_plan.md), DEC-001–014).

Both presentations require a native theme format that the language table does not admit:

- An SDDM theme is a QtQuick program (`Main.qml`) loaded by `sddm-greeter`. [ADR 0012](0012-owned-quickshell-desktop-shell.md)
  admits project-owned QML only for the desktop shell, and the MVP scope names a small owned QML greeter theme
  without an architecture rule for it.
- A Plymouth script theme is written in Plymouth's own script language, which no record admits.

The [MVP scope](../mvp-scope.md) also lists the Plymouth boot splash only as a deferred candidate, together with
optional LUKS encryption and autologin, owned by installation and requiring an amendment of
[ADR 0003](0003-storage-and-recovery-baseline.md).

The questions are:

1. May MirrorOS own the QML of one SDDM theme and the script of one Plymouth theme, and within which limits?
2. Can the boot splash be adopted alone, as a configure-owned visual overlay, without the deferred storage and
   authentication changes?

## Constraints and decision criteria

- NFR37: custom code needs a documented recurring need that simpler supported mechanisms cannot meet.
- Authentication surfaces carry security risk and must not be project-owned code
  ([ADR 0012](0012-owned-quickshell-desktop-shell.md)).
- The language hierarchy must not gain a general application framework, supervisor or daemon.
- Installation plans, storage layouts, hibernation policy, bootloader choice and editor policy are unchanged.
- Diagnostics remain available: no aggressive log suppression, fake progress or artificial delay.
- Omarchy is an idea reference only; no theme code or graphical asset is copied (DEC-013).

## Alternatives considered

1. **Keep the default SDDM theme and no splash.** No new code, but no coherent boot-to-login presentation; the
   default theme also shows an incorrect layout label on Wayland.
2. **Third-party SDDM and Plymouth themes.** Less owned code, but their layout, assets and behavior are not under
   project control, and many include clocks, power menus, progress or password dialogues outside the agreed scope.
3. **Replace SDDM with a project-owned greeter (for example, Quickshell or greetd with a custom client).**
   Full control, but MirrorOS would own the authentication surface and a new login provider.
4. **Owned native themes, bounded to presentation (selected).** One SDDM theme and one static Plymouth theme,
   written independently in their native formats. SDDM, its login proxy, PAM and Plymouth keep every
   authentication, session and boot responsibility.

## Evidence

- Interview decisions DEC-001–014 in the [greeter and Plymouth interview log](../technical-interviews/greeter-plymouth_log.md).
- The [SDDM theming documentation](https://github.com/sddm/sddm/blob/develop/docs/THEMING.md): themes receive the
  `sddm` proxy, whose `login(user, password, sessionIndex)` method is transferred to the daemon, and native user,
  session and keyboard models.
- The [Plymouth article](https://wiki.archlinux.org/title/Plymouth) of the Arch Wiki: script themes, the
  `plymouth` mkinitcpio hook and the `quiet splash` kernel parameters, with Esc showing boot messages.
- Omarchy revision `1801adc1983b06f6ab218f8060e430cb3477d8d0` (`default/sddm/omarchy/Main.qml`,
  `default/plymouth/omarchy.script`), inspected as an idea reference only.
- No prototype is required: both formats are the providers' own theme interfaces, and the qualification of
  plan 02-20 provides the post-adoption evidence.

## Decision

MirrorOS owns two native presentation themes, each bounded to presentation:

- **SDDM theme (QML).** QML is additionally admitted for exactly one MirrorOS SDDM theme, loaded by SDDM's own
  greeter. It may import only QtQuick modules shipped with Qt and the context objects SDDM provides. It displays the
  wordmark, the selected account with a discreet account selector, a password field, the keyboard layout and a
  failure state. Login submission happens only through the `sddm.login` proxy method; SDDM and its PAM service
  authenticate and start the configured session. The theme does not execute processes, read or write files beyond
  its own theme resources, use the network, import Quickshell or shell modules, change PAM, enable autologin, or add
  power menus, avatars or settings.
- **Plymouth theme (Plymouth script).** Plymouth's script language is admitted only as the native format of one
  static MirrorOS theme: the shared wordmark centered on a solid background. It has no animation, progress,
  password dialogue or delay, and it keeps Plymouth's native details and Esc behavior.
- **Shared wordmark.** A font-independent SVG adaptation of the installer wordmark is the single graphical source;
  derived raster images are generated during configure, never committed.
- **Ownership.** Configure owns both themes and their boot integration in target and running contexts. The
  installation engine, its approved plans and its base postconditions are unchanged; configure verifies its own
  additive `quiet splash` overlay and the boot artifacts it regenerates.
- **Deferred bundle.** Adopting the splash alone does not adopt LUKS encryption or autologin and does not amend
  [ADR 0003](0003-storage-and-recovery-baseline.md). Those candidates remain deferred and still require their own
  decision.

This ADR does not change the shell scope of [ADR 0012](0012-owned-quickshell-desktop-shell.md) and does not admit
QML or Plymouth script for any other component.

## Consequences and trade-offs

- `docs/architecture.md` gains bounded language entries for the SDDM theme QML and the Plymouth script theme.
- MirrorOS maintains a small QML file and a small Plymouth script; SDDM or Plymouth API changes may require updates.
- The SDDM Wayland keyboard backend does not publish layouts, so the theme must show the layout without its own
  authority over keyboard configuration.
- Boot integration adds initramfs hook and kernel-parameter management to configure, with regeneration, conflict and
  recovery handling for each supported bootloader.
- The live medium keeps its current boot visuals and package list.

## Replacement or reversal boundary

Reconsider this decision through a new ADR if either theme needs authentication logic, process execution, persistent
settings, or surfaces beyond those listed; if SDDM is replaced as the login provider; or if the splash conceals boot
failures or requires boot delays. Removing the themes restores the providers' defaults without changing the
authentication or storage design.

## Required validation

Before adoption:

- `docs/architecture.md` admits only the bounded formats and references this ADR.

After adoption, through plan 02-20:

- Automated tests cover the theme behavior with synthetic SDDM models and the configure delivery and boot
  convergence in both contexts.
- VM qualification covers the three storage schemes, real login, failed authentication, account switching, logout,
  the splash and Esc access to boot messages, and the documented no-splash recovery.
- No copied Omarchy material exists; idea references are recorded without attribution entries.

## References

- [Architecture](../architecture.md)
- [MVP scope](../mvp-scope.md)
- [Greeter and Plymouth interview plan](../technical-interviews/greeter-plymouth_plan.md)
- [Greeter and Plymouth interview log](../technical-interviews/greeter-plymouth_log.md)
- [ADR 0003](0003-storage-and-recovery-baseline.md), [ADR 0010](0010-environment-configuration-mechanism-and-scope.md),
  [ADR 0011](0011-hyprland-compositor-provider.md), [ADR 0012](0012-owned-quickshell-desktop-shell.md)
- [SDDM theming](https://github.com/sddm/sddm/blob/develop/docs/THEMING.md)
- [Arch Wiki: Plymouth](https://wiki.archlinux.org/title/Plymouth)
- [ADR 0015](0015-greeter-keyboard-layout-switching.md): later extension of this decision's keyboard-layout
  boundary (greeter layout switching and one state file read by the theme); the other decisions are unchanged

## Superseded by

[ADR 0016](0016-greeter-power-actions.md) supersedes only the exclusion of power menus: confirmed restart and
shutdown through SDDM's native proxy are permitted. The other decisions remain in force, with the keyboard-layout
extension already recorded in ADR 0015.

[ADR 0017](0017-live-console-display-preference.md) supersedes only the consequence that live boot visuals remain
unchanged, for a best-effort display-mode preference and native-display recovery entry. Installed presentation
and the live package list remain unchanged.

[ADR 0019](0019-shared-symbol-and-live-splash.md) supersedes only the historical-wordmark selection, static-only
splash restriction, and installed-only integration boundary: a shared installer symbol, static greeter, reviewed
fade-plus-pulse splashes, and bounded live build integration are permitted. Authentication, diagnostic access,
boot completion, storage, and the ADR 0015/0016 extensions remain unchanged; runtime qualification is separate.
