**Conventions.** The Consolidated Plan (`epic-3-environment-configuration_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding entry, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: What is the scope and possible outcome of the technical interview about Epic 3?
- **Context/Nuances**: Epic 3 will be evaluated as a whole. The interview must not assume that generic modules, inventories, or a convergence tool are necessary. Decisions must respect the current architecture and identify any required architecture or ADR updates. Possible outcomes include keeping, rewriting/reducing, postponing, or dropping the epic.
- **User Response**: Approved the proposed interview framework and requested that the decision be recorded directly.
- **Decision**: Evaluate Epic 3 as a whole; choose among keeping it, rewriting or reducing it, postponing it, or dropping it, based on the interview. Do not presume specific mechanisms are needed.
- **Status**: Accepted

## DEC-002
- **Question**: What concrete user-visible outcome, if any, should Epic 3 deliver beyond the base installation and simple software/configuration scripts?
- **Context/Nuances**: The outcome should be useful after base installation, independent of image rebuilding or system reinstallation, safely repeatable, and diagnosable. This does not by itself justify a generic capability inventory or module framework.
- **User Response**: Approved the recommended outcome and asked to record it directly.
- **Decision**: `configure` must install and apply the agreed software and settings after installation without rebuilding the ISO or reinstalling the system. It must be safe to rerun and report which operation failed. A generic capability inventory or module framework is not presumed necessary.
- **Status**: Accepted

## DEC-003
- **Question**: Should `configure` apply the complete user environment, including the desktop and workflow tools, or only the system base?
- **Context/Nuances**: This settles the user-visible scope of configuration, not its internal decomposition or whether Epics 3 and 4 should be merged.
- **User Response**: Chose the complete environment scope and approved recording it directly.
- **Decision**: `configure` covers the complete agreed environment, including the desktop and user tools.
- **Status**: Accepted

## DEC-004
- **Question**: What is included in the complete environment that `configure` must apply?
- **Context/Nuances**: The scope should be bounded by agreed MVP requirements rather than undefined future personalizations. Additional software or preferences can be proposed through reviewable scope changes.
- **User Response**: Approved the recommended MVP boundary and requested that it be recorded directly.
- **Decision**: “Complete environment” means the environment in the existing MVP scope described by the PRD, including the agreed desktop and workflow. It excludes software and personal preferences not yet specified; those may be added through reviewable scope changes.
- **Status**: Accepted

## DEC-005
- **Question**: How should MirrorOS express and apply the MVP package and configuration set?
- **Context/Nuances**: The starting point should favor existing Arch and application mechanisms. A central manifest would add a MirrorOS abstraction and should require demonstrated value.
- **User Response**: Approved the recommendation to record the decision directly.
- **Decision**: Start with native Arch and application formats plus explicit scripts to apply configuration. Do not create a central manifest describing the entire environment unless a concrete need demonstrates its value.
- **Status**: Accepted

## DEC-006
- **Question**: Should Epics 3 and 4 remain separate when configuration covers the complete MVP environment?
- **Context/Nuances**: MirrorOS is intended to be the user's desktop. A base configuration without a desktop is not a meaningful independent readiness milestone. The epics should not remain separate merely to distinguish mechanism from content.
- **User Response**: Approved recording the conclusion directly.
- **Decision**: Treat system configuration, desktop, and user tools as one ready-environment outcome. Do not maintain separate configuration and desktop epics unless a useful practical boundary is identified.
- **Status**: Accepted

## DEC-007
- **Question**: Must separate installations use identical package versions, or is the same declared environment sufficient?
- **Context/Nuances**: MirrorOS uses rolling Arch repositories. Version pinning and exact historical package reconstruction are not required for the current goal.
- **User Response**: Stated that package versions do not need to be pinned and approved recording the decisions directly.
- **Decision**: `configure` installs the MVP's declared package and configuration set using package versions available from the repositories at execution time. Separate installations share the environment definition but are not guaranteed to have identical package versions.
- **Status**: Accepted

## DEC-008
- **Question**: Is `configure` intended to continuously synchronize already configured machines, or reconstruct the agreed environment on new installations?
- **Context/Nuances**: The goal is not ongoing drift reconciliation or fleet synchronization. The same version-controlled environment definition should be applied when setting up separate machines; exact package-version identity is not required.
- **User Response**: Clarified that MirrorOS should install the established environment on a new machine, not synchronize existing machines, and approved recording both clarifications directly.
- **Decision**: `configure` is a reconstruction step for applying the established environment definition to a newly installed system, not a continuous synchronization mechanism for configured machines.
- **Status**: Accepted

## DEC-009
- **Question**: What recovery behavior is needed if `configure` fails partway through?
- **Context/Nuances**: Recovery should be practical without introducing a complex resume engine or ongoing drift reconciliation. Rerunning is distinct from continuous synchronization.
- **User Response**: Approved the recommendation and requested that it be recorded directly.
- **Decision**: The user can rerun `configure` from the beginning after interruption. Steps already in the expected state should avoid unnecessary changes, and the run must identify the failed step. No separate complex resume mechanism is required.
- **Status**: Accepted

## DEC-010
- **Question**: Should Epic 3 remain an independent configuration-mechanism epic, or should its work be integrated into the ready-desktop environment epic?
- **Context/Nuances**: The agreed outcome is reconstruction of the complete MVP desktop environment on a newly installed machine. Configuration is not a separate user-visible outcome. The current architecture and associated stories contain normative requirements that must be reconciled before rewriting; this decision does not itself specify the final epic title or story breakdown.
- **User Response**: Confirmed that Epic 3's work should be integrated into the ready-desktop environment epic.
- **Decision**: Integrate Epic 3 configuration work into the epic that delivers the ready MVP desktop environment; do not retain Epic 3 as an independent abstract mechanism epic.
- **Status**: Accepted

## DEC-011
- **Question**: Should MirrorOS retain a formal capability inventory as a separate mechanism?
- **Context/Nuances**: The architecture currently requires a minimal capability inventory, while the accepted direction rejects an assumed generic inventory or central manifest. The MVP scope, package provenance, and required checks must remain reviewable without introducing a separate MirrorOS data layer.
- **User Response**: Approved removing the separate formal inventory and requested that the decision be recorded directly.
- **Decision**: Do not create or maintain a formal capability inventory as a separate mechanism. Retain a human-readable list of MVP scope, and document package provenance and checks in native declarations or alongside the scripts that apply them.
- **Status**: Accepted

## DEC-012
- **Question**: Should MirrorOS run a shell-versus-Ansible comparison, or use explicit scripts for configuration?
- **Context/Nuances**: The current architecture requires a comparative prototype, but the user has stated Ansible is not intended. The existing architecture prefers Bash for native Arch integration. Any norm that mandates the prototype must be updated before implementation stories are revised.
- **User Response**: Approved dropping the comparison and recording the decision directly.
- **Decision**: Do not implement the shell-versus-Ansible prototype. Apply configuration with bounded Bash scripts and native Arch/application formats. Reconsider a framework only if actual recurring problems in those scripts demonstrate its value.
- **Status**: Accepted

## DEC-013
- **Question**: Should configuration postconditions and complete environment readiness verification remain separate?
- **Context/Nuances**: In the current epic breakdown, independent readiness verification belongs to Epic 5 (FR37–FR45), not Epic 4. Configuration must not report full readiness merely because its operations completed. Verification must remain independently runnable.
- **User Response**: Approved preserving the separation and requested that the decision be recorded directly.
- **Decision**: `configure` checks postconditions for the changes it performs. The independent `verify` stage evaluates whether the complete MVP environment is ready and remains separate from configuration.
- **Status**: Accepted

## DEC-014
- **Question**: Should `operations/configure` remain the documented entry point for applying the complete MVP environment, with bounded task-specific scripts internally?
- **Context/Nuances**: The existing command is a stub whose help describes capability modules and convergence declarations, which no longer matches the accepted direction. The lifecycle interface remains a documented stage; internal scripts need not form a public CLI.
- **User Response**: Approved retaining the entry point and requested that the decision be recorded directly.
- **Decision**: Keep `operations/configure` as the documented command for preparing the complete MVP environment. It may invoke explicit, bounded Bash scripts for concrete tasks; those internal scripts are not a separate public CLI.
- **Status**: Accepted

## DEC-015
- **Question**: Should the complete MVP environment be configured before the first normal reboot or after the newly installed system's first boot?
- **Context/Nuances**: The PRD requires personal environment configuration before the first normal reboot (FR18), and the desired first normal use should not encounter background installation work. The execution mechanism remains open: configuration may be applied against the target during installation or through a first-boot path, but must respect privilege boundaries and avoid presenting an incomplete desktop as ready.
- **User Response**: Approved the recommendation to have the environment prepared before the first normal reboot, while asking for a comparison of user-experience options and the Omarchy pattern.
- **Decision**: The complete MVP environment must be prepared before the first normal reboot. The exact execution mechanism and presentation remain open for evaluation.
- **Status**: Accepted

## DEC-016
- **Question**: Where should the complete MVP environment be configured to provide the best first-use experience?
- **Context/Nuances**: Options considered were configuration during installation against the target root, first-boot setup before the graphical session, and background installation after login. Omarchy's ISO follows a comparable install-time pattern: system setup in the target chroot, followed by user setup. Background installation after login would expose an incomplete desktop and can interfere with use. Privilege boundaries remain in force: system operations elevate narrowly and user configuration does not run wholesale as root.
- **User Response**: Accepted the recommendation to configure during installation and requested that it be recorded directly.
- **Decision**: Apply the complete MVP environment during installation against the installed target, before the first normal reboot, with visible progress and actionable failures. Do not defer required environment setup to background work after login.
- **Status**: Accepted

## DEC-017
- **Question**: Should the guided installation invoke configuration before reboot while keeping `operations/configure` independently invocable?
- **Context/Nuances**: The install procedure currently applies the base system; the configure command is a help-only stub. Lifecycle stages must remain independently invocable, while the MVP desktop must be ready before first normal use. Configuration failure must remain attributable to configuration and cannot be represented as a ready environment.
- **User Response**: Approved the recommendation and requested that it be recorded directly.
- **Decision**: The guided installation runs `configure` after base installation and before the first normal reboot. `operations/configure` remains independently invocable. If required configuration fails, installation must not report the environment as ready.
- **Status**: Accepted

## DEC-018
- **Question**: Should the integrated environment epic include an initial story that makes the exact MVP desktop scope explicit and reviewable?
- **Context/Nuances**: This is a scope-definition story, not an architecture or implementation story. It must not recreate the rejected formal capability inventory.
- **User Response**: Approved the recommendation and requested that it be recorded directly.
- **Decision**: Include an initial story that defines and documents the concrete, reviewable software and capabilities in the MVP environment. Do not implement a formal capability inventory as part of that story.
- **Status**: Accepted

## DEC-019
- **Question**: Should Epic 4 become the integrated epic, absorbing Epic 3?
- **Context/Nuances**: Epic 4 already promises the agreed outcome (a ready daily environment with desktop and workflow tools); Epic 3 is mostly mechanism. The restructuring must adapt every affected artifact, including documentation. Accepted ADRs that reference Epic 3 or Story 3.2 must not be rewritten (ADR history rules).
- **User Response**: Asked to create a plan whose objective is to rewrite Epic 4 and adapt the necessary artifacts, including docs, so that Epics 3 and 4 are merged; afterwards each story will be worked one by one as usual.
- **Decision**: Epic 4 is the integrated epic. It absorbs the useful work of Epic 3, which is retired as an independent epic. A plan will rewrite Epic 4 and adapt affected artifacts; implementation of the resulting stories follows later, one story at a time.
- **Status**: Accepted

## DEC-020
- **Question**: How should epic numbering be handled after the merge?
- **Context/Nuances**: Accepted ADRs 0003, 0008, 0009 and `prototypes/storage/btrfs-limine/README.md` reference "Story 3.2"/"Epic 3" for AUR provenance; contracts and ADRs reference Epics 5 and 6. Accepted ADRs must not be rewritten. Renumbering would break those references.
- **User Response**: Approved option A and requested that it be recorded directly.
- **Decision**: Keep existing numbers. Epic 4 is rewritten in place. Epic 3 remains in `docs/epics.md` as a short retired/merged section with a correspondence table mapping each former Epic 3 story (e.g. Story 3.2) to its destination in Epic 4 or to its explicit removal. Epics 5 and 6 keep their numbers.
- **Status**: Accepted

## DEC-021
- **Question**: Should the plan include an ADR and an architecture update resolving the convergence gate and the capability inventory?
- **Context/Nuances**: `docs/architecture.md` still mandates a shell-versus-Ansible prototype and a minimal capability inventory. Repository rules require prototype-gated decisions to be resolved through an ADR. The research document is non-normative. PRD FR20 (define the MVP capability inventory) is satisfied by the human-readable MVP scope list, so the PRD is not changed.
- **User Response**: Approved and requested that it be recorded directly.
- **Decision**: The plan creates ADR 0010 (Accepted) recording DEC-011 and DEC-012 (no Ansible prototype; bounded Bash scripts with native formats; formal inventory replaced by a human-readable MVP scope list), and updates `docs/architecture.md` consistently. The research document and the PRD remain unchanged.
- **Status**: Accepted

## DEC-022
- **Question**: How should the technical decisions DEC-013 to DEC-017 be reflected in the rewritten Epic 4?
- **Context/Nuances**: Those decisions exceed pure restructuring. The epic should state observable outcomes; implementation mechanics are decided while working each story.
- **User Response**: Approved the recommendation and requested that it be recorded directly.
- **Decision**: Reflect them in Epic 4 only as observable acceptance outcomes: the environment is ready before the first normal reboot with no background installation after login; `operations/configure` stays independently invocable and safely rerunnable; a configuration failure is never presented as a ready environment; `verify` stays independent in Epic 5. Mechanics (`arch-chroot`, installer sequencing, system/user split) are decided per story, with the interview decisions as context rather than closed epic criteria.
- **Status**: Accepted

## DEC-023
- **Question**: What is the story breakdown of the rewritten Epic 4 and the correspondence for retired Epic 3 stories?
- **Context/Nuances**: Current Epic 4 outcome stories are kept; three foundation stories absorb the useful Epic 3 work. Current Story 4.x identifiers have no references outside `docs/epics.md`, so renumbering them is safe. Story 3.2 carries concrete obligations from accepted ADRs 0003, 0008, 0009 (pinned AUR tools, update path, Gradle limitation), so it keeps a dedicated destination.
- **User Response**: Approved and requested that it be recorded directly.
- **Decision**: New Epic 4 stories: 4.1 Define the MVP environment scope (human-readable list plus frozen frequent-action list); 4.2 Apply the environment through `configure` (independent command, invoked by installation before reboot, rerunnable, validation before mutation, bounded privilege, runtime secrets); 4.3 Record package and external source provenance (AUR review and ADR 0003/0008/0009 obligations); 4.4–4.10 the current Stories 4.1–4.7 renumbered (graphical session, terminal, Wayland operations, controls, development, browser, first login). Correspondence: 3.1→4.1, 3.2→4.3, 3.3→removed (ADR 0010), 3.4/3.5/3.6→4.2.
- **Status**: Accepted

## DEC-024
- **Question**: Which operational artifacts does the restructuring plan adapt?
- **Context/Nuances**: `operations/configure` help and `docs/procedures/configure.md` still describe capability modules and a prototype-gated convergence mechanism. `tests/operations/configure.contract.bats` asserts only the pending diagnostic, not the purpose text. `operations/verify` and `docs/procedures/verify.md` belong to Epic 5 and their "capability inventory" wording remains consistent with PRD FR20.
- **User Response**: Approved and requested that it be recorded directly.
- **Decision**: Align only the wording of `operations/configure` help and `docs/procedures/configure.md` (remove capability modules and the prototype gate; describe an independent stage that prepares the MVP environment through bounded Bash scripts; defer remaining details to Story 4.2). The command stays help-only with no new behavior. Do not modify `operations/verify` or `docs/procedures/verify.md`. In `docs/epics.md`, only retarget Story 5.1's "frozen capability inventory" reference to the scope defined by Story 4.1.
- **Status**: Accepted
