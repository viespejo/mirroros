# Greeter and lock under themes — Consolidated interview plan

Date: 2026-10-29

## Agreed scope

System surfaces are neutral product identity; user surfaces follow the selected theme. The Plymouth splash is
unchanged [DEC-001]. The greeter keeps the splash's neutral colors and follows no theme [DEC-002]. The lock follows
the theme and the user's selected background [DEC-008, DEC-011]. The splash-to-greeter handoff is unchanged
[DEC-006]. Authentication, PAM, faillock policy, keyboard-layout switching and confirmed power semantics are
unchanged.

The greeter changes require a normative amendment of ADR 0014 (always displaying the selected account) and ADR 0019
(preserving the existing greeter layout). The amendment is proposed as
[ADR 0021](../adr/0021-neutral-greeter-and-themed-lock.md).

## Greeter

- The symbol occupies exactly the splash rectangle, statically; the 320 px cap is computed in device pixels.
  [DEC-003]
- Below it, separated by 5% of the display height: the account name and selector only with more than one account
  [DEC-004], then a 280x44 password field with a 1 px border at 35% foreground opacity (85% while typing or
  authenticating), fill `#15191c` and failure `#a55555`. [DEC-003]
- Bottom-left: the active keyboard layout and `Super+I` hint, always shown, de-emphasized [DEC-005].
  Bottom-right: the unchanged power control.

## Lock

- Only the password field: no clock and no keyboard layout. [DEC-007]
- Background: `current/background`, `blur_passes = 3`, `blur_size = 8`, `brightness = 0.9`; theme background color
  as fallback. [DEC-008]
- Field 378x57 logical pixels with a 3 logical-pixel accent border, converted to physical pixels from the focused
  monitor's scale when locking (fallback `31.5%, 8.4%` and 5 px), no rounding, theme background at 80%, placeholder
  `Enter Password` in the foreground at 60%. [DEC-009, DEC-012]
- Failure: `<i>$PAMFAIL</i>`, no attempt counter, `general:fail_timeout = 5000`. [DEC-010]
- Colors: literal fallbacks, then `source = ~/.local/state/mirroros/current/theme/hyprlock.conf`; each theme
  publishes that file. [DEC-011]

## Evidence

Synthetic browser prototypes compared the current surfaces with themed variants; they are not runtime
qualification. Guest tests used hyprlock `0.9.6` and Hyprland `0.57.0` at 1920x1080, scale 1.6, with temporary
configurations under `~/.cache` that were removed afterwards; no product file was changed:

| Test | Result |
|---|---|
| T1 | Theme variables sourced through `~` and a symlink apply; a missing background image yields the solid color, not a screenshot. |
| T2 | A missing sourced file is logged; hyprlock still locks with variables defined before `source`. |
| T3 | The selected background is followed through `current/background`; percentage sizes are accepted. |
| T4 | `size` is in physical pixels; `input-field:font_size` does not exist; Pango placeholder markup applies. |
| T5 | `<i>$PAMFAIL</i>` shows `Authentication failed`; `input-field:fail_timeout` does not exist. |
| T6 | `general:fail_timeout = 5000` keeps the failure readable; the maintainer accepted the result. |
| T7 | After installation, a Pango `size` attribute in the placeholder is ignored; a 5 px border matches Omarchy's 3 logical pixels at scale 1.6. |
| T8 | A `31.5%, 8.4%` field brings the text close to Omarchy's; the maintainer accepted it. |

During T4, repeated failures triggered `pam_faillock` (10 minutes); `$PAMFAIL` then reports the remaining time.

## Unresolved implementation details

- Delivery of the theme `hyprlock.conf` through the theme publisher and manifest, with tests keeping it consistent
  with `colors.toml`.
- Migration of the managed `~/.config/hypr/hyprlock.conf` from the currently shipped content, preserving modified
  files and links.
- Device-pixel cap and anchored layout in `Main.qml`, single-account behavior in `LoginModel.js`, and their tests.
- Updates to `desktop/lock/sources.md`, `desktop/login/sources.md`, procedures and attribution with the change.
- VM qualification: real login, failed authentication, two-account selection, `Super+I`, power actions, lock with a
  missing background and a missing theme file.

Investigate code-answerable details directly; ask the maintainer only about consequential alternatives.

## Final plan state

Not yet approved or materialized.
