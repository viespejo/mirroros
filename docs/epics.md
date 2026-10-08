---
stepsCompleted:
  - step-01-extraction
  - step-02-epic-design
  - step-03-story-creation
  - step-04-final-validation
status: complete
completedAt: '2026-09-25'
inputDocuments:
  - "docs/prd.md"
  - "docs/architecture.md"
  - "docs/product-brief-mirroros.md"
  - "docs/research/technical-mirroros-foundations-research-2026-09-24.md"
  - "docs/brainstorming/brainstorming-session-2026-09-23-201236.md"
---

---
stepsCompleted: []
inputDocuments: []
---

# MirrorOS - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for MirrorOS, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: The user can build a MirrorOS installation artifact from the version-controlled product definition.
FR2: The user can identify the location and relevant build metadata of a generated installation artifact.
FR3: The user can invoke the build, test, install, configure, and verify lifecycle stages independently.
FR4: The user can execute the lifecycle stages as one documented end-to-end reconstruction journey.
FR5: The user can launch the MirrorOS validation journey in the reference disposable VM environment.
FR6: The user can execute reproducible, non-destructive operations without interactive input.
FR7: The user can discover each lifecycle stage's purpose, prerequisites, required inputs, and consequential effects.
FR8: The user can observe the current stage and outcome of each lifecycle operation.
FR9: External scripts and test harnesses can distinguish successful execution, verification failure, invalid input, user cancellation, and execution failure.
FR10: The user can inspect the target device's relevant hardware, storage, and network state before installation changes begin.
FR11: The user can review a proposed installation plan before the target device is modified.
FR12: The user can identify whether each proposed default originates from personal preference, hardware detection, Arch guidance, or technical necessity.
FR13: The user can modify editable installation choices before approving the plan.
FR14: The user must explicitly confirm partitioning, disk erasure, secret handling, and ambiguous decisions.
FR15: The user receives the same destructive-action confirmation behavior on virtual and physical devices.
FR16: The user can cancel at a confirmation boundary without the cancellation being reported as successful installation or execution failure.
FR17: The user can install the required base operating system onto the selected target.
FR18: The user can complete personal environment configuration before the first normal reboot.
FR19: MirrorOS can withhold a successful completion state until required verification has run.
FR20: The user can define the capability inventory required for the MVP daily workflow.
FR21: The user can declare required packages and record the source provenance of each package.
FR22: The user can declare required system and user services.
FR23: The user can declare configuration for the graphical environment, terminal, shell, Tmux, editor, Git, browser capabilities, keyboard shortcuts, and development tools.
FR24: The user can organize environment declarations into independently applicable capability modules.
FR25: The user can validate environment declarations before consequential changes are applied.
FR26: The user can apply the declared environment independently of image construction and base-system installation.
FR27: The user can reapply configuration to converge the system without duplicating declared state.
FR28: The user can keep portable configuration, hardware-derived choices, privileged changes, secret references, and private state separate.
FR29: The user can provide or resolve required secrets without storing their values in the repository, logs, or installation artifact.
FR30: The user can reach the first graphical login with the declared MVP environment already applied.
FR31: The user can apply or replace a desktop or workflow component without requiring unrelated environment modules to change.
FR32: MirrorOS can detect hardware capabilities required by the reference VM and target laptop.
FR33: MirrorOS can select applicable configuration based on detected hardware capabilities.
FR34: The user can inspect which configuration choices were derived from hardware detection.
FR35: The user can maintain target-specific hardware adaptation separately from portable personal configuration.
FR36: The user can add support for a new hardware capability without redefining unrelated portable workflow modules.
FR37: The user can associate each declared MVP capability with one or more readiness checks.
FR38: The user can run readiness verification independently after installation or configuration.
FR39: The user can see a concise aggregate result that emphasizes failed capabilities and external blockers requiring action.
FR40: The user can see an actionable reason and next step for every failed or externally blocked capability.
FR41: The user can access the complete passed, failed, or externally blocked status of every declared capability on demand.
FR42: The user can distinguish a completed execution with failed verification from a fully verified success.
FR43: The user can retain a verification summary as reconstruction evidence.
FR44: The verification process can produce a structured summary artifact when required by tests or evidence collection.
FR45: The user can rerun verification without repeating installation or configuration.
FR46: The user can access persistent diagnostic logs for lifecycle operations.
FR47: The user can identify the failed lifecycle stage, affected capability, and last confirmed successful state.
FR48: MirrorOS can stop a failed operation before performing avoidable subsequent changes.
FR49: The user can retry a safe failed stage without implicitly repeating unrelated completed stages.
FR50: MirrorOS can prevent destructive actions from being retried without renewed explicit confirmation.
FR51: The user can follow documented recovery procedures when installation or configuration cannot continue.
FR52: The user can abandon a failed physical-device attempt and use an independent rescue path.
FR53: The user can identify undocumented intervention used during recovery so that it can be incorporated into the repository or documentation.
FR54: The user can manually update the version-controlled environment definition after changing the daily system.
FR55: The user can review declared changes before applying them.
FR56: The user can test a changed environment definition in the reference VM when its risk justifies validation.
FR57: The user can apply a validated environment change to the daily system independently of reinstallation.
FR58: The user can preserve the history and rationale of environment evolution through version-controlled changes.
FR59: The user can reflect migration and recovery fixes back into the authoritative environment definition.
FR60: The user can complete the documented clean-VM validation before proceeding to physical-device migration.
FR61: The user can declare explicit prerequisites between capability modules.
FR62: The user can organize modules by user capability independently of the current package or tool used to provide that capability.
FR63: The user can isolate stable system declarations from faster-changing workflow and application declarations.
FR64: The user can perform every action in the frozen frequent-action inventory through a keyboard-accessible path.
FR65: The user can validate terminal, browser, portal-dependent operations, clipboard, screenshots, launcher, bar, and notifications within the provisional desktop environment.

### NonFunctional Requirements

