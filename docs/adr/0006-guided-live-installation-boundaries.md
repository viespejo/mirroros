# ADR 0006: Guided Live Installation Boundaries

## Identifier and title

- **Identifier:** `0006`
- **Title:** Guided Live Installation Boundaries

## Status

`Accepted`

## Date

`2026-10-09`

## Context and question

Plan 02-06 produced a dashboard-based confirmation flow. The maintainer replaced that direction with a guided live installer that reproduces the prototype preserved at [`prototypes/frontend/guided-installer/`](../../prototypes/frontend/guided-installer/README.md), and approved the design recorded in the [Story 2.4 guided installer transition log](../technical-interviews/story-2-4-guided-installer-transition_log.md) (DEC-001 to DEC-032). Four parts of that design collide with accepted normative text:

1. **Privilege model.** The architecture states that lifecycle orchestration begins unprivileged and that the complete workflow must not run under a single persistent privileged session. The Arch live ISO, and the reference experience, run the console session as root. Applied literally, the rule would require an unprivileged live account and artificial elevation between installer phases that the reference experience does not have.
2. **Machine admission.** The architecture and the PRD bound the MVP to one reference VM and one target laptop, and the current discovery contract binds every facts document to a `target_id`. The approved design removes manual profile selection, identifies known profiles internally, and lets technically admissible machines that match no profile proceed through an explicitly experimental path.
3. **Terminal scope.** The architecture requires commands to respect `NO_COLOR` and non-interactive terminals, and [ADR 0004](0004-interactive-presentation-with-gum.md) requires a `colorless_confirm` wrapper and degradation under `NO_COLOR` and `TERM=dumb`. The approved design focuses on the colored interactive live console and implements no colorless presentation.
4. **Live startup.** The live ISO opens the assistant automatically on tty1, while the architecture admits a styled welcome only in interactive TTY sessions of `install` and `configure`.

The question is how to reconcile these four points without weakening destructive-operation safety, and without silently rewriting accepted decisions.

## Constraints and decision criteria

- Root privileges, automatic startup, and experimental admission must never authorize an installation-disk operation: validated planning, explicit confirmation, and revalidation stay mandatory on every path.
- Installed-user configuration keeps its privilege separation; nothing here makes it inherit root.
- Recognizing a profile, passing technical checks, and being qualified are three distinct claims. No path may present one as another.
- Accepted ADR files are not rewritten. Supersession is recorded forward, and only the clauses named below are superseded.
- The scope change is limited to the live installer. Build, storage, system-configuration, and every other command keep their current boundaries.
- Presentation keeps no authority: Gum presents and collects input only, and the plan, its digest, and `install/engine/apply` do not depend on it (ADR 0004).
- This delivery performs no installation-disk operation, collects no password, and creates no installation engine.

## Alternatives considered

1. **Run the installer as an unprivileged live user with narrow elevation.** It matches the architecture literally. It adds a live account and per-phase elevation that the reference experience lacks, and it would change the fidelity the maintainer approved. Rejected.
2. **Keep manual profile selection and refuse unmatched machines.** It preserves the MVP boundary. It conflates qualification identity with admission and blocks technically capable machines, contrary to the approved direction. Rejected.
3. **Create a generic "unknown machine" profile.** It satisfies existing validators with no format change. It invents an identity and lets profile-specific adjustments appear to apply to machines that were never captured. Rejected.
4. **Implement a colorless presentation next to the colored one.** It satisfies the architecture and ADR 0004 as written. It doubles the interface surface for a personal distribution whose maintainer does not need it. Rejected for this delivery; reconsidered only through a later ADR.
5. **Narrow, explicit reconciliation (chosen).** Scope the three exceptions to the live installer and state each superseded clause.

## Evidence

- The maintainer exercised all prototype screens on the Omarchy 4.0.4 ISO. This is attended evidence of the desired prototype experience, not qualification of MirrorOS integration.
- The reference evidence read from that ISO (see [`UPSTREAM.md`](../../prototypes/frontend/guided-installer/UPSTREAM.md)) shows autologin as root on tty1, a Tokyo Night VT palette set on the console, forced color for Gum, and no `NO_COLOR` or `TERM=dumb` presentation path in the reviewed sources. The published upstream source reviewed during the interview was not extracted from the exact tested ISO.
- The Arch Linux Installation Guide documents the live environment as a root session and requires accurate live time for TLS and package signature verification.
- ADR 0004's evidence covers Gum 2.0.2 on host surfaces; the live ISO console was not exercised. Task 11 of plan 02-07 provides the attended MirrorOS verdict, and plan 02-07 provides the clean-build qualification evidence.
- No physical-hardware evidence exists, and none is claimed.

