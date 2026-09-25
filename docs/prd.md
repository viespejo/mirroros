---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
status: complete
completedAt: '2026-09-24T12:25:39+02:00'
inputDocuments:
  - "docs/product-brief-mirroros.md"
  - "docs/brainstorming/brainstorming-session-2026-09-23-201236.md"
documentCounts:
  productBriefs: 1
  research: 0
  brainstorming: 1
  projectDocs: 0
classification:
  projectType: cli_tool
  domain: general
  complexity: low
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - MirrorOS

**Author:** Vicente Espejo
**Date:** 2026-09-24

## Executive Summary

MirrorOS is a personal Arch Linux distribution designed to reproduce an experienced Linux user's complete working environment on a new or recovered device. It is built and maintained through a CLI-driven toolchain that coordinates a minimal installation medium, guided system installation, hardware-aware configuration, personal environment convergence, and capability verification.

MirrorOS addresses the loss of productivity caused by rebuilding years of accumulated packages, services, desktop behavior, terminal tooling, shortcuts, and application configuration from incomplete dotfiles, scripts, and memory. Its initial target user is an experienced Arch Linux user facing an imminent laptop migration.

Starting from a blank device, MirrorOS must provide an integrated path to a machine that is ready for daily work. It transforms migration from an exceptional reconstruction project into a routine, trustworthy operation while remaining narrower than a public, general-purpose Linux distribution.

MirrorOS restores working capabilities rather than owning personal content. Credentials, private data, repositories, and application state remain external to the core product. Importing exportable accounts, profiles, or sessions is a desirable extension where applications support it safely, but it is not a first-version priority.

### What Makes This Special

MirrorOS treats workflow continuity—not the installation medium—as the product. The ISO, installer, scripts, package declarations, and dotfiles are replaceable components within one complete, maintainable, and verifiable distribution lifecycle.

Unlike a conventional dotfiles repository, package-installation script, or static custom image, MirrorOS owns the journey from a blank machine to a productive personal Linux environment. It combines visible installation policy, hardware adaptation, repeatable configuration, and post-run verification while preserving explicit control over destructive, ambiguous, secret, or difficult-to-reverse decisions.

The durable asset is a version-controlled definition of the distribution and working environment that can evolve independently of any laptop, ISO, compositor, or current tool choice. Success means the user can move to a new device quickly and regain the capabilities required for daily work without undocumented reconstruction steps.

## Project Classification

- **Product Definition:** Personal Arch Linux distribution
- **Primary Product Interface:** CLI-driven installation and configuration toolchain
- **Project Type:** CLI tool
- **Domain:** General software and Linux system tooling
- **Domain Complexity:** Low; no specialized regulatory requirements
- **Technical Complexity:** Significant due to system installation, hardware adaptation, configuration convergence, and end-to-end verification
- **Project Context:** Greenfield

## Product Principles

- **Workflow continuity is the product:** The ISO, installer, scripts, and current tools are replaceable means of restoring productive capability.
- **Simplicity before abstraction:** Existing configuration and supported tools take precedence over custom formats, wrappers, applications, and services.
- **Explicit control over consequential actions:** Automation removes repetition without hiding destructive, ambiguous, secret, or difficult-to-reverse decisions.
- **Configuration over captured state:** The version-controlled environment definition remains authoritative; personal content and secret values remain external.
- **Replaceability by design:** Desktop, workflow, and installation components may evolve without redesigning the distribution lifecycle.
- **Evidence before commitment:** Comparative research and disposable prototypes precede binding architecture decisions.
- **Progressive automation:** A task is documented or assisted before repeated use justifies automating it.
- **One-maintainer sustainability:** Every component must repay its implementation, testing, and maintenance cost.

### Experience Principles

- The environment is quiet when healthy and explicit when intervention is required.
- Frequent launching, navigation, window-management, and tooling actions remain keyboard-accessible.
- Terminal, compositor, bar, launcher, and notification surfaces form a restrained and coherent visual system.
- Character comes from behavior and coherence rather than logos, welcome screens, or promotional branding.
- Visual effects remain only when they improve orientation, readability, or flow at negligible maintenance cost.
- Upstream defaults are the baseline; MirrorOS maintains only personally valuable differences.
- Visual customization remains isolated from functional configuration and reversible through version control where practical.

## Success Criteria

### User Success