NFR1: The initial reconstruction target is less than two hours from booting the installation medium to a passing ready-state verification on the target laptop.
NFR2: Reconstruction timing must be measured under documented hardware, network, and package-source conditions so results can be compared across runs.
NFR3: The two-hour target excludes restoration of personal data, private repositories, credentials, authenticated sessions, and optional application state.
NFR4: The reconstruction target remains provisional until at least one complete VM baseline and one target-laptop run provide measured evidence.
NFR5: Every long-running lifecycle operation must expose its active stage so the user can distinguish progress from a stalled process.
NFR6: The repository must be safe to publish without exposing credentials, private keys, secret values, personal content, or authenticated session material.
NFR7: Automated inspection of the repository, generated installation artifacts, verification summaries, and diagnostic logs must detect zero known secret values before an artifact is accepted.
NFR8: Secret values must not appear in terminal output, persistent logs, build metadata, or verification artifacts.
NFR9: Privileged execution must be limited to operations that require system-level access; user-level configuration must not inherit privilege solely for execution convenience.
NFR10: Every partitioning or disk-erasure operation must require explicit confirmation that identifies the selected target.
NFR11: A cancelled destructive confirmation must result in zero execution of the rejected destructive operation.
NFR12: One hundred percent of installed packages must have recorded source provenance.
NFR13: Generated installation artifacts must include a checksum and metadata that relates the artifact to its source state.
NFR14: Portable public configuration, hardware-specific configuration, private state, and secret references must remain separable for review and distribution.
NFR15: A documented clean-clone build must produce a bootable installation artifact in the supported build environment.
NFR16: One complete reconstruction must pass in the reference VM before physical-device installation is considered eligible to proceed.
NFR17: A second configuration run against an already configured system must produce zero unintended changes and zero duplicated state.
NFR18: Every declared MVP capability must end verification in exactly one explicit state: passed, failed, or blocked by an identified external dependency.
NFR19: No failed or incomplete verification may be reported as a ready system.
NFR20: A lifecycle-stage failure must prevent avoidable dependent stages from continuing.
NFR21: Retrying a safe failed stage must not implicitly repeat destructive or unrelated completed operations.
NFR22: Destructive retries must require renewed explicit confirmation.
NFR23: The complete VM and target-laptop journeys must contain zero undocumented manual steps.
NFR24: An independent rescue path and documented recovery procedure must be available before installation begins on the target laptop.
NFR25: Diagnostic evidence from a failed run must remain accessible after termination unless the user explicitly removes it.
NFR26: Recovery workarounds required to complete a supported journey must be captured in version control or documentation before that journey is considered reproducible.
NFR27: The MVP must satisfy its complete capability inventory on one reference VM configuration and one target laptop.
NFR28: Behavior outside the declared MVP hardware targets carries no compatibility guarantee.
NFR29: Hardware-specific adaptation must not alter unrelated portable workflow declarations.
NFR30: Adding a hardware capability rule must not require redesigning the portable configuration model.
NFR31: Every generated artifact must record sufficient package, repository, source, and relevant tool-version metadata to diagnose the environment from which it was built.
NFR32: The strategy for current packages versus known-good package sets remains an architecture decision, but each accepted artifact must be validated against the package set it actually contains.
NFR33: Niri-specific configuration must remain isolated so replacing the compositor does not require redesigning installation or unrelated workflow modules.
NFR34: One experienced maintainer must be able to build, test, install, configure, verify, and troubleshoot MirrorOS using repository documentation.
NFR35: Every lifecycle stage must have documented prerequisites, inputs, expected outputs, failure evidence, and recovery guidance.
NFR36: A change confined to one capability module must not require modifications to unrelated modules unless an explicit dependency exists.
NFR37: Custom code, formats, services, and abstractions must have a documented recurring need that cannot be met adequately through simpler supported mechanisms.
NFR38: MirrorOS must not require a proprietary configuration format unless comparative research identifies and documents a concrete gap in existing options.
NFR39: The configuration source must remain human-readable and reviewable without requiring a running MirrorOS environment.
NFR40: The quantitative maintenance budget remains unset until repeated builds, updates, and reconstructions establish an evidence baseline.
NFR41: Failures originating in upstream tools must retain enough original diagnostic context to identify the responsible operation and dependency.
NFR42: Integration wrappers must not convert an upstream failure into a successful MirrorOS outcome.
NFR43: Persistent logs must identify the lifecycle stage, operation outcome, and relevant non-secret diagnostic context.
NFR44: Command outcomes must remain distinguishable through reliable exit statuses for success, validation failure, invalid input, cancellation, and execution failure.
NFR45: Concise and structured verification outputs must represent the same aggregate outcome as the complete per-capability report.
NFR46: Binding choices of installer, configuration mechanism, orchestration tool, and package-state strategy must remain deferred until comparative research and a minimal prototype provide evidence.
NFR47: MirrorOS must introduce zero persistent assistants, welcome applications, or healthy-state notifications in the MVP.
NFR48: One hundred percent of actions in the frozen frequent-action inventory must have a documented keyboard-accessible path.
NFR49: Supported desktop components must use the declared typography, color, and density choices where those choices require no additional theming framework.
NFR50: Visual customization must remain independently removable without breaking functional environment configuration.
NFR51: Each maintained deviation from an upstream visual default must have identifiable daily value or negligible maintenance cost.
NFR52: A task must have a documented manual or assisted process and demonstrated repetition before MirrorOS introduces custom automation for it.

### Additional Requirements

- Initialize the repository from a project-owned, attributed copy of the official Archiso `releng` profile; retain recognizable upstream structure, record upstream identity, and use the documented `mkarchiso` build command.
- Use independently invocable documented lifecycle scripts for build, test, install, configure, verify, and clean; do not introduce a unified CLI or task runner unless evidence demonstrates recurring value.
- Use Bash for native Arch integration and JavaScript ESM on Node.js only for non-trivial structured logic; project-owned Python is forbidden unless an accepted ADR explicitly authorizes it.
- Complete and record the Archinstall JSON/CLI versus native Arch-command installation prototype and ADR before populating the production installation-engine boundary.
- Complete and record the shell versus Ansible local-mode convergence prototype and ADR before selecting a production configuration mechanism; Ansible is confined to its prototype until selected.
- Freeze the exact MVP capability inventory and verification checks before broad desktop and workflow implementation.
- Implement a synchronous local pipeline with explicit process, file, exit-status, plan, evidence, and target-root contracts; preserve upstream diagnostics and original child exit status.
- Use normalized lifecycle exit statuses: success (0), invalid input/precondition (2), cancellation (3), verification not ready (4), execution failure (5), and internal contract failure (6).
- Generate reviewable installation plans containing target identity, discovery facts, proposed operations, default provenance, secret requirements, and a content digest; confirmation is bound to that digest and expires when plan or target state changes.
- Use UEFI, GPT, an unencrypted root filesystem with the storage option selected under [ADR 0003](adr/0003-storage-and-recovery-baseline.md) (ext4 with systemd-boot by default), and a resizeable swapfile; hibernation is an MVP capability, including resume-offset maintenance and repeated validation with hybrid AMD/NVIDIA graphics.
- Keep Secure Boot disabled for the MVP; use the official Arch `linux` kernel for initial qualification, with CachyOS kernel evaluation isolated as a reversible experiment.
- Separate image, installation, hardware, target override, system capability, user capability, visual capability, verification, inventory, and prototype ownership; Niri remains a replaceable compositor provider.
- Treat native Arch and application formats as authoritative; do not create a proprietary configuration schema or database.
- Keep Neovim, Pi, and other independent application repositories authoritative; integrate them through explicit clone/link/configuration operations rather than copied configuration trees.
- Record source identity, tool versions, repositories, resolved package manifests, checksums, VM configuration, stage durations, and secret-scanned allowlisted logs in per-run evidence.
- Enforce secret scanning with gitleaks against source, staging trees, artifacts, retained evidence, and logs; use runtime-only secret injection and narrow privilege boundaries.
- Qualify artifacts through QEMU/KVM with OVMF before physical installation; promote artifacts only through build, boot, install, configuration, hibernation, idempotency, and capability-verification gates.
- Maintain distinct current-package canary and accepted-known-good artifact tracks; require external backup, independent rescue media, and VM qualification before the Framework Laptop 13 Pro physical migration.
- Use the defined project layout, naming, atomic structured-output, validation-before-mutation, postcondition, idempotency, retry, attribution, testing, and documentation conventions from Architecture.
- Do not introduce public-distribution infrastructure, Calamares, custom repositories, persistent assistants, welcome applications, background management daemons, remote control planes, or broad hardware support in the MVP.

