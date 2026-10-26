# ADR 0016: Greeter Power Actions

## Identifier and title

- **Identifier:** `0016`
- **Title:** Greeter Power Actions

## Status

`Accepted`

## Date

`2026-10-28`

## Context and question

The maintainer requests restart and shutdown from the installed greeter without disrupting its minimal login
layout, and approves one discreet bottom-right power control, a small menu and explicit confirmation.
[ADR 0014](0014-native-login-and-boot-presentation.md) explicitly excludes power menus, so this extension requires
a new decision rather than an unrecorded theme change.

## Constraints and decision criteria

- Keep the centered wordmark, account, password and layout unchanged.
- SDDM remains the authority for authentication, sessions and system power requests.
- No theme process execution, new helper, service, privilege grant or policy override.
- Mouse and keyboard access, explicit confirmation and cancellation without a power request.

## Alternatives considered

1. **Keep power actions absent.** Smallest interface, but requires leaving the graphical greeter for a routine task.
2. **Two permanent action buttons.** Discoverable but adds visual weight to the login surface.
3. **One discreet control with a menu and confirmation (selected).** Adds one peripheral control; actions require
   deliberate selection and confirmation rather than a single click or key press.

## Evidence

SDDM v0.21.0's native [GreeterProxy.h](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/GreeterProxy.h)
exposes `canReboot`, `canPowerOff`, `reboot()` and `powerOff()`. Its
[GreeterProxy.cpp](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/GreeterProxy.cpp) receives capabilities
from the daemon and forwards requests over SDDM's socket. These are existing provider interfaces, not a new
privileged MirrorOS execution boundary. No upstream theme code or asset is copied.

## Decision

- Extend only ADR 0014's exclusion of power menus: the owned theme may offer **Restart** and **Shut down** through
  `sddm.reboot()` and `sddm.powerOff()` respectively. No other power action is admitted.
- Show one low-emphasis power icon at the bottom right, outside the centered login content. Hide unavailable
  actions according to SDDM's capability flags; hide the control when neither action is available.
- Selecting an action opens a compact confirmation in the same panel, with **Cancel** focused by default.
  Enter or Space activates the focused control. Escape, Cancel or clicking outside closes the panel without a
  request and restores focus to the power control (or the password field if the control is unavailable).
- Opening the menu clears the password and closes account selection. Login submission is blocked while the menu
  is open; power controls are disabled while authentication is pending. Recheck capabilities before dispatch and
  consume confirmation before issuing exactly one proxy call. Do not report an unobserved power outcome as success.
- SDDM and the system retain their existing authorization, inhibitor and active-session behavior. The theme does
  not force a transition or change policy. All other ADR 0014 and ADR 0015 boundaries remain in force.

## Consequences and trade-offs

- The theme gains a small transient power panel, without a clock, settings or additional management surface.
- A failed or inhibited request has no dedicated completion signal in this proxy API; the greeter remains usable
  and users may deliberately retry. There is no automatic retry or forced fallback.
- Existing configure delivery publishes the updated theme; no package, service or privilege change is required.

## Required validation

- Synthetic SDDM tests cover capability combinations and revocation, mouse and keyboard access, explicit
  confirmation of each action, cancellation, repeated activation, and exclusion during authentication.
- Existing login, layout, theme delivery and idempotency tests must keep passing; lint diagnostics remain reviewed.
- Attended disposable-VM checks must verify the icon and panel at small and normal resolutions, keyboard-only
  operation, cancellation, and real restart and shutdown. Automated stubs do not qualify system power behavior.

## References

- [Architecture](../architecture.md)
- [ADR 0014](0014-native-login-and-boot-presentation.md), [ADR 0015](0015-greeter-keyboard-layout-switching.md)
- [Login sources and ownership](../../capabilities/desktop/login/sources.md)
- [Greeter procedure](../procedures/greeter-plymouth.md)

## Superseded by

`None`