- The user can start from a blank supported laptop and reach a verified, daily-work-ready MirrorOS environment in under two hours. This is an initial target to be validated against measured VM and hardware baselines.
- The reconstructed environment provides all capabilities declared in the MVP capability inventory, including the graphical environment, terminal, shell, Tmux, Neovim, Git, browser, keyboard shortcuts, required services, and development tools.
- The complete journey contains zero undocumented manual steps. Documented interaction is permitted for destructive, ambiguous, secret, hardware-dependent, or difficult-to-reverse decisions.
- The user can review consequential installation choices before execution and understand whether defaults originate from personal preference, hardware detection, Arch guidance, or technical necessity.
- Successful reconstruction ends with an explicit verification report showing which declared capabilities passed, failed, or require an external dependency.
- The immediate success milestone is a complete VM validation followed by a successful migration to the target laptop.
- The user experiences migration as a repeatable operation rather than an exceptional reconstruction project.

### Business Success

MirrorOS is a personal product and has no revenue, acquisition, or public-adoption objective. Its value is measured by continuity, reduced migration effort, and sustainable personal maintenance.

- The upcoming laptop migration completes through the documented MirrorOS process without relying on remembered or improvised reconstruction steps.
- The resulting laptop becomes the user's daily working environment rather than a disposable demonstration.
- The repository remains the authoritative definition of the environment after migration; fixes required during migration are reflected back into version control.
- MirrorOS demonstrates that maintaining the system requires less effort than manually reconstructing the environment it replaces.
- A quantitative maintenance budget will be established after repeated builds, configuration runs, and at least one real-device migration provide an evidence baseline.

### Technical Success

- A fresh repository clone can build the minimal installation image using documented commands.
- The image boots in QEMU with working networking and the tools required to begin installation.
- A clean VM can complete installation, personal configuration, reboot, graphical login, and capability verification with zero undocumented steps.
- The same validated process succeeds on the target laptop with a documented recovery path available.
- Reapplying the configuration produces no unintended duplication, breakage, or configuration drift.
- No credentials, private keys, personal content, authenticated sessions, or secret values are stored in version control or generated images.
- Every installed package has recorded source provenance.
- Hardware-derived and private configuration remain separated from portable public configuration.
- Desktop and workflow components remain replaceable; Niri is treated as a provisional default rather than an architectural dependency.
- Failures identify the affected capability, failed operation, and actionable next step.
- Comparative research into Archiso, Archinstall, Omarchy, CachyOS, EndeavourOS, and other relevant projects is completed before binding architecture decisions are made.
- The research gate produces a comparison matrix, evidence log, adopt/avoid pattern catalog, external dependency map, technical decision record, candidate minimal architecture, and validation prototype.

### Measurable Outcomes

- **Reconstruction time:** provisional target of less than two hours from booting the installation medium to a passing ready-state verification on the target laptop, subject to baseline validation.
- **Documented execution:** zero undocumented manual steps across a clean end-to-end reconstruction.
- **Capability completion:** 100% of declared MVP capabilities either pass verification or are explicitly reported as unresolved with an actionable reason.
- **Idempotency:** a second configuration run causes zero unintended changes or duplicated state.
- **Secret exposure:** zero secret values or personal-content artifacts in the repository and generated images.
- **Package traceability:** 100% of installed packages have recorded provenance.
- **Migration validation:** one successful clean-VM reconstruction followed by one successful target-laptop migration.
- **Research gate:** no final architecture commitment precedes a comparison matrix, evidence log, adopt/avoid pattern catalog, external dependency map, technical decision record, candidate minimal architecture, and validation prototype.

## Product Scope and Phased Development

### MVP Strategy

**Approach:** Complete-experience, problem-solving MVP.

MirrorOS must validate its core promise end to end: a blank supported device becomes the user's verified daily working environment. The MVP limits breadth rather than removing lifecycle stages: one user, one reference VM, one target laptop, one provisional desktop stack, and one frozen daily-work capability inventory.

Lifecycle stages remain independently invocable, but a unified CLI is not mandatory. Existing tools, task runners, or small scripts may provide the conceptual build, test, install, configure, and verify boundaries when they satisfy the requirements more simply.

**Resources:** One experienced maintainer; an Arch-compatible build environment; QEMU/KVM or equivalent virtualization; the target laptop; an independent rescue medium; source control; and storage for artifacts, logs, and evidence.

### Phase 1 — MVP

**Core journeys:**

1. Build and validate MirrorOS from a clean clone in a disposable VM.
2. Migrate from a blank target laptop to a verified daily-work-ready environment.
3. Diagnose failures and leave the system recovered or in a clearly actionable state.
4. Manually incorporate environment changes into the source of truth and reapply them safely.

**Must-have capabilities:**