### UX Design Requirements

No UX Design document was provided; no UX-specific requirements were extracted.

### FR Coverage Map

### FR Coverage Map

FR1: Epic 1 - Build a traceable installation artifact.
FR2: Epic 1 - Locate artifact and build metadata.
FR3: Epic 1 - Independently invoke lifecycle stages.
FR4: Epic 6 - Execute the complete documented reconstruction journey.
FR5: Epic 1 - Launch reference-VM validation.
FR6: Epic 1 - Run reproducible non-destructive operations without input.
FR7: Epic 1 - Discover lifecycle purpose, prerequisites, inputs, and effects.
FR8: Epic 1 - Observe lifecycle stage and outcome.
FR9: Epic 1 - Distinguish execution outcomes for scripts and tests.
FR10: Epic 2 - Inspect target hardware, storage, and network.
FR11: Epic 2 - Review the installation plan.
FR12: Epic 2 - Identify default provenance.
FR13: Epic 2 - Edit installation choices.
FR14: Epic 2 - Explicitly confirm consequential decisions.
FR15: Epic 2 - Use consistent destructive confirmation across targets.
FR16: Epic 2 - Cancel safely at confirmation boundaries.
FR17: Epic 2 - Install the base operating system.
FR18: Epic 2 - Configure before first normal reboot.
FR19: Epic 2 - Withhold success until verification runs.
FR20: Epic 3 - Define the MVP capability inventory.
FR21: Epic 3 - Declare packages and their provenance.
FR22: Epic 3 - Declare required services.
FR23: Epic 4 - Declare graphical and daily-work tooling configuration.
FR24: Epic 3 - Organize independently applicable capability modules.
FR25: Epic 3 - Validate declarations before consequential changes.
FR26: Epic 3 - Apply environment independently of image and installation.
FR27: Epic 3 - Reapply configuration without duplication.
FR28: Epic 3 - Separate portable, hardware, privileged, secret, and private concerns.
FR29: Epic 3 - Resolve secrets without storing their values.
FR30: Epic 4 - Reach first graphical login with the MVP environment applied.
FR31: Epic 4 - Replace desktop or workflow components independently.
FR32: Epic 2 - Detect supported hardware capabilities.
FR33: Epic 2 - Select configuration from detected capabilities.
FR34: Epic 2 - Inspect hardware-derived choices.
FR35: Epic 2 - Separate target hardware adaptation from portable configuration.
FR36: Epic 2 - Add hardware capabilities without redefining portable modules.
FR37: Epic 5 - Associate capabilities with readiness checks.
FR38: Epic 5 - Run readiness verification independently.
FR39: Epic 5 - View concise aggregate readiness results.
FR40: Epic 5 - Receive actionable failure or blocker next steps.
FR41: Epic 5 - Access complete per-capability status.
FR42: Epic 5 - Distinguish verification failure from verified success.
FR43: Epic 5 - Retain verification evidence.
FR44: Epic 5 - Produce structured verification summaries when needed.
FR45: Epic 5 - Rerun verification independently.
FR46: Epic 5 - Access persistent diagnostic logs.
FR47: Epic 5 - Identify failed stage, capability, and last confirmed state.
FR48: Epic 5 - Stop avoidable dependent operations after failure.
FR49: Epic 5 - Retry a safe failed stage independently.
FR50: Epic 5 - Require renewed confirmation for destructive retries.
FR51: Epic 5 - Follow documented recovery procedures.
FR52: Epic 5 - Use an independent rescue path after physical failure.
FR53: Epic 5 - Capture undocumented recovery intervention for correction.
FR54: Epic 6 - Update the version-controlled environment definition.
FR55: Epic 6 - Review declared changes before application.
FR56: Epic 6 - Validate risky changes in the reference VM.
FR57: Epic 6 - Apply validated changes without reinstalling.
FR58: Epic 6 - Preserve evolution history and rationale.
FR59: Epic 6 - Return migration and recovery fixes to source.
FR60: Epic 6 - Complete VM validation before physical migration.
FR61: Epic 3 - Declare module prerequisites.
FR62: Epic 3 - Organize modules by user capability.
FR63: Epic 3 - Separate stable from fast-changing declarations.
FR64: Epic 4 - Provide keyboard-accessible frequent actions.
FR65: Epic 4 - Validate provisional desktop capabilities.

## Epic List

### Epic 1: Establish a Trustworthy MirrorOS Bootstrap
The user can research critical choices, build a traceable minimal installation medium from a clean clone, and validate that it boots with networking in the reference VM.
**FRs covered:** FR1, FR2, FR3, FR5, FR6, FR7, FR8, FR9

### Epic 2: Install a Target System Safely and Transparently
The user can inspect a supported VM or laptop, review and edit an explainable installation plan, safely approve it, and install a base system with appropriate hardware adaptation.
**FRs covered:** FR10–FR19, FR32–FR36

### Epic 3: Define and Converge the Portable Environment
The user can declare, validate, apply, and safely reapply portable system capabilities while keeping private, privileged, and hardware-specific concerns separate.
**FRs covered:** FR20–FR22, FR24–FR29, FR61–FR63

### Epic 4: Restore a Ready Daily-Work Environment
The user reaches first graphical login with a keyboard-accessible, cohesive daily environment—including the provisional desktop stack and declared development workflow—already ready to use.
**FRs covered:** FR23, FR30, FR31, FR64, FR65

### Epic 5: Verify Readiness and Recover from Failures
The user can independently verify every declared capability, understand readiness outcomes, retain diagnostic evidence, and safely diagnose, retry, or recover from failures.
**FRs covered:** FR37–FR53

### Epic 6: Complete Repeatable Migration and Evolve MirrorOS
The user can execute the complete VM-to-laptop reconstruction journey, safely maintain the environment as it changes, and return validated migration fixes to the source of truth.
**FRs covered:** FR4, FR54–FR60

<!-- Repeat for each epic in epics_list (N = 1, 2, 3...) -->

## Epic 1: Establish a Trustworthy MirrorOS Bootstrap

