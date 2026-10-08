---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-09-24T18:15:13+02:00'
inputDocuments:
  - "docs/prd.md"
  - "docs/product-brief-mirroros.md"
  - "docs/brainstorming/brainstorming-session-2026-09-23-201236.md"
  - "docs/research/technical-mirroros-foundations-research-2026-09-24.md"
workflowType: 'architecture'
project_name: 'MirrorOS'
user_name: 'SHEAF'
date: '2026-09-24'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The PRD defines 65 functional requirements across seven capability areas:

- **Lifecycle execution and artifact management (FR1–FR9):** MirrorOS must expose independently invocable build, test, install, configure, and verify stages while also supporting a documented end-to-end reconstruction journey. Each stage requires discoverable inputs, observable progress, useful outputs, and distinguishable exit outcomes.
- **Installation planning and safety (FR10–FR19):** Installation must inspect the target, produce a reviewable and editable plan, explain the provenance of defaults, and require explicit confirmation for destructive, ambiguous, or secret-related operations. Cancellation and failed verification must never be represented as success.
- **Environment declaration and configuration (FR20–FR31):** The environment must be represented as readable, modular, validatable, and repeatable declarations. Portable configuration, hardware-derived choices, privileged changes, secret references, and private state require explicit separation. Configuration must remain independently applicable and idempotent.
- **Hardware adaptation (FR32–FR36):** Hardware decisions must be capability-based, inspectable, and isolated from portable workflow declarations. MVP support is limited to the reference VM and target laptop.
- **Capability verification and reporting (FR37–FR45):** Every declared MVP capability requires readiness checks and an explicit passed, failed, or externally blocked state. Verification must be independently runnable and capable of producing concise human output, complete evidence, and an optional structured summary.
- **Diagnostics and recovery (FR46–FR53):** Lifecycle failures require persistent evidence, bounded execution, safe retry semantics, renewed confirmation for destructive retries, documented recovery, and an independent rescue path.
- **Ongoing evolution and maintainability (FR54–FR65):** The repository remains the authoritative environment definition. Changes must be reviewable, testable, modular, and organized around user capabilities rather than permanently coupled tool choices.

Together, these requirements imply several cooperating architectural responsibilities rather than a single installation script: image construction, disposable-environment testing, installation planning and execution, hardware capability detection, modular configuration convergence, readiness verification, diagnostic evidence management, and lifecycle documentation or orchestration.

**Non-Functional Requirements:**

The PRD defines 52 non-functional requirements across six categories:

- **Performance (NFR1–NFR5):** The provisional reconstruction target is under two hours, measured under documented conditions, with visible progress for long-running operations.
- **Security and privacy (NFR6–NFR14):** The repository and generated artifacts must remain free of secrets and personal content. Privileges must be narrowly bounded, destructive targets explicitly confirmed, package provenance complete, and artifacts traceable to source state.
- **Reliability and recoverability (NFR15–NFR26):** Clean-clone builds, VM qualification, configuration idempotency, explicit verification states, bounded failures, safe retries, persistent diagnostics, zero undocumented steps, and an independent rescue path are acceptance conditions.
- **Portability and compatibility (NFR27–NFR33):** MVP compatibility is deliberately limited to one VM and one laptop. Hardware adaptation and Niri-specific configuration must remain isolated, while artifact metadata must preserve enough upstream state for diagnosis.
- **Maintainability and simplicity (NFR34–NFR40):** One maintainer must be able to understand and operate the complete lifecycle. Custom abstractions require demonstrated recurring value, and proprietary configuration formats are disfavored.
- **Upstream integration and operational transparency (NFR41–NFR52):** Upstream failures must retain diagnostic fidelity, wrappers must preserve failure semantics, lifecycle outcomes require stable exit statuses, and architecture commitments remain gated by research and prototype evidence.

The strongest architectural drivers are safety around destructive operations, idempotent convergence, secret isolation, privilege separation, diagnostic preservation, package and artifact provenance, explicit lifecycle boundaries, upstream change tolerance, and replaceability of desktop and workflow components.

**Scale & Complexity:**

MirrorOS has a narrow product and organizational scope but significant systems-engineering complexity. It has one primary user, one maintainer, no multi-tenancy, no regulatory compliance burden, no collaborative real-time behavior, and low application-data volume. Complexity instead arises from destructive storage operations, privileged system changes, hardware variation, rolling upstream dependencies, cross-stage failure handling, and the need to prove complete reconstruction.

- Primary domain: CLI-driven Linux distribution lifecycle and system configuration tooling
- Complexity level: High technical complexity within a deliberately narrow product scope
- Estimated architectural components: 8 logical responsibility areas
- User interaction complexity: Moderate to high at installation and recovery boundaries
- Data complexity: Low volume, but high integrity and provenance requirements
- Integration complexity: High due to operating-system tools, package sources, virtualization, hardware, and native Arch installation commands
- Real-time requirements: None
- Multi-tenancy requirements: None
- Regulatory requirements: None identified

### Technical Constraints & Dependencies

- Arch Linux and its rolling package ecosystem form the base platform and a continuously changing upstream dependency.
- Archiso is the expected image-construction baseline, but final integration details remain subject to research.
- Native Arch installation commands are the installation engine, selected by [ADR 0002](adr/0002-installation-engine-selection.md); Archinstall is not selected.
- QEMU/KVM or an equivalent disposable virtualization environment is required for pre-hardware validation.
- The MVP support boundary is one reference VM and one target laptop; broader hardware compatibility is explicitly excluded.
- The installation medium must remain minimal, while personal environment configuration evolves independently.
- Build, test, install, configure, and verify must remain independently invocable even if no unified executable is created.
- Existing tools and supported configuration mechanisms take precedence over custom applications, services, formats, or control planes.
- Destructive operations cannot become unattended through a generic automation flag.
- Secrets, personal content, credentials, repositories, and authenticated sessions remain external to the repository and generated image.
- Niri is a provisional desktop default and cannot become an architectural dependency.
- Final choices for orchestration, installation integration, configuration management, and package-state strategy are blocked by the comparative research and validation-prototype gate.
- Network access, Arch repositories, optional AUR or external package sources, source control, artifact storage, and an independent rescue medium are operational dependencies.

### Cross-Cutting Concerns Identified

- **Safety and confirmation semantics:** Every component involved in destructive or ambiguous changes must share consistent planning, confirmation, cancellation, and retry behavior.
- **Idempotency and convergence:** Configuration modules must support repeat execution without duplicated or unintended state.
- **Observability and evidence:** Lifecycle stages need coherent progress reporting, persistent logs, exit statuses, artifact metadata, and verification evidence.
- **Failure propagation:** Upstream failures must remain failures, prevent avoidable dependent execution, and identify the affected stage and capability.
- **Security and privacy:** Secret redaction, artifact inspection, privilege boundaries, and separation of public, private, hardware-specific, and secret-related state affect the full lifecycle.
- **Provenance and traceability:** Packages, generated artifacts, source state, tool versions, and accepted verification results must be attributable.
- **Modularity and replaceability:** Hardware rules, desktop components, workflow capabilities, visual customization, and lifecycle stages must evolve without unrelated changes.
- **Upstream volatility:** Arch, Archiso, installation tooling, repositories, package formats, and third-party sources require diagnosable integration boundaries.
- **Validation consistency:** Human-readable summaries, structured evidence, exit codes, and full per-capability reports must represent the same outcome.
- **Documentation as part of correctness:** A technically successful process with undocumented intervention does not satisfy the reconstruction contract.
- **One-maintainer sustainability:** Every abstraction and automation layer must justify its ongoing implementation, testing, and maintenance cost.
- **Evidence-gated decisions:** Comparative research and disposable prototypes must precede binding choices for major architecture mechanisms.

## Starter Template Evaluation

### Primary Technology Domain

Arch Linux distribution lifecycle and local system-configuration tooling, based on a version-controlled Archiso profile and independently invocable build, test, install, configure, and verify stages.

### Technical Preferences

