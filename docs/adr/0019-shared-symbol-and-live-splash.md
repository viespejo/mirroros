# ADR 0019: Shared Symbol and Live Splash

## Identifier and title

- **Identifier:** `0019`
- **Title:** Shared Symbol and Live Splash

## Status

`Accepted`

## Date

`2026-10-27`

## Context and question

The maintainer approved extending the installer reflection symbol to the static SDDM greeter and matching
installed-system and live Plymouth splashes. ADR 0014 selected the historical wordmark, a static-only splash,
and configure-owned installed integration. ADR 0018 deliberately left graphical surfaces unchanged.
This decision narrowly amends those boundaries; it does not rewrite their historical evidence.

## Constraints and decision criteria

- Preserve authentication, PAM, login submission, keyboard switching, and confirmed power semantics.
- Preserve installation planning, confirmation, credentials, engine, and authorization.
- Preserve storage, resume, snapshots, bootloader editor policy, firmware/kernel display choice, and font policy.
- Keep native details and Esc diagnostics available; never delay boot completion for animation.
- No lock-screen redesign, new text, progress indicator, visual variant, or runtime font dependency.
- Generated rasters remain outside source control. Builds, VM launches, installation, service and power operations
  require separate authorization.

## Alternatives considered

1. Retain the historical wordmark and installed-only static splash: does not implement the approved identity.
2. Adopt the symbol with static or single-fade splashes: considered in synthetic comparison but not selected.
3. Share the symbol with a static greeter and matching fade-plus-pulse splashes: selected by DEC-005.
4. Introduce a custom renderer or boot supervisor: unnecessary and outside the native presentation boundary.

## Evidence

[Interview decisions DEC-001–005](../technical-interviews/installer-symbol-boot-greeter_log.md) establish the
three surfaces, square proportions, existing size bounds, and reviewed animation. DEC-003 and DEC-004 describe
synthetic comparisons, not runtime qualification. DEC-005 approves the browser preview's effect, not real
Plymouth timing, boot lifecycle, a rebuilt ISO, or physical hardware.

The graphical source derives cell-for-cell from `install/confirmation/symbol.txt`. The historical banner and
wordmark remain unchanged. No external theme code or graphical material is incorporated by this decision.

## Decision

- **Shared symbol (DEC-001, DEC-002).** Use one font-independent 16x16-unit SVG, with each terminal cell occupying
  1x2 units, foreground `#CACCCC` and transparent background. Render a 320x320 PNG. Both splash consumers and SDDM
  use this graphical source on `#101315`, centered without deformation, no upscaling, bounded by 22% of display
  height and 42% of display width. Preserve historical banner and wordmark assets under their existing names.
- **Static greeter (DEC-001, DEC-005).** Change the asset only; preserve existing layout and behavior.
- **Splash animation (DEC-005).** Both splashes fade in once over 400 ms, then pulse smoothly between 75% and 100%
  opacity over a two-second cycle of active elapsed time. Use Plymouth's native refresh callback to update
  opacity. The native boot-progress callback is permitted solely as a source of elapsed `duration`; ignore its
  percentage entirely. No frame counting, sleeps, helpers, shell execution, or blocking loops are permitted.
  The first duration sample establishes the animation origin; native timing pauses freeze the effect and are
  excluded from elapsed time. Plymouth controls shutdown and quit without waiting for a cycle; diagnostics
  remain native. If the native API cannot reproduce the effect, stop and report the incompatibility instead
  of substituting another design.
- **Installed ownership.** Configure retains atomic branding delivery, conflict protection, pending/complete
  boot-image regeneration, and installed integration. Intact previous deliveries migrate; edited deliveries
  remain protected. Delivery identity includes both graphical sources, renderer version, and raster sizes;
  an unchanged rerun renders nothing.
- **Live ownership.** Image construction prepares the same theme and symbol from the captured embedded
  capabilities snapshot in a container-local writable profile. Captured `/profile` remains read-only. Render
  with container librsvg and reuse branding validation; never run configure on live. Preparation failure stops
  before mkarchiso. Add the Plymouth hook after udev without reordering other hooks, and `quiet splash` exactly
  once to normal boot paths while preserving live-root arguments, technical paths, serial/NoCloud operation,
  and automatic installer startup. No display-mode request or newly enabled boot editor is permitted.

This supersedes only ADR 0014's historical-wordmark selection, static-only splash restriction, and installed-only
integration boundary, and ADR 0018's exclusion of graphical changes. All unrelated decisions remain in force,
including ADR 0015's keyboard switching and ADR 0016's confirmed power proxy boundary. The lock screen and
historical prototypes are unchanged; LUKS encryption and autologin remain deferred.

## Consequences and trade-offs

MirrorOS maintains one shared symbol and native animation logic, plus a bounded live preparation stage. Fast boots
may show only part of the fade; boot must not be prolonged to display it. The approved execution amendment
allows the boot-progress callback's duration only: upstream schedules it nominally at 30 Hz independently of
status messages, using a native clock minus paused intervals. The refresh callback has no elapsed-time argument
or script-accessible clock; frame counting would not preserve timing under dropped refreshes. The effect is
sampled, not a hard real-time guarantee. Synthetic doubles can verify equations and contracts, but cannot establish
actual native timing, diagnostic access, or hardware behavior.

## Replacement or reversal boundary

A different effect, additional surfaces, authentication logic, diagnostic suppression, boot delays, or a new
rendering technology requires another ADR. Reversal must preserve native diagnostic and no-splash recovery paths
without altering storage or authentication policy.

## Required validation

- Verify exact symbol silhouette, square dimensions, atomic migration, edited-delivery protection, render failure
  recovery, both-source identity, and unchanged reruns.
- Test native-API doubles with controlled elapsed time for fade endpoints, pulse extrema/period, resize bounds,
  percentage independence, native timing pauses, and absence of blocking completion logic. Doubles do not
  qualify real Plymouth.
- Test installed regeneration and live preparation identity, read-only source preservation, stage ordering,
  failure propagation, preserved boot parameters, display/font boundaries, and installer startup.
- Document Esc diagnostics and one-boot removal of `quiet splash` using existing editor behavior only.
- Rebuilt-ISO boot, real Plymouth and greeter, attended Esc/cancellation and animation checks remain pending until
  individually authorized and performed. Physical-hardware qualification remains separate.

## References

- [Architecture](../architecture.md)
- [ADR 0014](0014-native-login-and-boot-presentation.md)
- [ADR 0018](0018-native-live-display-and-installer-presentation.md)
- [Interview plan](../technical-interviews/installer-symbol-boot-greeter_plan.md)
- [Branding sources](../../capabilities/visual/branding/sources.md)
- [Plymouth native callbacks](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/plugins/splash/script/script-lib-plymouth.c)
- [Plymouth duration scheduling](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/libply-splash-core/ply-boot-splash.c)
- [Plymouth active elapsed clock](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/libply/ply-progress.c)

## Superseded by

`None`