The user can research critical choices, build a traceable minimal installation medium from a clean clone, and validate that it boots with networking in the reference VM.

### Story 1.1: Set Up the Initial Project from the Archiso Starter

**Requirements:** Architecture starter requirement

As the MirrorOS maintainer,
I want an attributed project-owned copy of the official Archiso `releng` profile,
So that I can build from a recognizable upstream foundation while safely tracking local changes.

**Acceptance Criteria:**

**Given** the approved Archiso source baseline is available
**When** I initialize the MirrorOS image profile
**Then** `image/archiso/` contains a complete project-owned copy of the official `releng` profile
**And** its upstream layout remains recognizable without functional personalization.

**Given** the profile has been imported
**When** I inspect `image/archiso/UPSTREAM.md` and project attribution records
**Then** they identify the upstream project, source URL, revision or package version, import date, license, incorporation method, and local-delta summary
**And** copied upstream files retain their applicable notices.

**Given** a future Archiso update is needed
**When** I follow the documented update procedure
**Then** I can import the upstream profile on the designated vendor branch, merge it into the main branch, review conflicts and local deltas, and requalify build and boot behavior
**And** the procedure does not claim that untested BIOS/Syslinux paths are supported by the MVP.

**Given** the imported profile is inspected in a clean clone
**When** source-control status and repository checks run
**Then** generated Archiso work/output directories are not tracked as source
**And** no secrets, private values, or personal environment configuration are added to the live-media profile.

### Story 1.2: Establish Repository Governance and Lifecycle Discovery

**Requirements:** FR3, FR6, FR7, FR8, FR9

As the MirrorOS maintainer,
I want a governed repository with discoverable lifecycle entry points,
So that I can safely understand the supported workflow and begin work without undocumented conventions.

**Acceptance Criteria:**

**Given** a clean MirrorOS repository clone
**When** I inspect its root documentation and governance files
**Then** I can identify the project license, contributor/agent rules, ignored generated paths, shell-validation configuration, attribution process, ADR template, and Archiso-update procedure
**And** workflow-managed directories are retained and explicitly treated as outside the product runtime.

**Given** I need to discover a lifecycle operation
**When** I invoke or consult the documented build, test, install, configure, verify, or clean entry point
**Then** its purpose, prerequisites, expected inputs, consequential effects, evidence location, and possible normalized exit outcomes are discoverable
**And** the initial implementation uses documented scripts rather than a unified CLI, Make, or Just.

**Given** a lifecycle command has not yet implemented its full domain behavior
**When** it is invoked
**Then** it must not report successful completion for unimplemented work
**And** it returns a documented, distinguishable invalid-precondition or execution outcome without modifying the system.

**Given** source or generated evidence is prepared for acceptance
**When** repository validation runs
**Then** secret scanning covers the intended source and generated-evidence paths
**And** generated `build/`, `dist/`, and `evidence/` outputs are excluded from authoritative source control.

### Story 1.3: Build a Traceable Installation Artifact

**Requirements:** FR1, FR2, FR6, FR8, FR9

As the MirrorOS maintainer,
I want to build the installation artifact from a clean repository state,
So that I have a reproducible bootstrap medium whose origin and contents can be diagnosed.

**Acceptance Criteria:**

**Given** a clean clone containing the attributed Archiso profile and documented build prerequisites
**When** I run the documented build operation
**Then** it invokes `mkarchiso` using isolated work and output directories
**And** it produces an installation artifact without requiring undocumented manual intervention.

**Given** an artifact is built successfully
**When** the build operation completes
**Then** it reports the artifact location and writes a checksum
**And** it records source commit and dirty-state indication, Archiso version, build timestamp, repository configuration, resolved package manifest, and relevant tool versions.

**Given** build validation runs before artifact acceptance
**When** source, staging, artifact metadata, and retained build evidence are scanned
**Then** no known secret value is detected
**And** secret values are absent from terminal output, build metadata, and retained logs.

**Given** `mkarchiso` or a prerequisite fails
**When** the build operation terminates
**Then** it preserves relevant non-secret upstream diagnostic context and records the failed stage and original child status in run evidence
**And** it returns the documented normalized execution-failure outcome without presenting an artifact as accepted.

### Story 1.4: Validate the Bootstrap Medium in the Reference VM

**Requirements:** FR5, FR8, FR9

As the MirrorOS maintainer,
I want to boot a built MirrorOS artifact in the reference UEFI VM and verify networking,
So that I have evidence that the bootstrap medium is usable before attempting installation work.

**Acceptance Criteria:**

**Given** a built artifact with checksum and build metadata
**When** I invoke the documented reference-VM test operation
**Then** it verifies required KVM acceleration and OVMF prerequisites before launching QEMU
**And** it creates or uses only disposable VM disks and runtime outputs.

**Given** the VM prerequisites are available
**When** the artifact boots through the supported UEFI/OVMF path
**Then** the test verifies that the live environment reaches a usable installation entry point with working network connectivity
**And** the result records the artifact identity, VM configuration, boot outcome, and test duration.

**Given** KVM, OVMF, boot, or networking validation fails
**When** the test operation ends
**Then** it identifies the failing stage and an actionable next step
**And** it retains allowlisted, secret-scanned diagnostic evidence without claiming boot qualification.

**Given** the reference-VM validation succeeds
**When** I review the resulting evidence
**Then** the artifact is eligible for later installation-engine prototypes
**And** it is not yet represented as install-tested, capability-verified, or target-laptop eligible.

## Epic 2: Install a Target System Safely and Transparently

The user can inspect a supported VM or laptop, review and edit an explainable installation plan, safely approve it, and install a base system with appropriate hardware adaptation.

### Story 2.1: Select the Installation Engine Through a Bounded Prototype

**Requirements:** NFR46, architecture installation-engine gate

As the MirrorOS maintainer,
I want to compare supported installation approaches against one fixed VM scenario,
So that I can learn their behavior and select an engine using evidence rather than assumption.

**Acceptance Criteria:**

**Given** the boot-qualified artifact and a fixed reference-VM scenario
**When** I run the Archinstall JSON/CLI and native Arch-command prototypes
**Then** both use the same disk, boot mode, base package set, user requirements, and postconditions
**And** production code neither imports nor sources prototype implementations.

**Given** both prototype runs are complete
**When** I compare their results
**Then** the comparison covers plan visibility, editability, confirmation, cancellation, credentials, diagnostics, exits, recovery evidence, dependencies, and maintenance cost
**And** generated results are ignored, allowlisted, and secret-scanned.

**Given** the evidence identifies a preferred approach
**When** I record the decision
**Then** an accepted ADR documents the question, evidence, trade-offs, selection, and replacement boundary
**And** only the selected approach may populate `install/engine/apply`.

### Story 2.2: Discover and Normalize the Installation Target

**Requirements:** FR10, FR32, FR34, FR35

