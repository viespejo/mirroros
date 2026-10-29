# ADR 0020: Wallpaper Display and Selection

## Identifier and title

- **Identifier:** `0020`
- **Title:** Wallpaper Display and Selection

## Status

`Accepted`

## Date

`2026-10-29`

## Context and question

The maintainer requested an Omarchy-inspired wallpaper experience: product and personal images, a visual selector, live changes, persistence and a next-image action. A theme manager is out of scope.

ADR 0012 excludes background management from the owned shell; the PRD excludes a background management service. A dynamic selector is more than static presentation. Should the shell's scope be extended for this bounded capability, and how should that extension relate to these exclusions?

## Constraints and decision criteria

- Preserve personal images and state; do not overwrite unknown files or links.
- Review provenance, distribution rights and attribution before publishing assets or copied material.
- Support multiple outputs and output changes without interfering with windows or keyboard focus.
- Missing or invalid selections must not prevent the shell or desktop from starting.
- Keep the shell maintainable; do not introduce a general theme manager or background management platform.
- NFR37 requires a documented recurring need that simpler supported mechanisms cannot adequately meet.

## Alternatives considered

1. **Existing wallpaper and selection tools.** Preserve the shell boundary, but introduce processes or dependencies and require integration for the requested interaction. Practical comparative evidence remains incomplete.
2. **Bounded display and selector in the owned shell (selected).** Reuse Quickshell and integrate the interaction, at the cost of extending its scope and maintenance obligations.
3. **Static image only.** Smaller scope, but does not meet personal selection and cycling requirements.

## Evidence

- The Omarchy reference uses Quickshell background surfaces and a separate selector. Its implementation is a design reference, not proof of suitability or permission to copy without attribution.
- Temporary Quickshell probes in the authorized guest demonstrated background placement and image loading on one output, and completion of a transition and a rapid valid/missing/valid sequence. They did not establish multi-monitor behavior, persistence, selector interaction or deployment readiness.
- Existing tools document various display and transition functions, but practical comparisons and a complete maintenance assessment remain open. The [research record](../technical-interviews/wallpaper-selection-research.md) contains the observations, limitations and comparison protocol.
- The approved default image was reproduced from a recovered generator; durable delivery, provenance and rights for the selected assets remain under review.

## Decision

Extend the owned Quickshell shell with a bounded wallpaper display and selector, including product and personal images, persistent selection, transitions, a next-image action, limited IPC and multi-monitor support. A theme manager, theme-switching gestures, arbitrary command execution, network image acquisition and a separate wallpaper daemon are outside the proposal.

This ADR amends ADR 0012's background-management exclusion only for this capability. Its other exclusions, authentication rules and QML and compositor-provider boundaries remain in force. It prevails over the PRD's unchanged background-management-service exclusion only for the bounded capability in the existing shell; a separate background management service remains excluded. The MVP scope records the capability under Story 4.8, and the architecture references this amendment.

The maintainer accepts the incomplete practical comparison as a risk: an existing shell avoids another daemon, while separate tools still require integration for the requested selector and gesture. This is the recurring need supporting NFR37, not a measured claim that every alternative is less maintainable. Real output lifecycle and recovery evidence remains a deployment gate.

## Consequences and trade-offs

The shell would gain a surface, selector and state-management responsibility. The project must maintain output lifecycle, recovery and IPC, and define safe asset publication and personal-state ownership. Personal images remain user data. No general Omarchy compatibility is implied.

## Replacement or reversal boundary

Reconsider the decision if the selector becomes a general theme or desktop management platform, if lifecycle or output handling repeatedly breaks, or if a supported existing tool meets the requirements with materially lower maintenance.

## Required validation

Before deployment: review source and asset rights and attribution; test publication and personal-state conflicts, missing or invalid images, selection and cycling, IPC failure, multiple outputs and hotplug, startup and recovery. Validate visual behavior in an authorized session and document the user-facing contract. Record versions, results and untested scenarios in the research record. Offscreen and logic tests alone cannot establish Wayland output, focus or visual behavior.

## References

- [Wallpaper selection research](../technical-interviews/wallpaper-selection-research.md)
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [ADR 0011: Hyprland Compositor Provider](0011-hyprland-compositor-provider.md)
- [Architecture](../architecture.md)
- [MVP scope and change control](../mvp-scope.md)
- [PRD](../prd.md)
- [Attribution](../attribution.md)

## Superseded by

`None`
