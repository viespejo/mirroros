# Decision Log — Story 2.1, Track 3: frontend (Gum) decision

Interview for plan 02-03. Depends on plan 02-02 (`.agents/plans/02-02-storage-recovery-prototypes-SUMMARY.md`), which carried TODO-002 of `story-2-1-storage-recovery-research_log.md`.

## DEC-001
- **Question**: Is Track 3 (frontend) executed as a prototype, or decided directly?
- **Context/Nuances**: The maintainer intends to use Gum to drive the configuration and installation interaction in the first MirrorOS version. `docs/adr/README.md` requires an ADR for a critical technology selection or an exception to the architecture; Gum is both (a new runtime dependency of the installation medium, and an exception to `docs/architecture.md` line 454, "MirrorOS introduces no custom TUI"). A prototype is not mandatory: presentation is not among the prototype-gated mechanisms (`docs/architecture.md` lines 79 and 95), and Track 3 was registered as optional. Line 586 forbids a technology marked as a prototype candidate in production before its ADR; Gum is named as a candidate in the Track 3 row. `gum 2.0.2-1` is in the official `extra` repository and depends only on `glibc` (no AUR provenance issue). The maintainer intends a rich experience with Gum (colors, styles, spinners, borders, and whatever else is needed), not a minimal use; this must degrade without loss of meaning under `NO_COLOR`, `TERM=dumb`, and without a TTY. Rejected alternatives: (a) a full Track 3 prototype with harness, variants, and counted runs, disproportionate for a question that does not touch disk or VM state; (b) a direct ADR without evidence, which would assert unverified contract behavior (exit-status mapping of `gum confirm` 0/1/130 to cancellation status `3`, no-TTY behavior, `NO_COLOR`, secret input without observable arguments, paging of the complete plan).
- **User Response**: Chose option (c); asked for an explanation of `NO_COLOR`; added that Gum will likely use colors and anything else needed for a rich experience.
- **Decision**: Gum is proposed as the presentation layer of the first MirrorOS version through a direct ADR, backed by a lightweight contract check with mock data in a terminal, without a VM and without counted runs. Track 3 is closed in `prototypes/README.md` as "not executed as a prototype; decided by the ADR". The ADR amends `docs/architecture.md` line 454. Gum only presents and collects input: the plan, its digest, and `install/engine/apply` do not depend on Gum, and Gum does not appear in production before the ADR is accepted. A Node.js frontend is out of scope for plan 02-03. TODO-002 of `story-2-1-storage-recovery-research_log.md` is resolved by this decision.
- **Status**: Accepted

## TODO-001
- **Description**: Decide which *Terminal output* rules of `docs/architecture.md` the ADR amends to admit the rich Gum experience, and which stay: "Progress does not depend on animation", "MirrorOS adds no banners, welcome flow, or persistent healthy-state notifications", "Healthy success remains concise". "Color never carries meaning alone" and "Commands respect non-interactive terminals and `NO_COLOR`" are compatible with rich styling if meaning is also carried by text.
- **Status**: Resolved by DEC-002

## DEC-002
- **Question**: Which *Terminal output* rules of `docs/architecture.md` does the ADR amend to admit the rich Gum experience (resolves TODO-001)?
- **Context/Nuances**: Rule-by-rule review: "Color never carries meaning alone" is compatible if every meaning is also carried by text; "Commands respect non-interactive terminals and `NO_COLOR`" is the degradation rule itself; "Progress does not depend on animation" is compatible when a spinner is decoration next to a textual active stage; "Healthy success remains concise" is compatible with a short styled summary; "Failures identify the stage, operation or capability, reason, and next action" is compatible because Gum only styles the content. Only "MirrorOS adds no banners, welcome flow, or persistent healthy-state notifications" conflicts with a styled header or welcome screen. Rejected alternative: leaving presentation rules open in the ADR ("revisited when UX is designed"), which would leave the contract check without clear criteria.
- **User Response**: Accepted the recommendation.
- **Decision**: The ADR amends only the banner and welcome-flow clause: a styled header or welcome is allowed solely in interactive TTY sessions of `install` and `configure`, and is suppressed in non-interactive mode, without a TTY, and in logs. The prohibition of persistent healthy-state notifications stays. All other *Terminal output* rules stay unchanged and become the acceptance criteria of the lightweight contract check.
- **Status**: Accepted

