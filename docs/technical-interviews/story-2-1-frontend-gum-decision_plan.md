# Consolidated Plan — Story 2.1, Track 3: frontend (Gum) decision

## Scope and approach

Plan 02-03 settles the frontend question left open by Track 3 and carried as TODO-002 from the storage interview. The maintainer intends Gum to drive the configuration and installation interaction of the first MirrorOS version. Rather than running a full Track 3 prototype, the plan takes a direct decision through an ADR, backed by a lightweight contract check that uses mock data in a terminal, with no VM and no counted runs [DEC-001]. That check is a minimal single-candidate prototype under `prototypes/frontend/` [DEC-003].

An ADR is required regardless, because Gum is both a critical technology selection (a new runtime dependency of the installation medium, `gum` from the official `extra` repository, depending only on `glibc`) and an exception to `docs/architecture.md` line 454, which currently states that MirrorOS introduces no custom TUI. A prototype is not required, because presentation is not one of the prototype-gated mechanisms and Track 3 was registered as optional. The contract check exists so that the ADR does not assert unverified behavior: exit-status mapping of confirmations to cancellation status `3`, behavior without a TTY, `NO_COLOR`, protected secret input, and paging of the complete plan [DEC-001].

## Boundaries of the Gum role

Gum only presents and collects input. The plan, its digest, and `install/engine/apply` never depend on Gum, and the frontend never determines the engine. Gum does not appear in production paths before the ADR is accepted (`docs/architecture.md` line 586). A Node.js frontend is out of scope for this plan [DEC-001].

## Experience intent

The maintainer wants a rich experience, using Gum's colors, styles, spinners, borders, and whatever else is needed, not a minimal use. The contract check must show that this experience degrades without loss of meaning under `NO_COLOR`, `TERM=dumb`, and without a TTY: textual markers for destructive operations, a selection that remains visible without color, and the active stage stated in text. Most *Terminal output* rules are compatible with this experience and stay unchanged; they become the acceptance criteria of the contract check: color never carries meaning alone, `NO_COLOR` and non-interactive terminals are respected, a spinner is decoration next to a textual active stage, healthy success stays concise, and failures keep stage, reason, and next action. The ADR amends only the banner and welcome-flow clause: a styled header or welcome is allowed solely in interactive TTY sessions of `install` and `configure`, suppressed in non-interactive mode, without a TTY, and in logs. Persistent healthy-state notifications remain prohibited [DEC-001, DEC-002, TODO-001].

## Track register

Track 3 is executed by plan 02-03 as a minimal single-candidate prototype under `prototypes/frontend/`: a Bash script with mock data walks every point of the interaction and *Terminal output* contract, including the TTY-only header, and a `README.md` holds the per-point result matrix. Raw transcripts go to `evidence/prototypes/frontend/<run-id>/` (ignored, allowlisted, Gitleaks-scanned). The Track 3 row in `prototypes/README.md` reads "executed by plan 02-03 as a single-candidate contract check; outcome in ADR 0004". The full multi-candidate prototype, VM, boot harness, and counted runs stay rejected, and the `prototypes/` rules apply (non-production, never sourced by production, Bash only, no Python) [DEC-001, DEC-002, DEC-003].

## Out of scope

The measurement follow-ups of plan 02-02 (ESP occupancy, `compsize` or `df` space, stricter pending-hibernation session, Limine persistent restore) and TODO-003, TODO-004, and TODO-005 from plan 02-01 [DEC-001].

## Execution environment

The real installer will run on the live ISO Linux console (`TERM=linux`, 8/16 colors, limited console glyphs), so a check limited to a graphical terminal would overstate the rich experience. The contract check therefore runs on the maintainer host on two surfaces, the terminal emulator and a host virtual console with `TERM=linux`, and the full matrix runs on both. `gum` is installed on the host from `extra` with `pacman -S gum`, and its version is recorded in the evidence. The host console font may differ from the live ISO console font; this is recorded as an evidence limit. Validation on the real live ISO console belongs to the story that adds `gum` to `image/`, if the ADR accepts Gum [DEC-004].

## Contract check matrix

The check drives a mock plan (target, defaults with provenance, destructive operations, fictitious digest) through ten points derived from the interaction model, the plan review flow, the *Terminal output* rules, the normalized exit statuses, and the secret-handling rules [DEC-005]:

- C1, attended with transcript: the six-step review flow, with destructive operations marked by text, the complete plan in `gum pager`, possible cancellation, and a confirmation that shows target and digest.
- C2: yes returns `0`, no or Esc returns `3`, and there is never a default yes. Ctrl+C returns `130` in `gum confirm`; C2 only records this, and whether it maps to `3` or keeps signal conventions is left to Story 2.4 [TODO-002].
- C3: without a TTY the flow fails with `2` without confirming, and no non-interactive flag bypasses it.
- C4: a secret read with `gum input --password` is not echoed, is absent from `/proc/<pid>/cmdline` and transcripts, and a planted canary yields zero findings.
- C5: `NO_COLOR=1` emits no ANSI color sequences while selection and destructive operations stay distinguishable (captured with `script(1)`).
- C6: `TERM=dumb` degrades without loss of meaning or fails clearly with `2`.
- C7, attended and visual: the `TERM=linux` console renders borders, spinner glyphs, and colors legibly [DEC-004].
- C8: `gum spin` states the stage in text, the child exit status is preserved (failure normalized to `5` with the original status recorded), and failures show stage, reason, and next action.
- C9: the styled header appears only with an interactive TTY and is absent without a TTY and in the log [DEC-002].
- C10: the persistent log contains no ANSI sequences and no secrets.

## Outcome rule

The rule is fixed before execution so that results cannot be interpreted after the fact. A point passes when Gum meets it natively, or passes with a wrapper when a thin MirrorOS Bash wrapper meets it without modifying Gum; each such wrapper becomes a mandatory constraint in the ADR for the future implementation. A point fails when only a patch or fork of Gum would meet it, or when the wrapper removes the rich experience in the normal TTY-and-color case. The ADR is Accepted when all points pass, natively or with a wrapper, and Rejected when any safety-critical point (C1 to C4) fails, in which case "no custom TUI" stays. A failure limited to C5 to C10 is a decision checkpoint put to the maintainer before the ADR is written, never resolved automatically. C1 and C7 are attended, and their verdict is the maintainer's recorded judgment [DEC-005, DEC-006].

## Documentation scope

With any outcome, the plan writes ADR 0004 (Accepted or Rejected) with the evidence run-ids, the mandatory wrappers, the limits (console font difference, the Ctrl+C mapping left to Story 2.4), and a replacement boundary; it updates the Track 3 row and the *Layout* list of `prototypes/README.md`; and it adds only the `prototypes/frontend/` block to the `docs/architecture.md` tree, following the precedent of plan 02-02 [DEC-003, DEC-007].

Only if the ADR is Accepted does `docs/architecture.md` change further: line 454 replaces "no custom TUI" with a statement that Gum is the interactive presentation layer, that it only presents and collects input, and that the plan, its digest, and the engine do not depend on it; the *Terminal output* banner and welcome-flow clause is amended as decided, and nothing else in that list; and the technology table gains a Gum row selected for interactive presentation [DEC-002, DEC-007].

Adding `gum` to the ISO packages in `image/` belongs to the story that implements the interface. `docs/epics.md`, `docs/attribution.md`, `install/`, and `tests/` are not touched. Gum needs no attribution entry, because it is installed from the official repository and nothing external is incorporated into the repository [DEC-007].

## Harness reuse

The frontend script sources the generic helpers of `prototypes/installation/lib/` without modifying them: `resources.sh` with `PROTO_TRACK=frontend` for the run-id and the private evidence directory, the generic `evidence.sh` functions for commit capture, allowlist enforcement with its own allowlist, and the redacted Gitleaks scan, and `secrets.sh` for the C4 canaries. It writes its own `run-metadata.json` and `result.json`, recording the `gum` version, the surface (terminal or VT), `TERM`, and each point's result with its outcome class, and it does not use the VM-specific functions. `prototypes/installation/lib/` stays unmodified; any unavoidable change must be backward-compatible with the current behavior as default and be followed by a regression of Track 1 and Track 2 consumers [DEC-006, DEC-008].

## Execution sequence

The maintainer installs `gum` on the host with `sudo pacman -S gum`; the agent does not install system packages. The script and README skeleton are developed with development runs that are `dirty: true` and never count as evidence. Commit 1 (`feat(prototypes): add frontend contract check`) carries `prototypes/frontend/` and marks the Track 3 row in progress. The evidence runs then execute at that commit with `dirty: false`, once on the terminal emulator and once on the `TERM=linux` virtual console, with C1 and C7 attended by the maintainer; a script defect means a new commit and a repetition of both runs. The README records the result matrix classified by the outcome rule, and a checkpoint presents the matrix and the derived outcome to the maintainer, who decides any C5 to C10 failure. ADR 0004, the final `prototypes/README.md`, and the `docs/architecture.md` changes follow, and commit 2 (`docs(prototypes): record frontend decision`) closes the plan [DEC-004, DEC-006, DEC-007, DEC-009].
