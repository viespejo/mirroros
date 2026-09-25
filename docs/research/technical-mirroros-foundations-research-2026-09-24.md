---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - "docs/prd.md"
  - "docs/product-brief-mirroros.md"
  - "docs/brainstorming/brainstorming-session-2026-09-23-201236.md"
workflowType: 'research'
lastStep: 6
status: 'complete'
completedAt: '2026-09-24'
research_type: 'technical'
research_topic: 'Technical foundations for MirrorOS: comparative analysis of Archiso, Archinstall, Omarchy, CachyOS, and EndeavourOS'
research_goals: 'Compare image construction, installation, configuration, architecture boundaries, extensibility, privileges, reproducibility, testing, and maintenance; derive an evidence log, comparison matrix, adopt/avoid catalog, external dependency map, candidate minimal architecture, and validation prototype.'
user_name: 'SHEAF'
date: '2026-09-24'
web_research_enabled: true
source_verification: true
---

# Evidence-Gated Foundations for MirrorOS: Comprehensive Technical Research

**Date:** 2026-09-24
**Author:** SHEAF
**Research Type:** Technical

> **Decision Authority Notice**
>
> This document is evidence, not an implementation specification. Technology
> references describe upstream mechanisms and prototype candidates. Current
> selections and permissions are defined only by `docs/architecture.md` and
> accepted ADRs. In particular, references to Archinstall's Python
> implementation do not authorize project-owned Python code.

---

## Research Overview

This report evaluates the technical foundations for MirrorOS, a personal Arch Linux distribution designed to reconstruct a verified working environment from a blank supported device. Research covered Archiso, Archinstall, Omarchy, CachyOS, EndeavourOS, native Arch installation interfaces, configuration-management alternatives, package provenance, secret handling, virtualization, testing, and artifact operations.

The evidence supports a repository-centered, staged architecture built around official Arch mechanisms. Archiso is the strongest image-building foundation; Archinstall remains a promising but unselected installation engine; configuration tooling must be chosen through a bounded shell-versus-Ansible spike; and user dotfile tooling should remain separate from system convergence. The complete conclusions, decision status, comparison matrix, dependency map, and validation prototype are consolidated in the Research Synthesis section.

Research used current public sources available on 2026-09-24, prioritizing official documentation, source repositories, package metadata, manuals, CI definitions, and selected issue evidence. Directly documented mechanisms receive high confidence; suitability judgments and untested MirrorOS-specific hypotheses receive medium confidence until validated through prototypes.

## Executive Summary

MirrorOS should not begin as a new Linux distribution framework. It should begin as a small, evidence-driven composition of official Arch tools with explicit boundaries between media construction, installation policy, hardware adaptation, system configuration, user configuration, verification, and recovery.

Archiso provides the appropriate profile-to-artifact foundation. Archinstall offers maintained installation semantics through JSON, CLI, Python profiles, and plugins, but only its documented JSON/CLI boundary should be tested initially. Omarchy contributes useful separation and acceptance-testing patterns. CachyOS demonstrates capability-based hardware profiles and installation matrices. EndeavourOS demonstrates both online and offline installation strategies. The downstream projects also reveal the maintenance costs MirrorOS should avoid: installer forks, custom repositories, broad hardware matrices, migration systems, hotfix channels, and public-distribution release machinery.

No evidence supports selecting a custom CLI, proprietary configuration language, database, cloud control plane, Calamares fork, Nix/Home Manager, or custom package repository for the MVP. The immediate engineering work is a sequence of decision prototypes: minimal Archiso, Archinstall versus native Arch installation, shell versus Ansible convergence, user-dotfile evaluation, capability verification, and an end-to-end disposable VM reconstruction.

**Key Findings:**

- The ISO is a derived bootstrap artifact; the version-controlled environment definition is the durable product.
- The dominant architecture is a synchronous local pipeline with explicit files, commands, exit outcomes, logs, and target-root boundaries.
- Installation safety requires discover–plan–confirm–apply–verify semantics.
- Current-package canaries and known-good recovery artifacts solve different problems and should remain distinct.
- Hardware, privileged system state, user state, secrets, and visual customization require separate ownership.
- End-to-end VM installation and capability verification are necessary; successful image construction or boot alone is insufficient.
- Tool selection remains intentionally unresolved where prototypes can provide better evidence.

**Strategic Recommendations:**

1. Build the smallest viable Archiso profile using official conventions.
2. Compare Archinstall JSON/CLI with a native Arch-command baseline.
3. Compare minimal shell modules with Ansible local mode on one representative capability.
4. Keep dotfile management independent from system convergence.
5. Establish package provenance, secret scanning, artifact metadata, and three-state capability verification before broad personalization.
6. Reject distribution-scale machinery until repeated evidence demonstrates a need.

## Table of Contents

1. Research Overview
2. Executive Summary
3. Technical Research Scope Confirmation
4. Technology Stack Analysis
5. Integration Patterns Analysis
6. Architectural Patterns and Design
7. Implementation Approaches and Technology Adoption
8. Technical Research Recommendations
9. Research Synthesis
   - Comparative Project Matrix
   - Adopt and Avoid Pattern Catalog
   - External Dependency Map
   - Architectural Decision Status
   - Candidate Minimal Architecture
   - Validation Prototype
   - Future Technical Outlook
   - Methodology and Source Verification
   - Limitations and Open Questions
   - Final Conclusion

## Technical Research Scope Confirmation

**Research Topic:** Technical foundations for MirrorOS: comparative analysis of Archiso, Archinstall, Omarchy, CachyOS, and EndeavourOS
**Research Goals:** Compare image construction, installation, configuration, architecture boundaries, extensibility, privileges, reproducibility, testing, and maintenance; derive an evidence log, comparison matrix, adopt/avoid catalog, external dependency map, candidate minimal architecture, and validation prototype.

**Technical Research Scope:**

- Architecture Analysis - design patterns, frameworks, system architecture
- Implementation Approaches - development methodologies, coding patterns
- Technology Stack - languages, frameworks, tools, platforms
- Integration Patterns - APIs, protocols, interoperability
- Performance Considerations - scalability, optimization, patterns

**Research Methodology:**

- Current web data with rigorous source verification
- Multi-source validation for critical technical claims
- Confidence level framework for uncertain information
- Comprehensive technical coverage with architecture-specific insights

**Scope Confirmed:** 2026-09-24

---

## Technology Stack Analysis

_Research cutoff: 2026-09-24. Package and project versions are point-in-time observations in rolling ecosystems and must not be treated as durable architecture constraints._

### Programming Languages

The compared projects use languages according to lifecycle responsibility rather than converging on one application stack.

| Project or layer | Principal languages and formats | Architectural role | Evidence-based relevance to MirrorOS |
|---|---|---|---|
| Archiso | Bash/shell, shell profile definitions, package lists, bootloader configuration | Build live/install media and bootstrap artifacts | Highest relevance for the minimal image; it exposes native Arch mechanisms without imposing an application framework |
| Archinstall | Python, JSON configuration, JSON Schema | Guided installation, reusable installation library, profiles, plugins, and scripts | High relevance if its configuration and extension boundaries can satisfy plan review, confirmation, and diagnostic requirements |
| Omarchy | Predominantly Bash/shell for runtime and target-side leaves; Arch package metadata and repository automation | Opinionated end-user environment, installation finalization, migrations, settings, and package publication | Useful as a pattern source for staged system/hardware/user responsibilities, but its product scope is broader than MirrorOS |
| CachyOS Live ISO | Shell around Archiso; Calamares configuration and modules | Distribution image construction and graphical installation | Useful for build/test patterns, but brings a public-distribution installer and repository surface outside MirrorOS MVP needs |
| CachyOS CHWD | Rust with TOML hardware profiles and shell lifecycle hooks | Hardware detection and driver profile application | Useful evidence for capability/profile-based hardware adaptation; adopting its implementation is a separate decision |
| EndeavourOS | Modified Archiso shell framework plus a Calamares fork | Live image and online/offline graphical installation | Useful comparison for integration cost and distribution-scale customization |
| Calamares | C++/Qt and QML for core/UI modules; Python for non-UI jobs | Distribution-independent graphical installer framework | Technically capable but substantially larger than a thin, one-user guided installation policy |

Archiso's official profile model centers on `profiledef.sh`, architecture-specific package lists such as `packages.x86_64`, and an optional `airootfs/` overlay. Its repository ships `baseline` and `releng` profiles, with `releng` providing the basis of the official Arch installation medium. The official Arch package observed during research was `archiso` 90-1. Sources: [Archiso package](https://archlinux.org/packages/extra/any/archiso/), [Archiso profile documentation](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst), [Archiso repository](https://github.com/archlinux/archiso).