## DEC-003
- **Question**: Where and how does the lightweight contract check live?
- **Context/Nuances**: Gum cannot appear in production paths (`install/`, `tests/`, and others) before the ADR is accepted (`docs/architecture.md` line 586), and generated outputs are never committed. Non-production code that precedes an ADR can only live under `prototypes/`, so a versioned check is a prototype in the repository's sense ("disposable, evidence-producing experiments"). It differs from the full prototype rejected in DEC-001 in size, not in category: one candidate instead of several, a local terminal with mock data instead of a VM and boot harness, and one pass/fail run per contract point instead of counted runs. Rejected alternative: (b) a manual check recorded only in the ADR, with no versioned code, which cannot be repeated when `gum` is updated.
- **User Response**: Asked whether this means there is a prototype; chose (a) after the clarification.
- **Decision**: Track 3 is executed by plan 02-03 as a minimal single-candidate prototype under `prototypes/frontend/`: a Bash script with mock data that walks every point of the interaction and *Terminal output* contract (including the TTY-only header of DEC-002), and a `README.md` with the per-point result matrix. Raw transcripts go to `evidence/prototypes/frontend/<run-id>/` (ignored, allowlisted, Gitleaks-scanned). The outcome is recorded in ADR 0004. The Track 3 row reads "executed by plan 02-03 as a single-candidate contract check; outcome in ADR 0004". This corrects the DEC-001 wording "not executed as a prototype; decided by the ADR" without rewriting DEC-001; the full multi-candidate prototype, VM, boot harness, and counted runs remain rejected. The `prototypes/` rules apply: non-production, never sourced by production, Bash only, no Python.
- **Status**: Accepted

## DEC-004
- **Question**: In which environment does the contract check run?
- **Context/Nuances**: `gum` is not installed on the maintainer host and is not part of `image/`. The real installer will run on the live ISO Linux console (`TERM=linux`, 8/16-color VT, a console font with a limited glyph set), not in a modern truecolor, full-Unicode terminal emulator; Gum borders, Unicode spinners, and colors may render very differently there, so a check limited to a graphical terminal would overstate the rich experience. Rejected alternatives: (a) host terminal emulator only, fastest but not representative; (c) host plus a visual check in the reference VM booting the unmodified bundle A ISO with `pacman -S gum` in the live session, most faithful but it reintroduces the VM that DEC-001 rejected.
- **User Response**: Chose (b) and asked to record it directly.
- **Decision**: The contract check runs on the maintainer host on two surfaces: the terminal emulator and a host virtual console (for example Ctrl+Alt+F3, `TERM=linux`); the full matrix runs on both. `gum` is installed on the host from the official `extra` repository with `pacman -S gum`, and its version is recorded in the evidence. The difference between the host console font and the live ISO console font is recorded as an evidence limit. Validation on the real live ISO console belongs to the story that adds `gum` to `image/`, if the ADR accepts Gum.
- **Status**: Accepted

