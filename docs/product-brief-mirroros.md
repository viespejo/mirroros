---
title: "Product Brief: MirrorOS"
status: "complete"
created: "2026-09-23T23:44:11+02:00"
updated: "2026-09-24T00:17:00+02:00"
inputs:
  - "docs/brainstorming/brainstorming-session-2026-09-23-201236.md"
---

# Product Brief: MirrorOS

## Executive Summary

An experienced Linux user's operating environment is the product of years of accumulated decisions: packages, services, shell behavior, keyboard shortcuts, desktop conventions, and tool configuration. Yet much of that value remains trapped in the current machine. Replacing a laptop or recovering from failure means reconstructing the environment from incomplete dotfiles, memory, and undocumented steps. The result may be technically functional while still failing to restore the workflow that made the machine productive.

MirrorOS is a personal, reproducible, and evolving Arch Linux environment. It makes the user's working system reviewable, rebuildable, and portable without turning it into a general-purpose distribution. A thin Archiso image provides a minimal bootstrap; a guided installation applies visible, editable personal defaults; and an independent, version-controlled configuration layer converges the installed system toward the intended working state. The durable asset is not the ISO—it is the executable definition of the environment.

The opportunity is to combine Arch's composability with disciplined reconstruction. Existing projects demonstrate the individual ingredients: Archiso builds official live and installation media; Archinstall supports guided and declarative installation; and distributions such as Omarchy, CachyOS, and EndeavourOS demonstrate polished defaults at the cost of broader product and maintenance scope. MirrorOS deliberately takes the smaller path: reuse upstream tools, automate only demonstrated needs, and validate every layer in disposable virtual machines before touching real hardware.

## The Problem

Personal Linux systems evolve continuously, but their reproducibility usually does not. Dotfiles capture only part of the state. Package choices, enabled services, privileged changes, hardware adaptations, desktop dependencies, and the order in which they were applied often remain implicit. Over time, the current laptop becomes the only complete copy of the operating environment.

This creates three recurring costs:

- **Migration is uncertain:** moving to a new laptop becomes a manual reconstruction project with forgotten steps and hidden dependencies.
- **Recovery is unverified:** having an ISO or backup does not prove that a clean machine can return to a usable state.
- **Customization creates maintenance debt:** tightly coupled scripts and fixed desktop assumptions make future tool changes harder, especially across X11, Wayland, compositor, and application transitions.

Generic Arch installation leaves most workflow reconstruction to the user. Opinionated distributions solve a broader onboarding problem but introduce choices, branding, repositories, installers, and release obligations that do not match a one-user product. A monolithic custom image would capture today's environment while making tomorrow's changes expensive.

## The Product

MirrorOS reconstructs a complete working capability—not personal content—through three independent layers:

1. **Thin bootstrap ISO:** boots reliably, provides networking and the minimum tools required to inspect the machine and begin installation.
2. **Guided installation policy:** detects hardware capabilities, preloads recurring personal defaults, and presents a plan before execution. Interaction is reserved for destructive, ambiguous, secret, or difficult-to-reverse choices.
3. **Versioned personal environment:** applies packages, services, dotfiles, keyboard-first desktop behavior, and current application choices independently of the ISO. It can be reapplied to converge the system without evident duplication or damage.

The target experience is a transparent journey from blank machine to ready-to-use environment. Defaults explain whether they come from personal preference, hardware detection, Arch guidance, or technical necessity. The intended journey completes installation and personal configuration before the first reboot, so the first graphical login opens into a quiet, coherent, terminal-centric environment rather than a second installation or onboarding flow.

## Product Principles and Differentiation

- **Configuration is the product; the ISO is replaceable.** Fast-changing workflow choices do not require rebuilding the installation medium.
- **Explicit control and automation coexist.** MirrorOS removes repeated decisions without hiding consequential ones.
- **Replaceability is a requirement.** Niri is the initial compositor experiment, not an architectural commitment; desktop components and workflow modules remain separable.
- **Capabilities are reproduced, content is not.** Browsers, Git, SSH, secret managers, and backup tools may be configured, but accounts, keys, repositories, credentials, sessions, and personal data remain external.
- **Upstream first, custom code last.** The implementation preference is supported configuration, existing profiles, small scripts, wrappers, and only then custom applications.
- **Recovery outranks perfection.** Known-good artifacts, diagnostics, rollback paths, and repeatable tests matter more than promising failure-free rolling updates.