- Remain as close as practical to native Arch Linux mechanisms.
- Prefer Bash for native Arch integration and JavaScript ESM on Node.js for non-trivial structured logic.
- Treat Python as an upstream runtime only unless an accepted ADR authorizes project-owned Python integration.
- Keep Lua local to tools that already use it.
- Begin with small, explicit scripts and documented commands.
- Adopt Ansible, Stow, chezmoi, or another abstraction only after a bounded prototype demonstrates a clear advantage.
- Keep independently maintained application configurations, including Neovim and Pi, in their existing repositories.
- Use official Arch repositories first and treat AUR packages as explicitly reviewed external sources.
- Defer Chaotic-AUR and CachyOS repositories until a measured requirement justifies their additional trust and maintenance surface.
- Use UEFI and GPT with a selectable storage option: ext4 with systemd-boot (default), Btrfs with Snapper and systemd-boot (supported), or Btrfs with Snapper and Limine (experimental), as recorded in [ADR 0003](adr/0003-storage-and-recovery-baseline.md); every root filesystem is unencrypted.
- Use a resizeable swapfile for both ordinary swap and hibernation.
- Treat hibernation as an essential MVP capability.
- Manage and verify the resume device and swapfile offset whenever the swapfile is created or resized.
- Validate repeated hibernation and resume with the hybrid AMD/NVIDIA graphics stack and selected kernel.
- Keep Secure Boot disabled for the MVP.

### Starter Options Considered

#### Official Archiso `releng` Profile

The official `releng` profile is used to produce the monthly Arch installation medium. It includes the established profile structure, package declarations, filesystem overlay, pacman configuration, and boot assets required for an installation-oriented image.

This option follows upstream conventions while allowing MirrorOS to remove unnecessary packages and overlays. It provides the shortest evidence-supported path to the required bootable installation artifact.

#### Official Archiso `baseline` Profile

The `baseline` profile is smaller, but provides fewer installation-oriented facilities. Starting from it would require MirrorOS to reconstruct decisions already represented by the official installation profile.

It remains useful as a minimality reference, but is not the preferred project foundation.

#### Archiso Source Checkout

Building from an Archiso source checkout permits testing unreleased changes and exact source revisions. Making the complete upstream repository the project starter would, however, couple MirrorOS unnecessarily to Archiso implementation and development files.

This should remain a compatibility-testing option rather than the owned project structure.

#### Downstream Distribution Profiles

Omarchy, CachyOS, and EndeavourOS provide useful patterns but include product-specific packages, installer integrations, repositories, release machinery, or broader hardware support. Forking one would inherit responsibilities outside the MirrorOS scope.

They remain pattern and test references, not starter candidates.

### Selected Starter: Project-Owned Copy of the Official Archiso `releng` Profile

**Rationale for Selection:**

- Uses the official installation-media foundation.
- Matches the research recommendation and thin-bootstrap architecture.
- Preserves normal Archiso documentation and ecosystem knowledge.
- Avoids inheriting a downstream distribution or installer fork.
- Provides a concrete profile that can be reduced through measured changes.
- Keeps generated images separate from authoritative source declarations.
- Does not commit MirrorOS to Archinstall, Ansible, a dotfile manager, or a custom CLI.

At verification time, the current official Arch package was `archiso` 90-1. This is a dated observation, not an architecture pin. Builds must record the actual installed Archiso version.

**Initialization Command:**

```bash
install -d image
cp -a /usr/share/archiso/configs/releng image/archiso
```

**Reference Build Command:**

```bash
sudo mkarchiso \
  -w build/archiso-work \
  -o dist \
  image/archiso
```

Exact repository paths and privilege boundaries may be refined by the first implementation story, but the upstream profile structure must remain recognizable.

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Shell-based Archiso profile and build integration.
- Native Arch package and configuration formats.
- No custom application runtime or CLI framework.

**Styling Solution:**
- None. Visual and desktop configuration remain outside the bootstrap image foundation.

**Build Tooling:**
- `mkarchiso`
- Pacman repository and package resolution
- Archiso filesystem overlays
- SquashFS and boot-image tooling
- Generated ISO artifacts

**Testing Framework:**
- Archiso's `run_archiso` may support initial boot testing.
- MirrorOS will own the QEMU/KVM UEFI harness, installation tests, and capability verification.
- Static shell validation and secret scanning apply from the first prototype.

**Code Organization:**
- Profile metadata in `profiledef.sh`.
- Architecture-specific package declarations.
- Pacman configuration.
- Minimal `airootfs` overlay.
- Bootloader assets.
- Generated work and output directories excluded from authoritative source.

**Development Experience:**
- Familiar Archiso conventions.
- Direct access to upstream diagnostic output.
- No mandatory wrapper or task runner.
- Commands remain documented and independently invocable.

**Input Research:**
- `docs/research/technical-mirroros-foundations-research-2026-09-24.md`

**Note:** Creating the project-owned `releng` profile, recording its upstream identity, building it cleanly, and booting it in a QEMU/UEFI environment should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions:**

- Use upstream-native, Git-tracked declarations rather than a proprietary MirrorOS schema.
- Implement lifecycle stages as a synchronous local pipeline with explicit process, file, exit-status, and evidence contracts.
- Use standard Linux accounts, PAM, narrowly scoped privilege elevation, and runtime-only secret injection.
- Bind every destructive authorization to a concrete target and plan digest.
- Use UEFI, GPT, an unencrypted root with the storage option selected under [ADR 0003](adr/0003-storage-and-recovery-baseline.md) (ext4 with systemd-boot by default), and a resizeable swapfile supporting mandatory hibernation.
- Qualify artifacts through QEMU/KVM before physical installation.
- Install through native Arch commands, as selected by [ADR 0002](adr/0002-installation-engine-selection.md) after an Archinstall JSON/CLI versus native Arch commands spike.
- Resolve the convergence mechanism through a shell versus Ansible local-mode spike and ADR.
- Require package provenance, secret scanning, capability verification, and retained evidence before artifact promotion.

**Important Decisions:**

- Begin with documented scripts rather than a task runner or unified CLI.
- Keep application configuration repositories independent and integrate them through explicit Git checkouts and links.
- Use official Arch repositories first and treat AUR packages as explicitly reviewed external sources.
- Start with the official Arch `linux` kernel and evaluate the CachyOS kernel as a parallel experiment.
- Maintain separate current-package canary and accepted-known-good artifact tracks.
- Keep hardware, system, user, visual, and verification responsibilities separate.

**Deferred Decisions:**

- Archinstall Python API or plugin integration.
- Stow or chezmoi adoption.
- Make, Just, or a unified `mirroros` executable.
- Chaotic-AUR.
- CachyOS repository and kernel adoption.
- Secure Boot and TPM integration.
- Encrypted secrets committed to the repository.
- Exact historical package reconstruction.
- Scheduled remote CI.
- General hardware-profile engine.
- Automated drift reconciliation.
- Broader hardware support.

### Data Architecture

MirrorOS uses no application database. Version-controlled text declarations are authoritative, while generated plans, artifacts, logs, and verification reports are derived operational data.

**Declaration strategy:** Use upstream-native formats with a minimal capability inventory rather than a universal MirrorOS schema. Archiso package lists, pacman configuration, systemd units, installer configuration, and application-native files retain their established semantics.

**Precedence:**

```text
portable baseline
  < detected hardware selection
  < explicit target-machine override
  < runtime secret/private input
```

Hardware detection may select applicable configuration, but target-specific overrides remain explicit and reviewable. Runtime secret and private inputs never become source-controlled values.

**Data classes:**

- Source declarations: Git-tracked and authoritative.
- Private references: Git-tracked references without secret values.
- Generated plans: Ephemeral, reviewable, and bound to discovered target state.
- Build artifacts: Derived, checksummed, and traceable to source.
- Operational evidence: Allowlisted, retained according to policy, and secret-scanned.
- Verification results: Generated from one shared result model.

**Capability inventory:** A minimal inventory relates each capability to its implementation, package provenance, dependencies, and verification checks. It does not replace the native configuration owned by each tool.

**Migration strategy:** Schema and configuration changes use ordinary version-controlled changes and explicit migrations only when existing installed state requires transformation. No database migration framework is introduced.

**Caching:** Build or package caches may improve execution speed but are never authoritative or required for correctness. Periodic clean reconstruction must prove that caches do not conceal undeclared dependencies.

### Authentication & Security

MirrorOS exposes no remote product API and introduces no application-specific authentication system. Identity and access remain owned by standard Linux accounts, PAM, and narrowly scoped privilege elevation.

**Local identity:**

- Linux accounts and PAM own user authentication.
- Credentials are supplied at execution time and never stored in source, generated images, or retained evidence.
- Password-manager integration is deferred until a concrete requirement demonstrates its value.

**Privilege model:**

- Lifecycle orchestration begins unprivileged.
- Build, storage, installation, and system-configuration operations elevate independently at the narrowest viable boundary.
- User configuration never inherits root privileges for convenience.
- The complete workflow must not run under a single persistent privileged session.
- The observed Arch package version is `sudo 1.9.17.p2-6`; this is recorded evidence, not an architecture pin.

**Destructive authorization:**