- A research gate producing a comparison matrix, evidence log, adopt/avoid pattern catalog, external dependency map, technical decision record, candidate minimal architecture, and validation prototype before binding architecture decisions.
- A reproducible minimal Arch-based installation image that boots with networking in the reference VM and target laptop.
- Explicit build, test, install, configure, and verify stages without requiring a custom wrapper when simpler mechanisms suffice.
- A guided installation plan with visible, editable defaults and mandatory confirmation for destructive, secret, or ambiguous decisions.
- Hardware adaptation for the reference VM and target laptop, isolated so future capabilities can be added without coupling them to portable configuration.
- A frozen capability inventory covering the graphical environment, Niri as the provisional compositor, terminal, shell, Tmux, Neovim, Git, browser, keyboard shortcuts, required services, development tools, portals, clipboard, screenshots, launcher, bar, and notifications.
- Modular, repeatable configuration separated into portable declarations, hardware-derived choices, privileged changes, secret references, and private state.
- Human-readable output, persistent logs, reliable exit codes, concise verification, a complete verification report, and actionable failures.
- A second configuration run with no unintended duplication or changes.
- Zero undocumented manual steps across build, boot, installation, configuration, verification, cleanup, recovery, and reapplication.
- One successful end-to-end VM reconstruction followed by one successful target-laptop migration with an independent recovery path available.

**Explicit exclusions:**

- General-purpose hardware support beyond the reference VM and target laptop.
- Public-distribution release, branding, repositories, support, or community operations.
- Automatic drift reconciliation or import of application accounts, profiles, and sessions.
- Personal data, repository, credential, or secret restoration.
- Fully unattended destructive installation.
- A proprietary configuration language.
- Mandatory machine-readable output across all commands or mandatory shell completion.
- A custom installer, control panel, welcome application, or background management service.
- A unified `mirroros` executable unless evidence shows that it simplifies the lifecycle without meaningful maintenance cost.

### Phase 2 — Reliability and Repeatability

- Scheduled build and boot canaries against current upstream packages.
- Retained known-good installation artifacts with verification metadata.
- Additional validated hardware capability rules and device profiles.
- Improved structured verification summaries and test integration.
- Evaluation of preview or dry-run reporting for package, file, service, and command changes.
- A revisable risk register, dependency-staleness diagnostics, and periodic health reports.
- Maintenance-effort measurement based on real builds, upgrades, failures, and reconstructions.
- Safe import of selected application profiles or sessions where explicit export/import mechanisms exist.
- A unified CLI or shell completion if repeated use demonstrates sufficient value.

### Phase 3 — Long-Term Evolution

- Optional drift detection that informs the user without becoming an autonomous control plane.
- Broader hardware adaptation while preserving capability-based modularity.
- Multiple environment depths or profiles if real use cases emerge.
- More complete optional restoration of exportable application state.
- Historical health reporting across repeated builds and reconstructions.
- Continued replacement of desktop and workflow components without redesigning the distribution lifecycle.

MirrorOS ultimately becomes a living, tested record of the user's environment. Device migration becomes routine: the user reviews consequential choices, restores declared capabilities, optionally imports safe application state, and receives a verified account of what is ready and what still depends on external data or credentials.

### Risk Mitigation

- **Upstream change:** Use research, upstream-first integration, documented dependencies, and Phase 2 canaries.
- **False reproducibility:** Require clean-VM reconstruction, capability verification, and a second configuration run.
- **Hardware-specific failure:** Gate physical installation on VM success and maintain an independent recovery path.
- **Unsafe destructive behavior:** Require consistent explicit confirmation on virtual and physical devices.
- **Architecture overcommitment:** Complete the research gate and prototype before binding choices.
- **Configuration complexity:** Prefer readable existing mechanisms and require evidence for every added abstraction.
- **Product risk:** Freeze and verify the actual workflow inventory, use the resulting laptop daily, and return migration fixes to version control.
- **Resource risk:** Use sequential milestones, one VM, one laptop, simple tools, explicit deferral, and a strict complexity budget.

## User Journeys

### Journey 1: Building Confidence Before Migration

The user has accumulated years of Linux workflow decisions and knows a laptop migration is approaching. Previous migrations required reconstructing the environment from dotfiles, package lists, memory, and undocumented fixes. This time, the user wants evidence that the environment can be rebuilt before touching the target laptop.

The user begins with the MirrorOS repository and its documented prerequisites. Before committing to an architecture, the user completes the comparative technical study, records relevant findings, and chooses the smallest approach capable of delivering the required journey. From a clean clone, the user builds the installation image using a documented command and boots it in a disposable VM.