As the MirrorOS user,
I want MirrorOS to inspect the target without modifying it,
So that installation decisions are based on visible hardware, storage, firmware, and network facts.

**Acceptance Criteria:**

**Given** a supported reference VM or target laptop
**When** I run installation discovery
**Then** MirrorOS records firmware mode, network readiness, storage identity and layout, and relevant hardware capabilities without changing target state
**And** stable identifiers, model, path, and size are retained where available.

**Given** discovery output is produced
**When** it is normalized
**Then** portable facts, detected hardware selections, and explicit target overrides remain distinguishable
**And** the precedence is portable baseline, detected selection, explicit target override, then runtime private input.

**Given** required facts are missing, contradictory, or outside the supported target boundary
**When** discovery validation runs
**Then** it exits as invalid input or unmet precondition with an actionable reason
**And** no privilege elevation or destructive operation occurs.

### Story 2.3: Generate an Explainable Installation Plan

**Requirements:** FR11, FR12, FR13

As the MirrorOS user,
I want a complete proposed installation plan before changes begin,
So that I can understand and adjust what will happen to the selected target.

**Acceptance Criteria:**

**Given** valid discovery facts and installation policy
**When** MirrorOS generates a plan
**Then** the plan identifies the target, proposed operations, defaults, secret requirements, and hardware-derived selections
**And** each default is labeled as personal preference, hardware detection, Arch guidance, or technical necessity.

**Given** the generated plan
**When** schema and safety validation run
**Then** malformed, incomplete, contradictory, and unknown safety-critical fields are rejected
**And** the valid plan is atomically persisted with a digest over its canonical content.

**Given** a valid plan contains editable choices
**When** I alter an allowed choice and regenerate it
**Then** the rendered plan reflects the change and receives a new digest
**And** the original plan remains unapproved and cannot authorize execution.

### Story 2.4: Authorize or Cancel Consequential Operations Safely

**Requirements:** FR14, FR15, FR16

As the MirrorOS user,
I want confirmations bound to the exact target and plan,
So that no destructive or ambiguous operation occurs without current, informed approval.

**Acceptance Criteria:**

**Given** a validated plan
**When** it is presented for approval
**Then** the target identity, destructive operations, secret requirements, defaults, and plan digest are visible
**And** virtual and physical targets use identical confirmation semantics.

**Given** I reject or cancel confirmation
**When** the operation terminates
**Then** none of the rejected destructive operations execute
**And** normalized cancellation status `3` is returned rather than success or execution failure.

**Given** the target state or plan content changes after approval
**When** execution is requested
**Then** prior approval is invalidated and renewed review and confirmation are required
**And** a missing interactive terminal cannot be bypassed by a generic non-interactive flag.

### Story 2.5: Install the Approved Base System

**Requirements:** FR17

As the MirrorOS user,
I want the approved plan applied through the selected installation engine,
So that the target receives a bootable Arch base without hidden policy changes.

**Acceptance Criteria:**

**Given** a current approved plan and required runtime inputs
**When** installation starts
**Then** only operations represented by the approved digest are executed
**And** UEFI, GPT, the selected storage option (ext4 with systemd-boot by default, per ADR 0003), unencrypted root, official Arch `linux`, and the declared resizeable swapfile policy are applied.

**Given** credentials or secret values are required
**When** they are supplied
**Then** they use protected runtime channels and are absent from source, process arguments, terminal output, logs, artifacts, and retained evidence
**And** user-level work does not inherit root privileges for convenience.

**Given** an upstream installation operation fails
**When** the stage terminates
**Then** avoidable dependent operations stop and original non-secret diagnostics and child status are retained
**And** installation is not reported as successful.

### Story 2.6: Apply Inspectable Hardware Adaptation and Installation Postconditions

**Requirements:** FR18, FR19, FR33, FR34, FR35, FR36

As the MirrorOS user,
I want supported hardware choices applied separately and the installed base verified before reboot,
So that the target is bootable without coupling portable configuration to one device.

**Acceptance Criteria:**

**Given** normalized hardware facts for the reference VM or target laptop
**When** hardware rules are evaluated
**Then** applicable graphics, battery, virtualization, storage, swap, and resume selections are inspectable
**And** target overrides remain separate from portable capability declarations.

**Given** a new hardware capability rule is added
**When** it is selected for a supported target
**Then** unrelated portable modules require no changes
**And** unsupported hardware produces an explicit unsupported or blocked outcome rather than an unsafe guess.

**Given** base installation and target adaptation complete
**When** installation postconditions run before normal reboot
**Then** bootloader, mounts, installed kernel, network prerequisites, swapfile, and resume configuration are checked
**And** completion is withheld on failure while the target remains diagnosable and recoverable.

## Epic 3: Define and Converge the Portable Environment

The user can declare, validate, apply, and safely reapply portable system capabilities while keeping private, privileged, and hardware-specific concerns separate.

### Story 3.1: Freeze the MVP Capability Inventory

**Requirements:** FR20, FR24, FR61, FR62, FR63

As the MirrorOS maintainer,
I want a capability-oriented inventory with explicit dependencies,
So that the intended daily environment is finite, reviewable, and independent of current providers.

**Acceptance Criteria:**

**Given** the approved MVP scope
**When** I define the inventory
**Then** every required capability has a stable dot-separated identifier, purpose, owner, dependencies, implementation reference, and verification reference
**And** identifiers describe user intent rather than replaceable tools wherever practical.

**Given** capabilities change at different rates
**When** the inventory and modules are organized
**Then** stable system, hardware, desktop, workflow, development, user, and visual responsibilities remain separable
**And** Niri is represented as a provider of `desktop.compositor`, not as the architectural capability.

**Given** an undeclared or circular prerequisite exists
**When** inventory validation runs
**Then** it fails before configuration changes begin
**And** the diagnostic identifies the affected capabilities and correction required.

### Story 3.2: Record Package and External Source Provenance

**Requirements:** FR21, FR28

As the MirrorOS maintainer,
I want every package and external artifact tied to a capability and source,
So that the environment's supply chain is reviewable and reproducible.

**Acceptance Criteria:**

**Given** an installed package or external artifact is declared
**When** provenance validation runs
**Then** it records name, version or resolution rule, source class, repository or URL, identity/checksum evidence, owning capability, and review responsibility
**And** 100 percent of declared installed packages have provenance.

**Given** an AUR package is accepted
**When** it is prepared
**Then** its `PKGBUILD` identity and review are recorded and the package is built unprivileged
**And** Chaotic-AUR and unapproved third-party repositories remain disabled.

**Given** an independent application configuration repository is integrated
**When** its capability is applied
**Then** the authoritative repository is explicitly checked out and linked or configured
**And** its configuration tree and credentials are not copied into MirrorOS source.

### Story 3.3: Select the Convergence Mechanism Through a Bounded Spike