- Read-only discovery precedes plan generation.
- Plans identify the selected device using its path, model, size, and available stable identifiers.
- Confirmation is bound to the concrete plan and target.
- Changed target state or regenerated plans invalidate prior approval.
- Retries require renewed confirmation.
- Cancellation performs none of the rejected destructive operations.

**Secret handling:**

- Source contains secret references, never secret values.
- Runtime values use protected prompts, file descriptors, or short-lived permission-restricted files rather than observable process arguments.
- Temporary secret-bearing material is removed after use.
- Evidence collection uses explicit allowlists and redaction.
- SOPS and encrypted values in Git are deferred.

**Package and artifact trust:**

- Signed official Arch repositories are the default package source.
- AUR packages may be installed through `yay` only after explicit `PKGBUILD` review and unprivileged build.
- Package provenance records source class, repository or recipe identity, version, and relevant verification evidence.
- Chaotic-AUR remains disabled.
- CachyOS packages and repositories remain experimental pending an ADR and validation.
- Direct binaries or archives require an explicit rationale and verified checksum or signature.

**Secret scanning:**

- `gitleaks` scans Git history, working trees, staging directories, and retained evidence before acceptance or publication.
- Terminal, log, and report redaction behavior receives deliberate tests.
- The verified release is `gitleaks 8.30.1`, also available as Arch package `8.30.1-1`; builds record the actual version rather than pinning this observation.

**Accepted security posture:**

- The root filesystem, ext4 or Btrfs, remains unencrypted.
- Secure Boot remains disabled for the MVP.
- Exposure of local data under physical access is an explicitly accepted risk.
- External backup and independent rescue media remain mandatory before physical installation.

### API & Communication Patterns

MirrorOS exposes no network API. Lifecycle components form a synchronous local pipeline using documented process and file contracts.

**Stage contract:**

- Every stage is independently invocable.
- Each stage declares inputs, preconditions, outputs, postconditions, and privilege requirements.
- Small options use command arguments; structured inputs use explicit files.
- Substantive configuration is not transported through environment variables.
- Core lifecycle transitions remain explicit rather than hidden in package hooks.
- Failure stops avoidable dependent execution.

**Output contract:**

- `stdout` contains concise human-readable progress and outcomes.
- `stderr` contains warnings and actionable diagnostics.
- Persistent logs retain allowlisted, redacted diagnostic detail.
- Structured results are written explicitly to files.
- Wrappers preserve original upstream diagnostics and exit statuses in evidence.

**Normalized exit statuses:**

```text
0  success
2  invalid input, configuration, or unmet precondition
3  explicit user cancellation
4  completed execution but verification is not ready
5  execution or upstream-operation failure
6  internal contract or invariant failure
```

Signal termination retains normal shell conventions. A wrapper returning normalized status `5` also records the original child exit status.

The `verify` stage returns `0` only when every required capability passes. Any `failed` or `blocked_external` capability returns `4`.

**Destructive plan contract:**

- A plan includes target identity, relevant discovery, proposed operations, default provenance, secret requirements, and a content digest.
- Confirmation authorizes only the concrete plan digest.
- Changed discovery or regenerated plan content invalidates prior authorization.

**Execution evidence:** Each run receives an identifier and evidence directory containing source and tool metadata, stage identity, non-secret inputs, normalized outcome, original child status where applicable, allowed logs, duration, and generated artifacts or reports.

**Verification model:**

```text
capability
├── identifier
├── checks
│   ├── identifier
│   ├── outcome
│   └── non-secret evidence
├── aggregate status
├── actionable reason
└── next step
```

Allowed aggregate states are `passed`, `failed`, and `blocked_external`. Human and structured reports derive from the same results. JSON is the initial structured-output candidate; its exact schema remains gated by the verification prototype.

**Implementation boundaries:**

- Documented scripts provide the initial lifecycle interface.
- A unified `mirroros` executable is not required.
- Archinstall is not selected as the installation engine ([ADR 0002](adr/0002-installation-engine-selection.md)); no Archinstall integration is planned.
- `arch-chroot` defines the live-environment to installed-target boundary.
- Wrappers never convert upstream failure into success.
- Completion markers never replace postcondition verification.

### Frontend Architecture

MirrorOS has no web or mobile frontend. Its product interaction surface is the terminal, while the configured graphical desktop remains an output capability rather than an administration interface.

**Lifecycle command surface:**

```text
build
test
install
configure
verify
```

These names define independently invocable contracts. They may initially be implemented as separate scripts and do not require a unified executable.

Each command documents its purpose, prerequisites, inputs, consequential effects, evidence location, and possible exit statuses.

**Interaction model:**

- Reproducible non-destructive operations support non-interactive execution.
- Destructive operations always require explicit interactive confirmation.
- A generic non-interactive option never bypasses destructive confirmation.
- Sensitive prompts use a terminal or protected input channel.
- A required confirmation without an interactive terminal fails as invalid input or an unmet precondition.
- Virtual and physical targets use identical confirmation semantics.

**Plan review flow:**

1. Present the target summary.
2. Present proposed defaults and their provenance.
3. Highlight destructive operations.
4. Allow inspection of the complete plan.
5. Permit cancellation without changes.
6. Require confirmation bound to the target and plan digest.

