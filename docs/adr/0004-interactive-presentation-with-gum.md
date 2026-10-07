# ADR 0004: Interactive Presentation with Gum

## Identifier and title

- **Identifier:** `0004`
- **Title:** Interactive Presentation with Gum

## Status

`Accepted`

## Date

`2026-10-08`

## Context and question

The architecture states that MirrorOS introduces no custom TUI (*Plan review flow*) and that a technology marked as a prototype candidate must not appear in production before its ADR. The maintainer intends to use [Gum](https://github.com/charmbracelet/gum) for a rich configuration and installation experience (colors, styles, spinners, borders). The question is whether Gum can be the interactive presentation layer of the first MirrorOS version without weakening the interaction model, the six-step plan review flow, the *Terminal output* rules, the normalized exit statuses, or the secret-handling rules.

Plan 02-03 answered it with a single-candidate contract check (points C1 to C10) driven by mock data on two host surfaces: a terminal emulator and a host virtual console with `TERM=linux`. This resolves TODO-002 of the Story 2.1 storage-recovery research log.

## Constraints and decision criteria

- Accepted only if every point C1 to C10 passes natively or with a named wrapper; Rejected if any of C1 to C4 fails; a failure limited to C5 to C10 is decided by the maintainer, never automatically.
- Gum only presents and collects input. The plan, its digest, and `install/engine/apply` must not depend on it.
- No confirmation is ever granted by default; a missing TTY fails with `2`, decline or Esc returns `3`.
- Secrets are never passed as arguments or environment and never reach transcripts or logs.
- `NO_COLOR` and `TERM=dumb` must degrade without loss of meaning; color never carries meaning alone.
- The persistent log contains no ANSI sequences and no secrets.
- The evidence is a non-production prototype with mock data; no real disk or system state is read or changed.

## Alternatives considered

1. **Keep plain paginated text (no custom TUI).** No new dependency and no architecture change. It does not provide the experience the maintainer intends.
2. **Adopt Gum as the interactive presentation layer, with mandatory wrappers (chosen).** It enables the rich experience, with the wrappers binding the behavior that native Gum does not satisfy.
3. **A custom frontend (for example on Node.js).** Not evaluated here. It would be a larger custom TUI with its own maintenance cost and is outside this plan.

## Evidence

Both counted runs used commit `78af2aefc722ccfe1bf6a13368f701d0d0653957` with `dirty: false` and Gum `2.0.2 (879f048)`. Raw results are under the ignored `evidence/prototypes/frontend/contract-check/<run-id>/`. The matrix is in [`prototypes/frontend/README.md`](../../prototypes/frontend/README.md#result-matrix).

| Surface | `TERM` | Run ID |
| --- | --- | --- |
| `terminal` | `xterm-kitty` | `20261007T231607Z-a1144b57-f5b7-4cd7-b10b-403cae6121f3` |
| `vt` | `linux` | `20261007T230932Z-c810f5e8-ec5d-4111-868f-f798a76bc1bc` |

- On each surface: 3 `pass` (C4, C7, C10), 7 `pass-with-wrapper` (C1, C2, C3, C5, C6, C8, C9), and 0 `fail`.
- The attended verdicts of C1 (six-step review flow) and C7 (visual rendering on `TERM=linux`) are `pass` on both surfaces.
- The canary search (negative control clean, planted canary found) and the redacted Gitleaks scan of the evidence passed on both runs.
- Native Gum deviations measured: `gum confirm` returns `1` for decline, Esc, and the absence of a terminal; `gum spin` preserves the child status and runs the command without a terminal; `gum style` prints without a terminal; `gum confirm` shows no focus cue without color.
- Limits of the evidence:
  - The host console font may differ from the live ISO console font.
  - One host and one run per surface; nothing about the target laptop.
  - Ctrl+C returns `130` and was recorded without being remapped.
  - The live ISO console was not exercised; Gum is not part of the ISO.

## Decision

Gum is selected as the interactive presentation layer of the first MirrorOS version, under the boundary below and with the following wrappers as mandatory constraints. Every implementation that uses Gum must keep each wrapper's behavior:

1. `tty_precheck` (C1, C3): a confirmation, choice, or secret prompt without an interactive terminal (stdin or stdout redirected) fails with `2` and never confirms; no non-interactive flag bypasses it.
2. `confirm_status_map` (C1, C2): decline and Esc map to `3`; confirmation returns `0`; the default focus is No; the Ctrl+C status is returned unmapped.
3. `colorless_confirm` (C5, C6): under `NO_COLOR` or `TERM=dumb`, the confirmation uses `gum choose` with a text cursor and the safe answer first, so selection stays distinguishable without color.
4. `stage_status_normalization` (C8): any stage failure is normalized to `5`, reports stage, reason, and next action, and records the original status.
5. `spin_plain_fallback` (C8): without an interactive terminal a stage is announced as plain text and run directly.
6. `tty_gate` (C9): the styled header or welcome appears only with an interactive terminal and never in non-interactive mode, and it is absent from the log.

The `docs/architecture.md` statements change only as follows: the "no custom TUI" statement states Gum as the interactive presentation layer under this boundary; the *Terminal output* clause on banners and welcome flow admits a styled header or welcome only in interactive TTY sessions of `install` and `configure`, suppressed in non-interactive mode, without a TTY, and in logs, and keeps the prohibition of persistent healthy-state notifications; and Gum is listed in the technology table.

The Ctrl+C mapping is not decided here and is carried to Story 2.4.

## Consequences and trade-offs

- The installation medium gains a runtime dependency (`gum`, from the official `extra` repository) once an implementing story adds it to `image/`.
- Every wrapper is a binding constraint; implementing stories must test its behavior, including the no-TTY, `NO_COLOR`, and `TERM=dumb` paths.
- Stories 2.3 and 2.4 can build plan presentation and confirmation on Gum.
- Without a terminal, the flow fails instead of confirming, so unattended use needs the non-interactive path that the architecture already defines, not Gum.
- The live ISO console and the target laptop remain unvalidated.

## Replacement or reversal boundary

- Gum only presents and collects input. The plan, its digest, and `install/engine/apply` do not depend on it; replacing Gum must not change them.
- Gum does not enter production paths (`install/`, `image/`, `tests/`, and others) until an implementing story adds it, and no production path sources anything under `prototypes/`.
- Revisit this decision if Gum cannot be kept within the wrappers, if a Gum release changes the measured behavior (exit statuses, secret handling, or no-TTY behavior), if the live ISO console renders it illegibly, or if the package becomes unavailable in the official repositories.

## Required validation

- Before adoption: the maintainer reviews this ADR and the updated architecture statements at the commit that records it.
- The story that adds `gum` to `image/` validates the live ISO console rendering and the pinned package version.
- Implementing stories re-run the behavior behind C1 to C10 against their own flow and map the Ctrl+C status (Story 2.4).
- `install/` and `image/` are neither created nor modified by this decision.

## References

- [Architecture](../architecture.md)
- [ADR 0002](0002-installation-engine-selection.md)
- [Frontend contract check](../../prototypes/frontend/README.md)
- [Story 2.1 frontend decision plan](../technical-interviews/story-2-1-frontend-gum-decision_plan.md) and [log](../technical-interviews/story-2-1-frontend-gum-decision_log.md)
- [Story 2.1 storage-recovery research log](../technical-interviews/story-2-1-storage-recovery-research_log.md) (TODO-002)

## Superseded by

`None`