**Requirements:** NFR37, NFR38, NFR46, architecture convergence gate

As the MirrorOS maintainer,
I want to compare shell and Ansible local mode on the same representative capability,
So that I can choose the smallest sustainable convergence mechanism after learning how each behaves.

**Acceptance Criteria:**

**Given** one capability containing a package, service, privileged file, user file, and readiness check
**When** shell and Ansible prototypes apply it
**Then** both demonstrate first-run changes, second-run behavior, failure diagnostics, privilege scope, and postcondition checks
**And** Ansible remains confined to its prototype unless selected by ADR.

**Given** the prototypes are complete
**When** they are evaluated
**Then** dry-run or diff quality, dependencies, readability, code volume, replacement cost, and maintenance burden are recorded
**And** successful exit alone is not accepted as proof of convergence.

**Given** a winner is selected
**When** the ADR is accepted
**Then** production capability modules use only the selected mechanism
**And** the losing prototype remains non-production evidence rather than a parallel supported path.

### Story 3.4: Validate Modular Environment Declarations

**Requirements:** FR25, FR28, FR61

As the MirrorOS user,
I want environment declarations validated before mutation,
So that malformed or conflicting intent cannot partially configure the machine.

**Acceptance Criteria:**

**Given** capability, package, service, hardware, target, secret-reference, and private-state declarations
**When** validation runs
**Then** required fields, references, ownership, dependencies, supported values, and precedence are checked
**And** native Arch and application formats remain authoritative rather than being replaced by a proprietary schema.

**Given** two layers claim authoritative ownership of the same package, file, service, or artifact
**When** validation runs
**Then** the conflict fails with both owners identified
**And** no configuration operation begins.

**Given** public, hardware-specific, privileged, visual, private, and secret-reference concerns are reviewed
**When** their locations are inspected
**Then** they remain independently identifiable and removable
**And** no committed declaration contains a secret value or personal content.

### Story 3.5: Apply Capabilities with Bounded Privilege and Runtime Secrets

**Requirements:** FR22, FR24, FR26, FR28, FR29

As the MirrorOS user,
I want to apply selected capability modules independently of installation,
So that my environment can converge safely without rebuilding the image or reinstalling the system.

**Acceptance Criteria:**

**Given** validated declarations and satisfied prerequisites
**When** I invoke configuration for all or selected capabilities
**Then** modules run in dependency order using validate, inspect, change, verify, and evidence phases
**And** unrelated capability modules are not executed.

**Given** a module includes system and user operations
**When** it applies changes
**Then** privilege is elevated only around operations that require it and user configuration runs as the target user
**And** commands use fixed argument arrays without `eval` or configuration-derived shell concatenation.

**Given** a capability requires a secret
**When** its reference is resolved at runtime
**Then** the value is supplied through a protected prompt, descriptor, or permission-restricted temporary file and removed after use
**And** missing external secrets produce an actionable blocked outcome without leaking values.

### Story 3.6: Prove Configuration Convergence

**Requirements:** FR27

As the MirrorOS user,
I want repeated configuration to make no unintended changes,
So that I can safely reapply the environment throughout its lifetime.

**Acceptance Criteria:**

**Given** a capability is already in its declared state
**When** its configuration is applied again
**Then** no unnecessary mutation or duplicate declaration occurs
**And** the same postcondition is verified and reported as already converged.

**Given** a declared postcondition is deliberately broken
**When** configuration runs
**Then** only the bounded required correction is applied
**And** unrelated files, services, packages, and modules remain unchanged.

**Given** the complete configured environment
**When** the second-run convergence test executes
**Then** it reports zero unintended changes and zero duplicated state
**And** secret-scanned evidence records inspected and changed outcomes without private values.

## Epic 4: Restore a Ready Daily-Work Environment

The user reaches first graphical login with a keyboard-accessible, cohesive daily environment—including the provisional desktop stack and declared development workflow—already ready to use.

### Story 4.1: Provide a Replaceable Graphical Session

**Requirements:** FR23, FR30, FR31

As the MirrorOS user,
I want a working graphical session with Niri as a provisional provider,
So that I can begin daily work while preserving the freedom to replace the compositor.

**Acceptance Criteria:**

**Given** the portable base and supported graphics adaptation are applied
**When** the installed system starts normally
**Then** the declared display/session services present a functional Niri graphical session
**And** Niri-specific packages and configuration remain isolated beneath the compositor provider boundary.

**Given** the compositor provider is disabled or replaced
**When** configuration validation runs
**Then** installation, hardware, terminal, development, and unrelated workflow modules require no redesign
**And** missing provider dependencies are reported before mutation.

**Given** graphical startup fails
**When** session postconditions run
**Then** the responsible service or provider and actionable diagnostic evidence are identified
**And** the system is not represented as graphically ready.

### Story 4.2: Restore the Terminal-Centric Workflow

**Requirements:** FR23, FR30, FR64

As the MirrorOS user,
I want my terminal, shell, and Tmux capabilities configured at first login,
So that my primary working environment is immediately familiar and productive.

**Acceptance Criteria:**

**Given** the user session is available
**When** terminal workflow modules apply
**Then** the declared terminal emulator, shell, Tmux, fonts, packages, and user configuration are installed from their authoritative sources
**And** user files are applied without running the complete process as root.

**Given** the first graphical login
**When** I launch the terminal and start Tmux through documented keyboard paths
**Then** the configured shell initializes successfully and Tmux can create and manage a session
**And** missing private state or credentials do not prevent the base workflow from functioning.

**Given** terminal workflow configuration is reapplied
**When** it is already correct
**Then** no duplicate links, shell entries, plugins, or sessions are created
**And** provider-specific failures identify an actionable next step.

### Story 4.3: Enable Core Wayland Desktop Operations

**Requirements:** FR23, FR64, FR65

As the MirrorOS user,
I want portals, clipboard, screenshots, and browser-facing desktop integration to work,
So that ordinary graphical tasks function in the provisional Wayland environment.

**Acceptance Criteria:**

**Given** the graphical session is running
**When** portal-dependent operations are invoked
**Then** the selected portal services match the compositor session and provide required file-selection or desktop integration behavior
**And** service ownership and environment propagation are documented and verifiable.

**Given** content is copied between supported terminal and graphical applications
**When** clipboard operations are performed
**Then** copy and paste work through a keyboard-accessible path
**And** clipboard tooling does not introduce an unapproved resident management service.

**Given** a screenshot is requested through the declared shortcut
**When** capture completes or fails
**Then** the expected output is created without secret-bearing metadata, or an actionable error is shown
**And** screenshot configuration remains independent of the compositor provider where practical.

### Story 4.4: Provide Keyboard-Accessible Desktop Controls

**Requirements:** FR23, FR64, FR65

As the MirrorOS user,
I want launching, navigation, window management, status, and notifications available through coherent controls,
So that frequent actions remain efficient without unnecessary persistent UI.