MirrorOS establishes networking, inspects the virtual hardware, and presents the proposed installation plan. The user can distinguish personal defaults from detected choices and technical requirements. After approving consequential actions, the user completes installation and personal configuration. MirrorOS then verifies the declared capabilities and reports each as passed, failed, or dependent on an external resource.

The decisive moment occurs when the VM reaches the expected graphical and terminal-centric working state without undocumented intervention. The user reruns the configuration to verify that it produces no unintended changes. Confidence now comes from observed reconstruction rather than from assuming that the repository is complete.

This journey reveals requirements for reproducible builds, documented prerequisites and commands, disposable VM execution, reviewable installation plans, end-to-end orchestration, capability verification, idempotency checks, and evidence capture.

### Journey 2: Migrating to the New Laptop

The user has validated MirrorOS in a VM and is ready to migrate. Personal data is already backed up, and an independent rescue device or recovery medium is available. The goal is to make the target laptop productive in under two hours without turning the migration into another manual systems project.

The user boots the validated MirrorOS medium. The system verifies basic prerequisites, detects relevant hardware capabilities, and presents a proposed plan before modifying storage. Destructive, ambiguous, secret, and hardware-dependent choices require explicit input; safe personal defaults are preselected and explained.

After approval, MirrorOS installs the base system and applies the declared environment before the first normal reboot. Packages, services, desktop components, terminal tools, editor configuration, browser capabilities, shortcuts, and development tooling are applied through modular configuration. Secrets and personal content remain outside the image and repository.

At first graphical login, the environment is already coherent and usable rather than entering a second setup phase. MirrorOS runs its ready-state checks and clearly identifies any capability requiring external credentials, data, or manual completion. The journey succeeds when every declared MVP capability either passes or has an actionable unresolved status and the user can resume daily work.

The emotional transition is from uncertainty—whether years of accumulated workflow can survive the move—to relief that the new device is functionally familiar and ready for productive use.

This journey reveals requirements for preflight checks, hardware detection, safe disk planning, explainable defaults, confirmation boundaries, pre-reboot configuration, modular capability application, secret separation, first-login readiness, time measurement, and final verification.

### Journey 3: Diagnosing and Recovering from Failure

During a VM test or laptop installation, any layer may fail: image boot, networking, storage, package retrieval, bootloader setup, hardware support, graphical startup, or personal configuration. MirrorOS must treat every such failure as important rather than optimizing only for a preferred failure category.

When a failure occurs, MirrorOS stops before compounding damage where possible. It identifies the failed stage, affected capability, relevant evidence, and the last confirmed successful state. The user sees an actionable explanation instead of an unstructured command failure or a falsely successful completion message.

The user can access logs and determine whether to correct an input, retry a safe operation, rerun configuration, use the documented recovery procedure, or abandon the attempt and use the independent rescue path. Destructive operations are never retried implicitly. Once the underlying problem is corrected, the user can repeat the documented process and verify the result.

Any workaround needed to complete the journey is not allowed to remain tribal knowledge. The user updates the repository or documentation, validates the correction in a disposable environment when practical, and ensures that the same failure no longer requires an undocumented step.

The journey resolves when the system is either restored to a verified state or left in a clearly diagnosed, recoverable condition. Confidence comes not from preventing every failure but from making failures observable, bounded, and recoverable.

This journey reveals requirements for staged execution, explicit failure states, preserved diagnostic evidence, actionable error reporting, safe retry semantics, destructive-action safeguards, recovery documentation, independent rescue access, and post-incident feedback into version control.

### Journey 4: Evolving the Daily Environment

After migration, the user adopts a new tool, changes a shortcut, replaces a desktop component, or adjusts a service. MirrorOS must support this evolution without becoming a complex background management platform.

The user makes or evaluates the change deliberately, then manually updates the relevant version-controlled declaration or module. The implementation remains separated according to responsibility and change rate so that replacing one component does not require redesigning the installation process.

Before broadly relying on the change, the user can inspect it, apply it to the current system, and validate it in a disposable VM when its risk justifies doing so. Reapplying the configuration converges the machine without duplicate state or unrelated changes. The repository records both the current choice and its evolution through version history.

MirrorOS does not require automatic drift reconciliation in the MVP. If later research demonstrates that drift detection can provide clear value without violating the simplicity principle, it may be introduced as an optional aid rather than an autonomous control plane.

The journey succeeds when the environment can change over time while the repository remains an understandable and executable source of truth. The user gains continuity without surrendering control or accepting unnecessary machinery.