## DEC-005
- **Question**: Which points does the contract check matrix contain?
- **Context/Nuances**: Derived from *Interaction model*, *Plan review flow*, and *Terminal output* in `docs/architecture.md`, the normalized exit statuses (`docs/architecture.md` line 370: `0` success, `2` invalid input or unmet precondition, `3` explicit user cancellation, `5` execution or upstream-operation failure), the secret-handling rules, and DEC-002. All points use a mock plan (target, defaults with provenance, destructive operations, fictitious digest).
- **User Response**: Accepted the recommendation and asked to record it directly.
- **Decision**: The matrix has ten points:
  - C1: the six-step review flow (target summary; defaults with provenance; destructive operations marked by text; complete plan in `gum pager`; cancellation possible; confirmation showing target and digest). Attended, with transcript.
  - C2: confirmation outcomes: yes returns `0`; no or Esc returns `3`; there is never a default yes. Exit status recorded.
  - C3: without a TTY (stdin or stdout redirected) the flow fails with `2` without confirming, and no non-interactive flag bypasses it. Automated.
  - C4: a secret read with `gum input --password` is not echoed, does not appear in `/proc/<pid>/cmdline` or in transcripts, and a planted canary yields zero findings in the evidence. Automated plus scan.
  - C5: `NO_COLOR=1` produces zero ANSI color sequences, and the selection and destructive operations stay distinguishable. Captured with `script(1)`.
  - C6: `TERM=dumb` degrades without loss of meaning, or fails clearly with `2`. Captured.
  - C7: the `TERM=linux` console (DEC-004) renders borders, spinner glyphs, and colors legibly. Attended, visual.
  - C8: progress through `gum spin` states the stage in text; the child exit status is preserved (failure normalized to `5` with the original status recorded); a failure shows stage, reason, and next action. Automated.
  - C9: the styled header or welcome appears only with an interactive TTY and is absent without a TTY and in the log. Automated.
  - C10: the persistent log contains no ANSI sequences and no secrets. Automated.
- **Status**: Accepted

## TODO-002
- **Description**: Ctrl+C in `gum confirm` returns `130` (SIGINT). `docs/architecture.md` states "Signal termination retains normal shell conventions", but the action can also be read as explicit user cancellation (`3`). C2 records the observed behavior only; the mapping is decided by Story 2.4 (authorize or cancel consequential operations). Not to be confused with TODO-002 of `story-2-1-storage-recovery-research_log.md`, resolved by DEC-001.
- **Status**: Pending (carried to Story 2.4)

## DEC-006
- **Question**: Which rule decides whether the ADR accepts or rejects Gum?
- **Context/Nuances**: Some points may not be met by Gum out of the box (for example C3 without a TTY, or C6 with `TERM=dumb`). The rule is fixed before execution so that results are not interpreted after the fact. C1 to C4 are the safety-critical points (review, confirmation, no TTY, secrets).
- **User Response**: Accepted the recommendation and asked to record it directly.
- **Decision**: Each point is classified as: **pass** (Gum meets it natively); **pass with wrapper** (a thin MirrorOS Bash wrapper meets it without modifying Gum, for example a `[[ -t 0 && -t 1 ]]` precheck or forcing a colorless profile; every required wrapper becomes a mandatory constraint in the ADR for future implementation); **fail** (it can only be met by patching or forking Gum, or the wrapper removes the rich experience in the normal TTY-and-color case). ADR outcome: **Accepted** if every point passes natively or with a wrapper; **Rejected** if any of C1 to C4 fails, keeping "no custom TUI"; a failure limited to C5 to C10 is a **decision checkpoint** presented to the maintainer before the ADR is written (accept with limits or reject), never resolved automatically. C1 and C7 are attended points whose verdict is the maintainer's recorded judgment.
- **Status**: Accepted