Unlike a public distribution, MirrorOS does not need a market-facing identity, broad hardware promise, installer fork, package repository, welcome application, or community release process. Its advantage is precise alignment with one user's workflow and the ability to evolve that workflow without redesigning the system.

## Primary User and Core Use Case

The initial and only required user is an experienced Arch/Linux user who values keyboard-first operation, terminal-centric workflows, visible system behavior, and freedom to replace components. The defining scenario is a laptop migration or recovery: starting from a clean machine, the user can inspect the proposed plan, approve consequential choices, and regain the declared working environment with no undocumented steps.

The product's “aha” moment occurs when a disposable VM—or eventually a new laptop—reaches the expected ready state from the repository alone, and reports clearly which capabilities were restored and which external dependencies remain unresolved.

## First-Version Scope

**In scope**

- A reproducible minimal Archiso profile that boots in QEMU with networking.
- A guided Arch installation using visible, editable personal defaults, evaluating Archinstall as the maintained engine.
- Separation between public configuration, hardware-derived choices, privileged system changes, secret references, and private state.
- Modular, repeatable configuration for packages, services, dotfiles, terminal, shell, editor, desktop, shortcuts, and essential applications.
- Niri as the provisional desktop default, with compositor-specific configuration isolated.
- Automated verification of declared capabilities and actionable reporting of failures.
- Documented build, boot, installation, configuration, validation, cleanup, and recovery operations.

**Out of scope**

- Personal file backup, repository restoration, credential storage, or session restoration.
- Project-level orchestration already owned by Tmux, Neovim, agents, browsers, or other tools.
- A custom installer, control panel, welcome app, package repository, or background management service without a demonstrated recurring need.
- Public-distribution requirements such as broad user support, branding, release marketing, or comprehensive hardware coverage.

## Validation and Success Criteria

MirrorOS succeeds when reconstruction is observable rather than assumed. Development follows five gated milestones:

1. **Minimal ISO:** a fresh clone builds an image that boots in QEMU with working networking.
2. **Guided installation:** the VM installs Arch using visible and editable defaults, with consequential choices requiring confirmation.
3. **Personal configuration:** the environment configuration can be applied and reapplied without evident damage or duplicate state.
4. **End-to-end VM:** a clean VM becomes a verified, ready-to-use environment with no undocumented manual steps.
5. **Laptop fire test:** the complete journey succeeds on real hardware only after the VM path passes and a recovery path is available.

Operational pass conditions include a successful build from a fresh clone; zero undocumented steps in the clean-VM journey; a second configuration run that produces no unintended changes; zero secrets or personal content in version control and generated images; recorded provenance for every installed package source; and post-run verification that identifies every unresolved declared capability. Scheduled canary builds expose upstream breakage, while restoration time and maintenance effort are tracked across repeated disposable reconstructions. The project remains healthy only if its ongoing maintenance cost is lower than the migration and recovery effort it replaces.

## Technical Direction and Risks

The initial hypothesis is Archiso for the minimal medium, Archinstall for guided/declarative base installation, and a separate idempotent configuration process for the personal environment. Archinstall's separation of general configuration and credentials supports the desired trust boundary, but integration must be proven rather than assumed.

The primary risks are upstream Arch, Archiso, and Archinstall changes; incomplete idempotency; hardware behavior that QEMU cannot represent; accidental coupling between desktop modules; package provenance risk, especially outside official repositories; and automation whose maintenance exceeds its value. Mitigations include scheduled builds, VM smoke tests, retained known-good artifacts and verification metadata, explicit dependency and provenance inventories, small privilege boundaries, technical decision records, disposable prototypes, and a strict complexity budget.

## Vision

Within two to three years, MirrorOS should function as a living, tested record of the user's operating environment: capable of rebuilding a new machine, detecting drift, adapting to changed hardware, and absorbing new desktop or workflow preferences while version history preserves the rationale and path of that evolution. Its success is not measured by downloads or feature count. It is measured by continuity—the confidence that the environment can evolve for years without remaining trapped in any single laptop, ISO, compositor, or moment in time.

## Sources Consulted — Initial Scan

These sources informed the initial product framing only. The structured comparative research and repository-level analysis defined in the roadmap remain future work and must precede final architecture decisions.

- [Archiso](https://wiki.archlinux.org/title/Archiso)
- [Archinstall documentation](https://archinstall.archlinux.page/)
- [Archinstall repository](https://github.com/archlinux/archinstall)
- [Omarchy](https://github.com/omacom/omarchy)
- [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO)
- [EndeavourOS ISO](https://github.com/endeavouros-team/EndeavourOS-ISO)