This journey reveals requirements for modular declarations, manual change capture, inspectable diffs, repeatable application, component replacement, risk-proportionate VM testing, version history, and a strict simplicity threshold for future automation.

### Journey Requirements Summary

The journeys establish the following capability areas:

- **Reproducible preparation:** clean-clone builds, documented prerequisites, comparative research gate, and disposable VM validation.
- **Transparent installation:** preflight inspection, hardware detection, explainable defaults, plan review, and explicit confirmation boundaries.
- **Complete reconstruction:** coordinated base installation, personal configuration, and ready-state verification.
- **Workflow capability inventory:** an explicit list of packages, services, tools, desktop behavior, shortcuts, and validation checks required for daily productivity.
- **Safety and privacy:** external backups, independent rescue access, no embedded secrets or personal content, and safeguards around destructive operations.
- **Failure management:** staged execution, useful diagnostics, preserved evidence, safe retries, independent rescue options, and no false-success states.
- **Maintainable evolution:** modular configuration, manual incorporation of changes, component replaceability, idempotent reapplication, and version-controlled history.
- **Simplicity:** no component, abstraction, background service, or automation is introduced unless its recurring value exceeds its implementation and maintenance cost.
- **Optional state restoration:** application profiles, accounts, and sessions may be imported later where explicit and safe export/import mechanisms exist.
- **Excluded journey types:** there is no separate administrator, support operator, or API consumer; the same user performs maintenance and troubleshooting roles.

## CLI Tool Specific Requirements

### Project-Type Overview

MirrorOS is a CLI-driven personal Arch Linux distribution organized around explicit lifecycle stages. The CLI coordinates existing tools and configuration rather than hiding them behind a monolithic interface. Its command surface must remain small, predictable, and aligned with the stages the user needs to execute, inspect, repeat, or troubleshoot independently.

The conceptual command model is:

```text
mirroros build
mirroros test
mirroros install
mirroros configure
mirroros verify
```

These names express required lifecycle boundaries rather than a binding implementation decision. Comparative research will determine whether a dedicated top-level executable, existing tool entry points, task runner, scripts, or another simple mechanism best satisfies the requirements.

### Technical Architecture Considerations

- Each lifecycle stage must be independently invocable so that failure and re-execution remain bounded.
- Stages must compose into the complete reconstruction journey without requiring undocumented transitions.
- The CLI must orchestrate upstream tools where practical rather than reimplementing their capabilities.
- Reproducible, non-destructive operations may run without interaction.
- Partitioning, disk erasure, secret handling, and ambiguous decisions always require explicit confirmation, including in disposable VMs.
- Destructive confirmation behavior must remain consistent across virtual and physical devices.
- The implementation must preserve useful diagnostics from underlying tools without exposing secrets.
- Exit behavior must distinguish success, verification failure, invalid input, user cancellation, and execution failure.
- Final command names, implementation language, and orchestration mechanism remain subject to comparative research.

### Command Structure

- **`build`:** Produce the installation artifact from a clean repository state and report its location and relevant build metadata.
- **`test`:** Launch or coordinate the documented validation workflow in a disposable environment. Any destructive installation action remains interactive.
- **`install`:** Inspect the target, present the proposed installation plan, obtain required confirmations, and perform base-system installation.
- **`configure`:** Apply the declared personal environment independently of image construction and base installation. Repeated execution must converge without unintended duplication.
- **`verify`:** Evaluate declared capabilities and report passed, failed, and externally blocked results.

Commands must expose their purpose, prerequisites, inputs, and consequential effects through built-in help or equally discoverable documentation. Additional commands or subcommands require demonstrated recurring value; they must not be added solely to create an abstraction over an existing command.

### Output Formats

- All MVP commands must provide concise, human-readable terminal output.
- Long-running operations must identify the current stage and must not appear successful before verification completes.
- Diagnostic detail must be retained in persistent logs suitable for troubleshooting.
- Commands must return reliable exit codes that support shell composition and test assertions.
- Output must never include secret values.
- `verify` may optionally write a structured summary artifact when required by automated tests or evidence collection.
- Machine-readable output across the entire CLI is not an MVP requirement. It may be introduced only after a demonstrated automation need establishes a stable schema.

### Configuration Method

The solution must use configuration that is:

- **Versionable:** meaningful changes can be reviewed and preserved in version control.
- **Readable:** the user can understand declared intent without specialized tooling.
- **Modular:** system, hardware, desktop, workflow, and application concerns can evolve independently.
- **Validatable:** malformed, incomplete, or contradictory declarations can be detected before consequential execution.
- **Repeatable:** the same declared inputs produce equivalent intended capabilities.
- **Simple:** configuration avoids unnecessary indirection, generators, and custom syntax.

