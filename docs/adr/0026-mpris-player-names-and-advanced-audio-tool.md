# ADR 0026: MPRIS Player Names and Advanced Audio Tool

## Identifier and title

- **Identifier:** `0026`
- **Title:** MPRIS Player Names and Advanced Audio Tool

## Status

`Proposed`

## Date

`2026-11-07`

## Context and question

[ADR 0025](0025-shell-panels.md) admits a bar-anchored audio panel adapted from Omarchy 4.5. Its Decision states
"Media service: none. The `playerctl` command boundary from plan 02-25 stays; MPRIS labels are deferred", and its
consequences record that "without a media service, the mixer shows PipeWire stream names rather than player
metadata". It does not list an advanced audio tool or a panel button to launch one.

The plan 02-27 technical interview (DEC-032, DEC-033) inventoried the Omarchy 4.5 audio panel and found:

- MPRIS in the 4.5 mixer contributes only the player name (`player.identity` or `desktopEntry`, for example replacing
  a generic `audio-src` stream name), not track metadata. It uses the native `Quickshell.Services.Mpris` module and
  matching in the panel `Model.js`. Only active-player highlighting needs Omarchy's `omarchy.media` service.
- The panel lacks per-application device routing, card profiles (HDMI, Bluetooth A2DP/HFP), port selection, balance,
  over-amplification and latency offset. The maintainer uses `pavucontrol` daily for these; Omarchy Quattro removed
  `pavucontrol` and `wiremix`, so no upstream path remains for them.

[`docs/adr/README.md`](README.md) forbids rewriting an accepted decision. The questions are:

1. May the audio panel mixer label streams with MPRIS player names without a shell media service?
2. Which tool covers the advanced audio functions the panel lacks, and how is it reached from the panel?

## Constraints and decision criteria

- ADR 0025's remaining decisions stay in force, including "no shell media service" and the `playerctl` boundary.
- ADR 0012's exclusions apply: no resident shell daemon, no general control panel in the shell.
- Prefer native Quickshell services and supported Arch packages over owned code (NFR37).
- The panel acts as the session user; no privilege is added.
- Copied upstream behaviour is preserved where it costs nothing extra on the supported hardware.

## Alternatives considered

1. **Native MPRIS player names and `pavucontrol` with a panel button (selected).** Keeps the 4.5 mixer labelling at
   no service cost and covers advanced functions with a supported upstream tool. Adds `pavucontrol` and its GTK4
   stack to the image.
2. **Keep ADR 0025 unchanged.** The mixer shows PipeWire stream names, often generic, and advanced functions have no
   graphical path from the panel.
3. **Adopt Omarchy's `omarchy.media` service for names and highlighting.** Brings a shell media service that
   ADR 0025 excludes.
4. **Reimplement advanced controls in the panel.** Grows the panel towards a general control panel and adds owned
   QML for functions a supported tool already provides.
5. **`wiremix` or another terminal mixer.** Removed from Omarchy Quattro as well; a terminal path does not match the
   panel's graphical entry point.

## Evidence

- [Story 4.4 panel infrastructure technical interview log](../technical-interviews/story-4-4-panel-infrastructure_log.md),
  DEC-032 (audio inventory, MPRIS scope correction, `pavucontrol` usage) and DEC-033 (reconciliation with ADR 0025).
- The Omarchy `v4.5.0` audio panel source (`shell/plugins/panels/audio/{Panel.qml,Model.js}`), read from the pinned
  upstream reference.
- `pavucontrol` is packaged in the Arch `extra` repository.

No laboratory or hardware evidence exists yet; validation belongs to plan 02-27.

## Decision

- **Mixer labels:** audio panel mixer rows show the MPRIS player name (`player.identity` or `desktopEntry`) when a
  player matches the stream, through the native `Quickshell.Services.Mpris` module and the panel model, and otherwise
  the PipeWire stream name. There is no shell media service and no active-player highlighting; the `playerctl` command
  boundary from plan 02-25 is unchanged.
- **Advanced audio tool:** `pavucontrol` (Arch `extra`) is installed from the `system/audio` capability as the
  advanced audio tool. The audio panel gains an "Advanced…" button that launches it with `uwsm app -- pavucontrol` as
  the session user.

This ADR supersedes only ADR 0025's "Media service … MPRIS labels are deferred" item and the matching consequence
that the mixer shows PipeWire stream names. Every other part of ADR 0025 remains in force, including the absence of a
shell media service and the exclusion of a general control panel.

## Consequences and trade-offs

- The image gains `pavucontrol` and its GTK4 dependencies; the cost is accepted for daily advanced audio use.
- `pavucontrol` is a separate application with its own appearance, reached on demand, not a resident applet.
- MPRIS matching remains copied panel model logic tracked per file in the shell `UPSTREAM.md`.
- Streams without a matching player keep their PipeWire names.

## Replacement or reversal boundary

Reconsider through a new ADR if player labelling requires a shell media service or resident daemon, if `pavucontrol`
leaves the supported repositories or breaks recurrently, or if a supported tool covers the advanced functions with
materially lower cost or better integration.

## Required validation

In plan 02-27, after acceptance:

- Model tests for stream labels with and without a matching MPRIS player.
- The "Advanced…" button opens `pavucontrol` in the laboratory guest without privilege prompts.
- The coupling checks show no `omarchy.media` or shell media service reference.
- Package and provenance records in `system/audio` list `pavucontrol`.

## References

- [ADR 0025: Shell Panels](0025-shell-panels.md)
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [Story 4.4 panel infrastructure technical interview log](../technical-interviews/story-4-4-panel-infrastructure_log.md)
- [Story 4.4 panel infrastructure consolidated plan](../technical-interviews/story-4-4-panel-infrastructure_plan.md)
- [MVP scope and change control](../mvp-scope.md)

## Superseded by

`None`