MirrorOS introduces no custom TUI. [Gum](https://github.com/charmbracelet/gum) is the interactive presentation layer ([ADR 0004](adr/0004-interactive-presentation-with-gum.md)): it only presents and collects input, and the plan, its digest, and `install/engine/apply` do not depend on it. The native installation engine ([ADR 0002](adr/0002-installation-engine-selection.md)) provides no interaction model of its own; the wrappers required by ADR 0004 keep this contract when Gum is used.

**Terminal output:**

- Every long-running operation identifies its active stage.
- Healthy success remains concise.
- Failures identify the stage, operation or capability, reason, and next action.
- Detailed diagnostics remain available in persistent logs.
- Progress does not depend on animation.
- Color never carries meaning alone.
- Commands respect non-interactive terminals and `NO_COLOR`.
- A styled header or welcome is allowed only in interactive TTY sessions of `install` and `configure`; it is suppressed in non-interactive mode, without a TTY, and in logs. MirrorOS adds no persistent healthy-state notifications.

**Desktop boundary:**

- Niri and related desktop components are configured capabilities, not a MirrorOS management console.
- No control panel, welcome application, or management daemon is introduced.
- The first graphical session is either ready or represented accurately by explicit verification results.

### Infrastructure & Deployment

MirrorOS deployment means reconstructing and qualifying a machine rather than deploying a hosted service.

**Supported environments:**

- Current Arch Linux-compatible build host.
- QEMU/KVM reference laboratory with OVMF UEFI firmware.
- One version-controlled reference VM configuration.
- One physical target: Framework Laptop 13 Pro (AMD Ryzen AI 300, integrated graphics only).
- Working KVM is an automatically checked validation precondition.
- Containers and remote CI are not required for the initial supported path.

Current observed versions include QEMU `11.1.1-4`, OVMF `202608-1`, Linux `7.2.6.arch2-1`, Archinstall `4.4-1`, Ansible Core `2.21.4-1`, Stow `2.4.1-1`, chezmoi `2.72.2-1`, and yay `13.0.1-1`. These are dated observations, not architecture pins.

**Artifact promotion:**

```text
built
→ boot-tested
→ install-tested
→ configured
→ hibernation-tested
→ idempotency-tested
→ capability-verified
→ accepted-known-good
→ target-laptop-eligible
```

Promotion evidence records source state, tool versions, repositories, resolved packages, checksum, VM configuration, allowed logs, capability results, and stage durations.

**Current and known-good tracks:**

- Current canaries build against rolling repositories to expose upstream breakage.
- Known-good storage retains a fully qualified ISO, checksum, package manifest, and evidence for recovery.
- Historical package reconstruction remains deferred; the MVP guarantees retention of the accepted artifact rather than binary-identical rebuilding.

**Validation sequence:**

1. Format validation and static analysis.
2. Secret scanning.
3. Module and contract tests.
4. Clean Archiso build.
5. UEFI boot and networking.
6. Plan generation and safe cancellation.
7. Installation onto a fresh virtual disk.
8. Reboot without installation media.
9. Configuration and capability verification.
10. Second configuration run with no unintended changes.
11. Repeated hibernation and resume.
12. Physical qualification with independent rescue access.

Hibernation validation covers swapfile resume configuration, offset recalculation after resizing, Niri, hybrid AMD/NVIDIA graphics, video-memory preservation, and graphical workloads across repeated cycles.

**Technology gates:**

- The installation-engine gate is resolved: native Arch installation commands, recorded in [ADR 0002](adr/0002-installation-engine-selection.md).
- Compare minimal shell against Ansible local mode using one representative end-to-end capability.
- Begin dotfile integration with explicit Git checkouts and links; evaluate Stow or chezmoi only after demonstrated repetition or machine-specific complexity.
- Begin orchestration with documented scripts; add Make, Just, or a unified CLI only after the real command graph demonstrates value.

**Kernel policy:**

- Use the official Arch `linux` kernel for initial qualification.
- Evaluate the CachyOS kernel as a parallel, reversible experiment.
- Keep a bootable official kernel during evaluation.
- Adoption requires measured improvement without unacceptable regression in battery use, suspension, hibernation, NVIDIA behavior, or maintenance.
- Hybrid graphics remain target-specific adaptation rather than portable configuration.

**Operations:**

- MirrorOS introduces no remote monitoring service or resident management daemon.
- Logs are local, persistent, and associated with an execution identifier.
- Health checks run explicitly.
- Scheduled remote CI remains deferred.
- External backup, independent rescue media, and a known-good ISO are mandatory before physical installation.

### Decision Impact Analysis

**Implementation Sequence:**

1. Create and reduce the project-owned Archiso `releng` profile.
2. Establish source, evidence, provenance, exit-status, and secret-scanning contracts.
3. Implement Arch host and KVM/OVMF preflight validation.
4. Build and boot the minimal ISO with networking and traceable metadata.
5. Execute the installation-engine comparison and record its ADR.
6. Execute the convergence-mechanism comparison and record its ADR.
7. Freeze the capability inventory and prototype the shared verification model.
8. Integrate package provenance and independent configuration repositories.
9. Implement portable system, target hardware, desktop, NVIDIA, swapfile, and hibernation capabilities.
10. Complete clean end-to-end VM reconstruction and artifact promotion.
11. Qualify the Framework Laptop 13 Pro only after backup, rescue, and known-good gates pass.

**Cross-Component Dependencies:**

- The selected installation engine must implement the shared plan, confirmation, cancellation, diagnostic, and evidence contracts.
- The selected convergence mechanism must preserve privilege boundaries and implement postcondition-based idempotency.
- Swapfile creation or resizing requires resume configuration recalculation and renewed hibernation verification.
- Kernel and NVIDIA choices directly affect graphical readiness, suspension, hibernation, and artifact qualification.
- Capability verification depends on the package inventory, configuration modules, and hardware selections but remains independently invocable.
- Known-good promotion depends on every preceding validation state; successful build or boot alone is insufficient.
- Unencrypted storage increases dependence on external backups and accepted physical-access risk.
- Native configuration formats remain authoritative; the capability inventory links responsibilities without replacing them.

## Implementation Patterns & Consistency Rules

### Decision Authority

Technology mentions do not imply technology selection.

- This architecture and accepted ADRs are normative for implementation.
- The PRD defines required outcomes but does not select implementation technologies.
- Research documents provide evidence and candidate options; they are non-normative.
- A technology marked as a prototype candidate, conditional option, or deferred choice must not appear in production implementation before its gate and ADR are complete.
- If architecture, ADRs, requirements, and research appear inconsistent, agents must stop and surface the conflict rather than choosing an interpretation.

### Pattern Categories Defined

**Critical Conflict Points Identified:** 13 areas where agents could otherwise make incompatible choices:

1. Implementation-language selection.
2. File and command naming.
3. Capability identifiers.
4. Bash conventions.
5. JavaScript conventions.
6. Test and fixture placement.
7. Configuration ownership.
8. JSON and time formats.
9. Logging and error representation.
10. Validation and postconditions.
11. Idempotency and retries.
12. Atomic output and evidence handling.
13. Decisions gated by prototypes and ADRs.

### Language Decision Status

| Language | Status | Permitted use |
|---|---|---|
| Bash | Selected | Default for Arch integration and bounded system scripting |
| JavaScript ESM on Node.js | Selected for structured lifecycle data | Plan processing, hardware normalization, verification aggregation, and other non-trivial structured logic |
| Python | Not selected for project-owned code | Upstream runtime dependency only unless an accepted ADR approves Archinstall API/plugin integration |
| Lua | Tool-local only | Existing Neovim, Niri, or other tool-owned configuration |
| Gum | Selected for interactive presentation | Presents and collects input only, under the wrappers of [ADR 0004](adr/0004-interactive-presentation-with-gum.md); not part of the plan, its digest, or `install/engine/apply` |

Invoking the packaged Archinstall CLI does not authorize project-owned Python code.

Agents MUST NOT add a project-owned `.py` file, add a Python project dependency, import the Archinstall Python package, implement an Archinstall plugin, or choose Python because it appears in research or upstream source. Any such action requires an accepted ADR and a corresponding architecture update.

### Naming Patterns

**General Naming Conventions:**

- Directories and ordinary files use `lowercase-kebab-case`.
- Lifecycle executables use `lowercase-kebab-case` without a language extension.
- Sourced Bash libraries use `lowercase-kebab-case.sh`.
- JavaScript ESM modules use `lowercase-kebab-case.mjs`.
- Test names mirror the source name and append the test type.
- Generated files include their content role, not generic names such as `output.json`.

Examples:

```text
build
verify
storage-plan.sh
plan-validator.mjs
storage-plan.unit.bats
verification-result.json
```

**Capability Identifiers:**

Capability identifiers use lowercase dot-separated semantic segments:

```text
desktop.clipboard
desktop.screenshot
power.hibernate
hardware.nvidia
development.neovim
```

Capability names describe user intent rather than a current provider. Use `desktop.compositor` for the replaceable capability; use a tool-specific identifier only for a genuinely tool-specific check.

**Code Naming Conventions:**

| Context | Convention | Example |
|---|---|---|
| Bash function | `lower_snake_case` | `verify_resume_offset` |
| Bash local variable | `lower_snake_case` | `target_device` |
| Shell constant/exported contract | `UPPER_SNAKE_CASE` | `MIRROROS_RUN_ID` |
| JavaScript function/variable | `lowerCamelCase` | `validatePlan` |
| JavaScript class | `PascalCase` | `VerificationResult` |
| JavaScript constant | `UPPER_SNAKE_CASE` only for true constants | `EXIT_CANCELLED` |
| JSON field | `snake_case` | `next_step` |
| Error code | `lower_snake_case` | `target_identity_changed` |

Database and network API naming conventions are not applicable because MirrorOS introduces neither an application database nor a network API.

### Structure Patterns

**Language Selection:**

Use the smallest language appropriate to the responsibility:

1. Bash for direct Arch integration, process composition, mounts, package operations, systemd operations, and small bounded scripts.
2. JavaScript ESM on Node.js for non-trivial structured data, plan generation, validation, result aggregation, and evidence reporting.
3. Python only when an approved ADR requires Archinstall API/plugin integration or another upstream Python interface.
4. Lua remains local to tools that already use it, such as Neovim or Niri configuration.

Do not rewrite simple shell operations in JavaScript for uniformity. Do not retain complex parsing or state models in Bash when JavaScript materially reduces risk.

Node.js is included in the live or installed environment wherever accepted plan processing, hardware normalization, or verification components execute. It is not used to replace simple native shell operations. The observed Arch version is `nodejs 26.10.0-1`; implementations record the actual version rather than depending on this observation.

**Project Organization:**

- Production code is grouped by lifecycle or capability ownership, never by generic technical type alone.
- Tests live under a top-level `tests/` tree that mirrors production ownership.
- Shared fixtures live under `tests/fixtures/`.
- Test-generated disks, images, logs, and evidence never live beside source fixtures.
- Shared helpers are introduced only after multiple concrete callers establish a stable responsibility.
- Do not create ambiguous `misc/`, `common/`, or `utils/` dumping grounds.
- External Neovim, Pi, and application repositories remain authoritative for their own configuration.

**Configuration Ownership:**

Every package, file, service, and generated artifact has one authoritative owner.

- The image profile owns live-media contents.
- Installation policy owns base installation choices.
- Hardware modules own detected target-specific choices.
- System capability modules own machine-wide desired state.
- User capability modules own unprivileged user state.
- External application repositories own their application configuration.
- Verification owns readiness checks, not configuration changes.

Agents must reference an existing declaration rather than copy it into another layer. A package required in both live and installed environments must have explicitly distinct reasons and provenance entries.

### Format Patterns

**Structured Data:**

- JSON fields use `snake_case`.
- Booleans use JSON `true` and `false`.
- Numbers remain numbers and are not encoded as strings.
- Omit fields that do not apply.
- Use `null` only when “known but without a value” has defined meaning.
- Arrays preserve meaningful execution order only when the contract declares order significant.
- Structured files include a schema or format version once compatibility across versions becomes necessary.
- Unknown fields are rejected for safety-critical plans unless the schema explicitly permits extension.

**Time and Identity:**

- Timestamps use RFC 3339 UTC, for example `2026-09-24T12:34:56Z`.
- Durations use integer milliseconds and names ending in `_ms`.
- A run identifier is generated once at the lifecycle boundary and propagated unchanged.
- Source identity includes commit, dirty-state indication, and relevant tool versions.
- Plans include a digest over their canonical persisted content.

**Atomic Output:**

Plans, manifests, and verification reports are written to a temporary file on the same filesystem, flushed as appropriate, validated, and renamed atomically. Partially written structured output must never be treated as valid evidence.

### Communication Patterns

**Process Communication:**

- Use argument arrays, explicit files, stdin, stdout, stderr, and exit status.
- Never construct commands by concatenating shell strings.
- Environment variables are reserved for small process context, not substantive configuration.
- Child diagnostics remain attributable to the child operation.
- A normalized wrapper result never erases the original child exit status.

**JavaScript Process Execution:**

Use `spawn` or `execFile` with argument arrays and shell execution disabled. Do not use `exec` for configuration-derived commands.

```javascript
const child = spawn("/usr/bin/pacman", ["--sync", "--needed", packageName], {
  shell: false,
  stdio: ["ignore", "pipe", "pipe"],
});
```

External npm dependencies require a documented need and a committed lockfile. Prefer Node built-ins for small scripts.

**Execution State:**

Pipeline state is explicit and monotonic:

```text
planned → running → succeeded
                  ↘ failed
                  ↘ cancelled
```

Verification readiness is separate from execution success. Logs and completion markers do not establish state without the corresponding postcondition.

MirrorOS introduces no event bus or asynchronous state-management framework.

### Process Patterns

**Bash Rules:**

- Use `#!/usr/bin/bash` for project-owned Bash executables.
- Executables begin with `set -Eeuo pipefail` unless a documented local exception is required.
- Quote expansions unless deliberate splitting is explicitly documented.
- Use arrays for commands and argument lists.
- Use `local` variables inside functions.
- Use traps to clean temporary resources and leave bounded safe state.
- Never use `eval` with generated or configuration-derived input.
- Never suppress failure with `|| true` without a documented reason and subsequent postcondition check.
- ShellCheck must pass for project-owned shell.

**JavaScript Rules:**

- Use JavaScript ESM, not CommonJS.
- Use `.mjs` until a package boundary explicitly establishes `"type": "module"`.
- Do not introduce TypeScript or a transpilation step for scripting.
- Validate parsed files and external process output at the boundary.
- Await asynchronous work explicitly.
- Propagate errors to the lifecycle boundary rather than logging and continuing.
- Never expose secrets through thrown messages, serialized objects, or child arguments.
- Keep filesystem and process side effects behind clearly named functions.

**Validation Pattern:**

Every state-changing operation follows:

```text
validate input
→ inspect current state
→ determine required change
→ apply bounded change
→ verify postcondition
→ record non-secret evidence
```

Validation occurs before privilege elevation and before destructive execution whenever possible.

**Idempotency Pattern:**

A successful second run:

- Detects the existing correct state.
- Performs no unnecessary mutation.
- Produces no duplicate declarations.
- Verifies the same postcondition.
- Reports success without claiming a change occurred.

Exit status zero alone is not proof of idempotency.

**Retry Pattern:**

- Automatic retries are disabled by default.
- Only transient, non-destructive operations may retry automatically.
- Retries are bounded and logged.
- A retry never broadens privilege or target scope.
- Destructive operations never retry automatically.
- Retrying a lifecycle stage creates new execution evidence.

**Error Pattern:**

Human logs use:

```text
2026-09-24T12:34:56Z INFO  build.archiso Starting image build
2026-09-24T12:35:10Z ERROR install.storage Target identity changed
```

Structured errors contain:

```json
{
  "code": "target_identity_changed",
  "stage": "install",
  "operation": "partition_target",
  "message": "The selected target no longer matches the approved plan.",
  "next_step": "Regenerate and review the installation plan.",
  "child_exit_status": null
}
```

- `message` is safe for users and logs.
- `next_step` is actionable.
- `child_exit_status` appears only when a child process exists.
- Secret-bearing arguments, environments, and raw installer directories are never logged indiscriminately.

### Enforcement Guidelines

**All AI Agents MUST:**

- Read this architecture and applicable ADRs before modifying a responsibility boundary.
- Preserve the Bash-first, JavaScript-second language hierarchy.
- Avoid Python project code unless an ADR explicitly approves its upstream integration need.
- Use native configuration formats and the established ownership boundary.
- Add or update verification whenever introducing or changing a capability.
- Add provenance whenever introducing a package or external artifact.
- Keep portable, hardware, privileged-system, user, and visual concerns separate.
- Preserve upstream diagnostics and exit outcomes.
- Validate before mutation and verify after mutation.
- Keep generated artifacts and evidence outside authoritative source paths.
- Avoid resolving prototype-gated decisions inside unrelated implementation work.
- Document exceptions next to the affected code and escalate architectural exceptions into an ADR.
- Avoid unrelated refactoring or formatting changes.

**Pattern Enforcement:**

- ShellCheck validates project shell.
- Unit and contract tests validate naming, exit codes, plan digests, redaction, and result formats.
- Secret scanning runs against source, staging trees, and retained evidence.
- Clean reconstruction tests detect undeclared cache or host dependencies.
- Second-run tests enforce convergence.
- Architecture exceptions are recorded in ADRs rather than silently establishing precedent.
- Pattern changes update this document before agents adopt the new convention.

### Pattern Examples

**Good Examples:**

```bash
#!/usr/bin/bash
set -Eeuo pipefail

verify_resume_offset() {
  local swap_file=$1
  # Inspect and verify the declared postcondition.
}
```

```javascript
import { readFile } from "node:fs/promises";

export async function loadInstallationPlan(path) {
  const content = await readFile(path, "utf8");
  const plan = JSON.parse(content);
  validateInstallationPlan(plan);
  return plan;
}
```

```text
capability: power.hibernate
owner: capabilities/power
result: passed
```

**Anti-Patterns:**

- Introducing Python merely because Archinstall itself uses Python.
- Introducing TypeScript and a build pipeline for a small script.
- Creating a universal MirrorOS YAML format over native Arch configuration.
- Naming a stable capability after its current implementation.
- Copying package declarations between image and installed-system layers.
- Running the complete workflow as root.
- Building commands through string interpolation or `eval`.
- Logging complete environments, credentials, or installer directories.
- Treating a completion marker or exit code zero as proof of readiness.
- Automatically retrying partitioning or installation.
- Selecting Archinstall, Ansible, CachyOS, Stow, or chezmoi inside an unrelated story before its gate and ADR.

## Project Structure & Boundaries

### Complete Project Directory Structure

```text
mirroros/
├── README.md
├── AGENTS.md
├── LICENSE
├── .gitignore
├── .shellcheckrc
│
├── docs/
│   ├── architecture.md
│   ├── prd.md
│   ├── product-brief-mirroros.md
│   ├── attribution.md
│   ├── adr/
│   │   ├── README.md
│   │   └── 000-template.md
│   ├── procedures/
│   │   ├── build.md
│   │   ├── test.md
│   │   ├── install.md
│   │   ├── configure.md
│   │   ├── verify.md
│   │   ├── recovery.md
│   │   └── update-archiso.md
│   ├── research/
│   │   └── technical-mirroros-foundations-research-2026-09-24.md
│   └── .obsidian/                  # Documentation tooling; outside product runtime
│
├── image/
│   ├── builder/                    # `image/builder/`
│   │   ├── arch-image-signature.conf
│   │   ├── build-artifact
│   │   ├── build-documents.mjs
│   │   └── lib/
│   │       ├── container.sh
│   │       ├── outcome.sh
│   │       ├── preconditions.sh
│   │       ├── publication.sh
│   │       ├── run-resources.sh
│   │       └── source-capture.sh
│   └── archiso/
│       ├── UPSTREAM.md
│       ├── profiledef.sh
│       ├── packages.x86_64
│       ├── pacman.conf
│       ├── bootstrap_packages
│       ├── airootfs/
│       │   ├── etc/
│       │   │   ├── hostname
│       │   │   ├── locale.conf
│       │   │   ├── localtime
│       │   │   ├── mkinitcpio.conf.d/
│       │   │   ├── pacman.d/
│       │   │   ├── ssh/
│       │   │   └── systemd/
│       │   ├── root/
│       │   └── usr/local/
│       ├── efiboot/
│       │   └── loader/
│       ├── grub/
│       │   ├── grub.cfg
│       │   └── loopback.cfg
│       └── syslinux/
│           ├── archiso_head.cfg
│           ├── archiso_pxe-linux.cfg
│           ├── archiso_pxe.cfg
│           ├── archiso_sys-linux.cfg
│           ├── archiso_sys.cfg
│           ├── archiso_tail.cfg
│           ├── splash.png
│           └── syslinux.cfg
│
├── operations/
│   ├── build
│   ├── test
│   ├── install
│   ├── configure
│   ├── verify
│   ├── clean
│   └── lib/
│       ├── evidence.sh
│       ├── exit-status.sh
│       ├── logging.sh
│       ├── preflight.sh
│       └── privilege.sh
│
├── contracts/
│   ├── README.md
│   ├── installation-plan.schema.json
│   ├── verification-result.schema.json
│   └── execution-result.schema.json
│
├── install/
│   ├── discovery/
│   │   ├── discover-firmware
│   │   ├── discover-network
│   │   ├── discover-storage
│   │   └── discover-hardware
│   ├── plan/
│   │   ├── generate-plan.mjs
│   │   ├── validate-plan.mjs
│   │   ├── render-plan.mjs
│   │   └── digest-plan.mjs
│   ├── confirmation/
│   │   └── confirm-plan
│   └── engine/
│       ├── README.md
│       └── apply
│
├── inventory/
│   ├── capabilities.json
│   ├── packages.json
│   └── external-sources.json
│
├── capabilities/
│   ├── base/
│   │   ├── packages/
│   │   ├── services/
│   │   └── system/
│   ├── desktop/
│   │   ├── compositor/
│   │   │   └── providers/
│   │   │       └── niri/
│   │   ├── terminal/
│   │   ├── portal/
│   │   ├── clipboard/
│   │   ├── screenshot/
│   │   ├── launcher/
│   │   ├── bar/
│   │   ├── notifications/
│   │   └── shortcuts/
│   ├── workflow/
│   │   ├── shell/
│   │   ├── tmux/
│   │   └── browser/
│   ├── development/
│   │   ├── git/
│   │   ├── neovim/
│   │   ├── pi/
│   │   └── tooling/
│   └── power/
│       └── hibernate/
│
├── hardware/
│   ├── discovery/
│   │   └── normalize-hardware.mjs
│   └── rules/
│       ├── amd-integrated-graphics/
│       ├── nvidia-discrete-graphics/   # not applicable to the current target (ADR 0005)
│       ├── hybrid-graphics/            # not applicable to the current target (ADR 0005)
│       ├── battery/
│       └── virtualization/
│
├── targets/
│   ├── reference-vm/
│   │   ├── README.md
│   │   └── overrides/
│   └── framework-13-pro-amd/
│       ├── README.md
│       └── overrides/
│
├── verify/
│   ├── run
│   ├── aggregate-results.mjs
│   ├── render-human-report.mjs
│   ├── render-json-report.mjs
│   └── checks/
│       ├── base/
│       ├── desktop/
│       ├── workflow/
│       ├── development/
│       ├── hardware/
│       └── power/
│
├── vm/
│   └── reference/
│       ├── README.md
│       ├── qualify-bootstrap
│       ├── reference-vm.conf
│       ├── bootstrap-documents.mjs
│       ├── guest/
│       │   └── bootstrap-checks.sh
│       └── lib/
│           ├── bootstrap-documents.mjs
│           ├── preconditions.sh
│           ├── run-resources.sh
│           ├── nocloud.sh
│           ├── launch.sh
│           ├── stop-cleanup.sh
│           ├── outcome.sh
│           └── evidence.sh
│
├── prototypes/
│   ├── README.md
│   ├── installation/
│   │   ├── README.md
│   │   ├── lib/
│   │   ├── archinstall-json-cli/
│   │   │   ├── README.md
│   │   │   ├── run
│   │   │   └── # Results: evidence/prototypes/installation/<engine>/<run-id>/
│   │   └── native-arch/
│   │       ├── README.md
│   │       ├── run
│   │       └── # Results: evidence/prototypes/installation/<engine>/<run-id>/
│   ├── storage/
│   │   ├── README.md
│   │   ├── lib/
│   │   ├── control/
│   │   ├── btrfs-rescue/
│   │   ├── btrfs-limine/
│   │   └── # Results: evidence/prototypes/storage/<variant>/<run-id>/
│   ├── frontend/
│   │   ├── README.md
│   │   ├── run
│   │   ├── lib/
│   │   └── # Results: evidence/prototypes/frontend/contract-check/<run-id>/
│   └── convergence/
│       ├── shell/
│       │   ├── README.md
│       │   ├── apply
│       │   └── results/            # Generated, ignored, and secret-scanned
│       └── ansible-local/
│           ├── README.md
│           ├── playbook.yml
│           └── results/            # Generated, ignored, and secret-scanned
│
├── tests/
│   ├── fixtures/
│   │   ├── discovery/
│   │   ├── plans/
│   │   ├── verification/
│   │   └── redaction/
│   ├── operations/
│   ├── install/
│   │   ├── discovery/
│   │   ├── plan/
│   │   ├── confirmation/
│   │   └── engine/
│   ├── capabilities/
│   ├── hardware/
│   ├── verify/
│   ├── integration/
│   │   ├── image-build/
│   │   ├── image-boot/
│   │   ├── safe-cancellation/
│   │   ├── configuration-convergence/
│   │   └── hibernation/
│   └── end-to-end/
│       ├── clean-reconstruction/
│       └── artifact-promotion/
│
├── build/                         # Generated and ignored
├── dist/                          # Generated and ignored
└── evidence/                      # Generated, ignored, and secret-scanned
```

The checked-in Archiso profile begins as an attributed copy of the complete official `releng` profile. Its internal upstream layout remains recognizable. UEFI/OVMF is the only guaranteed and validated path, but upstream BIOS/Syslinux assets may remain without creating a support commitment. MirrorOS-specific additions must remain minimal and attributable. Pure upstream profile imports are maintained on a `vendor/archiso-releng` branch and merged into main, where `UPSTREAM.md` records the source revision, package version, import date, and local-delta summary.

Directories under `build/`, `dist/`, and `evidence/` are runtime outputs and are not authoritative source. They may be absent in a clean clone.

No root `package.json` is required while JavaScript uses only Node built-ins and `.mjs` modules. If an external npm dependency becomes justified, the same change must introduce the package boundary, lockfile, provenance entry, and dependency rationale.

### Architectural Boundaries

**Image Boundary:**

`image/archiso/` owns only the live bootstrap environment:

- Boot and firmware support.
- Networking.
- Diagnostics.
- Installation entry point.
- Tools required by accepted installation and validation paths.

It does not own the complete installed desktop or personal environment. Adding a package to the image requires a live-environment reason even if the same package is installed on the target.

**Lifecycle Boundary:**

`operations/` exposes the human-facing lifecycle commands. These scripts coordinate components but do not absorb their implementation:

- `build` invokes image construction.
- `test` invokes VM validation.
- `install` coordinates discovery, planning, confirmation, and the selected engine.
- `configure` applies capability modules.
- `verify` invokes the verification system.
- `clean` removes generated local outputs without deleting accepted external recovery artifacts.

Shared lifecycle behavior enters `operations/lib/` only after multiple commands need the same stable contract.

**Installation Boundary:**

`install/` owns:

- Read-only target discovery.
- Reviewable plan generation.
- Plan validation and digest.
- Target-bound confirmation.
- Selected installation-engine adapter.

`install/engine/apply` is a stable production boundary, not a place to mix competing engines. Its implementation is populated only after the installation ADR. Production never imports from `prototypes/`.

**Capability Boundary:**

`capabilities/` is organized by stable user capability rather than current package.

Each capability may contain only the responsibility-specific material it needs:

- Package references.
- System configuration.
- User configuration.
- Visual configuration.
- External repository integration.
- Postcondition metadata.

Niri is placed below `desktop/compositor/providers/` because it is a replaceable provider, not the architectural capability itself.

**Hardware and Target Boundaries:**

- `hardware/discovery/` normalizes observed capabilities.
- `hardware/rules/` maps capabilities to applicable selections.
- `targets/reference-vm/` and `targets/framework-13-pro-amd/` contain explicit target overrides.
- Hardware rules do not modify portable capability definitions.
- Target overrides have higher precedence than detected selections and remain reviewable.

**Verification Boundary:**

`verify/` owns readiness checks, aggregation, and reporting. It never mutates desired system state.

Checks are grouped by capability domain and return the shared three-state model. Human and JSON reports derive from the same collected results.

**Inventory Boundary:**

`inventory/` links capabilities to implementation, packages, sources, dependencies, and verification checks. It does not generate or replace native Arch, systemd, application, or installer configuration.

**Prototype Boundary:**

`prototypes/` is explicitly non-production:

- Production code cannot import or source it.
- Each prototype records its question, fixed scenario, criteria, and result.
- Python project code remains forbidden in the Archinstall JSON/CLI prototype.
- Ansible is permitted only inside its convergence prototype until an ADR selects it.
- A winning approach is implemented through the stable production boundary rather than promoted by directory rename without review.

**External Repository Boundary:**

Neovim, Pi, and other independent repositories remain authoritative. Their capability modules contain explicit clone/link/configuration scripts, not copied configuration trees. Credentials remain external.

**Licensing Boundary:**

- Root project code is licensed `GPL-3.0-only`.
- Copied files retain applicable upstream notices.
- `docs/attribution.md` records source project, URL, revision, license, incorporation method, and modifications.
- Ideas may be cited without being represented as copied code.
- No agent copies source without verifying compatibility and recording attribution.

### Requirements to Structure Mapping

| Requirement group | Primary location | Supporting locations |
|---|---|---|
| FR1–FR9: lifecycle and artifacts | `operations/`, `image/`, `vm/` | `contracts/`, `evidence/`, `docs/procedures/` |
| FR10–FR19: installation planning and safety | `install/` | `contracts/`, `tests/install/`, `prototypes/installation/` |
| FR20–FR31: environment declarations | `capabilities/`, `inventory/` | `operations/configure`, external repositories |
| FR32–FR36: hardware adaptation | `hardware/`, `targets/` | `tests/hardware/`, `verify/checks/hardware/` |
| FR37–FR45: verification and reporting | `verify/`, `contracts/verification-result.schema.json` | `inventory/capabilities.json`, `evidence/` |
| FR46–FR53: diagnostics and recovery | `operations/lib/`, `evidence/` | `docs/procedures/recovery.md`, `tests/integration/` |
| FR54–FR65: evolution and maintainability | `capabilities/`, `docs/adr/` | `tests/`, external configuration repositories |

**Cross-Cutting Concerns:**

| Concern | Location |
|---|---|
| Exit statuses | `operations/lib/exit-status.sh`, `contracts/execution-result.schema.json` |
| Logging and evidence | `operations/lib/logging.sh`, `operations/lib/evidence.sh`, `evidence/` |
| Privilege boundaries | `operations/lib/privilege.sh`, stage-specific scripts |
| Secret scanning | lifecycle validation and artifact-promotion tests |
| Package provenance | `inventory/packages.json`, `inventory/external-sources.json` |
| Attribution | `docs/attribution.md` |
| Architecture decisions | `docs/adr/` |
| Agent authority rules | `AGENTS.md`, `docs/architecture.md` |
| Hibernation | `capabilities/power/hibernate/`, `tests/integration/hibernation/` |
| Hybrid graphics (not applicable to the current target, ADR 0005) | `hardware/rules/hybrid-graphics/`, target overrides, verification checks |

### Integration Points

**Internal Communication:**

```text
operations/install
  → install/discovery
  → install/plan
  → contracts/installation-plan.schema.json
  → install/confirmation
  → install/engine/apply
  → operations/configure
  → verify/run
  → contracts/verification-result.schema.json
  → evidence/<run-id>/
```

Components communicate through arguments, explicit structured files, stdout, stderr, and normalized exit statuses. No component reaches into another component's private implementation.

**External Integrations:**

- Archiso through `mkarchiso`.
- Pacman and signed Arch repositories.
- Native Arch installation commands as the selected installation engine ([ADR 0002](adr/0002-installation-engine-selection.md)), behind `install/engine/apply` once it is populated.
- Archinstall JSON/CLI only as evidence inside its non-production prototype.
- QEMU/KVM and OVMF through `vm/reference/`.
- AUR through reviewed `PKGBUILD` workflows and `yay`.
- Git hosting for explicitly declared external configuration repositories.
- CachyOS only through a future accepted ADR and isolated experiment.

**Data Flow:**

```text
Git-tracked source
→ validated native declarations and inventory
→ Archiso artifact
→ VM discovery
→ installation plan and digest
→ explicit authorization
→ installed target
→ capability convergence
→ verification results
→ retained evidence
→ known-good promotion
```

Secrets enter only at the execution boundary and do not flow into source, images, logs, reports, or retained VM state.

### File Organization Patterns

**Configuration Files:**

- Native configuration remains next to its owning capability or upstream profile.
- Target overrides live only under `targets/`.
- Hardware matching logic lives only under `hardware/`.
- Structured contracts live only under `contracts/`.
- No `.env` file is an authoritative configuration source.
- No committed directory stores secret values.

**Source Organization:**

- Lifecycle orchestration belongs in `operations/`.
- Domain implementation belongs in its owning component directory.
- Capability-specific integration stays with the capability.
- Shared helpers require multiple established callers.
- Production and prototype code never share import paths.

**Test Organization:**

- Tests mirror production ownership.
- Fixtures are immutable inputs, not mutable test workspaces.
- Integration tests exercise boundaries between components.
- End-to-end tests begin from a clean clone and fresh virtual disk.
- Generated test state goes under ignored build/evidence locations.
- A test requiring secret-like data uses documented synthetic fixtures that secret scanning explicitly recognizes as non-secret.

**Asset Organization:**

- Boot assets remain under the Archiso profile.
- Desktop visual assets remain under the owning visual/provider capability.
- Screenshots and logs produced by tests are evidence, not source assets.
- Third-party assets require provenance and license recording.

### Development Workflow Integration

**Local Development:**

- Read `AGENTS.md`, architecture, and relevant ADR before work.
- Run preflight before build or VM tests.
- Keep changes within one ownership boundary where possible.
- Update inventory, verification, tests, attribution, and documentation when the corresponding concern changes.
- Do not populate a gated production implementation before its ADR.

**Build Process:**

```text
operations/build
→ validate profile and source state
→ run static and secret checks
→ invoke mkarchiso
→ create checksum and manifests
→ write run evidence
→ place generated artifact in dist/
```

**Validation Process:**

```text
operations/test
→ verify KVM/OVMF preconditions
→ create disposable disk
→ boot installation media
→ exercise cancellation
→ install and reboot
→ configure and verify
→ reapply configuration
→ test hibernation
→ retain allowlisted evidence
```

**Recovery and Promotion:**

- `dist/` contains local generated outputs.
- Accepted known-good artifacts are copied to storage outside the disposable build tree.
- Recovery procedures identify the accepted artifact and required external backup.
- Physical installation is blocked until VM promotion and rescue preconditions pass.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**

The architecture is internally compatible:

- Archiso `releng` provides the upstream media foundation.
- Bash owns native Arch integration and bounded system operations.
- JavaScript ESM on Node.js owns non-trivial structured plans, hardware normalization, and verification aggregation.
- Python remains an upstream implementation detail unless an accepted ADR authorizes project-owned integration.
- Installation and convergence choices remain behind explicit prototype and ADR gates.
- Native formats remain authoritative while minimal JSON contracts provide cross-stage interoperability.
- UEFI, the default ext4 and systemd-boot option, a resizeable swapfile, and hibernation form a compatible target-system baseline; the Btrfs options are selectable under [ADR 0003](adr/0003-storage-and-recovery-baseline.md).
- Official Arch `linux` remains the qualification kernel while CachyOS remains an isolated experiment.

No incompatible version pins were found. Recorded versions are dated observations and build metadata, not permanent constraints.

**Pattern Consistency:**

Implementation patterns reinforce the selected decisions:

- Naming rules align with Bash and JavaScript ESM.
- Process rules preserve upstream diagnostics and normalized lifecycle outcomes.
- Data rules support atomic plans, digests, evidence, and three-state verification.
- Language authority rules prevent research references from becoming accidental technology selections.
- Prototype rules prevent Archinstall, Ansible, Python, or CachyOS candidates from leaking into production.
- Ownership rules prevent duplicate package, configuration, or verification authority.

**Structure Alignment:**

The project tree supports the architecture through explicit boundaries for Archiso media, lifecycle orchestration, installation, capability-oriented configuration, hardware adaptation, verification, evidence, non-production prototypes, mirrored tests, documentation, ADRs, attribution, and recovery. Generated outputs remain separate from authoritative source.

### Requirements Coverage Validation ✅

**Feature Coverage:**

The architecture supports the complete lifecycle:

```text
build → test → install → configure → verify
```

It also supports safe cancellation, recovery, evolution, clean reconstruction, artifact promotion, and target-laptop qualification.

**Functional Requirements Coverage:**

- FR1–FR9 are supported by `operations/`, `image/`, `vm/`, contracts, and evidence.
- FR10–FR19 are supported by installation discovery, plan generation, target-bound confirmation, engine boundaries, and cancellation tests.
- FR20–FR31 are supported by capability modules, inventory, package provenance, external configuration repositories, and convergence gates.
- FR32–FR36 are supported by hardware discovery, capability rules, and explicit target overrides.
- FR37–FR45 are supported by the verification catalog, shared result model, human and JSON reports, and retained evidence.
- FR46–FR53 are supported by stage-specific diagnostics, bounded retries, persistent evidence, recovery procedures, and independent rescue requirements.
- FR54–FR65 are supported by capability-oriented organization, replaceable providers, ADRs, tests, version history, and isolated application repositories.

All 65 functional requirements have an architectural owner.

**Non-Functional Requirements Coverage:**

- Performance is addressed through measured stage durations, a controlled matrix, and cache-independent clean reconstruction.
- Security is addressed through secret-free source, narrow privileges, target-bound authorization, package provenance, signature/checksum controls, and secret scanning.
- Reliability is addressed through VM qualification, idempotency, postcondition verification, explicit failure states, safe retries, and retained known-good artifacts.
- Portability is intentionally bounded to one reference VM and one Framework Laptop 13 Pro target.
- Maintainability is addressed through upstream-first integration, minimal profile changes, language constraints, ownership boundaries, and prototype gates.
- Operational transparency is addressed through stable exit statuses, preserved upstream diagnostics, persistent logs, and explicit artifact metadata.
- Visual and keyboard requirements have structural owners under desktop capabilities but require the MVP capability inventory to freeze their exact acceptance checks.

All 52 non-functional requirements are architecturally supported.

### Implementation Readiness Validation ✅

**Decision Completeness:**

Decisions required for the first implementation gate are complete: starter profile, build environment, language policy, licensing, source and evidence authority, privilege and security boundaries, naming and process conventions, VM qualification path, and initial kernel and storage policy.

Installation engine, convergence mechanism, and final schemas remain intentionally gated rather than accidentally unspecified.

**Structure Completeness:**

The structure identifies production boundaries, prototype boundaries, tests, evidence, generated outputs, documentation, and external integrations. Reserved schema and inventory paths establish ownership but must not be populated speculatively. Their content is produced by the corresponding prototypes with fixtures and contract tests.

**Pattern Completeness:**

Agents have explicit rules for technology authority, Bash and JavaScript selection, Python prohibition, naming, JSON and time formats, process execution, errors, validation, idempotency, retries, atomic output, secret-safe evidence, package provenance, and architectural exceptions.

### Gap Analysis Results

**Critical Gaps:** None.

**Important Gated Work:**

1. Populate `install/engine/apply` with the native Arch installation engine selected by [ADR 0002](adr/0002-installation-engine-selection.md).
2. Complete the shell versus Ansible convergence prototype and ADR.
3. Freeze the exact MVP capability inventory before broad environment implementation.
4. Define installation, execution, and verification schemas through their prototypes and contract tests.
5. Capture actual Framework Laptop 13 Pro PCI, USB, firmware, storage, and graphics topology before final hardware rules.
6. Validate swapfile hibernation and hybrid AMD/NVIDIA behavior on physical hardware.
7. Decide whether the CachyOS kernel produces sufficient measured value to justify its repository and maintenance surface.

These are implementation gates, not missing architecture decisions.

**Nice-to-Have Future Work:**

- Scheduled current-package CI.
- Historical package-state reconstruction.
- Secure Boot and TPM.
- Optional drift detection.
- Additional hardware profiles.
- Unified CLI if repeated use proves its value.
- Chaotic-AUR only if local build cost demonstrates a need.

### Validation Issues Addressed

**Language ambiguity:** The broad technology preference was replaced with an explicit Bash-first, JavaScript-for-structured-data policy. Python remains an upstream runtime unless an accepted ADR authorizes project-owned integration. Node.js is included in the live or installed environment wherever accepted plan processing, hardware normalization, or verification components execute.

**Archiso update strategy:**

- The project retains the complete upstream `releng` profile unless removing a component has demonstrated value.
- UEFI/OVMF is the only guaranteed and validated boot path.
- Upstream BIOS/Syslinux assets may remain without creating a support promise.
- MirrorOS does not customize or test BIOS in the MVP.
- A `vendor/archiso-releng` branch receives pure upstream profile imports.
- Main contains the minimal MirrorOS delta.
- `image/archiso/UPSTREAM.md` records repository, revision, package version, import date, and local-delta summary.
- `docs/procedures/update-archiso.md` defines import, merge, conflict review, build, boot qualification, and attribution updates.
- Archiso tool and profile updates are validated together.

**Prototype evidence:** Raw prototype results are generated, ignored, and secret-scanned. Stable conclusions belong in prototype `README.md` files and accepted ADRs.

**Reserved contracts:** Paths under `contracts/` and `inventory/` are ownership reservations. Agents must not invent final schemas before the associated prototype. Initial schema work includes fixtures and contract tests.

**Local documentation tooling:** `docs/.obsidian/` is local editor configuration outside the MirrorOS runtime. It is ignored by Git, is not authoritative source, and agents must not remove or reorganize it as unrelated cleanup.

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed.
- [x] Scale and complexity assessed.
- [x] Technical constraints identified.
- [x] Cross-cutting concerns mapped.
- [x] All FR and NFR categories assigned architectural owners.

**✅ Architectural Decisions**

- [x] First-gate critical decisions documented.
- [x] Technology selections and prototype gates distinguished.
- [x] Integration patterns defined.
- [x] Performance and recovery considerations addressed.
- [x] Security and licensing posture documented.
- [x] Upstream update strategy defined.

**✅ Implementation Patterns**

- [x] Naming conventions established.
- [x] Language authority and selection rules defined.
- [x] Structure patterns defined.
- [x] Communication patterns specified.
- [x] Error, retry, validation, and idempotency patterns documented.
- [x] Good examples and anti-patterns provided.

**✅ Project Structure**

- [x] Complete target directory structure defined.
- [x] Component and prototype boundaries established.
- [x] Integration points mapped.
- [x] Requirements-to-structure mapping complete.
- [x] Generated, external, and tool-managed content distinguished.

### Architecture Readiness Assessment

**Overall Status:** READY FOR GATED IMPLEMENTATION

**Confidence Level:** High for architectural boundaries, first-gate implementation, and agent consistency; medium for prototype-gated mechanisms until their evidence and ADRs exist.

**Key Strengths:**

- Strong normative authority prevents research from becoming accidental architecture.
- Upstream-first profile management minimizes long-term Archiso maintenance.
- Production and prototype code are physically separated.
- Destructive operations have explicit plan and authorization boundaries.
- Verification, provenance, evidence, recovery, and hibernation are foundational rather than deferred concerns.
- Capability-oriented structure keeps Niri, kernels, installers, and configuration tools replaceable.
- Language choices are explicit and enforceable.
- Scope remains sustainable for one maintainer.

**Areas for Future Enhancement:**

- Exact capability inventory and keyboard-action catalog.
- Selected installation and convergence engines.
- Final contract schemas.
- Physical hardware facts and qualification evidence.
- Known-good package-retention mechanism.
- Automated current-package canaries.

### Implementation Handoff

**AI Agent Guidelines:**

- Treat `docs/architecture.md` and accepted ADRs as normative.
- Treat research as evidence only.
- Follow implementation patterns and ownership boundaries exactly.
- Never resolve a gated decision inside unrelated work.
- Do not add project-owned Python without an accepted ADR and architecture update.
- Preserve the full upstream diagnostic context.
- Update tests, verification, provenance, attribution, and documentation with the implementation they govern.
- Do not remove workflow-managed repository metadata.

**First Implementation Priority:**

1. Create repository governance files: `LICENSE`, `AGENTS.md`, `.gitignore`, `.shellcheckrc`, attribution, ADR template, and Archiso update procedure.
2. Import the current official `releng` profile through the vendor branch.
3. Record upstream identity in `image/archiso/UPSTREAM.md`.
4. Merge the profile into main without functional customization.
5. Build with the documented `mkarchiso` command.
6. Boot with QEMU/KVM and OVMF.
7. Verify networking, artifact checksum, package manifest, source identity, and persistent evidence.

No installation engine, convergence framework, desktop environment, or kernel experiment enters this first implementation gate.