Portable configuration, hardware-derived choices, privileged operations, secret references, and private state must remain separable. The exact configuration mechanism and precedence model remain subject to comparative research. MirrorOS must avoid creating a proprietary configuration format unless existing mechanisms have a demonstrated, documented deficiency.

### Scripting Support

- Reproducible and non-destructive commands must support non-interactive execution.
- Commands must produce stable exit outcomes suitable for shell scripts and test harnesses.
- Destructive operations must not become unattended through a generic non-interactive flag.
- User cancellation at a confirmation boundary must terminate safely and be distinguishable from execution failure.
- Structured verification summaries may support automated assertions without requiring every command to implement JSON output.
- Full unattended end-to-end installation is not an MVP requirement because destructive confirmation remains mandatory.
- Shell completion is not required for the MVP. It may be enabled when the selected implementation provides it with negligible additional code and maintenance.

### Implementation Considerations

- Simplicity takes precedence over providing a uniform wrapper for every underlying tool.
- The CLI must expose lifecycle boundaries and useful failures rather than conceal operational detail.
- Architecture selection must follow the comparative research gate and a minimal validation prototype.
- Interactive and scriptable behavior must be tested separately.
- Tests must verify exit codes, cancellation behavior, log creation, secret redaction, configuration validation, and structured verification output where enabled.
- New abstractions, output modes, configuration layers, and convenience commands require evidence that their recurring value exceeds their maintenance cost.

## Functional Requirements

### Lifecycle Execution and Artifact Management

- **FR1:** The user can build a MirrorOS installation artifact from the version-controlled product definition.
- **FR2:** The user can identify the location and relevant build metadata of a generated installation artifact.
- **FR3:** The user can invoke the build, test, install, configure, and verify lifecycle stages independently.
- **FR4:** The user can execute the lifecycle stages as one documented end-to-end reconstruction journey.
- **FR5:** The user can launch the MirrorOS validation journey in the reference disposable VM environment.
- **FR6:** The user can execute reproducible, non-destructive operations without interactive input.
- **FR7:** The user can discover each lifecycle stage's purpose, prerequisites, required inputs, and consequential effects.
- **FR8:** The user can observe the current stage and outcome of each lifecycle operation.
- **FR9:** External scripts and test harnesses can distinguish successful execution, verification failure, invalid input, user cancellation, and execution failure.

### Installation Planning and Safety

- **FR10:** The user can inspect the target device's relevant hardware, storage, and network state before installation changes begin.
- **FR11:** The user can review a proposed installation plan before the target device is modified.
- **FR12:** The user can identify whether each proposed default originates from personal preference, hardware detection, Arch guidance, or technical necessity.
- **FR13:** The user can modify editable installation choices before approving the plan.
- **FR14:** The user must explicitly confirm partitioning, disk erasure, secret handling, and ambiguous decisions.
- **FR15:** The user receives the same destructive-action confirmation behavior on virtual and physical devices.
- **FR16:** The user can cancel at a confirmation boundary without the cancellation being reported as successful installation or execution failure.
- **FR17:** The user can install the required base operating system onto the selected target.
- **FR18:** The user can complete personal environment configuration before the first normal reboot.
- **FR19:** MirrorOS can withhold a successful completion state until required verification has run.

### Environment Declaration and Configuration

- **FR20:** The user can define the capability inventory required for the MVP daily workflow.
- **FR21:** The user can declare required packages and record the source provenance of each package.
- **FR22:** The user can declare required system and user services.
- **FR23:** The user can declare configuration for the graphical environment, terminal, shell, Tmux, editor, Git, browser capabilities, keyboard shortcuts, and development tools.
- **FR24:** The user can organize environment declarations into independently applicable capability modules.
- **FR25:** The user can validate environment declarations before consequential changes are applied.
- **FR26:** The user can apply the declared environment independently of image construction and base-system installation.
- **FR27:** The user can reapply configuration to converge the system without duplicating declared state.
- **FR28:** The user can keep portable configuration, hardware-derived choices, privileged changes, secret references, and private state separate.
- **FR29:** The user can provide or resolve required secrets without storing their values in the repository, logs, or installation artifact.
- **FR30:** The user can reach the first graphical login with the declared MVP environment already applied.
- **FR31:** The user can apply or replace a desktop or workflow component without requiring unrelated environment modules to change.

### Hardware Adaptation