## Decision

### Live-root installer

The live session and the guided installer run as root, as on the Arch live ISO. MirrorOS introduces no live account, no artificial elevation between installer phases, and no setuid file. Executable modes on the live medium are not elevation grants.

Root privilege does not authorize destructive operations. Authorization remains the bound, two-step confirmation of the concrete disk and plan, followed by revalidation. Starting the assistant, including automatic startup, grants no authorization.

This exception covers only the live installer. Installed-user configuration never inherits root privileges for convenience, and the build, storage, and system-configuration boundaries of the architecture are unchanged. The live-keyboard adjustment runs inside the live-root session; its separation from the installed-system keyboard choice remains.

### Experimental admission and internal profiles

End users do not select a machine profile. Discovery inspects the machine, checks the technical requirements, and identifies a known profile only when a verifiable match exists. Profiles remain for qualification, evidence, and machine-specific adjustments; their adjustments apply only after an unambiguous verified match. A profile with pending identity capture is never identified.

A machine that passes the technical requirements but matches no profile is recorded as **unqualified**, without a generic profile, and may proceed through an explicitly experimental path. The interface states that the machine is unqualified and that no compatibility or support is promised.

The technical requirements are the existing ones: x86_64, UEFI boot without Secure Boot, a ready network, and an eligible disk of at least 20 GiB whose complete planned layout fits. No arbitrary RAM, CPU, or GPU requirement is added, and no bypass of any requirement is introduced. Recognized and unqualified machines receive identical safety guarantees.

NFR27 keeps its meaning as the qualification bound: the MVP capability inventory is satisfied and qualified on one reference VM configuration and one target laptop. Experimental admission is not qualification and does not extend that claim.

### Colored live-console presentation

The guided installer's presentation scope is the colored interactive console of the live ISO. It implements no colorless variant. A terminal outside that scope (`NO_COLOR` requested, `TERM=dumb`, or `TERM` unset) is rejected before discovery or any prompt, with exit `2`, rather than rendered through an unqualified alternative. A missing interactive terminal remains a hard failure that no flag bypasses.

For the live installer only, this ADR supersedes these clauses of ADR 0004 and the architecture:

- ADR 0004 wrapper 3, `colorless_confirm`, and the decision criterion that `NO_COLOR` and `TERM=dumb` degrade without loss of meaning.
- The architecture's *Terminal output* clause "Commands respect non-interactive terminals and `NO_COLOR`", which becomes rejection of those modes for the guided assistant instead of degradation.
- The architecture's "Color never carries meaning alone", as far as the selected-option cue of Gum widgets depends on color on the supported console. Labels, warnings, and the destructive-operation text stay textual. This is a stated exception, not a claim of equivalence.

The other ADR 0004 wrappers and constraints remain in force: `tty_precheck`; `confirm_status_map`, with the Ctrl+C status mapped to `3` during the interactive phase (the mapping ADR 0004 carried to Story 2.4); `stage_status_normalization`; `spin_plain_fallback`; and `tty_gate`. The `gum` major-version check stays: Gum missing or not at major version 2 exits `6` with `gum_not_qualified`. Gum remains presentation only.

The assistant uses `gum pager` for optional complete-plan and Wi-Fi-instruction inspection. A previously observed search defect is accepted, no dedicated pager test is required, and the safety behavior around the pager (inspection grants no authorization, leaving it preserves answers) remains tested.

### Automatic welcome on the live console

The live ISO opens the welcome screen on tty1 for an interactive terminal; cancellation returns to the shell, `mirroros-install` restarts it, and other consoles stay available. This is an interactive TTY session of `install`: it adds no persistent healthy-state notification, no welcome application, and no daemon. Seeded qualification coordinates the startup so that two assistants never run concurrently, and no coordination bypasses a command-level confirmation or terminal check.

### Proposed narrow amendments

These amendments are applied only when this ADR is accepted (plan 02-07, Task 5), and only as written here.

**`docs/architecture.md`**