## DEC-007
- **Question**: Which documentation does plan 02-03 change for each outcome?
- **Context/Nuances**: Gum needs no `docs/attribution.md` entry: it is installed from the official repository and no external material is incorporated into the repository (the policy covers "externally incorporated material"). Plan 02-02 set the precedent of adding its prototype block to the `docs/architecture.md` tree (lines 1129 to 1150). No story in `docs/epics.md` names a TUI.
- **User Response**: Accepted the recommendation and asked to record it directly.
- **Decision**: With any outcome: `docs/adr/0004-<slug>.md` (Accepted or Rejected) with the evidence run-ids, mandatory wrappers, limits (console font difference, TODO-002), and replacement boundary; `prototypes/README.md` Track 3 row (DEC-003 wording) and a `frontend/` entry in *Layout*; `docs/architecture.md` gains only the `prototypes/frontend/` block in the tree. Only if Accepted: `docs/architecture.md` line 454 replaces "no custom TUI" with a statement that Gum is the interactive presentation layer, only presents and collects input, and that the plan, its digest, and the engine do not depend on it; the *Terminal output* banner and welcome-flow clause is amended per DEC-002 and nothing else in that list; the technology table (lines 611 to 612) gains a `Gum | Selected for interactive presentation | ...` row. Out of the plan with any outcome: `image/` (adding `gum` to the ISO packages belongs to the story that implements the interface), `docs/epics.md`, `docs/attribution.md`, `install/`, and `tests/`.
- **Status**: Accepted

## DEC-008
- **Question**: Does the `prototypes/frontend/` script reuse the existing harness or stand alone?
- **Context/Nuances**: Part of `prototypes/installation/lib/` is generic and reusable unmodified: `resources.sh` (UTC+UUID run-id, private 0700 directories, and the `PROTO_TRACK` parameter added by plan 02-02), `evidence.sh` (`evidence_capture_commit`, `evidence_enforce_allowlist` with an `EVIDENCE_ALLOWLIST` array that can be reassigned after sourcing, `evidence_scan`), and `secrets.sh` (canary generation and search, validated with the negative control in two plans). The rest is VM-specific (`evidence_write_metadata` and `evidence_write_result` depend on bundle, QEMU, and reference-VM variables; `launch.sh`; `nocloud.sh`). Rejected alternative: (b) a standalone script duplicating about 100 lines of run-id, allowlist, scan, and canary logic.
- **User Response**: Chose (a) and confirmed the summary.
- **Decision**: The script sources, unmodified, `resources.sh` with `PROTO_TRACK=frontend`, the generic functions of `evidence.sh` (`evidence_capture_commit`, `evidence_enforce_allowlist` with its own `EVIDENCE_ALLOWLIST`, `evidence_scan`), and `secrets.sh` for the C4 canaries. `prototypes/frontend/` provides its own `run-metadata.json` and `result.json` writer (`gum` version, surface terminal or VT, `TERM`, per-point C1 to C10 result with the DEC-006 class) and its `README.md`. The VM-specific functions are not used. `prototypes/installation/lib/` stays unmodified; if a change ever becomes necessary, it is backward-compatible with the current behavior as default, as in plan 02-02, with a regression of the existing consumers (Track 1 and Track 2).
- **Status**: Accepted

## DEC-009
- **Question**: How are commits and runs ordered?
- **Context/Nuances**: Plan 02-02 used code, commit 1, runs on a clean tree (`dirty: false`), results with ADR and architecture, then commit 2. There are no counted runs here in the strict sense, but the ADR cites run-ids, which must point to a clean commit to be traceable. The agent does not install system packages.
- **User Response**: Accepted the recommendation.
- **Decision**: (1) Manual precondition by the maintainer: `sudo pacman -S gum` on the host. (2) Script and README skeleton development; development runs are `dirty: true` and are not evidence. (3) Commit 1 `feat(prototypes): add frontend contract check` with `prototypes/frontend/` and the Track 3 row marked in progress. (4) Evidence runs at commit 1 with `dirty: false`: one on the terminal emulator and one on the `TERM=linux` virtual console, with C1 and C7 attended by the maintainer; a script defect leads to a new commit and a repetition of both runs (the 02-02 pattern). (5) Result matrix in the README and classification per DEC-006. (6) Checkpoint: the matrix and the outcome derived from the rule are presented to the maintainer, who decides any C5 to C10 failure. (7) ADR 0004, final `prototypes/README.md`, and the `docs/architecture.md` changes per DEC-007. (8) Commit 2 `docs(prototypes): record frontend decision`.
- **Status**: Accepted