**Acceptance Criteria:**

**Given** the frozen frequent-action inventory
**When** launcher, compositor, bar, and notification configuration are applied
**Then** every listed action has a documented keyboard-accessible path
**And** conflicting or missing bindings fail validation.

**Given** the graphical session is healthy
**When** I use the launcher, window controls, bar, and notifications
**Then** each component performs its declared capability and remains quiet when no intervention is required
**And** color is not the sole means of communicating state.

**Given** visual settings are removed
**When** functional configuration is reapplied
**Then** launching, navigation, status, and notification behavior continue to work
**And** visual customization remains independently reversible.

### Story 4.5: Restore Development Tooling

**Requirements:** FR23, FR30, FR65

As the MirrorOS user,
I want Git, Neovim, Pi, and required development tools available,
So that I can resume development without restoring personal content into MirrorOS.

**Acceptance Criteria:**

**Given** the development capability modules are selected
**When** configuration runs
**Then** declared packages, services, external repositories, links, and native application configuration are applied with recorded provenance
**And** Neovim, Pi, and other independent repositories remain authoritative for their own configuration.

**Given** first login is complete
**When** I launch Git, Neovim, Pi, and declared development tools
**Then** each starts with its intended non-secret configuration and required integrations
**And** absent credentials, repositories, or personal data are identified as external dependencies rather than copied or fabricated.

**Given** an external configuration checkout cannot be obtained
**When** its module runs
**Then** the affected capability fails or is externally blocked with a next step
**And** unrelated development and desktop capabilities continue according to their dependencies.

### Story 4.6: Restore Browser Capability

**Requirements:** FR23, FR30, FR65

As the MirrorOS user,
I want a configured browser capability in the graphical environment,
So that web-based daily work is available without embedding accounts or authenticated sessions.

**Acceptance Criteria:**

**Given** the browser capability is selected
**When** its module applies
**Then** the declared browser package, non-secret policy, desktop integration, and provenance are configured
**And** accounts, profiles, credentials, authenticated sessions, and personal browsing data remain external.

**Given** the graphical session is ready
**When** I launch the browser through its documented keyboard path
**Then** it starts successfully and portal, clipboard, and file-selection integrations work as declared
**And** missing external account state does not make the browser capability itself fail.

**Given** the browser provider is replaced
**When** declarations are updated and applied
**Then** unrelated graphical and workflow modules require no redesign
**And** provider-specific checks and provenance are updated with the replacement.

### Story 4.7: Deliver a Coherent First Graphical Login

**Requirements:** FR30, FR31, FR64, FR65

As the MirrorOS user,
I want the first normal login to open into the declared daily environment,
So that first boot is not a hidden second installation or onboarding phase.

**Acceptance Criteria:**

**Given** installation and environment configuration have completed
**When** the installation medium is removed and the machine reboots
**Then** the system reaches graphical login and starts the declared environment without a welcome application, setup assistant, or background management daemon
**And** no undocumented configuration action is required before use.

**Given** supported desktop components render
**When** typography, color, and density are inspected
**Then** declared choices are used without an additional theming framework
**And** each maintained deviation from upstream defaults has daily value or negligible maintenance cost.

**Given** one required daily capability is unavailable
**When** first-login postconditions run
**Then** the environment is not represented as fully ready
**And** the affected capability and next action are available for independent verification.

## Epic 5: Verify Readiness and Recover from Failures

The user can independently verify every declared capability, understand readiness outcomes, retain diagnostic evidence, and safely diagnose, retry, or recover from failures.

### Story 5.1: Define the Shared Verification Contract

**Requirements:** FR37

As the MirrorOS maintainer,
I want every MVP capability associated with explicit readiness checks,
So that readiness is measured consistently rather than inferred from completed commands.

**Acceptance Criteria:**

**Given** the frozen capability inventory
**When** verification definitions are validated
**Then** every required capability has one or more owned checks, dependencies, and actionable result guidance
**And** verification checks do not mutate desired system state.

**Given** a check completes
**When** its result is recorded
**Then** its outcome contributes to exactly one aggregate capability state: `passed`, `failed`, or `blocked_external`
**And** the result contains non-secret evidence, reason, next step, timestamp, and source/artifact identity.

**Given** result schemas are introduced
**When** contract tests run
**Then** fixtures cover success, failure, external blocker, malformed input, and unknown fields
**And** structured output is atomically written and validated before being accepted as evidence.

### Story 5.2: Run and Aggregate Readiness Checks Independently

**Requirements:** FR38, FR40, FR41, FR42, FR45

As the MirrorOS user,
I want to run verification without repeating installation or configuration,
So that I can reassess readiness after fixes or external dependencies change.

**Acceptance Criteria:**

**Given** an installed or configured system
**When** I invoke verification for all or selected capabilities
**Then** applicable checks run in dependency-aware order without changing the declared environment
**And** each capability receives exactly one aggregate state.

**Given** a check fails or is externally blocked
**When** aggregation completes
**Then** the affected capability includes an actionable reason and next step
**And** unrelated checks continue unless an explicit dependency prevents meaningful execution.

**Given** all required capabilities pass
**When** verification completes
**Then** normalized status `0` is returned
**And** any failed or blocked required capability instead returns verification-not-ready status `4`.

### Story 5.3: Report and Retain Consistent Readiness Evidence

**Requirements:** FR39, FR41, FR43, FR44

As the MirrorOS user,
I want concise and complete readiness reports derived from the same results,
So that I can act quickly while retaining auditable reconstruction evidence.

**Acceptance Criteria:**

**Given** collected verification results
**When** human output is rendered
**Then** it emphasizes failures and external blockers while allowing access to every passed, failed, or blocked capability
**And** healthy output remains concise and does not rely on color alone.

**Given** structured evidence is requested
**When** the JSON summary is rendered
**Then** it represents the same aggregate outcome as the human and complete reports
**And** schema/version identity is included when compatibility requires it.

**Given** a verification run completes
**When** evidence is retained
**Then** reports are associated with the run and artifact identity and remain available for diagnosis
**And** automated scanning confirms no known secrets appear in reports or retained evidence.

### Story 5.4: Preserve Actionable Lifecycle Diagnostics

**Requirements:** FR46, FR47, FR48

As the MirrorOS user,
I want failures to identify what stopped and what remains safe,
So that I can diagnose problems without reconstructing events from unstructured output.

**Acceptance Criteria:**

**Given** any lifecycle stage starts
**When** it emits progress and evidence
**Then** active stage, operation, outcome, duration, and relevant non-secret context are associated with one run identifier
**And** long-running work cannot appear silently stalled or prematurely successful.

**Given** an upstream or module operation fails
**When** failure handling executes
**Then** the failed stage, affected capability, last confirmed successful state, original child status, safe message, and next step are retained
**And** wrappers do not convert the failure into success.