- *Privilege model*: after "Lifecycle orchestration begins unprivileged.", add "The live installer is the exception: it runs in the live ISO's root session ([ADR 0006](adr/0006-guided-live-installation-boundaries.md)). Root privilege does not authorize destructive operations, and installed-user configuration never inherits it."
- *Terminal output*: after the `NO_COLOR` bullet, add "The guided live installer supports only the colored interactive live console and rejects `NO_COLOR`, `TERM=dumb`, and non-interactive terminals ([ADR 0006](adr/0006-guided-live-installation-boundaries.md))."
- *Terminal output*, welcome bullet: append "The live ISO opens the guided installer's welcome on tty1 automatically; this grants no authorization."
- *Plan review flow* paragraph on Gum: append "Machine profiles are identified internally and never selected by the user; an unqualified machine proceeds through an explicitly experimental path ([ADR 0006](adr/0006-guided-live-installation-boundaries.md))."
- *MVP support boundary* statements (the hardware adaptation summary and the portability limit): append "Experimental admission of other machines is not qualification or a support commitment."

**`docs/prd.md`**

- Scope statement "a blank supported device becomes the user's verified daily working environment": unchanged. Add one sentence to the MVP scope paragraph: "Technically admissible machines that match no known profile may attempt installation through an explicitly experimental path, without a compatibility guarantee or support commitment."
- NFR27 text is unchanged.

**`docs/epics.md`**

- Story 2.4: add to its acceptance criteria that the guided assistant identifies profiles automatically, that an unqualified machine is admitted only through the experimental path with the same confirmation semantics, and that the colored live console is the supported presentation.
- NFR27 text is unchanged.

## Consequences and trade-offs

- The live installer matches the reference experience and the Arch live model, with no additional account or elevation machinery.
- A root console session carries more blast radius than an unprivileged one. The mitigation is that no installation-disk operation is reachable without the bound confirmation, and this delivery reaches no engine.
- Unmatched machines can reach confirmation. The risk is users reading admission as compatibility; the mitigation is explicit experimental wording and the `machine_unqualified` plan warning, with no support commitment.
- Profile recognition does not establish that an individual machine was qualified. Evidence of qualification remains separate.
- The guided interface is unusable on monochrome or dumb terminals. The accepted cost is rejection with a clear message, not a degraded flow.
- The facts and installation-plan contracts change versions, and old plans are rejected rather than migrated, so earlier plans must be regenerated.
- The reference experience depends on the live ISO console; the console font remains the kernel default because the reference evidence documents none.

## Replacement or reversal boundary

- Revisit the live-root decision if the live session stops running as root, if a live account is introduced, or if any installer phase needs elevation that root does not already hold.
- Revisit experimental admission if a defect shows that an unqualified machine can reach a destructive operation without the bound confirmation, or if hardware support becomes a promise.
- Revisit the terminal scope if a colorless or non-console presentation is required, or if the live console renders the interface illegibly (ADR 0004's reversal condition).
- Supersede this ADR before the installation engine story changes the hand-over boundary described in the installation confirmation contract.

## Required validation

- Before adoption: the maintainer reviews this ADR, the revised contracts, and the inventory of presentation differences (plan 02-07, Task 4).
- After adoption: automatic discovery tests cover recognized, unqualified, pending, missing-identity, ambiguous, and explicit-mismatch cases; the guided flow tests cover terminal rejection, confirmation, cancellation, and invalidation.
- Attended review of the real MirrorOS live console records the fidelity verdict (plan 02-07, Task 11).
- Two counted VM scenarios, one recognized and one unqualified, produce the expected outcomes with clean source identity (plan 02-07, Task 12). No physical-hardware qualification is claimed.

## References

- [Architecture](../architecture.md)
- [PRD](../prd.md)
- [Epics](../epics.md)
- [ADR 0004](0004-interactive-presentation-with-gum.md)
- [ADR 0005](0005-physical-target-change.md)
- [Guided installer reference](../../prototypes/frontend/guided-installer/README.md)
- [Target facts contract](../../contracts/target-facts.md)
- [Installation plan contract](../../contracts/installation-plan.md)
- [Installation confirmation contract](../../contracts/installation-confirmation.md)
- [Story 2.4 guided installer transition plan](../technical-interviews/story-2-4-guided-installer-transition_plan.md) and [log](../technical-interviews/story-2-4-guided-installer-transition_log.md)
- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)

## Superseded by

Partially superseded by [ADR 0008](0008-installation-engine-execution-boundary.md), which supersedes only the hand-over boundary: the premise that no installation engine is reachable and the reversal-boundary clause that required this supersession. The rest of this decision is unchanged by ADR 0008.

[ADR 0018](0018-native-live-display-and-installer-presentation.md) supersedes only the kernel-default-font consequence by permitting an optional temporary Original / Original x2 selector. Its live-only presentation changes do not alter the safety boundaries.
