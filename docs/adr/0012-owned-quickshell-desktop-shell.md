# ADR 0012: Owned Quickshell Desktop Shell

## Identifier and title

- **Identifier:** `0012`
- **Title:** Owned Quickshell Desktop Shell

## Status

`Accepted`

## Date

`2026-10-14`

## Context and question

The MVP environment needs a bar, an application launcher, notifications, on-screen indicators for volume and
brightness, and a session menu. The architecture language table does not include QML, which Quickshell uses for its
configuration, and NFR37 requires a documented recurring need for custom code. The PRD excludes a control panel, a
welcome application, and a background management service.

The Story 4.1 technical interview observed that the Omarchy desktop shell, a possible design reference, is about
45,000 lines of QML. The questions are:

1. Should the shell surfaces be provided by separate single-purpose components, a third-party shell, a fork of an
   existing shell, or a MirrorOS-owned shell?
2. If MirrorOS owns the shell, how is its scope bounded and how is QML admitted without weakening the language
   hierarchy?

## Constraints and decision criteria

- NFR37: custom code needs a documented recurring need that simpler supported mechanisms cannot meet.
- NFR38: no proprietary configuration format without a documented, concrete gap.
- PRD exclusions: no control panel, welcome application, or background management service.
- Sustainability for a single maintainer: the shell must stay small enough to read and maintain.
- Control and a coherent premium appearance across surfaces.
- Authentication surfaces carry security risk and must not be project-owned code.
- Licensing and attribution: third-party code needs a recorded origin and license.
- The compositor remains a replaceable provider ([ADR 0011](0011-hyprland-compositor-provider.md)).

## Alternatives considered

1. **Modular single-purpose components.** A separate bar, launcher, notification daemon, and indicator tool. Each is
   small and supported upstream, but styling and behavior must be coordinated across tools, and a coherent premium
   appearance is harder to achieve and keep.
2. **Third-party Quickshell shell used as-is.** Lowest initial effort. The environment would depend on a shell
   whose scope, update pace, and structure the project does not control.
3. **Fork or vendor of the Omarchy shell.** Fast start. It imports a large QML code base that one maintainer would
   have to maintain, with a scope beyond the MVP.
4. **MirrorOS-owned minimal Quickshell shell (selected).** Gives full control over the surfaces and a coherent
   appearance. It adds a QML code base that MirrorOS must maintain, bounded to the MVP surfaces.

## Evidence

- Story 4.1 technical interview log (`docs/technical-interviews/story-4-1-mvp-environment-scope_log.md`),
  DEC-007 and DEC-008.
- Observation of the Omarchy shell size (about 45,000 QML lines), which shows the cost of an unbounded shell.
- No MirrorOS shell prototype exists yet. The replacement boundary below is the mitigation.

## Decision

MirrorOS owns a minimal Quickshell desktop shell written in QML, bounded to the MVP capabilities. Specifically:

- The shell covers the bar, the launcher, notifications, on-screen indicators (OSD), and the session menu.
- QML is admitted as a project-owned language only for this shell. It is not admitted for any other component. The
  small SDDM greeter theme named in the MVP scope is outside this ADR's shell scope and follows the MVP scope
  document.
- The NFR37 justification is control and a coherent premium appearance across surfaces, which separate components
  do not achieve equally.
- The shell excludes control-panel, welcome-application, and background-management functionality, consistent with
  the PRD exclusions.
- Authentication is never project-owned QML. The screen lock and the polkit authentication agent use existing
  supported components.
- Omarchy (MIT) is a design reference only. It is not forked, vendored, or used as-is. Any copied fragment requires
  an entry in `docs/attribution.md`.
- The shell location under `capabilities/` is not decided here. Stories 4.4 and 4.7 decide it.

## Consequences and trade-offs

- `docs/architecture.md` gains a QML row in the language table and a Language Selection item, both bounded to this
  shell.
- MirrorOS owns and maintains a QML code base for the shell surfaces. This cost is accepted for control and
  coherence.
- The shell is tied to Quickshell and to the Wayland compositor protocols it uses, so upstream changes may require
  updates.
- The bounded scope limits growth. Adding a surface outside the MVP list requires a scope change in
  `docs/mvp-scope.md`.
- Risk: no prototype exists, so the maintenance cost is unmeasured. This is accepted and covered by the boundary
  below.

## Replacement or reversal boundary

Reconsider this decision through a new ADR if the shell grows beyond the MVP surfaces, or if its maintenance cost
proves recurring, for example repeated breakage from upstream changes or time spent that exceeds the benefit. The
new ADR must cite the observed problems as evidence. Replacing the shell with separate components or a third-party
shell does not change the desktop shell capability, only its provider.

## Required validation

Before adoption:

- `docs/architecture.md` is amended to admit QML bounded to the owned shell and to reference this ADR, without
  deciding the shell location.

After adoption, through Stories 4.4 and 4.7:

- Any copied fragment from a third-party source has an entry in `docs/attribution.md`.
- The shell provides only the listed MVP surfaces and no excluded functionality.
- The screen lock and polkit agent are not project-owned QML.

## References

- [Architecture](../architecture.md)
- [MVP scope](../mvp-scope.md)
- [Story 4.1 technical interview plan](../technical-interviews/story-4-1-mvp-environment-scope_plan.md)
- [Story 4.1 technical interview log](../technical-interviews/story-4-1-mvp-environment-scope_log.md)
- [PRD](../prd.md), NFR37, NFR38
- [ADR 0011](0011-hyprland-compositor-provider.md)

## Superseded by

`None`