- **FR32:** MirrorOS can detect hardware capabilities required by the reference VM and target laptop.
- **FR33:** MirrorOS can select applicable configuration based on detected hardware capabilities.
- **FR34:** The user can inspect which configuration choices were derived from hardware detection.
- **FR35:** The user can maintain target-specific hardware adaptation separately from portable personal configuration.
- **FR36:** The user can add support for a new hardware capability without redefining unrelated portable workflow modules.

### Capability Verification and Reporting

- **FR37:** The user can associate each declared MVP capability with one or more readiness checks.
- **FR38:** The user can run readiness verification independently after installation or configuration.
- **FR39:** The user can see a concise aggregate result that emphasizes failed capabilities and external blockers requiring action.
- **FR40:** The user can see an actionable reason and next step for every failed or externally blocked capability.
- **FR41:** The user can access the complete passed, failed, or externally blocked status of every declared capability on demand.
- **FR42:** The user can distinguish a completed execution with failed verification from a fully verified success.
- **FR43:** The user can retain a verification summary as reconstruction evidence.
- **FR44:** The verification process can produce a structured summary artifact when required by tests or evidence collection.
- **FR45:** The user can rerun verification without repeating installation or configuration.

### Diagnostics and Recovery

- **FR46:** The user can access persistent diagnostic logs for lifecycle operations.
- **FR47:** The user can identify the failed lifecycle stage, affected capability, and last confirmed successful state.
- **FR48:** MirrorOS can stop a failed operation before performing avoidable subsequent changes.
- **FR49:** The user can retry a safe failed stage without implicitly repeating unrelated completed stages.
- **FR50:** MirrorOS can prevent destructive actions from being retried without renewed explicit confirmation.
- **FR51:** The user can follow documented recovery procedures when installation or configuration cannot continue.
- **FR52:** The user can abandon a failed physical-device attempt and use an independent rescue path.
- **FR53:** The user can identify undocumented intervention used during recovery so that it can be incorporated into the repository or documentation.

### Ongoing Evolution and Maintainability

- **FR54:** The user can manually update the version-controlled environment definition after changing the daily system.
- **FR55:** The user can review declared changes before applying them.
- **FR56:** The user can test a changed environment definition in the reference VM when its risk justifies validation.
- **FR57:** The user can apply a validated environment change to the daily system independently of reinstallation.
- **FR58:** The user can preserve the history and rationale of environment evolution through version-controlled changes.
- **FR59:** The user can reflect migration and recovery fixes back into the authoritative environment definition.
- **FR60:** The user can complete the documented clean-VM validation before proceeding to physical-device migration.
- **FR61:** The user can declare explicit prerequisites between capability modules.
- **FR62:** The user can organize modules by user capability independently of the current package or tool used to provide that capability.
- **FR63:** The user can isolate stable system declarations from faster-changing workflow and application declarations.
- **FR64:** The user can perform every action in the frozen frequent-action inventory through a keyboard-accessible path.
- **FR65:** The user can validate terminal, browser, portal-dependent operations, clipboard, screenshots, launcher, bar, and notifications within the provisional desktop environment.

## Non-Functional Requirements

### Performance

- **NFR1:** The initial reconstruction target is less than two hours from booting the installation medium to a passing ready-state verification on the target laptop.
- **NFR2:** Reconstruction timing must be measured under documented hardware, network, and package-source conditions so results can be compared across runs.
- **NFR3:** The two-hour target excludes restoration of personal data, private repositories, credentials, authenticated sessions, and optional application state.
- **NFR4:** The reconstruction target remains provisional until at least one complete VM baseline and one target-laptop run provide measured evidence.
- **NFR5:** Every long-running lifecycle operation must expose its active stage so the user can distinguish progress from a stalled process.

### Security and Privacy

- **NFR6:** The repository must be safe to publish without exposing credentials, private keys, secret values, personal content, or authenticated session material.
- **NFR7:** Automated inspection of the repository, generated installation artifacts, verification summaries, and diagnostic logs must detect zero known secret values before an artifact is accepted.
- **NFR8:** Secret values must not appear in terminal output, persistent logs, build metadata, or verification artifacts.
- **NFR9:** Privileged execution must be limited to operations that require system-level access; user-level configuration must not inherit privilege solely for execution convenience.
- **NFR10:** Every partitioning or disk-erasure operation must require explicit confirmation that identifies the selected target.
- **NFR11:** A cancelled destructive confirmation must result in zero execution of the rejected destructive operation.
- **NFR12:** One hundred percent of installed packages must have recorded source provenance.
- **NFR13:** Generated installation artifacts must include a checksum and metadata that relates the artifact to its source state.
- **NFR14:** Portable public configuration, hardware-specific configuration, private state, and secret references must remain separable for review and distribution.

