# ADR 0027: Display Panel Mirror Toggle

## Identifier and title

- **Identifier:** `0027`
- **Title:** Display Panel Mirror Toggle

## Status

`Accepted`

The maintainer accepted this architectural decision on 2026-11-08 at the plan 02-27 T14s checkpoint, together with
restoring the external output's layout when mirroring ends. Implementation and validation remain with plan 02-27.

## Date

`2026-11-08`

## Context and question

[ADR 0025](0025-shell-panels.md) admits a bar-anchored display panel adapted from Omarchy 4.5. Its Decision lists
the panel content as "**Display:** brightness, output enable and disable with a last-display guard, and scale". The
Omarchy `v4.5.0` monitor panel (`shell/plugins/panels/monitor/Panel.qml`) has no mirroring control either.

Mirroring already exists outside the panel. Plan 02-25 delivered the owned Hyprland `display` helper with a
runtime-only `display mirror` toggle (the internal display is mirrored onto the active external output; a second call
detaches it), bound to `SUPER+CTRL+ALT+Delete`. Plan 02-27 serialized every mutating `display` subcommand under one
runtime lock and added `display state`, which reports the mirror source of each output.

During the plan 02-27 supervised T14s checkpoint (2026-11-08) the maintainer validated the display panel and asked
for the mirror toggle in the panel itself, because the chord is hard to discover and the panel already shows the
outputs it would affect. [`docs/adr/README.md`](README.md) forbids rewriting an accepted decision.

The question is: may the display panel offer the existing mirror toggle, and within which boundary?

## Constraints and decision criteria

- ADR 0025's remaining decisions stay in force, including no general control panel in the shell.
- ADR 0012's exclusions apply: no resident shell daemon.
- The panel acts as the session user through owned commands; no privilege is added.
- Display changes from the panel stay runtime-only: nothing writes `monitors.lua`, `personal-monitors.lua` or other
  user configuration (plan 02-25 boundary).
- Reuse the existing command and its lock instead of adding panel-side display logic.

## Alternatives considered

1. **Panel toggle over the existing `display mirror` (selected).** One control, no new command semantics, shares the
   lock and settle logic already validated for the chord.
2. **Keep mirroring keyboard-only.** No change, but the function stays hidden from the panel that lists the outputs.
3. **General mirror source/target selection.** Covers more than one external output, but needs new command
   semantics and validation the supported hardware does not exercise.
4. **Monitor arrangement editor with persistence.** Also requested by the maintainer, but persisting a layout means
   writing user display configuration, which the plan 02-25 boundary excludes; it needs its own decision.

## Evidence

- Plan 02-27 T14s checkpoint record (ignored `evidence/shell-panels/t14s-02-27/`): the display panel checks pass,
  including disabling a mirror source after `display mirror`.
- The owned helper `capabilities/desktop/compositor/providers/hyprland/display` (`mirror`, `state`, runtime lock) and
  its tests in `tests/capabilities/desktop/hyprland/display.test.mjs`.
- The Omarchy `v4.5.0` monitor panel source, read from the pinned upstream reference, has no mirror control.

No laboratory or hardware evidence exists yet for the panel control; validation belongs to plan 02-27.

## Decision

- **Mirror toggle:** the display panel gains a mirror toggle that runs `display mirror` as the session user. It is
  shown only when an internal display and an enabled external output exist, reflects the mirror state reported by
  `display state`, and ignores repeated activation while an action is pending.
- **Boundary:** the toggle is runtime-only, like every other display panel action. It mirrors the internal display
  onto the active external output exactly as the existing chord does; it adds no source or target selection and
  writes no display configuration.
- **Layout restore:** when `display mirror` starts mirroring, it records the external output's runtime mode,
  position and scale in the session runtime directory; when a mirror of that output is detached (by the toggle, the
  chord, or before disabling its source), the recorded values are reapplied at runtime. Without a valid record the
  helper only detaches the mirror. The record is runtime state, not configuration, and disappears with the session.

This ADR supersedes only ADR 0025's "Display" panel-content item, extending it with the mirror toggle. Every other
part of ADR 0025 remains in force. A monitor arrangement editor is not admitted by this ADR.

## Consequences and trade-offs

- The panel gains one owned control in the adapted `Monitor.qml`, recorded as a MirrorOS divergence in the shell
  `UPSTREAM.md`.
- While mirrored, the external output uses Hyprland's automatic position and scale 1; after detaching it returns to
  the layout it had before mirroring, including runtime changes such as a panel-chosen scale, without a
  configuration reload.
- A mirror started before this change, or whose record is missing or invalid, is only detached; the configured
  layout then returns on the next configuration reload or session.
- Setups with more than one external output keep the helper's first-enabled-external choice.

## Replacement or reversal boundary

Reconsider through a new ADR if mirroring needs source or target selection, if a persistent monitor layout becomes a
product function, or if the runtime mirror path breaks recurrently on supported hardware.

## Required validation

In plan 02-27, after acceptance:

- Model tests for when the toggle is shown and its on/off state derived from `display state`.
- Laboratory guest with a single output: the toggle is absent and no mirror action can be triggered.
- T14s with an external monitor: toggle on and off from the panel, state reflected after each action, the
  last-display guard still applies, and detaching restores the maintainer's personal layout (position and scale)
  from the chord as well as from the panel.
- Helper tests for recording on mirror, restoring on detach (toggle and source disable), and ignoring a missing,
  foreign or malformed record.

## References

- [ADR 0025: Shell Panels](0025-shell-panels.md)
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [Hardware procedure](../procedures/hardware.md)
- [Story 4.4 panel infrastructure technical interview log](../technical-interviews/story-4-4-panel-infrastructure_log.md)

## Superseded by

`None`
