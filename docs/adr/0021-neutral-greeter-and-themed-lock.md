# ADR 0021: Neutral Greeter and Themed Lock

## Identifier and title

- **Identifier:** `0021`
- **Title:** Neutral Greeter and Themed Lock

## Status

`Accepted`

## Date

`2026-10-29`

## Context and question

MirrorOS publishes a fixed Osaka Jade theme and a per-user selection link,
`$XDG_STATE_HOME/mirroros/current/theme`, already followed by Foot and the wallpaper capability
([ADR 0020](0020-wallpaper-selection.md)). The splash, greeter and lock still use fixed literals unrelated to the
theme. More themes are planned. The maintainer asked how these three surfaces should relate to themes.

[ADR 0014](0014-native-login-and-boot-presentation.md) requires the greeter to display the selected account, and
[ADR 0019](0019-shared-symbol-and-live-splash.md) changed only the greeter asset and required its existing layout to
be preserved. The lock is a managed hyprlock configuration outside those ADRs, last described as solid background,
clock, password field and active layout.

## Constraints and decision criteria

- Authentication stays with SDDM's proxy and PAM, and with hyprlock's PAM service; MirrorOS code handles no
  credentials. Faillock policy, keyboard-layout switching (ADR 0015) and confirmed power actions (ADR 0016) are
  unchanged.
- Changing the splash requires privileged boot-image regeneration; the splash and greeter run before any user, and
  therefore before any per-user theme selection, is known.
- No window or notification content may appear on the lock surface; a missing theme file or image must not prevent
  locking.
- Diagnostics remain available; no boot delay or retained splash is introduced.
- Omarchy is an idea reference only; no theme code or asset is copied.

## Alternatives considered

1. **Every surface follows the theme.** Regenerating the initramfs on every theme change is slow, privileged and
   boot-critical, and a pre-login surface cannot know which user's theme to show. Rejected.
2. **System surfaces fixed to the default theme's colors.** Matches the desktop only while the default theme is
   selected, needs a recolored symbol and creates a color jump after the gray splash. Rejected.
3. **Greeter follows the last user's theme.** Requires the greeter to read a user's home state. Rejected.
4. **Neutral system surfaces and a themed lock (selected).** The splash and greeter remain product identity; the lock
   runs in the user's session and can follow the user's theme and background.

## Evidence

- [Interview decisions DEC-001–011](../technical-interviews/greeter-lock-theming_log.md) and the
  [consolidated plan](../technical-interviews/greeter-lock-theming_plan.md).
- Synthetic browser prototypes compared the current surfaces with themed variants; they are not runtime evidence.
- Guest tests with hyprlock `0.9.6` on Hyprland `0.57.0` (1920x1080, scale 1.6) used temporary configurations only:
  sourcing through `~` and a symlink applies theme variables; a missing sourced file is logged and the lock still
  starts with earlier variables; a missing image yields the solid color, not a screenshot; sizes are physical
  pixels and accept percentages; `general:fail_timeout` controls the failure display.
- Omarchy `4.0.6-1` was inspected read-only: its theme switch changes neither Plymouth nor SDDM; its lock shows one
  field over a blurred background. SDDM `0.21.0` on Arch has no Plymouth integration.

## Decision

- **Principle.** System surfaces (splash, greeter) are neutral product identity and follow no theme. User surfaces
  (desktop, lock) follow the selected theme.
- **Splash.** Unchanged.
- **Greeter.** Keeps the splash colors. The symbol is drawn statically in exactly the splash rectangle, with the
  320 px cap in device pixels. The form sits below it at 5% of the display height: the account name and selector
  only when more than one account is listed, then the password field. The keyboard layout and its hint are always
  shown in the bottom-left corner; the power control stays in the bottom-right corner. Field styling is recorded in
  DEC-003. Login submission, failure handling, layout switching and power behavior are unchanged.
- **Lock.** Shows only the password field over the user's selected background, blurred, with the theme background
  color as fallback; no clock and no keyboard layout. Each theme publishes `hyprlock.conf` color variables; the
  managed lock configuration defines literal fallbacks and then sources the theme file through the `current/theme`
  link, as Foot does. Failures show PAM's message for five seconds. Geometry is recorded in DEC-009.

This supersedes only ADR 0014's requirement to always display the selected account and ADR 0019's requirement to
preserve the existing greeter layout. All other decisions of ADR 0014, 0015, 0016 and 0019 remain in force,
including the greeter's file-read and process boundaries.

## Consequences and trade-offs

- Theme changes never touch boot artifacts or the greeter; the visual identity before login stays constant.
- The desktop and lock change with the theme while the greeter does not; this difference is intended.
- Each theme must publish `hyprlock.conf`; tests must keep it consistent with the palette.
- Following the user-controlled link means the lock trusts the selected theme's hyprlock configuration, which can run
  commands through labels. This adds no capability beyond the user-writable lock configuration and matches Foot.
  The sourced path uses the default state directory, not a custom `XDG_STATE_HOME`.
- The lock no longer shows the time.

## Replacement or reversal boundary

Reconsider this decision if the greeter must identify users before login differently, if themes need executable lock
logic, if a theme selector requires trusted-path resolution for all consumers, or if the lock provider changes.
Reverting restores the previous literal configurations without changing authentication.

## Required validation

Before adoption:

- `docs/architecture.md` and the forward links of ADR 0014 and ADR 0019 reference this decision.

After adoption:

- Automated tests cover the anchored greeter layout, single- and multi-account display, theme `hyprlock.conf`
  publication and consistency, and migration of the managed lock configuration.
- VM qualification covers real login, failed authentication, account switching, `Super+I`, power actions, locking
  with a missing background and a missing theme file, and unlocking after a PAM failure.

## References

- [Architecture](../architecture.md)
- [ADR 0014](0014-native-login-and-boot-presentation.md), [ADR 0015](0015-greeter-keyboard-layout-switching.md),
  [ADR 0016](0016-greeter-power-actions.md), [ADR 0019](0019-shared-symbol-and-live-splash.md),
  [ADR 0020](0020-wallpaper-selection.md)
- [Interview log](../technical-interviews/greeter-lock-theming_log.md)
- [Interview plan](../technical-interviews/greeter-lock-theming_plan.md)
- [Theme sources](../../capabilities/visual/theme/sources.md)
- [Lock sources](../../capabilities/desktop/lock/sources.md)

## Superseded by

`None`