### Reliability and Recoverability

- **NFR15:** A documented clean-clone build must produce a bootable installation artifact in the supported build environment.
- **NFR16:** One complete reconstruction must pass in the reference VM before physical-device installation is considered eligible to proceed.
- **NFR17:** A second configuration run against an already configured system must produce zero unintended changes and zero duplicated state.
- **NFR18:** Every declared MVP capability must end verification in exactly one explicit state: passed, failed, or blocked by an identified external dependency.
- **NFR19:** No failed or incomplete verification may be reported as a ready system.
- **NFR20:** A lifecycle-stage failure must prevent avoidable dependent stages from continuing.
- **NFR21:** Retrying a safe failed stage must not implicitly repeat destructive or unrelated completed operations.
- **NFR22:** Destructive retries must require renewed explicit confirmation.
- **NFR23:** The complete VM and target-laptop journeys must contain zero undocumented manual steps.
- **NFR24:** An independent rescue path and documented recovery procedure must be available before installation begins on the target laptop.
- **NFR25:** Diagnostic evidence from a failed run must remain accessible after termination unless the user explicitly removes it.
- **NFR26:** Recovery workarounds required to complete a supported journey must be captured in version control or documentation before that journey is considered reproducible.

### Portability and Compatibility

- **NFR27:** The MVP must satisfy its complete capability inventory on one reference VM configuration and one target laptop.
- **NFR28:** Behavior outside the declared MVP hardware targets carries no compatibility guarantee.
- **NFR29:** Hardware-specific adaptation must not alter unrelated portable workflow declarations.
- **NFR30:** Adding a hardware capability rule must not require redesigning the portable configuration model.
- **NFR31:** Every generated artifact must record sufficient package, repository, source, and relevant tool-version metadata to diagnose the environment from which it was built.
- **NFR32:** The strategy for current packages versus known-good package sets remains an architecture decision, but each accepted artifact must be validated against the package set it actually contains.
- **NFR33:** Niri-specific configuration must remain isolated so replacing the compositor does not require redesigning installation or unrelated workflow modules.

### Maintainability and Simplicity

- **NFR34:** One experienced maintainer must be able to build, test, install, configure, verify, and troubleshoot MirrorOS using repository documentation.
- **NFR35:** Every lifecycle stage must have documented prerequisites, inputs, expected outputs, failure evidence, and recovery guidance.
- **NFR36:** A change confined to one capability module must not require modifications to unrelated modules unless an explicit dependency exists.
- **NFR37:** Custom code, formats, services, and abstractions must have a documented recurring need that cannot be met adequately through simpler supported mechanisms.
- **NFR38:** MirrorOS must not require a proprietary configuration format unless comparative research identifies and documents a concrete gap in existing options.
- **NFR39:** The configuration source must remain human-readable and reviewable without requiring a running MirrorOS environment.
- **NFR40:** The quantitative maintenance budget remains unset until repeated builds, updates, and reconstructions establish an evidence baseline.

### Upstream Integration and Operational Transparency

- **NFR41:** Failures originating in upstream tools must retain enough original diagnostic context to identify the responsible operation and dependency.
- **NFR42:** Integration wrappers must not convert an upstream failure into a successful MirrorOS outcome.
- **NFR43:** Persistent logs must identify the lifecycle stage, operation outcome, and relevant non-secret diagnostic context.
- **NFR44:** Command outcomes must remain distinguishable through reliable exit statuses for success, validation failure, invalid input, cancellation, and execution failure.
- **NFR45:** Concise and structured verification outputs must represent the same aggregate outcome as the complete per-capability report.
- **NFR46:** Binding choices of installer, configuration mechanism, orchestration tool, and package-state strategy must remain deferred until comparative research and a minimal prototype provide evidence.
- **NFR47:** MirrorOS must introduce zero persistent assistants, welcome applications, or healthy-state notifications in the MVP.
- **NFR48:** One hundred percent of actions in the frozen frequent-action inventory must have a documented keyboard-accessible path.
- **NFR49:** Supported desktop components must use the declared typography, color, and density choices where those choices require no additional theming framework.
- **NFR50:** Visual customization must remain independently removable without breaking functional environment configuration.
- **NFR51:** Each maintained deviation from an upstream visual default must have identifiable daily value or negligible maintenance cost.
- **NFR52:** A task must have a documented manual or assisted process and demonstrated repetition before MirrorOS introduces custom automation for it.
