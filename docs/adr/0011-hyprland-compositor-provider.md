# ADR 0011: Hyprland Compositor Provider

## Identifier and title

- **Identifier:** `0011`
- **Title:** Hyprland Compositor Provider

## Status

`Accepted`

## Date

`2026-10-14`

## Context and question

The PRD, the product brief, `docs/architecture.md`, and `docs/epics.md` name Niri as the provisional Wayland
compositor of the MVP environment. The architecture already treats the compositor as a replaceable provider beneath
a compositor provider boundary, and states that Niri cannot become an architectural dependency.

The Story 4.1 technical interview concluded that Hyprland is the compositor the maintainer intends to use for the
daily environment. No code, package list, or configuration in the repository depends on Niri. The question is which
compositor the documents must name as the provisional provider, and how that choice relates to the PRD and product
brief, which are not rewritten.

## Constraints and decision criteria

- The compositor remains a replaceable provider; the architectural capability is the Wayland compositor and
  graphical session, not a specific product.
- NFR27–NFR33: MVP compatibility is limited to one VM and one laptop, and provider-specific configuration stays
  isolated.
- NFR33: replaceable providers must not become architectural dependencies.
- Native application formats remain authoritative. Hyprland has been configured in Lua since 0.55, and the
  hyprlang format is deprecated.
- Sustainability for a single maintainer: the provider must be one the maintainer will actually use and maintain.
- The PRD and product brief stay unchanged; the precedent of ADR 0010 is that an accepted ADR prevails over
  unchanged PRD wording.

## Alternatives considered

1. **Keep Niri as the provisional provider.** Matches the existing documents and needs no amendment. It does not
   match the compositor the maintainer intends to use daily, so the documents would name a provider that will not be
   built.
2. **Leave the provider pending.** Avoids a decision before exploration. It blocks Stories 4.4 and 4.7 and keeps a
   contradiction between the documents and the intended environment.
3. **Select Hyprland as the provisional provider (selected).** Aligns the documents with the intended environment
   while preserving the provider boundary, so a later replacement stays a bounded change.

## Evidence

- Story 4.1 technical interview log (`docs/technical-interviews/story-4-1-mvp-environment-scope_log.md`),
  DEC-003 and DEC-004.
- No prototype was run in the repository and no comparative measurement exists. The choice follows the
  maintainer's daily-use intent, and the replacement boundary below is the mitigation.

## Decision

Hyprland is the provisional compositor provider of the MVP environment, placed beneath the compositor provider
boundary. Specifically:

- Hyprland is not the architectural capability. The capability remains the Wayland compositor and graphical
  session.
- Niri is an uncommitted future trial. It is not a planned provider and creates no obligation.
- Hyprland configuration is tool-owned Lua, since Hyprland 0.55 configures through Lua. Hyprland replaces Niri as
  the tool-owned Lua example in the architecture.
- This ADR prevails over the Niri mentions in `docs/prd.md` and `docs/product-brief-mirroros.md`, which stay
  unchanged.
- The PRD-derived NFR33 copy in `docs/epics.md` keeps its PRD wording.
- `docs/architecture.md` and the affected stories in `docs/epics.md` name Hyprland and reference this ADR.

## Consequences and trade-offs

- The architecture, the MVP scope list, and Stories 4.1 and 4.4 name Hyprland instead of Niri.
- The PRD and product brief keep stale Niri wording; readers must follow this ADR as the normative source. This is
  accepted to avoid rewriting source documents.
- Hyprland-specific configuration must stay isolated under the compositor provider path so that replacement does
  not touch other capabilities.
- Risk: the choice is made without repository-level comparative evidence. This is accepted because the provider is
  replaceable and covered by the boundary below.

## Replacement or reversal boundary

Replacing Hyprland requires a new ADR that cites the observed problems, such as recurring maintenance cost,
instability on the target hardware, or loss of a required capability. The compositor capability does not change
when the provider changes. Trying Niri or another compositor in exploration does not by itself require an ADR, but
adopting it into MirrorOS does.

## Required validation

Before adoption:

- `docs/architecture.md` is amended so that it names Hyprland, references this ADR, and reserves
  `desktop/compositor/providers/hyprland/`.
- `docs/epics.md` Stories 4.1 and 4.4 and the Additional Requirements name Hyprland.

After adoption, through Story 4.4:

- A clean installation followed by `configure` yields a functional Hyprland graphical session in the VM.
- Hyprland-specific configuration remains isolated under the provider path.

## References

- [Architecture](../architecture.md)
- [Epics](../epics.md), Stories 4.1 and 4.4
- [Story 4.1 technical interview plan](../technical-interviews/story-4-1-mvp-environment-scope_plan.md)
- [Story 4.1 technical interview log](../technical-interviews/story-4-1-mvp-environment-scope_log.md)
- [PRD](../prd.md), NFR27–NFR33
- [ADR 0010](0010-environment-configuration-mechanism-and-scope.md), the precedent for an ADR prevailing over
  unchanged PRD wording

## Superseded by

`None`
