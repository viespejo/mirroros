# Epic 3 Technical Interview — Consolidated Plan

## Scope
Epic 3 will be evaluated as a whole. The interview may conclude that it should be kept, rewritten or reduced, postponed, or dropped. No particular mechanism—such as generic modules, a formal inventory, or a convergence tool—is presumed necessary. Decisions must respect the current architecture and identify any required architecture or ADR updates. [DEC-001]

## Current design decisions
After base installation, `configure` must install and apply the agreed software and settings without rebuilding the ISO or reinstalling the system. It must be safe to rerun and report which operation failed. This outcome does not presume a generic capability inventory or module framework. [DEC-002]

`configure` reconstructs the established environment definition on a newly installed system; it is not a continuous synchronization or drift-reconciliation mechanism for already configured machines. [DEC-008]

Package versions are not pinned. Each configuration run installs the declared package set using versions available from repositories at execution time; separate installations are not guaranteed to have identical package versions. [DEC-007]

After an interruption, the user can rerun `configure` from the beginning. Steps already in the expected state should avoid unnecessary changes, and the run must identify the failed step. A separate complex resume mechanism is not required. [DEC-009]

`configure` checks postconditions for the changes it performs. The independent `verify` stage assesses readiness of the complete MVP environment and remains separate from configuration, consistent with its current placement in Epic 5. [DEC-013]

`configure` covers the complete agreed environment, including the desktop and user tools. [DEC-003]

The complete MVP environment must be prepared during installation against the installed target and before the first normal reboot, with visible progress and actionable failures. Required setup is not deferred to background work after login. System operations elevate narrowly; user configuration does not run wholesale as root. [DEC-015, DEC-016]

System configuration, desktop, and user tools form one ready-environment outcome; a base configuration without a desktop is not a meaningful independent readiness milestone. [DEC-006]

Integrate Epic 3 configuration work into the epic that delivers the ready MVP desktop environment; do not retain Epic 3 as an independent abstract mechanism epic. This decision does not set the final epic title or story breakdown. [DEC-010]

“Complete environment” is bounded by the existing MVP scope in the PRD, including the agreed desktop and workflow. Software and personal preferences not yet specified are excluded unless added through reviewable scope changes. [DEC-004]

Start with native Arch and application formats plus explicit scripts to apply configuration. Do not create a central manifest describing the entire environment unless a concrete need demonstrates its value. [DEC-005]

Do not maintain a formal capability inventory as a separate mechanism. Keep the MVP scope in a human-readable list, and document package provenance and required checks in native declarations or alongside their application scripts. [DEC-011]

Do not implement the shell-versus-Ansible prototype. Apply configuration with bounded Bash scripts and native Arch/application formats. Reconsider a framework only if recurring problems in actual scripts demonstrate its value. [DEC-012]

Keep `operations/configure` as the documented entry point for preparing the complete MVP environment. It may call explicit task-specific Bash scripts, which are internal implementation details rather than a separate public CLI. The current stub's capability-module and convergence wording must be aligned with this decision. [DEC-014]

The guided installation runs `configure` after base installation and before the first normal reboot. `operations/configure` remains independently invocable. If required configuration fails, installation must not report the environment as ready. [DEC-017]

## Structural decisions for the integrated epic
The integrated environment epic will begin with a scope-definition story that makes the concrete MVP software and capabilities explicit and reviewable. This is not a formal capability inventory or architecture story. [DEC-018]

## Open questions
- What verification should establish that a newly configured system matches the declared MVP environment? [DEC-002, DEC-004, DEC-007] — Deferred to Story 4.2.
- How should configuration failures and verification failures be reported to the user? [DEC-002, DEC-009] — Deferred to Story 4.2.
- What specific system and user setup operations can safely run against the target during installation, and how should the installer sequence them before first reboot? [DEC-016, DEC-017] — Deferred to Story 4.2.
- How can `operations/configure` be independently invoked against an installed target while also being called by the live installer? [DEC-014, DEC-017] — Deferred to Story 4.2.
- Reconcile the existing normative architecture requirements for a formal capability inventory and a shell-versus-Ansible prototype with the accepted direction; update the architecture and ADRs as required before revising implementation stories. [DEC-001, DEC-005, DEC-010, DEC-011, DEC-012] — Resolved by plan 02-12 (ADR 0010 and `docs/architecture.md`).
- Rewrite the epic and story breakdown to deliver the complete MVP desktop environment as one outcome. [DEC-003, DEC-004, DEC-006, DEC-010] — Resolved by plan 02-12 (`docs/epics.md`).
- Align the `operations/configure` stub documentation and implementation contract with the decisions recorded here. [DEC-012, DEC-014] — Resolved by plan 02-12 (`operations/configure` help and `docs/procedures/configure.md`).

## Restructuring direction
Epic 4 becomes the integrated epic and absorbs the useful work of Epic 3, which is retired as an independent epic. A dedicated plan rewrites Epic 4 and adapts affected artifacts, including documentation; the resulting stories are then implemented one at a time. Accepted ADRs that mention Epic 3 or Story 3.2 are not rewritten. [DEC-019]

Epic numbers are preserved. Epic 4 is rewritten in place; Epic 3 stays in `docs/epics.md` as a short retired section whose correspondence table maps each former story (notably Story 3.2, referenced by accepted ADRs) to its Epic 4 destination or explicit removal. Epics 5 and 6 keep their numbers so existing contract and ADR references stay valid. [DEC-020]

The plan adds ADR 0010 (Accepted) resolving the convergence gate without an Ansible prototype (bounded Bash scripts and native formats) and replacing the formal capability inventory with a human-readable MVP scope list, and updates `docs/architecture.md` to match. The non-normative research document and the PRD stay unchanged; FR20 is satisfied by the scope list. [DEC-021, DEC-011, DEC-012]

Decisions DEC-013 to DEC-017 enter the rewritten Epic 4 only as observable outcomes: readiness before the first normal reboot without post-login background installation, an independently invocable and safely rerunnable `operations/configure`, no ready claim after a configuration failure, and independent `verify` in Epic 5. Execution mechanics are settled per story, using the interview decisions as context. [DEC-022]

The rewritten Epic 4 opens with three foundation stories that absorb the useful Epic 3 work: 4.1 defines the human-readable MVP environment scope and the frozen frequent-action list; 4.2 applies the environment through an independent, rerunnable `configure` invoked by installation before reboot, with validation before mutation, bounded privilege, and runtime secrets; 4.3 records package and external source provenance, including AUR review and the obligations assigned to "Story 3.2" by ADRs 0003, 0008, and 0009. Stories 4.4–4.10 are the current outcome stories 4.1–4.7, renumbered. The retired Epic 3 correspondence is 3.1→4.1, 3.2→4.3, 3.3→removed by ADR 0010, and 3.4/3.5/3.6→4.2. [DEC-023]

Operational artifacts change only in wording: `operations/configure` help and `docs/procedures/configure.md` drop capability modules and the prototype gate, describe an independent stage preparing the MVP environment through bounded Bash scripts, and defer remaining details to Story 4.2; the command stays help-only. `operations/verify` and its procedure remain untouched, and Story 5.1 only retargets its inventory reference to the Story 4.1 scope. [DEC-024]