**Given** a run terminates unexpectedly
**When** the user inspects its evidence
**Then** allowlisted diagnostic logs remain accessible unless explicitly removed
**And** secret redaction and scanning are applied before retention.

### Story 5.5: Retry and Recover Without Compounding Damage

**Requirements:** FR49, FR50, FR51, FR52, FR53

As the MirrorOS user,
I want bounded retry and documented recovery paths,
So that failures leave the system diagnosable, recoverable, or safely abandoned.

**Acceptance Criteria:**

**Given** a safe non-destructive stage failed
**When** I retry it
**Then** a new run records the retry without implicitly repeating unrelated completed stages
**And** any automatic retry is bounded, limited to transient non-destructive work, and logged.

**Given** a destructive stage must be repeated
**When** retry is requested
**Then** discovery and the plan are refreshed and renewed target-bound confirmation is mandatory
**And** destructive work never retries automatically.

**Given** installation or configuration cannot continue
**When** I follow the recovery procedure
**Then** it identifies evidence, safe correction/retry options, abort conditions, and independent rescue steps
**And** physical-device recovery uses an external backup and an independent rescue medium without depending on a future MirrorOS artifact-promotion capability.

**Given** an undocumented intervention enables recovery
**When** the supported journey is reviewed
**Then** the intervention is captured as a repository or documentation correction with validation where practical
**And** the journey is not considered reproducible until that correction is recorded.

## Epic 6: Complete Repeatable Migration and Evolve MirrorOS

The user can execute the complete VM-to-laptop reconstruction journey, safely maintain the environment as it changes, and return validated migration fixes to the source of truth.

### Story 6.1: Orchestrate the Documented Reconstruction Journey

**Requirements:** FR4

As the MirrorOS user,
I want a documented path through all lifecycle stages,
So that I can reconstruct a machine without hidden transitions while retaining independent stage control.

**Acceptance Criteria:**

**Given** a clean clone and supported prerequisites
**When** I follow the end-to-end procedure
**Then** build, test, install, configure, and verify compose into one ordered journey
**And** each stage remains independently invocable and produces its own outcome and evidence.

**Given** a stage fails, cancels, or completes without readiness
**When** orchestration evaluates the result
**Then** avoidable dependent stages do not continue and the normalized outcome is preserved
**And** the next safe entry point is documented.

**Given** the journey completes
**When** its execution record is reviewed
**Then** every manual interaction is documented and stage durations are captured
**And** no unified executable is required unless later evidence justifies one.

### Story 6.2: Qualify a Clean Reference-VM Reconstruction

**Requirements:** FR4, FR56, FR60

As the MirrorOS user,
I want to prove the complete journey on a fresh disposable VM,
So that physical migration is based on observed reconstruction rather than confidence in isolated parts.

**Acceptance Criteria:**

**Given** a fresh virtual disk and boot-qualified artifact
**When** the complete journey runs
**Then** it exercises plan review, safe cancellation, renewed confirmation, installation, configuration, reboot without media, graphical login, and verification
**And** no undocumented action is required.

**Given** the configured VM passes initial verification
**When** configuration and verification run a second time
**Then** configuration causes zero unintended changes or duplicated state and required capabilities retain explicit outcomes
**And** failures prevent VM qualification.

**Given** power and graphics qualification runs
**When** repeated hibernation and resume cycles execute
**Then** swapfile resume configuration and offset are verified with the supported VM constraints
**And** physical hybrid AMD/NVIDIA qualification remains explicitly pending rather than inferred from the VM.

### Story 6.3: Promote and Retain an Accepted Known-Good Artifact

**Requirements:** NFR16, NFR24, NFR31, NFR32

As the MirrorOS user,
I want a fully qualified artifact retained with its evidence,
So that recovery does not depend on repairing current upstream breakage first.

**Acceptance Criteria:**

**Given** an artifact has passed build, boot, install, configuration, hibernation, idempotency, and capability verification gates
**When** promotion is requested
**Then** each required gate and evidence reference is validated before the artifact becomes accepted-known-good
**And** partial success cannot be promoted.

**Given** promotion succeeds
**When** the artifact is retained outside the disposable build tree
**Then** its checksum, source identity, tools, repositories, package manifest, VM configuration, durations, logs, and verification results remain associated
**And** retained material passes secret scanning.

**Given** current Arch packages evolve
**When** a current-package canary is run
**Then** its outcome remains distinct from the accepted-known-good recovery track
**And** failure of the current canary does not erase or misrepresent the retained artifact.

### Story 6.4: Migrate the Target Laptop Through Qualified Gates

**Requirements:** FR4, FR59, FR60

As the MirrorOS user,
I want to migrate the Framework Laptop 13 Pro using the VM-qualified process,
So that the new laptop becomes a verified daily working environment with a recovery path available.

**Acceptance Criteria:**

**Given** a passing clean-VM reconstruction, accepted-known-good artifact, external backup, and independent rescue medium
**When** physical migration eligibility is checked
**Then** all prerequisites are explicitly confirmed before target discovery or destructive approval
**And** absence of any prerequisite blocks migration safely.

**Given** the target-laptop plan is reviewed and approved
**When** installation and configuration execute
**Then** target-specific hardware overrides remain inspectable and separate from portable modules
**And** the official kernel remains bootable while any experimental kernel or graphics choice stays reversible.

**Given** the laptop reaches first graphical login
**When** capability, hybrid AMD/NVIDIA, swapfile, and repeated hibernation verification run
**Then** every required capability passes or has an actionable failed or external-blocker state
**And** total reconstruction duration is recorded under documented hardware, network, and package-source conditions against the provisional two-hour target.

### Story 6.5: Evolve and Reapply the Daily Environment Safely

**Requirements:** FR54, FR55, FR56, FR57, FR58, FR59

As the MirrorOS user,
I want to incorporate daily-system changes into the authoritative definition,
So that MirrorOS evolves without accumulating undocumented drift or irreversible tool coupling.

**Acceptance Criteria:**

**Given** I adopt, change, or replace a package, shortcut, service, desktop provider, or workflow tool
**When** I preserve the change
**Then** the owning capability declaration, provenance, dependencies, verification, documentation, and rationale are updated as applicable
**And** unrelated modules remain unchanged unless an explicit dependency exists.

**Given** a declared change is ready for application
**When** I review it
**Then** its version-control diff, intended effect, risk, and replacement/removal boundary are inspectable
**And** risk-appropriate changes can be validated in the reference VM before daily-system application.

**Given** a validated definition is applied to the daily system
**When** convergence and verification complete
**Then** the change takes effect without reinstalling or duplicating state
**And** the repository remains the authoritative definition with evolution preserved in version history.

**Given** migration, recovery, or daily use reveals a missing step or defect
**When** the correction is made
**Then** it is returned to source or documentation and the affected path is revalidated
**And** custom automation is introduced only after a documented or assisted process demonstrates repeated need.