Archinstall is explicitly usable as a Python library, supports Python scripts and plugins, and accepts JSON configuration for guided installation. Its official package observed during research was `archinstall` 4.4-1. Sources: [Archinstall package](https://archlinux.org/packages/extra/any/archinstall/), [guided installation documentation](https://archinstall.archlinux.page/installing/guided.html), [Python module documentation](https://archinstall.archlinux.page/examples/python.html), [plugin documentation](https://archinstall.archlinux.page/archinstall/plugins.html), [source repository](https://github.com/archlinux/archinstall).

**Assessment:** Shell is the native integration language across image construction and distribution glue; Python becomes the primary language only if MirrorOS extends or embeds Archinstall; Rust appears in CachyOS for a specialized hardware subsystem rather than as a general distribution requirement. No evidence supports choosing a compiled custom CLI language before a demonstrated gap exists.

_Confidence: High for Archiso and Archinstall; medium-high for cross-project language-role comparisons._

### Development Frameworks and Libraries

This domain does not use a conventional application framework. The relevant frameworks are lifecycle engines and extension models:

- **Archiso profile framework:** `mkarchiso` consumes a profile directory containing metadata, package declarations, filesystem overlays, and bootloader configuration. This is the smallest official foundation among the candidates. [ArchWiki](https://wiki.archlinux.org/title/Archiso), [`mkarchiso(1)`](https://man.archlinux.org/man/mkarchiso.1.en).
- **Archinstall library and guided UI:** Archinstall provides a reusable Python installation library, guided menu flow, serializable configuration, profiles, scripts, and plugin hooks. This offers more installation semantics than raw Arch commands but couples extensions to a changing Python API and schema. [Archinstall documentation](https://archinstall.archlinux.page/), [schema](https://github.com/archlinux/archinstall/blob/master/schema.json), [profile base class](https://github.com/archlinux/archinstall/blob/master/archinstall/default_profiles/profile.py).
- **Calamares framework:** Calamares provides a full graphical installer architecture with C++/Qt view modules, QML support, and Python job modules. CachyOS and EndeavourOS maintain customized integrations or forks. This demonstrates breadth but also a larger extension, packaging, UI, and testing burden. [Calamares module architecture](https://github.com/calamares/calamares/blob/calamares/src/modules/README.md), [CachyOS Calamares](https://github.com/CachyOS/cachyos-calamares), [EndeavourOS development repositories](https://github.com/endeavouros-team).
- **Omarchy staged shell conventions:** Current Omarchy documentation separates ISO ownership from target-side system, hardware, login, post-install, and per-user finalization leaves. It is a repository convention rather than a general framework. [Omarchy file layout](https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md), [installation script conventions](https://github.com/omacom/omarchy/blob/quattro/agents/skills/install-scripts.md).
- **CHWD profile engine:** CHWD matches detected PCI hardware to TOML driver profiles and associated packages/hooks. It is a specialized capability engine, not a general configuration manager. [CHWD repository](https://github.com/CachyOS/chwd), [graphics profiles](https://github.com/CachyOS/chwd/blob/master/profiles/pci/graphic_drivers/profiles.toml).

**Assessment:** The ecosystem favors composition of native tools and narrowly scoped engines. For MirrorOS, the research hypothesis to test is an Archiso profile plus either declarative Archinstall use or a thin installation-policy layer—not a general application framework or a Calamares fork.

_Confidence: High for framework capabilities; medium for MirrorOS suitability pending prototype results._

### Database and Storage Technologies

No compared system requires an application database, NoSQL store, in-memory database, or data warehouse. State is intentionally file- and artifact-oriented:

- Package intent is represented by package lists, Arch package metadata, or installer configuration.
- Archinstall uses JSON configuration and JSON Schema; sensitive configuration has separate handling and must be assessed carefully because installation artifacts and logs can contain sensitive disk or credential information. [guided configuration](https://archinstall.archlinux.page/installing/guided.html), [bug-report guidance](https://archinstall.archlinux.page/help/report_bug.html).
- CHWD uses TOML profiles for hardware matching and package/hook declarations. [CHWD profiles](https://github.com/CachyOS/chwd/tree/master/profiles).
- Live roots and installation artifacts use ordinary filesystems, SquashFS images, ISO files, package caches/repositories, checksums, signatures, and logs.
- Git is the durable history and review mechanism for project declarations; generated images and logs are operational artifacts, not authoritative configuration state.

**MirrorOS implication:** Introducing a database would conflict with the current requirements unless a future measured need cannot be met by versioned text declarations and append-only evidence artifacts.

_Confidence: High._

### Development Tools and Platforms

**Build systems and package tooling**

- Archiso uses `mkarchiso`, pacman repositories/configuration, SquashFS tooling, initramfs integration, and bootloader-specific assets. The official package includes `baseline` and `releng` profile material. [Archiso package files](https://archlinux.org/packages/extra/any/archiso/files/).
- CachyOS wraps Archiso with `buildiso.sh`/`util-iso.sh`, generates checksums and signatures, and maintains separate Calamares and hardware tooling. [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), [build documentation](https://github.com/CachyOS/CachyOS-Live-ISO/blob/master/README.md).
- EndeavourOS uses a heavily modified Archiso framework with `prepare.sh` and a repository-local `mkarchiso`; related installer and package recipes are maintained separately. [EndeavourOS ISO](https://github.com/endeavouros-team/EndeavourOS-ISO), [development map](https://github.com/endeavouros-team/EndeavourOS-Development).
- Omarchy separates its ISO repository, runtime/settings source, and package build/publication repository. Its ISO repository tracks Archiso and wraps image creation/release through repository scripts. [Omarchy ISO](https://github.com/omacom/omarchy-iso), [Omarchy packages](https://github.com/omacom/omarchy-pkgs).

**Testing and quality tools**

- Archiso includes GitLab CI configuration, ShellCheck configuration, QEMU-oriented testing dependencies, and Make targets. [Archiso repository](https://github.com/archlinux/archiso), [Archiso CI](https://github.com/archlinux/archiso/blob/master/.gitlab-ci.yml).
- Archinstall maintains `tests/`, `test_tooling/`, lint/type configuration, examples, and schema validation material in its source repository. [Archinstall repository](https://github.com/archlinux/archinstall).
- Omarchy uses shell syntax checks, ShellCheck, shell/CLI tests, and disposable-VM acceptance testing conventions. [Omarchy testing guidance](https://github.com/omacom/omarchy/blob/quattro/docs/testing.md), [repository guidance](https://github.com/omacom/omarchy/blob/quattro/AGENTS.md).
- CachyOS CI builds an ISO in an Arch container and exercises Calamares installations in QEMU across a bootloader/filesystem matrix, preserving result artifacts. [CachyOS build workflow](https://github.com/CachyOS/CachyOS-Live-ISO/blob/master/.github/workflows/build.yml).
- The public EndeavourOS ISO repository documents local builds; the visible GitHub workflow primarily synchronizes the repository rather than demonstrating an equivalent public install-test matrix. [EndeavourOS ISO actions](https://github.com/endeavouros-team/EndeavourOS-ISO/actions), [build instructions](https://github.com/endeavouros-team/EndeavourOS-ISO/blob/main/README.md).

**Runtime and validation platforms**

The build host is expected to be Arch-compatible. QEMU/KVM is the dominant disposable validation platform in the evidence reviewed; OVMF is relevant for UEFI testing. Physical hardware remains necessary for final driver, firmware, power, display, input, and networking validation.

_Confidence: High for repository-visible tooling; medium where absence of public CI does not prove absence of private testing._

### Cloud Infrastructure and Deployment

MirrorOS and the compared installation stacks are not cloud-hosted runtime services. Conventional cloud-provider, Kubernetes, serverless, CDN, and edge architecture choices are not applicable to the product runtime.

Hosted infrastructure is relevant only to the software supply and evidence pipeline:

- GitHub or GitLab hosts source, issues, CI, and release metadata.
- CI runners may build packages or images in containers or privileged Arch environments.
- Package repositories and mirrors distribute packages and repository metadata.
- Release storage distributes ISOs, checksums, signatures, and retained known-good artifacts.

CachyOS demonstrates containerized CI image construction followed by QEMU installation tests. Omarchy demonstrates separate package publication and ISO release tooling. These are patterns to evaluate for later canaries, not justification for adding a cloud control plane to the MVP.

_Confidence: High._

### Technology Adoption Trends

Several ecosystem patterns recur across the projects:

1. **Official Arch mechanisms remain the foundation.** Even highly customized distributions retain Archiso concepts, pacman packages/repositories, filesystem overlays, and standard boot tooling. [Archiso](https://github.com/archlinux/archiso), [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), [EndeavourOS ISO](https://github.com/endeavouros-team/EndeavourOS-ISO).
2. **Installer complexity grows rapidly with audience breadth.** Archinstall supplies guided/declarative semantics in Python; CachyOS and EndeavourOS maintain Calamares integration and distribution-specific modules; Omarchy now maintains distinct ISO, runtime/settings, package, and release surfaces. This is direct evidence that broad polish carries recurring integration cost.
3. **Configuration formats are plural and responsibility-specific.** Shell/profile files, package lists, JSON/Schema, TOML hardware profiles, YAML CI definitions, and package recipes coexist. A new universal MirrorOS format would add translation work rather than remove ecosystem complexity.
4. **Virtualized installation testing is a mature pattern.** Archiso references QEMU testing, Omarchy separates disposable-VM acceptance tests from fast shell tests, and CachyOS runs installation matrices under QEMU. MirrorOS can adopt the layered testing pattern while keeping its target matrix much smaller.
5. **Hardware adaptation is increasingly isolated.** CachyOS separates CHWD and profile data from the installer; Omarchy identifies a distinct hardware application stage. This supports MirrorOS's requirement to keep hardware-derived configuration separate from portable workflow configuration.
6. **Rolling versions reinforce metadata over pinning assumptions.** At the research cutoff, official packages reported Archiso 90-1 and Archinstall 4.4-1, while active downstream projects maintained their own release channels and wrappers. MirrorOS must record actual package/tool versions per artifact rather than embedding research-time versions into architecture.

**Technology-stack conclusion:** The strongest evidence supports beginning experiments from official Archiso profile conventions and evaluating Archinstall through configuration-first prototypes. Omarchy provides useful staging and separation patterns. CachyOS provides strong examples of hardware profiles and VM installation matrices. CachyOS and EndeavourOS also demonstrate the maintenance surface MirrorOS should avoid inheriting without a proven need: graphical-installer forks, broad hardware matrices, custom repositories, and public-distribution release machinery.

_Overall confidence: High for directly documented mechanisms; medium for comparative maintenance conclusions, which are architectural interpretations to validate during deeper repository analysis._

---

## Integration Patterns Analysis

### API Design Patterns

MirrorOS does not require a network API. Its relevant APIs are local process, configuration, and optional library interfaces.

**Command-line contracts.** Native Arch installation is already decomposed into commands with explicit inputs and process outcomes: `pacstrap` populates a target root, `genfstab` derives filesystem mount declarations, and `arch-chroot` executes commands against the installed target while arranging required API filesystems and resolver access. These commands form stable point-to-point interoperability boundaries without requiring an application server. Sources: [`pacstrap(8)`](https://man.archlinux.org/man/pacstrap.8), [`genfstab(8)`](https://man.archlinux.org/man/genfstab.8), [`arch-chroot(8)`](https://man.archlinux.org/man/arch-chroot.8), [arch-install-scripts package](https://archlinux.org/packages/extra/any/arch-install-scripts/).

**Configuration-driven interface.** Archinstall accepts a general JSON configuration and separately handled credential material, supports post-install custom commands in the target root, and provides dry-run configuration generation. This is the least coupled Archinstall integration surface because it uses documented CLI and data contracts rather than importing internals. Sources: [guided installation](https://archinstall.archlinux.page/installing/guided.html), [custom commands](https://archinstall.archlinux.page/cli_parameters/config/custom_commands.html), [source README](https://github.com/archlinux/archinstall).

**Python library and plugin interface.** Archinstall also exposes `Installer`, custom scripts, profiles, and plugin hooks. This surface is more powerful but more tightly coupled to Archinstall's Python objects and hook lifecycle. Open issues around `arch-chroot` behavior and implementation-level hooks demonstrate why any plugin/library integration must be tested against the exact packaged version. Sources: [Installer API](https://archinstall.archlinux.page/archinstall/Installer.html), [plugins](https://archinstall.archlinux.page/archinstall/plugins.html), [`installer.py`](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/installer.py), [arch-chroot issue #4008](https://github.com/archlinux/archinstall/issues/4008).

**Remote API styles.** REST, GraphQL, gRPC, webhooks, and RPC services are not present in the required reconstruction path. HTTPS endpoints may distribute source, packages, metadata, or artifacts, but they are external supply dependencies rather than a MirrorOS product API.

**Integration preference to validate:** documented CLI/configuration boundaries first; version-sensitive Python embedding only when a prototype proves that declarative configuration cannot satisfy plan visibility, safety, or diagnostics.

_Confidence: High for available interfaces; medium for preferred boundary pending prototype evidence._

### Communication Protocols

The dominant communication mechanisms are local and synchronous:

- **Process invocation:** arguments, environment variables, standard input/output/error, and exit status connect lifecycle stages and upstream commands.
- **Target-root transition:** `arch-chroot` is the principal boundary between the live environment and installed system. CachyOS demonstrates this explicitly by invoking `chwd --autoconfigure` inside the target root from a Calamares module and treating nonzero child status as failure. Sources: [CachyOS CHWD module](https://github.com/CachyOS/cachyos-calamares/blob/cachyos/src/modules/chwd/main.py), [Calamares sequence](https://github.com/CachyOS/cachyos-calamares/blob/cachyos/settings.conf).
- **Filesystem handoff:** mounted target roots, configuration files, package lists, logs, completion markers, and generated artifacts carry state between stages.
- **Package protocol:** pacman/libalpm consumes repository databases and signed package artifacts according to `pacman.conf`; repository ordering and signature policy are operationally significant. Sources: [`pacman.conf(5)`](https://man.archlinux.org/man/pacman.conf.5), [`pacman(8)`](https://man.archlinux.org/man/pacman.8).
- **HTTPS/Git transport:** source repositories, mirrors, and external artifacts are retrieved over network transports. These dependencies must be recorded, verified, and allowed to fail visibly.
- **Virtual machine control:** QEMU process invocation, virtual disks, firmware, serial/console output, and result files form the test-harness boundary.

WebSockets, AMQP, MQTT, gRPC, Protocol Buffers, and persistent messaging are not used by the compared installation paths and have no demonstrated MirrorOS requirement.

_Confidence: High._

### Data Formats and Standards

MirrorOS must interoperate with multiple upstream-native formats instead of inventing one universal schema:

| Format | Current role | Integration implication |
|---|---|---|
| Shell/profile files | Archiso metadata, build glue, downstream installation stages | Keep shell boundaries narrow, linted, and explicit about privilege and failure behavior |
| Plain package lists | Archiso live-image package selection | Preserve package source/provenance separately where a name alone is insufficient |
| JSON and JSON Schema | Archinstall configuration and validation | Candidate installation-plan interchange, but schema compatibility must be checked against the packaged version |
| Separate credential JSON | Archinstall secret-bearing inputs | Must never enter Git, image layers, terminal output, retained logs, or ordinary evidence artifacts |
| TOML | CHWD hardware profiles | Evidence that hardware matching can be data-driven without coupling to the portable environment model |
| INI-like pacman/ALPM configuration | Repositories, signatures, transaction hooks | Repository order, trust policy, and hooks become part of artifact provenance |
| YAML | CI workflows and some automation metadata | Build/test infrastructure only, not a required product configuration format |
| Systemd unit/drop-in files | Service declaration and activation | Prefer native service semantics over wrapper-owned background processes |
| Human-readable logs | Diagnosis and stage evidence | Require redaction, stable locations, stage identity, and retention rules |
| Checksums/signatures | Artifact integrity and authenticity | Associate every accepted image with source and build metadata |
| ISO/SquashFS/package archives | Built and distributed artifacts | Binary outputs are derived artifacts, never the authoritative environment declaration |

Archiso's profile documentation defines the filesystem-overlay and profile contracts. Archinstall's schema and samples define its current JSON shape. CHWD's repository demonstrates TOML hardware profile matching. Sources: [Archiso profile documentation](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst), [Archinstall schema](https://github.com/archlinux/archinstall/blob/master/schema.json), [Archinstall configuration sample](https://github.com/archlinux/archinstall/blob/master/examples/config-sample.json), [CHWD profiles](https://github.com/CachyOS/chwd/tree/master/profiles).

**Finding:** Format plurality reflects different ownership domains. MirrorOS should define responsibility and precedence across native formats rather than normalize all of them into a proprietary superset.

_Confidence: High._

### System Interoperability Approaches

**Staged point-to-point integration** is the dominant and most suitable pattern. Each stage consumes declared inputs, invokes an upstream tool or bounded module, writes explicit outputs/evidence, and stops on failure. This matches MirrorOS's independently invocable build, test, install, configure, and verify requirements.

A likely boundary model to validate is:

1. **Build host → Archiso profile:** source tree and package repositories produce an ISO plus metadata.
2. **ISO/live environment → installation planner:** detected storage, firmware, network, and hardware facts produce a reviewable plan.
3. **Approved plan → installation engine:** declarative choices and separately supplied secrets drive target creation.
4. **Live environment → target root:** `arch-chroot` or an installer-provided target abstraction performs bounded installed-system operations.
5. **Target system → configuration modules:** portable, privileged, hardware-specific, user-level, and visual concerns are applied separately.
6. **Configured system → verification:** capability checks produce human and optional structured evidence.

The compared projects support stage isolation:

- Omarchy separates root/system application, explicitly idempotent hardware application, and per-user finalization, with separate logs and completion/migration markers. Sources: [installation script conventions](https://github.com/omacom/omarchy/blob/quattro/agents/skills/install-scripts.md), [file layout](https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md), [testing](https://github.com/omacom/omarchy/blob/quattro/docs/testing.md).
- CachyOS positions CHWD as a target-root hardware stage in a larger Calamares sequence. [CHWD module](https://github.com/CachyOS/cachyos-calamares/blob/cachyos/src/modules/chwd/main.py).
- EndeavourOS separates online `pacstrap` installation from offline SquashFS deployment and selects mode-specific Calamares configuration. Sources: [development overview](https://github.com/endeavouros-team/EndeavourOS-Development), [ISO framework](https://github.com/endeavouros-team/EndeavourOS-ISO).

API gateways, service meshes, and enterprise service buses solve network-service routing and policy problems that do not exist in the MirrorOS MVP. Introducing them would add persistent infrastructure while weakening the desired transparent process boundaries.

_Confidence: High for observed patterns; medium-high for the candidate boundary model, which remains subject to prototype validation._

### Microservices Integration Patterns

MirrorOS has no microservice topology. Therefore:

- API gateway and service discovery: not applicable.
- Circuit breakers: not applicable as a service pattern; bounded retries for package/network operations remain a local command concern.
- Sagas and distributed transactions: not applicable. Installation cannot be made transactional merely by adopting a distributed-systems pattern; recovery points, stage boundaries, explicit retries, and destructive-operation confirmation are the appropriate mechanisms.
- Service mesh: not applicable.

The useful analogue is a **fail-fast staged pipeline**, not microservices: preserve the upstream error, identify the failed operation and last successful stage, avoid dependent work, and require renewed confirmation before any destructive retry.

_Confidence: High._

### Event-Driven Integration

MirrorOS does not need a message broker, event sourcing, CQRS, or publish-subscribe infrastructure. It does use local event mechanisms:

- **ALPM transaction hooks** react to package install, upgrade, or removal events and can run before or after transactions. Ordering, targets, and failure semantics are defined by the hook format. Sources: [`alpm-hooks(5)`](https://man.archlinux.org/man/alpm-hooks.5), [`pacman.conf(5)`](https://man.archlinux.org/man/pacman.conf.5).
- **Systemd dependencies and activation** coordinate local services using native unit relationships rather than an application event bus.
- **Build and test CI triggers** react to commits, schedules, or pull requests outside the installed product.
- **First-login/finalization markers** can defer user-context work, as demonstrated by Omarchy, but markers require idempotency and explicit failure handling to avoid false completion. [Omarchy file layout](https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md).

**Guidance:** Use hooks only when the triggering transaction genuinely owns the reaction. Do not hide core lifecycle transitions in implicit hooks when an explicit stage would be easier to inspect, rerun, and diagnose.

_Confidence: High._

### Integration Security Patterns

**Package and artifact trust.** Pacman repository configuration controls package sources, precedence, and signature requirements. MirrorOS must record every enabled repository and package provenance, retain checksums for generated ISOs, and avoid treating transport encryption alone as authenticity. Sources: [`pacman.conf(5)`](https://man.archlinux.org/man/pacman.conf.5), [Archiso baseline pacman configuration](https://github.com/archlinux/archiso/blob/master/configs/baseline/pacman.conf).

**Credential separation.** Archinstall supports separate configuration and credential inputs; account credentials may be hashed, while disk-encryption material can still require sensitive handling. Its logs and saved configurations reside under `/var/log/archinstall`, so evidence collection must use an explicit allowlist/redaction policy rather than copying the directory indiscriminately. Sources: [Archinstall guided documentation](https://github.com/archlinux/archinstall/blob/master/docs/installing/guided.rst), [credential sample](https://github.com/archlinux/archinstall/blob/master/examples/creds-sample.json), [reporting guidance](https://archinstall.archlinux.page/help/report_bug.html).

**Privilege boundaries.** Build, partitioning, package installation, target-root configuration, and user-level personalization have different privilege needs. The full orchestration process should not remain privileged merely because some stages require root. `arch-chroot` provides target context, not automatic least privilege; each invoked operation still requires review.

**Command safety.** Configuration-derived shell commands create injection and quoting risks. Prefer structured upstream configuration or fixed command arrays over constructing shell programs from untrusted strings. Log command identity and outcome without logging secret arguments or environment values.

**Destructive authorization.** A generated plan and explicit target-bound confirmation must precede storage changes. Generic noninteractive flags must not bypass this control, and a retry must obtain fresh confirmation.

OAuth 2.0, JWT, API keys, and mutual TLS are not product-level requirements because MirrorOS exposes no remote service. SSH/Git credentials and package-signing keys are external secrets or supply-chain trust material, not reasons to create an authentication service.

_Confidence: High for upstream mechanisms; medium-high for recommended controls pending implementation validation._

### Integration Findings for the Research Gate

- Treat CLI arguments, exit status, files, logs, and target-root boundaries as first-class contracts.
- Prototype Archinstall through documented JSON/CLI integration before considering Python plugins or library embedding.
- Keep credentials out of ordinary configuration and evidence; inspect Archinstall outputs before retaining them.
- Separate live-environment, target-root, privileged-system, hardware, and user-context execution.
- Preserve upstream diagnostics and nonzero outcomes instead of translating them into generic success/failure text.
- Use native package, systemd, and ALPM integration selectively; avoid implicit hooks for core lifecycle transitions.
- Do not introduce network APIs, brokers, microservices, or a service mesh without a future requirement absent from the MVP.

---

## Architectural Patterns and Design

### System Architecture Patterns

The evidence favors a repository-centered, staged architecture rather than a monolithic installer application or distributed control plane.

#### Pattern 1: Profile-to-Artifact Build Pipeline

Archiso separates version-controlled profile inputs from generated ISO, bootstrap, or netboot artifacts. A profile supplies package declarations, pacman configuration, filesystem overlays, boot configuration, and image metadata; `mkarchiso` validates and transforms those inputs into derived artifacts.

This pattern keeps the installation medium reproducible and disposable. The ISO is an output of the product definition rather than the authoritative product state.

Sources: [Archiso profile documentation](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst), [`mkarchiso`](https://github.com/archlinux/archiso/blob/master/archiso/mkarchiso), [Arch release engineering](https://github.com/archlinux/releng).

#### Pattern 2: Plan–Confirm–Apply–Verify

MirrorOS requirements imply four distinct installation states:

1. **Discover:** inspect firmware, storage, networking, and relevant hardware capabilities.
2. **Plan:** derive proposed choices and label their provenance.
3. **Confirm:** obtain target-bound authorization for consequential operations.
4. **Apply and verify:** execute the approved plan, then evaluate declared capabilities.

Archinstall provides guided and configuration-driven installation semantics, but the research has not yet established that its native presentation exposes every provenance and confirmation requirement. This must be tested rather than assumed.

Sources: [Archinstall guided installation](https://archinstall.archlinux.page/installing/guided.html), [configuration sample](https://github.com/archlinux/archinstall/blob/master/examples/config-sample.json), [Installer implementation](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/installer.py).

#### Pattern 3: Staged Responsibility Layers

The following candidate boundaries are supported by the comparison:

1. **Source and policy:** version-controlled declarations, rationale, provenance, and documentation.
2. **Image build:** minimal live environment, networking, diagnostics, and installation entry point.
3. **Installation planning and execution:** storage, base system, boot, users, and target-root setup.
4. **Hardware adaptation:** capability detection and isolated hardware-specific choices.
5. **System configuration:** privileged packages, services, and machine-wide configuration.
6. **User environment:** unprivileged workflow and application configuration.
7. **Verification and evidence:** capability checks, logs, metadata, and final status.
8. **Recovery:** retained artifact, rescue procedure, and bounded retry entry points.

Omarchy demonstrates separate ISO, system, hardware, user, runtime/settings, and package-publication responsibilities. CachyOS isolates CHWD as a hardware subsystem invoked inside the target. Archinstall profiles expose selection, installation, post-install, and user-provisioning lifecycle hooks.

Sources: [Omarchy file layout](https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md), [Omarchy installation scripts](https://github.com/omacom/omarchy/blob/quattro/agents/skills/install-scripts.md), [Archinstall profile abstraction](https://github.com/archlinux/archinstall/blob/master/archinstall/default_profiles/profile.py), [CachyOS CHWD module](https://github.com/CachyOS/cachyos-calamares/blob/cachyos/src/modules/chwd/main.py).

#### Pattern 4: Modular Pipeline, Not Microservices

MirrorOS should behave as a modular local pipeline:

- Stages are independently invocable.
- Modules communicate through explicit files, command inputs, target-root state, logs, and exit outcomes.
- A stage owns one bounded responsibility.
- Failure blocks dependent stages without silently rerunning destructive work.
- No persistent coordinator is required.

This provides modularity without network APIs, daemons, service discovery, or distributed state.

#### Pattern 5: Capability-Oriented Configuration

Configuration modules should describe user capabilities—such as graphical session, terminal workflow, screenshots, clipboard, or development environment—rather than permanently encoding one tool as the architectural concept.

Tool-specific declarations remain adapters beneath a stable capability boundary. Niri, a terminal emulator, launcher, or bar can then be replaced without redesigning installation or unrelated modules.

#### Candidate Minimal Architecture

The evidence supports this prototype hypothesis, not yet a binding decision:

```text
Version-controlled source
├── Archiso profile
│   ├── package list
│   ├── pacman configuration
│   ├── minimal airootfs overlay
│   └── boot configuration
├── installation policy
│   ├── preflight discovery
│   ├── generated reviewable plan
│   ├── explicit confirmation
│   └── Archinstall JSON/CLI adapter or native Arch command adapter
├── capability modules
│   ├── portable system declarations
│   ├── hardware-specific declarations
│   ├── privileged operations
│   ├── user-level configuration
│   └── visual configuration
├── verification catalog
│   ├── per-capability checks
│   └── aggregate evidence
└── operational documentation
    ├── build/test/install/configure/verify
    └── recovery
```

The first prototype should compare an Archinstall configuration adapter with the smallest viable native Arch-command path. Python embedding, a custom CLI, a configuration framework, or a custom installer should be introduced only when that comparison demonstrates a concrete deficiency.

_Confidence: High for staged layering; medium for the candidate implementation boundary pending prototype evidence._

### Design Principles and Best Practices

#### Explicit Ownership

Each concern must have one authoritative owner:

- Archiso owns live-media construction.
- The installation engine owns base-system installation.
- Hardware modules own hardware-derived choices.
- Capability modules own intended system/user behavior.
- Verification owns readiness classification.
- Git owns declared source history.
- Generated artifacts and logs are evidence, not configuration authority.

Duplicate ownership creates drift—for example, package declarations copied independently into the ISO, installer, and post-install configuration.

#### Configuration Over Captured State

An installed machine or preconfigured SquashFS image can demonstrate a result but should not replace readable declarations. EndeavourOS’s offline path shows the operational utility of copying a known live image, but it also requires cleanup and transformation of live-only state. MirrorOS’s requirement for long-term evolution favors reconstructing declared capability over treating a captured desktop image as canonical.

Sources: [EndeavourOS development overview](https://github.com/endeavouros-team/EndeavourOS-Development), [pre-SquashFS customization](https://github.com/endeavouros-team/EndeavourOS-ISO/blob/main/run_before_squashfs.sh).

#### Idempotency With Postcondition Verification

A module is not idempotent merely because rerunning it exits successfully. It must:

1. Inspect current state.
2. Apply only the required change.
3. Verify the intended postcondition.
4. Return nonzero when the postcondition is not achieved.
5. Produce no unintended change on a second run.

Omarchy’s migration guidance requires state checks and repeatability, while its issue history also demonstrates risks when failures are suppressed or user-state changes outlive system rollback.

Sources: [Omarchy migration guidance](https://github.com/omacom/omarchy/blob/quattro/agents/skills/migrations.md), [failure suppression issue](https://github.com/basecamp/omarchy/issues/8395), [snapshot/home-state limitation](https://github.com/basecamp/omarchy/issues/5916).

#### Prefer Native Contracts

Use package metadata, systemd units, pacman configuration, ALPM hooks, Archiso profiles, and documented installer configuration before adding wrappers or proprietary formats.

A wrapper is justified only when it adds stable policy that upstream tools do not provide, such as:

- Default provenance explanation.
- Cross-stage status normalization.
- Destructive confirmation rules.
- Evidence aggregation.
- Secret-safe logging.

#### Decisions as Replaceable Adapters

Volatile choices should sit behind explicit boundaries:

- Installation engine.
- Compositor.
- Hardware detector.
- Dotfile/configuration mechanism.
- Task runner.
- Package-state strategy.

Replaceability should mean bounded source changes and preserved lifecycle contracts, not simultaneous support for many implementations.

#### Evidence-Gated Expansion

Adopt a component only after documenting:

- Requirement or repeated need.
- Alternatives.
- Smallest prototype.
- Failure and maintenance surface.
- Removal or replacement path.

This protects the one-maintainer complexity budget.

### Scalability and Performance Patterns

MirrorOS does not need request throughput or horizontal service scaling. Its relevant scaling dimensions are:

- Number of supported devices.
- Number of capability modules.
- Number of package sources.
- Number of upstream integrations.
- Size of the VM validation matrix.
- Frequency of rolling-release breakage.
- Time to reconstruct and diagnose.

#### Controlled Compatibility Matrix

The MVP matrix should remain deliberately small:

- One reference VM.
- One target laptop.
- One primary UEFI path.
- One provisional desktop stack.
- One frozen capability inventory.

CachyOS demonstrates the cost and benefit of a broad filesystem/bootloader installation matrix. MirrorOS should adopt the testing pattern without adopting its breadth.

Source: [CachyOS build and installation workflow](https://github.com/CachyOS/CachyOS-Live-ISO/blob/master/.github/workflows/build.yml).

#### Layered Test Cost

A practical validation pyramid is:

1. Static validation and shell lint.
2. Configuration/schema validation.
3. Module-level tests.
4. ISO build.
5. VM boot and networking smoke test.
6. Clean installation and reboot.
7. Configuration reapplication.
8. Capability verification.
9. Target-laptop validation.

Archiso provides `run_archiso`; CachyOS automates QEMU installation tests; Omarchy distinguishes fast CLI/shell tests from installed-desktop acceptance tests.

Sources: [`run_archiso`](https://github.com/archlinux/archiso/blob/master/scripts/run_archiso.sh), [CachyOS CI](https://github.com/CachyOS/CachyOS-Live-ISO/blob/master/.github/workflows/build.yml), [Omarchy acceptance testing](https://github.com/omacom/omarchy/blob/quattro/agents/skills/acceptance-tests.md).

#### Performance Optimization Boundaries

The two-hour reconstruction goal should be optimized through measurement rather than concurrency by default. Likely contributors include:

- Package download and mirror quality.
- Package cache reuse.
- Compression choice and ISO build cost.
- Disk and filesystem operations.
- Configuration serialization.
- Unnecessary package breadth.
- Repeated network retrieval.
- VM acceleration availability.

Parallelizing privileged or state-mutating operations can create ordering and diagnostic risks. Independent downloads, checks, or tests may be parallelized only where ownership and failure semantics remain clear.

_Confidence: High._

### Integration and Communication Patterns

The architectural integration pattern is synchronous orchestration over stable local interfaces:

- CLI commands and exit statuses.
- Versioned text configuration.
- Filesystem artifacts and target-root state.
- `arch-chroot` for installed-system execution.
- Native package and systemd mechanisms.
- Persistent logs and verification summaries.

A thin orchestration layer may normalize stage identity and outcomes, but it must preserve original upstream diagnostics.

Direct Archinstall JSON/CLI integration should be evaluated before Python plugins. Direct use of native Arch commands remains the comparison baseline.

Sources: [`arch-chroot(8)`](https://man.archlinux.org/man/arch-chroot.8), [Archinstall guided configuration](https://archinstall.archlinux.page/installing/guided.html), [Archinstall plugins](https://archinstall.archlinux.page/archinstall/plugins.html).

_Confidence: High._

### Security Architecture Patterns

#### Staged Privilege

Execution should be partitioned into:

- Read-only discovery.
- Unprivileged build preparation.
- Privileged image/package operations.
- Destructive storage operations.
- Target-root system configuration.
- Unprivileged user configuration.
- Read-only verification where possible.

Privilege should be obtained at the narrowest viable boundary rather than inherited by the complete process.

#### Plan-Bound Destructive Authorization

Confirmation should bind to the concrete target and proposed operations. A changed disk identity or regenerated plan invalidates previous approval. Retries require renewed confirmation.

#### Secret-Free Source and Artifacts

Secrets must be injected at execution time and excluded from:

- Git history.
- Archiso overlays.
- Package metadata.
- Command arguments where observable.
- Terminal output.
- Retained logs.
- Verification reports.
- VM snapshots intended for reuse.

Archinstall’s separation of ordinary configuration and credential material is useful, but disk-encryption secrets and saved logs still require explicit handling.

Sources: [Archinstall guided documentation](https://github.com/archlinux/archinstall/blob/master/docs/installing/guided.rst), [credential sample](https://github.com/archlinux/archinstall/blob/master/examples/creds-sample.json), [reporting guidance](https://archinstall.archlinux.page/help/report_bug.html).

#### Supply-Chain Boundaries

Each accepted artifact should identify:

- Source commit.
- Archiso and installer versions.
- Repository configuration and order.
- Package manifest and versions.
- External source provenance.
- Build timestamp/epoch.
- Checksum.
- Signature status where applicable.
- Verification outcome.

Transport security does not replace package or artifact authenticity.

#### Recovery Is a Security Control

An independent rescue path, retained known-good artifact, diagnostic evidence, and documented abort procedure limit the impact of destructive or supply-chain failures.

_Confidence: High._

### Data Architecture Patterns

The authoritative data model is a version-controlled set of declarations and evidence schemas rather than a database.

#### Data Classes

1. **Portable declarations:** capabilities, packages, services, and user configuration.
2. **Hardware-derived declarations:** capability rules and target-specific selections.
3. **Privileged declarations:** machine-wide changes.
4. **Secret references:** where secrets come from, never their values.
5. **Private state references:** external content and repositories.
6. **Build metadata:** source/tool/package versions and checksums.
7. **Operational evidence:** logs and stage outcomes.
8. **Verification evidence:** capability status and actionable reason.

#### Precedence Must Be Explicit

If declarations can override one another, the order should be simple and documented. A candidate model is:

```text
portable baseline
  < detected hardware selection
  < explicit target override
  < runtime secret/private input
```

This is a hypothesis for architecture review, not yet a selected schema.

#### Current Versus Known-Good Package State

The evidence supports treating these as separate operational modes:

- **Current mode:** resolve against current rolling repositories and discover upstream incompatibility.
- **Known-good mode:** reconstruct from recorded package inputs or a dated repository state and retained artifacts.

Archiso supports reproducibility-related timestamp controls, while the Arch Linux Archive exposes historical repository snapshots. Exact rebuildability still requires preserving source, tool, package, trust, and build-environment metadata.

Sources: [`mkarchiso`](https://github.com/archlinux/archiso/blob/master/archiso/mkarchiso), [Arch Linux Archive](https://wiki.archlinux.org/title/Arch_Linux_Archive), [Arch reproducibility status](https://reproducible.archlinux.org/).

_Confidence: High for the distinction; medium for the eventual retention mechanism._

### Deployment and Operations Architecture

MirrorOS deployment is reconstruction, not service rollout.

#### Artifact Lifecycle

```text
source commit
  → validated declarations
  → ISO build
  → checksum and metadata
  → VM boot qualification
  → clean VM installation
  → reboot and configuration
  → capability verification
  → accepted known-good artifact
  → target-laptop eligibility
```

An ISO should not be promoted to known-good merely because it builds or boots.

#### Current Canary and Known-Good Recovery

Two complementary tracks should be evaluated:

- A periodic current-package canary to expose rolling breakage.
- A retained, fully qualified known-good artifact for urgent recovery.

The canary protects future compatibility; the known-good artifact protects recovery availability.

#### Failure Domains

Failures should be classified by stage:

- Build environment.
- Repository/package resolution.
- Image generation.
- Firmware/boot.
- Networking.
- Storage planning.
- Installation.
- Bootloader.
- Hardware adaptation.
- System configuration.
- User configuration.
- Graphical readiness.
- Capability verification.

Each stage should preserve its own evidence and stop dependent execution when appropriate.

#### Rollback Boundaries

Rollback claims must specify which state is covered. Omarchy’s snapshot experience demonstrates that restoring system state does not necessarily reverse changes in a user home directory. MirrorOS should not claim rollback unless system, user, secret, and external-data boundaries are explicit.

Source: [Omarchy rollback limitation](https://github.com/basecamp/omarchy/issues/5916).

#### Operational Simplicity

The evidence does not justify these MVP components:

- Custom package repository.
- Calamares fork.
- Background management daemon.
- Welcome application.
- Remote control plane.
- Automatic drift reconciliation.
- General hardware-profile engine.
- Multi-profile distribution release system.

They may contain patterns worth adopting, but their operational surfaces should not be inherited without demonstrated need.

_Overall confidence: High for the architectural patterns and exclusions; medium for the candidate minimal architecture until the validation prototype is completed._

---

## Implementation Approaches and Technology Adoption

### Technology Adoption Strategies

MirrorOS should adopt technologies through bounded prototypes rather than selecting a complete stack upfront.

#### Progressive Adoption Model

1. Establish the smallest official Archiso baseline.
2. Prove build and VM boot without personalization.
3. Compare installation-engine boundaries.
4. Compare configuration mechanisms on one representative capability.
5. Select tools using observed safety, idempotency, diagnostics, and maintenance results.
6. Expand only after the selected path passes a clean reconstruction.

This avoids a big-bang commitment to Archinstall internals, Ansible, Nix, a dotfile manager, or a custom CLI.

#### Installation Engine Adoption

Two implementations should be compared:

| Candidate | Prototype boundary | Strengths | Risks |
|---|---|---|---|
| Archinstall JSON/CLI | Generate release-compatible configuration and invoke the packaged CLI | Maintained guided installer, typed configuration, existing disk and boot logic | Schema/version drift, incomplete control over provenance presentation, secret/log handling |
| Native Arch commands | Thin policy around `pacstrap`, `genfstab`, `arch-chroot`, bootloader and storage tools | Maximum transparency and direct diagnostics | More safety logic, validation, and installation behavior become MirrorOS-owned |
| Archinstall Python API/plugins | Import library objects or add hooks | Deep control and reuse | Highest coupling to implementation details and Python lifecycle |
| Calamares | Distribution-specific module/configuration stack | Mature graphical installer framework | Excessive UI, packaging, testing, and maintenance surface for the MVP |

The prototype should evaluate JSON/CLI and native-command paths first. Python embedding is a fallback only if the documented boundary fails a concrete requirement.

Sources: [Archinstall guided configuration](https://archinstall.archlinux.page/installing/guided.html), [Archinstall plugins](https://archinstall.archlinux.page/archinstall/plugins.html), [`pacstrap(8)`](https://man.archlinux.org/man/pacstrap.8), [`arch-chroot(8)`](https://man.archlinux.org/man/arch-chroot.8).

#### Configuration Mechanism Adoption

| Option | Appropriate scope | Strengths | Costs and limitations | Research disposition |
|---|---|---|---|---|
| Small shell modules | Native Arch/system integration and early prototypes | Minimal bootstrap dependency; transparent commands | Idempotency, diff behavior, structured state, and error handling are project-owned | Required baseline for comparison |
| Ansible local mode | System and user desired state | Declarative modules, privilege escalation, check/diff support, Arch pacman module | Python/runtime plus collection dependencies; arbitrary command tasks still require explicit idempotency | Strong prototype candidate |
| GNU Stow | Static user dotfiles | Small, inspectable symlink model; dry-run and conflict detection | No templating, package/service management, or hardware logic | Candidate only for simple static dotfiles |
| chezmoi | Templated user configuration | Per-machine templates, source-state model, lifecycle scripts, password-manager integrations | Adds its own template model; scripts still require idempotency; secret rendering may write values to disk | Candidate for user layer, not system convergence |
| Home Manager | Declarative user packages, files, and services | Strong user-state model and generations | Introduces Nix language, Nixpkgs, `/nix/store`, and commonly `nix-daemon`; creates a second package ecosystem | Defer unless its benefits justify the added platform |
| Custom configuration framework | Any layer | Exact fit | Proprietary semantics, tests, documentation, and long-term ownership | Reject until existing options demonstrate a concrete gap |

Ansible’s local connection, `become`, check mode, diff mode, and `community.general.pacman` module make it a credible convergence candidate. Its command and shell modules are not automatically declarative; they need `creates`, `removes`, `changed_when`, or explicit postcondition checks.

Sources: [Ansible local connection](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/local_connection.html), [privilege escalation](https://docs.ansible.com/projects/ansible/latest/plugins/become.html), [pacman module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/pacman_module.html), [check and diff mode](https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_checkmode.html), [command module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html).

Chezmoi and Stow solve narrower user-file problems. Chezmoi supports templating and controlled script execution; Stow projects static directory trees through symlinks and refuses conflicting real files by default.

Sources: [chezmoi setup](https://www.chezmoi.io/user-guide/setup/), [chezmoi scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/), [chezmoi password-manager integration](https://www.chezmoi.io/user-guide/password-managers/), [GNU Stow manual](https://www.gnu.org/software/stow/manual/stow.html), [Stow conflicts](https://www.gnu.org/software/stow/manual/html_node/Conflicts.html).

Home Manager is available in standalone mode on non-NixOS systems, but the standard Nix multi-user installation introduces a shared store and privileged daemon. That is materially different from adopting a dotfile tool.

Sources: [Home Manager standalone installation](https://nix-community.github.io/home-manager/installation/standalone.html), [Home Manager standalone flakes](https://nix-community.github.io/home-manager/nix-flakes/standalone.html), [Nix installation](https://nixos.org/download/).

_Recommendation: prototype shell and Ansible for one system capability; evaluate the existing dotfile shape separately against Stow and chezmoi. Do not combine tools until each has a distinct ownership boundary._

### Development Workflows and Tooling

#### Repository Workflow

Use short-lived branches or focused commits with these gates:

1. Source/configuration validation.
2. Static analysis.
3. Secret scan.
4. Unit or module tests.
5. ISO build when image inputs change.
6. VM boot or installation test according to change risk.
7. Evidence retention for failed and promoted runs.

Architecture decisions should be recorded after prototype evidence, not before it.

#### Command Discovery

Build, test, install, configure, verify, and clean must be discoverable, but this does not require a custom executable.

Candidate approaches:

- Documented scripts are the zero-abstraction baseline.
- GNU Make is suitable when real file targets and prerequisites model artifact construction.
- Just is suitable when the primary need is discoverable named command recipes.
- A custom CLI is justified only if argument validation, shared safety policy, or structured output cannot remain clear through smaller mechanisms.

Sources: [GNU Make rules](https://www.gnu.org/software/make/manual/html_node/Rule-Introduction.html), [phony targets](https://www.gnu.org/s/make/manual/html_node/Phony-Targets.html), [Just recipes](https://just.systems/man/en/the-default-recipe.html), [Just shell configuration](https://just.systems/man/en/configuring-the-shell.html).

_Recommendation: begin with scripts and documented commands. Add Make or Just only after the actual dependency/command model is visible._

#### Shell Quality

If shell is used:

- Declare the intended shell explicitly.
- Use strict error handling where its semantics are understood.
- Avoid parsing human-oriented command output when structured interfaces exist.
- Preserve child exit status and diagnostic output.
- Quote configuration-derived values.
- Use ShellCheck.
- Test behavior with Bats or an equivalent harness.
- Keep privileged scripts small and auditable.

Sources: [ShellCheck](https://github.com/koalaman/shellcheck), [Bats Core](https://github.com/bats-core/bats-core).

#### Dependency Recording

Pin or record:

- Archiso version/commit.
- Archinstall version and configuration-schema version.
- Ansible core and collection versions if selected.
- Dotfile/configuration tool versions if selected.
- QEMU and firmware versions relevant to VM evidence.
- Repository snapshot or package-resolution date.
- External source commits/checksums.

Version recording should not automatically imply permanent pinning; current-canary and known-good workflows serve different purposes.

### Testing and Quality Assurance

#### Test Pyramid

1. **Static checks**
   - ShellCheck.
   - JSON/TOML/YAML/schema validation.
   - Ansible syntax/lint if selected.
   - Broken-link and documentation checks.
   - Secret scanning.

2. **Module tests**
   - Discovery parsing.
   - Plan generation.
   - Confirmation cancellation.
   - Package provenance validation.
   - Verification status aggregation.
   - Redaction behavior.

3. **Convergence tests**
   - Apply a representative module.
   - Apply it a second time.
   - Assert zero unintended changes.
   - Deliberately break its postcondition.
   - Assert an actionable failure.

4. **Image tests**
   - Clean build.
   - Checksum and metadata generation.
   - UEFI boot.
   - Networking.
   - Required installer/configuration entry point.

5. **Installation tests**
   - Review generated plan.
   - Exercise cancellation before destructive execution.
   - Confirm and install to a disposable disk.
   - Reboot without the ISO.
   - Preserve logs and stage outcomes.

6. **Ready-state tests**
   - Graphical login.
   - Terminal and shell.
   - Clipboard and screenshots.
   - Portals.
   - Launcher, bar, notifications.
   - Browser and development capabilities.
   - Keyboard-action inventory.

7. **Physical validation**
   - Run only after clean-VM qualification.
   - Preserve independent rescue access.
   - Return all required workarounds to source or documentation.

#### Disposable VM Pattern

Use fresh disks for destructive installation tests. QEMU supports temporary snapshots and qcow2 overlays whose writes do not modify the backing image. Omarchy demonstrates a stronger acceptance pattern: install in a headless disposable VM, boot the result, run in-guest checks, and retain screenshots, serial output, and installer logs.

Sources: [QEMU disk images](https://www.qemu.org/docs/master/system/images), [`qemu-img` documentation](https://github.com/qemu/qemu/blob/master/docs/tools/qemu-img.rst), [`run_archiso`](https://github.com/archlinux/archiso/blob/master/scripts/run_archiso.sh), [Omarchy acceptance tests](https://github.com/omacom/omarchy/blob/quattro/agents/skills/acceptance-tests.md).

#### Verification Result Model

Every capability should end in exactly one state:

- `passed`
- `failed`
- `blocked_external`

A result should contain:

- Capability identifier.
- Check identifier.
- Outcome.
- Non-secret evidence.
- Actionable reason.
- Suggested next step.
- Timestamp and relevant source/artifact identity.

Human and structured outputs must derive from the same result model.

### Deployment and Operations Practices

#### Artifact Promotion

An artifact moves through explicit states:

```text
built
→ boot-tested
→ install-tested
→ configured
→ idempotency-tested
→ capability-verified
→ accepted-known-good
```

A failed or incomplete stage prevents promotion.

#### Package Provenance

Use separate source classes:

- Official Arch repository package.
- AUR recipe built locally.
- Custom or third-party repository package.
- Direct upstream binary/archive.
- Source-built local package.

For each package record:

- Name and version.
- Source class.
- Repository or source URL.
- Package/build recipe identity.
- Signature or checksum evidence.
- Reason/capability.
- Review requirements.
- Rebuild/upgrade responsibility.

The AUR contains unofficial, user-contributed `PKGBUILD` recipes that require manual review. `makepkg` must run unprivileged; only installation of the resulting package requires privilege. Official pacman packages use configured OpenPGP signature policies.

Sources: [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository), [makepkg](https://wiki.archlinux.org/title/Makepkg), [`pacman.conf(5)`](https://man.archlinux.org/man/pacman.conf.5), [package signing](https://wiki.archlinux.org/title/Pacman/Package_signing).

#### Secret Controls

Use defense in depth:

- Public-safe repository structure.
- Runtime secret injection.
- Explicit redaction tests.
- Local Git-history scanning.
- Hosting-provider secret scanning/push protection where available.
- Artifact and log scans before promotion.

Gitleaks currently exposes `gitleaks git` for Git-history scanning and `gitleaks dir` for filesystem scanning. GitHub automatically scans public repositories for supported secret patterns, but local scanning remains useful before publication and for generated artifacts.

Sources: [Gitleaks](https://github.com/gitleaks/gitleaks), [GitHub secret scanning](https://docs.github.com/en/code-security/concepts/secret-security/secret-scanning), [GitHub push protection](https://docs.github.com/en/code-security/concepts/secret-security/push-protection).

SOPS or password-manager rendering should be considered only if MirrorOS eventually needs versioned encrypted values. The simpler MVP boundary is to store references and obtain values externally at execution time.

#### Operational Evidence

Retain per run:

- Source commit and dirty-state indication.
- Tool versions.
- Repository configuration.
- Requested and resolved package manifests.
- Artifact checksums.
- Build/install/configure/verify logs.
- VM configuration.
- Stage durations.
- Final capability report.

Evidence retention must use allowlists and secret scans rather than indiscriminate archival.

### Team Organization and Skills

MirrorOS has one maintainer, so ownership boundaries replace team boundaries.

Required working knowledge:

- Arch installation and recovery.
- Archiso profiles and build process.
- Pacman, repository trust, and package provenance.
- Storage, filesystems, encryption, UEFI, and bootloaders.
- Shell safety and process semantics.
- Archinstall configuration/API behavior if selected.
- Python and testing if Archinstall is extended.
- Ansible semantics if selected.
- QEMU/KVM and UEFI firmware.
- systemd system/user units.
- Wayland, portals, session services, and Niri integration.
- Secret handling and diagnostic redaction.
- Incident and recovery documentation.

Skill expansion should follow selected technology. There is no reason to learn or maintain Rust, Nix, Calamares internals, or a custom CLI framework unless a validated decision introduces them.

### Cost Optimization and Resource Management

The relevant cost is maintainer attention rather than cloud spend.

Control cost by:

- Limiting hardware support to the reference VM and target laptop.
- Reusing official tools and schemas.
- Keeping the ISO thin.
- Avoiding a custom package repository.
- Avoiding duplicate declarations.
- Running expensive end-to-end tests only when change risk requires them.
- Using cached packages or VM bases without allowing cache state to hide missing declarations.
- Keeping a known-good artifact while current-package canaries detect drift.
- Measuring build, installation, configuration, verification, and diagnosis separately.
- Removing tools whose ongoing maintenance exceeds demonstrated value.

Caches accelerate testing but must never become undeclared prerequisites. Periodic clean runs remain mandatory.

### Risk Assessment and Mitigation

| Risk | Evidence or trigger | Mitigation |
|---|---|---|
| Archinstall schema/API drift | Configuration and internal models evolve | Generate/test config against the packaged version; prefer CLI/JSON before Python embedding |
| Rolling repository breakage | Package names, dependencies, and installer assumptions change | Current canary, package metadata, known-good artifact, bounded snapshot strategy |
| False idempotency | Second run exits successfully but changes or hides failure | State inspection, postcondition checks, second-run assertions |
| Secret leakage | Credentials may appear in config, environment, logs, images, or reports | Separate injection, allowlisted evidence, automated scans, redaction tests |
| Privilege sprawl | Whole workflow runs as root | Stage privilege, unprivileged builds/user config, explicit target-root boundary |
| AUR supply-chain exposure | Unofficial recipes execute build instructions | Manual review, unprivileged clean build, recorded recipe commit and source checks |
| VM-only confidence | QEMU cannot represent all laptop behavior | Physical qualification after complete VM success and rescue preparation |
| Configuration-tool overreach | One tool begins owning image, installation, secrets, hardware, and user state | Explicit ownership matrix and replaceable adapters |
| Rollback overclaim | System snapshots may not restore user state | Document covered state; test recovery; preserve external backups |
| Wrapper hides upstream failure | Normalized output loses responsible command | Preserve raw non-secret diagnostics and original exit outcome |
| CI/cache contamination | Reused state masks missing inputs | Fresh work directories, clean VM disks, periodic uncached reconstruction |
| Maintenance expansion | Custom repo, installer fork, daemon, or schema becomes permanent | Evidence gate and documented recurring-value requirement |

## Technical Research Recommendations

### Implementation Roadmap

#### Gate 1: Research Baseline

- Freeze the comparison matrix and evidence log.
- Record adopted, rejected, and unresolved patterns.
- Define evaluation criteria before writing the prototype.
- Do not select a configuration mechanism based solely on feature breadth.

#### Gate 2: Minimal Archiso Prototype

- Copy the official `releng` profile into project ownership.
- Remove packages and overlays not required for boot, networking, diagnostics, and installation.
- Build with documented clean commands.
- Emit checksum, profile identity, tool versions, and resolved package manifest.
- Boot through QEMU/UEFI and verify networking.

**Pass condition:** a clean clone produces a bootable, traceable artifact with no undocumented action.

#### Gate 3: Installation Boundary Prototype

Implement the same constrained VM installation scenario twice:

- Variant A: Archinstall JSON/CLI.
- Variant B: smallest viable native Arch command orchestration.

Evaluate:

- Plan readability.
- Default provenance.
- Editability.
- Destructive confirmation.
- Cancellation semantics.
- Credential isolation.
- Upstream diagnostic fidelity.
- Exit behavior.
- Recovery evidence.
- Code and dependency surface.

**Pass condition:** select or reject Archinstall using observed evidence and an ADR.

#### Gate 4: Configuration Mechanism Spike

Choose one representative capability containing:

- Official packages.
- One system service.
- One privileged configuration file.
- One user configuration file.
- One verification check.

Implement it with:

- Minimal shell baseline.
- Ansible local-mode candidate.
- Existing dotfile approach plus either Stow or chezmoi only if user-file complexity requires comparison.

Measure:

- First-run changes.
- Second-run changes.
- Dry-run/diff accuracy.
- Failure clarity.
- Privilege scope.
- Code volume and dependencies.
- Replacement cost.

**Pass condition:** select the smallest mechanism that meets idempotency, readability, diagnostics, and maintenance requirements.

#### Gate 5: Verification Catalog

- Freeze MVP capability identifiers.
- Define one or more checks per capability.
- Implement the three-state result model.
- Generate concise and complete reports from the same data.
- Test failed and externally blocked outcomes.

#### Gate 6: End-to-End VM Reconstruction

- Build ISO.
- Boot.
- Review and approve plan.
- Install.
- Configure before normal reboot where practical.
- Reboot.
- Reach graphical login.
- Verify capabilities.
- Reapply configuration.
- Preserve evidence and measured stage durations.

**Pass condition:** zero undocumented steps and zero unintended second-run changes.

#### Gate 7: Target-Laptop Qualification

- Confirm backup and independent rescue path.
- Review target-specific plan.
- Run the VM-qualified process.
- Capture all deviations.
- Return every required correction to version control.
- Rerun affected verification.

### Technology Stack Recommendations

**Adopt for the initial prototype:**

- Arch Linux.
- Official Archiso profile conventions.
- Pacman and native package trust mechanisms.
- QEMU/KVM with UEFI firmware.
- Git.
- Shell for minimal glue.
- ShellCheck.
- Checksums, manifests, and persistent logs.

**Prototype before selection:**

- Archinstall JSON/CLI versus native Arch installation commands.
- Shell modules versus Ansible local mode.
- Stow versus chezmoi only for the user-file layer.
- Make versus Just only after command/dependency shape becomes concrete.
- Current repositories versus a bounded known-good retention mechanism.

**Defer unless evidence changes:**

- Archinstall Python embedding/plugins.
- Home Manager/Nix.
- Calamares.
- Custom installer or unified CLI.
- Custom package repository.
- General hardware-profile engine.
- Background management daemon.
- Encrypted secrets committed to the repository.

### Skill Development Requirements

Immediate:

- Archiso profile construction.
- QEMU/UEFI test harnesses.
- Arch package provenance.
- Storage and installation recovery.
- Shell testing and redaction.
- Capability verification design.

Conditional:

- Archinstall Python API only if embedding is selected.
- Ansible and collection management only if the spike wins.
- Chezmoi templating only if user configuration requires it.
- Nix/Home Manager only after an explicit architecture decision.

### Success Metrics and KPIs

| Area | Metric |
|---|---|
| Build reproducibility | Clean clone builds an artifact with recorded metadata and checksum |
| Boot readiness | Reference VM boots through the supported firmware path with networking |
| Documentation | Zero undocumented steps in the clean reconstruction |
| Installation safety | Every destructive operation has target-bound confirmation |
| Cancellation | Rejected confirmation performs zero destructive work |
| Configuration convergence | Second run causes zero unintended changes |
| Capability readiness | 100% of MVP capabilities end passed, failed, or externally blocked |
| Diagnostic quality | Every failure identifies stage, operation/capability, evidence, and next action |
| Secret safety | Zero known secrets in source, ISO, logs, and evidence |
| Package provenance | 100% of installed packages have a recorded source class |
| Artifact traceability | Every accepted ISO maps to source, tools, repositories, package manifest, and verification |
| Recovery readiness | Independent rescue path exists before physical installation |
| Performance | Reconstruction stage durations are measured against the provisional two-hour target |
| Maintainability | Added abstractions have documented recurring value and removal boundaries |

_Overall implementation confidence: High for the staged adoption and test strategy; medium for tool selection until the installation and configuration spikes are executed._

---

## Research Synthesis

### Comparative Project Matrix

| Criterion | Archiso | Archinstall | Omarchy | CachyOS | EndeavourOS |
|---|---|---|---|---|---|
| Primary role | Official live/install media builder | Official guided installer and Python installation library | Opinionated Arch desktop distribution and runtime | Performance-oriented Arch distribution | Accessible Arch-based distribution |
| Image construction | Native profile consumed by `mkarchiso` | Not an image builder; shipped on official Arch media | Separate ISO repository tracking Archiso | Archiso-derived build wrapper | Heavily modified Archiso framework |
| Image contents | Profile package list, overlay, boot assets | Installer executable/library and dependencies | Installer, offline packages, runtime/settings | Live desktop, Calamares, CachyOS tooling | KDE live session, Calamares, offline content |
| Installation engine | None; supplies the environment | Guided TUI, JSON/CLI, library, profiles, plugins | ISO-owned staged installation | Customized Calamares and CLI alternatives | Customized Calamares online/offline modes |
| Configuration separation | Profile concerns only | Base installation plus profiles and custom commands | ISO, settings, runtime, hardware, user and migrations separated | Installer, CHWD, repositories and desktop packages separated | ISO, installer configuration, package repository and hotfixes separated |
| Hardware adaptation | No general engine | Profile and graphics-driver selections | Explicit idempotent hardware stage | Rust/TOML CHWD profile engine | Installer scripts and package/driver handling |
| Testing pattern | CI, ShellCheck and QEMU helper | Python tests, tooling and QEMU guidance | Fast shell/CLI tests plus installed-desktop VM acceptance | ISO build plus QEMU Calamares matrix | Public repository emphasizes local build; public test automation is less visible |
| Package strategy | Configurable pacman repositories | Uses Arch repositories and selected packages | Own signed package repository and channels | Own repositories and CPU-optimized tiers | Arch plus smaller EndeavourOS repository |
| Maintenance surface | Official Arch-owned toolset | Official but evolving schema/API | Multiple repositories, packages, migrations and release channels | Installer fork, repositories, hardware engine and broad matrix | Installer fork, online/offline paths, repository and hotfix mechanism |
| MirrorOS value | Direct adoption candidate | Prototype candidate | Pattern source | Pattern source | Pattern source |
| MirrorOS caution | Rolling inputs require metadata and testing | Schema/API and credential/log coupling | Product scope and maintenance breadth | Distribution-scale complexity | Distribution-scale complexity |

Sources: [Archiso](https://github.com/archlinux/archiso), [Archinstall](https://github.com/archlinux/archinstall), [Omarchy](https://github.com/omacom/omarchy), [Omarchy ISO](https://github.com/omacom/omarchy-iso), [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), [CachyOS CHWD](https://github.com/CachyOS/chwd), [EndeavourOS ISO](https://github.com/endeavouros-team/EndeavourOS-ISO), [EndeavourOS development map](https://github.com/endeavouros-team/EndeavourOS-Development).

### Adopt and Avoid Pattern Catalog

#### Adopt

- **Profile as source, artifact as output:** keep Archiso input under version control and treat generated media as disposable.
- **Thin bootstrap:** include only boot, networking, diagnostics, installation, and required validation support.
- **Discover–plan–confirm–apply–verify:** separate hardware/storage discovery from authorization and execution.
- **Responsibility layers:** isolate image, installation, hardware, privileged system, user, visual, verification, and recovery concerns.
- **Configuration-first upstream integration:** prefer documented JSON/CLI and native configuration before library internals.
- **Capability-oriented modules:** preserve user intent independently of the current package or desktop component.
- **Narrow privilege boundaries:** perform user-level work without inherited root access.
- **Three-state verification:** classify every capability as passed, failed, or externally blocked.
- **Layered tests:** combine static checks, module tests, boot tests, clean installation, reboot, convergence, and ready-state verification.
- **Disposable VM evidence:** retain serial logs, screenshots where useful, stage results, and artifact identity.
- **Current and known-good tracks:** use canaries to expose rolling breakage and retained qualified artifacts for recovery.
- **Explicit provenance:** distinguish official packages, AUR recipes, third-party repositories, binaries, and source builds.
- **Quiet healthy state:** report actionable failures without persistent assistants or onboarding applications.

#### Avoid

- **Custom installer before proving an upstream gap.**
- **Calamares fork for a one-user CLI-driven product.**
- **Custom package repository without package ownership requirements.**
- **Universal proprietary configuration schema.**
- **Unified CLI created only for aesthetic consistency.**
- **Implicit lifecycle transitions hidden in package hooks.**
- **Whole-workflow root execution.**
- **Credentials embedded in Git, images, command output, logs, or reusable VM state.**
- **Treating a live desktop image as the authoritative environment definition.**
- **Broad hardware, filesystem, bootloader, or desktop matrices in the MVP.**
- **Suppressing failures to preserve apparent progress.**
- **Claiming rollback without defining system and user-state boundaries.**
- **Archinstall Python coupling before JSON/CLI evaluation.**
- **Nix/Home Manager before accepting its second package ecosystem and daemon/store model.**
- **Automation before a documented process and repeated need exist.**

### External Dependency Map

```text
MirrorOS source repository
│
├── Build environment
│   ├── Arch Linux-compatible host
│   ├── archiso / mkarchiso
│   ├── pacman and configured repositories
│   ├── squashfs and filesystem tooling
│   ├── bootloader tooling
│   └── Git and source forge
│
├── Installation environment
│   ├── firmware: UEFI/OVMF in VM
│   ├── networking and DNS
│   ├── storage/filesystem tools
│   ├── arch-install-scripts
│   │   ├── pacstrap
│   │   ├── genfstab
│   │   └── arch-chroot
│   ├── candidate: archinstall
│   └── package repositories and keyrings
│
├── Configuration environment
│   ├── pacman
│   ├── systemd system/user units
│   ├── native application configuration
│   ├── candidate: Ansible
│   ├── candidate: Stow or chezmoi
│   └── external secret provider
│
├── Validation environment
│   ├── QEMU/KVM
│   ├── OVMF
│   ├── disposable virtual disks
│   ├── shell/static analysis tools
│   ├── secret scanner
│   └── capability-specific probes
│
├── Upstream supply
│   ├── Arch official repositories
│   ├── Arch Linux Archive when dated state is required
│   ├── AUR recipes where explicitly accepted
│   ├── third-party release sources
│   └── Git hosting availability
│
└── Physical recovery
    ├── target laptop
    ├── independent rescue medium
    ├── external backup
    └── retained known-good MirrorOS artifact
```

#### Trust Boundaries

- Repository source versus runtime-injected private values.
- Build host versus generated artifact.
- Live environment versus target root.
- Official repositories versus AUR or third-party sources.
- Read-only discovery versus destructive execution.
- Privileged system configuration versus user configuration.
- Generated logs/evidence versus secret-bearing installer state.
- VM qualification versus physical-hardware assurance.

### Architectural Decision Status

#### Supported by Current Evidence

- Use official Archiso conventions for the image prototype.
- Keep the ISO minimal and personal configuration independent.
- Use a staged local pipeline rather than a daemon or service architecture.
- Treat QEMU/KVM as the reference laboratory.
- Require package and artifact provenance.
- Separate current-package compatibility from known-good recovery.
- Keep hardware-derived configuration separate.
- Use capability-based verification.
- Exclude databases, cloud runtime infrastructure and distributed-system patterns.
- Avoid Calamares, a custom repository and public-distribution machinery in the MVP.

#### Pending Prototype Decision

- Archinstall JSON/CLI versus native Arch installation orchestration.
- Shell versus Ansible for convergence.
- Existing dotfile approach versus Stow or chezmoi.
- Scripts alone versus Make or Just for command discovery.
- Exact known-good package retention mechanism.
- Exact hardware capability representation.
- Exact structured verification format.
- Whether any unified `mirroros` command provides recurring value.

#### Deferred

- Archinstall Python plugins or library embedding.
- Nix/Home Manager.
- General hardware-profile engine.
- Automated drift reconciliation.
- Broader device support.
- Scheduled cloud CI.
- Application session/profile restoration.
- Custom package publishing.

### Candidate Minimal Architecture

This is the smallest architecture currently supported by evidence, but remains a hypothesis until the validation prototype passes.

```text
Repository
│
├── image/
│   └── Archiso profile
│       ├── profile metadata
│       ├── live package input
│       ├── pacman configuration
│       ├── minimal root overlay
│       └── boot assets
│
├── install/
│   ├── read-only discovery
│   ├── plan generation
│   ├── default provenance
│   ├── target-bound confirmation
│   └── engine adapter
│       ├── Archinstall JSON/CLI candidate
│       └── native Arch baseline
│
├── capabilities/
│   ├── portable/
│   ├── hardware/
│   ├── system/
│   ├── user/
│   └── visual/
│
├── verify/
│   ├── capability catalog
│   ├── check implementations
│   └── human and structured reporting
│
├── operations/
│   ├── build
│   ├── test
│   ├── configure
│   ├── evidence
│   └── recovery
│
└── docs/
    ├── prerequisites
    ├── lifecycle procedures
    ├── architecture decisions
    └── recovery guidance
```

#### Core Contracts

- Every lifecycle stage is independently invocable.
- Every state-changing stage has explicit inputs and outputs.
- Every destructive action is preceded by target-bound confirmation.
- Every upstream failure remains observable.
- Every module has a postcondition.
- Every capability maps to verification.
- Every artifact maps to source and package state.
- Every retained evidence path is secret-scanned.
- Every tool-specific implementation remains replaceable behind its ownership boundary.

### Validation Prototype

#### Prototype Question

Can official Archiso plus a documented installation/configuration composition satisfy MirrorOS safety, transparency, repeatability, and verification requirements without a custom installer or control plane?

#### Workstream A: Minimal Image

Deliver:

- Project-owned Archiso profile derived from the current official reference.
- Minimal live package list.
- Networking and diagnostics.
- Installation entry point.
- Clean build command.
- ISO checksum and build metadata.
- QEMU/UEFI boot evidence.

Pass when a clean clone builds and boots with networking and traceable metadata.

#### Workstream B: Installation Comparison

Implement one fixed VM scenario using:

- Archinstall JSON/CLI.
- Native `pacstrap`/`genfstab`/`arch-chroot` baseline.

Use the same:

- Virtual disk.
- Partition/filesystem target.
- Boot mode.
- Base package set.
- User requirements.
- Verification checks.

Measure:

- Source size and dependency count.
- Plan visibility and editability.
- Default provenance support.
- Confirmation and cancellation semantics.
- Credential handling.
- Exit and diagnostic fidelity.
- Log sensitivity.
- Recovery and retry behavior.
- Version coupling.

Pass when one approach clearly satisfies the requirements with lower justified maintenance cost. Record the result in an ADR.

#### Workstream C: Configuration Comparison

Implement one representative capability through:

- Minimal shell.
- Ansible local mode.
- User-file mechanism only where needed.

The capability must include an official package, system service, privileged file, user file, and readiness check.

Measure:

- First-run changes.
- Second-run changes.
- Dry-run accuracy.
- Diff quality.
- Failure diagnostics.
- Privilege duration.
- Dependencies.
- Readability and removal cost.

Pass when a mechanism demonstrates convergence, useful failure behavior, and one-maintainer sustainability.

#### Workstream D: Verification Contract

Implement:

```text
capability
├── identifier
├── description
├── checks
│   ├── identifier
│   ├── outcome
│   └── non-secret evidence
├── aggregate status
└── actionable next step
```

Pass when success, failure, and external-blocker scenarios produce consistent human and structured outcomes.

#### Workstream E: End-to-End Reconstruction

Execute:

```text
clean clone
→ build
→ boot
→ inspect plan
→ cancel safely
→ rerun and confirm
→ install
→ configure
→ reboot
→ graphical login
→ verify
→ configure again
→ verify again
```

Pass when:

- No undocumented action occurs.
- Cancellation performs no rejected destructive change.
- Every capability receives one explicit state.
- The second configuration run has zero unintended changes.
- Logs and evidence contain zero known secrets.
- The run records stage durations and artifact identity.

### Future Technical Outlook

#### Near-Term

The highest-value evolution is improved evidence, not increased abstraction:

- Stable capability inventory.
- Better VM harness.
- Clear package provenance.
- Repeatable current-package canaries.
- Retained known-good artifacts.
- Measured reconstruction stages.

#### Medium-Term

Only evidence from repeated use should justify:

- Additional hardware profiles.
- More structured verification.
- Preview reporting.
- Optional drift detection.
- Unified command entry point.
- Safe import of application state.
- Automated scheduled validation.

#### Long-Term

MirrorOS may become a living record of environment evolution across devices and desktop changes. Its success depends on preserving replaceability: no current installer, compositor, package source, configuration tool, or artifact format should become indistinguishable from the product itself.

### Methodology and Source Verification

#### Source Priority

1. Official package metadata and manuals.
2. Official project documentation.
3. Primary source repositories and CI definitions.
4. Project-maintained architecture and contributor guidance.
5. Issues or discussions used only to demonstrate observed limitations.
6. Secondary sources only where primary evidence was unavailable.

#### Verification Method

- Parallel searches covered official and downstream projects.
- Critical claims were checked against primary URLs and source passages.
- Versions were treated as dated observations.
- Capability claims were separated from suitability judgments.
- Conflicting or incomplete evidence was reported as uncertainty.
- Recommendations were derived from MirrorOS requirements, not presented as upstream project claims.

#### Confidence Framework

- **High:** directly documented behavior or source-visible mechanism.
- **Medium-high:** conclusion supported by multiple primary project examples.
- **Medium:** MirrorOS-specific suitability judgment requiring prototype validation.
- **Low:** insufficient evidence; no binding recommendation made.

#### Source Currency

Research was conducted on 2026-09-24. At that cutoff, official package metadata reported Archiso 90-1 and Archinstall 4.4-1. These versions are evidence of current activity, not architecture pins.

Sources: [Archiso package](https://archlinux.org/packages/extra/any/archiso/), [Archinstall package](https://archlinux.org/packages/extra/any/archinstall/), [Arch downloads](https://archlinux.org/download/), [Arch Linux Archive](https://wiki.archlinux.org/title/Arch_Linux_Archive).

### Limitations and Open Questions

The research cannot resolve these without implementation or user-specific context:

- Exact target-laptop model and hardware capabilities.
- Secure Boot and TPM requirements.
- Preferred storage, filesystem, encryption, and bootloader choices.
- Current dotfile organization and ownership.
- Existing familiarity with shell, Python, Ansible, Nix, Stow, or chezmoi.
- Frozen MVP package and capability inventory.
- Actual Archinstall behavior for the chosen storage plan.
- Whether Archinstall exposes sufficient default provenance.
- Real reconstruction duration.
- Network and mirror performance.
- Exact package sources, including AUR dependencies.
- Whether a task runner provides value beyond scripts.
- Long-term artifact and package-retention storage.
- Physical-device behavior not represented by QEMU.

These are intentionally inputs to prototypes and architecture collaboration, not gaps to fill through assumption.

## Technical Research Conclusion

The research gate is complete at the documentary level. It identifies a credible minimal architecture, explicit exclusions, unresolved decisions, and executable prototypes for resolving them.

The strongest technical direction is an official Archiso-based bootstrap feeding a transparent staged pipeline. Archinstall should be evaluated at its documented JSON/CLI boundary. Configuration should be selected through a shell-versus-Ansible experiment, while dotfiles remain a separate concern. Verification, provenance, secrets, evidence, and recovery are architectural foundations rather than final-stage additions.

Architecture work may now resume without guessing technology preferences. Binding choices should be made only after the corresponding prototype supplies the evidence defined in this report.

**Technical Research Completion Date:** 2026-09-24  
**Source Verification:** Current public sources with primary-source preference  
**Overall Confidence:** High for ecosystem mechanisms and architectural boundaries; medium for pending tool selections

---

<!-- Technical research workflow complete -->
