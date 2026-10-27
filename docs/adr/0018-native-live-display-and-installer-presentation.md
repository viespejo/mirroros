# ADR 0018: Native Live Display and Installer Presentation

## Identifier and title

- **Identifier:** `0018`
- **Title:** Native Live Display and Installer Presentation

## Status

`Accepted`

## Date

`2026-10-27`

## Context and question

The maintainer rejected the live 720p preference after further visual exploration and approved a minimal
installer welcome with a standalone reflection symbol, the existing login/lock background and foreground,
a new blue-gray selection accent, native Gum help, and an optional text-size selector. The previous
requirement to reproduce the frozen reference's presentation must not prevent this explicitly approved change.

## Constraints and decision criteria

- Use the kernel/firmware display choice; add no runtime modesetting, forced driver, or display daemon.
- Keep installation planning, confirmation, credentials, and disk-operation boundaries unchanged.
- Change only live installer presentation, not installed boot parameters or graphical scaling.
- Preserve the exact console font and mapping captured on entry; do not substitute a packaged font based
  on a partial glyph match. Font changes are temporary and local to the current virtual console.
- Keep the frozen prototype unchanged and retain attribution for adapted screen text and behavior.

## Alternatives considered

1. Retain the 720p preference and native recovery entry: rejected by the maintainer.
2. Choose packaged fonts at several sizes: rejected because matching ASCII does not establish matching
   arrows, block glyphs, or the complete mapping.
3. Preserve firmware/kernel display choice with optional doubling of the captured font: selected.
4. Introduce a graphical installer or a custom font generator: outside scope.

## Evidence

The disposable preview was reviewed on the MirrorOS live VM at a framebuffer size of 2387x1303, with
an original 16x32 font and a 149x40 console. The system accepted a doubled 32x64 font, approximately
74x20 cells. These are exploratory observations, not qualification of a rebuilt artifact or physical hardware.
The maintainer approved the welcome and explicitly withdrew the 720p decision on 2026-10-27.

The selected symbol has two offset stepped facets with an open center, rendered with full-block
characters alone and centered on the screen independently of the form. Native Gum help was observed to
distinguish keys from descriptions with `COLORTERM=yes`; removing that variable lost the distinction.
An earlier transient overly-blue initial render was not separately proven resolved.

## Decision

Supersede ADR 0017 in full. The single normal live entry in systemd-boot and both retained GRUB
configurations carries no MirrorOS `video=` request. Remove the now-redundant native-display alternative.
This preserves the firmware/kernel choice, not a guarantee of native panel resolution. GRUB retention
still does not qualify Ventoy or another boot path.

Amend ADR 0006's kernel-default-font consequence only: the initial font stays unchanged, but the welcome
offers **Change text size**, with **Original** and **Original x2**. Capture the current console's exact font
and mapping in a private temporary file before offering changes. Original reloads that file; Original x2
uses native `setfont -d` on the same file. Repeated choices never compound doubling. Restore the saved
font on normal exit, cancellation, or handled interruption before removing the temporary file. Failure to
capture or load a font must be reported, never represented as success. Forced termination or console/kernel
failure cannot promise cleanup. No font is persisted or copied to the installed system.

Approve the shared installer visual baseline: background `#101315`, foreground `#CACCCC`, error red
`#A55555`, secondary gray `#8C9698`, and experimental interaction accent `#8FAFC1`. Palette changes remain
VT-only. The standalone symbol is centered on the screen; the form uses an independently centered
80-column area. Gum selection uses an accent-colored cursor and text, without inverse video. Gum's own
help is retained, with forced color and `COLORTERM=yes` after the existing terminal gate.

The welcome title is **Welcome to MirrorOS**, followed by **Let's set up your machine.**, the current
**Installation keyboard: <label>**, and **Used only during installation.** The options are **Continue**,
**Change keyboard layout**, and **Change text size**, separated from the prose by a blank line.
Continue retains the existing preparation/discovery flow and grants no authorization. Keyboard changes
retain their live-only behavior; the installed-system keyboard choice remains separate.

The welcome and its text-size selector omit the symbol below 32 console rows. This is a limited
safeguard, not a claim of responsive layout for every screen. Other screens remain subject to individual
review; their approval is not implied by adoption of the shared visual baseline. Long review content,
warning wrapping, pagination, and complete usability at doubled size remain pending.

The console symbol is a new installer-owned asset. The existing `banner.txt` remains the historical
wordmark source used to verify the graphical wordmark. Neither the graphical asset nor the greeter,
splash, or lock screen is changed by this decision; ADR 0014's installed presentation remains in force.

## Consequences and trade-offs

No new package or runtime language is introduced. Small text can remain small until the user selects a
larger size. Doubled text reduces available rows and columns and may overflow screens not yet reviewed.
Visual approval is not release qualification, installation authorization, or approval of every screen.

## Replacement or reversal boundary

Revisit through an ADR if display modes are requested again, packaged/generated fonts replace the saved
font, installed presentation changes, or another rendering technology is introduced. Responsive layout
work must preserve complete warnings and confirmation boundaries rather than truncate them to fit.

## Required validation

- Static contracts verify one live entry per loader, unchanged live-root arguments, no display request,
  no installed-system display/font policy change, and unchanged automatic-startup font behavior.
- Presentation tests verify centering, selection settings, real welcome text and navigation, absolute
  font choices, failure propagation, and restoration before temporary-file cleanup.
- Exercise the production presentation safely on the live console with synthetic data; do not run the
  installer engine for visual review. Recheck initial selection colors and native help after integration.
- Before promotion, build and boot the changed artifact, inspect effective display/font geometry, test
  cancellation and restoration, and review remaining screens, long values and warnings. Physical
  qualification remains separate. No build, VM launch, or disk operation is authorized by this ADR.

## References

- [Architecture](../architecture.md)
- [ADR 0004](0004-interactive-presentation-with-gum.md)
- [ADR 0006](0006-guided-live-installation-boundaries.md)
- [ADR 0014](0014-native-login-and-boot-presentation.md)
- [Superseded ADR 0017](0017-live-console-display-preference.md)
- [Installation confirmation contract](../../contracts/installation-confirmation.md)
- [Install procedure](../procedures/install.md#live-display-and-text-size)

## Superseded by

`None`
