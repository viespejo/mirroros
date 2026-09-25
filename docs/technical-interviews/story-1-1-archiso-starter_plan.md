# Story 1.1 Archiso Starter — Consolidated Plan

## Repository Foundation

The existing `/home/its32ve1/mirroros` directory will become the authoritative MirrorOS Git repository, with `main` serving as the integration branch. A remote will not be configured until its destination is explicitly selected. [DEC-001]

The unused Sheaf/Pi/Claude workflow tooling (`.pi/`, `.claude/`, `.sheaf/`, `.sheaf-runtime/`) was removed before initialization, and its only project artifact, the brainstorming session, now lives at `docs/brainstorming/brainstorming-session-2026-09-23-201236.md` with all frontmatter references updated. `docs/.obsidian/` remains on disk as local editor configuration but is ignored by Git and must not be removed or reorganized as unrelated cleanup. [DEC-050]

## Upstream Baseline Selection

At implementation start, the importer will resolve the latest official Archiso package available from the supported Arch repositories and use its `releng` profile as the initial baseline. The implementation must not silently adopt the host's currently installed version or treat the architecture's historical version observation as a pin. The imported baseline will record the exact package version, package checksum, and corresponding upstream revision or release tag so its origin can be independently diagnosed. Archiso profile and tool updates must be qualified together. [DEC-002]

## Upstream Branch and Integration Model

The `vendor/archiso-releng` branch will be created once from the initial `main` baseline and retained for subsequent updates. Its import commits will contain only complete transitions between unmodified official `releng` profile snapshots. In this context, a “pure” vendor import means that the commit introduces no MirrorOS attribution, adaptation, correction, or other local delta; it does not mean the branch must have unrelated history or contain no shared project paths. `image/archiso/UPSTREAM.md` and every MirrorOS-specific change belong only on `main`. [DEC-003]

Each vendor import will be integrated into `main` with an explicit `--no-ff` merge. The merge commit creates a visible adoption boundary for each upstream baseline. Keeping the vendor branch at the imported snapshots also allows later upstream changes to be distinguished from MirrorOS changes and causes conflicts with local deltas to surface for deliberate review. An orphan branch or repeated direct copies onto `main` will not be used. [DEC-003]

The update procedure must teach this model rather than merely list commands. It will cover initial branch creation, an unmodified first import, explicit merge into `main`, main-only attribution and local changes, later upstream replacement imports, conflict and delta review, and requalification. A compact commit-history diagram or equivalent worked example will clarify the meaning and purpose of the branch boundary. [DEC-003, TODO-001]

## Isolated Archiso Acquisition and Build Environment

Docker will provide the supported current Arch environment for upstream profile acquisition and subsequent ISO construction. The work host will not be fully updated for this purpose, nor will it receive an isolated Archiso package update. The process will resolve an official Arch Linux container image, record its immutable digest, perform a complete package update inside the container, and install Archiso there. It will record the resulting Archiso package version and checksum and map that release to its upstream revision or tag. This protects the work host from userspace package changes while retaining a diagnosable source chain. Package resolution against current repositories provides traceability rather than a promise of bit-for-bit future reconstruction. [DEC-002, DEC-004]

The initial official `releng` profile will be copied from the container's `/usr/share/archiso/configs/releng/` with `docker cp`. Before a vendor import commit is created, a recursive comparison must demonstrate that the exported tree matches the container source exactly. Profile acquisition does not require a writable bind mount into the repository. [DEC-003, DEC-004]

ISO construction will run `mkarchiso` in a privileged Docker container because its chroot and mount operations require elevated kernel capabilities. The profile will be mounted read-only. Build work and initial output will remain inside Docker as disposable `/work` and `/out` storage rather than writable host bind mounts. The privileged container is an isolation mechanism for the host userspace, not a security boundary comparable to a VM. Boot qualification remains a separate QEMU/KVM and OVMF responsibility. [DEC-004]

The container lifecycle will be create, execute, export, verify, and remove. It must not automatically remove the container before outputs have been exported. Accepted ISO artifacts, checksums, metadata, and relevant success or failure evidence will be transferred with `docker cp`, avoiding root-owned files written directly into the host repository or generated-output directories. The container and disposable work/output storage will be removed only after export verification; a failed run must retain the container long enough to export diagnostics. [DEC-004]

Build containers will always be ephemeral so their mutable state cannot silently influence later runs. A persistent Docker volume for `/var/cache/pacman/pkg` may optionally accelerate later builds, but it is non-authoritative, removable, and governed by documented pruning and deletion procedures. Package selection must remain controlled by the active repositories and signatures, not by cache contents, and the supported process must pass a clean build without the cache. [DEC-004]

Before profile acquisition is represented as supported, Story 1.1 must document and exercise the unprivileged container lifecycle, `linux/amd64` digest resolution and Cosign verification, package authenticity and integrity, profile export and comparison, normal-user export ownership, cache management, one uncached acquisition, and preservation plus scanning of failure evidence. Only this acquisition scope blocks Story 1.1 completion. [TODO-005]

Story 1.3 must separately qualify privileged ISO construction: read-only profile input, disposable internal `/work` and `/out`, verified artifact and evidence export before cleanup, normal-user ownership, cache behavior including a no-cache build, failure-evidence handling, and final cleanup. Its build qualification also includes the exact profile/tool version preflight. [TODO-004, TODO-006]

## Archiso Provenance and Attribution

Archiso is the upstream source of the copied `releng` profile. `image/archiso/UPSTREAM.md` will be the authoritative technical provenance record located beside that profile. It will identify the upstream project and canonical URL, exact package version and checksum, upstream revision or release tag, Docker image digest, UTC import date, SPDX license identifier, incorporation method and source path, vendor import commit, local-delta summary and inspection command, and supported boot scope. A local delta means any MirrorOS-owned difference from the unmodified profile snapshot retained on `vendor/archiso-releng`. [DEC-005]

`docs/attribution.md` will serve as the repository-wide index of externally incorporated material. Its Archiso entry will identify the project, license, and incorporated profile, then link to `image/archiso/UPSTREAM.md` for mutable import-specific provenance instead of duplicating it. Applicable copyright, license, and notice text already present in copied upstream files must remain at its original location; the MirrorOS attribution records supplement rather than replace those notices. [DEC-005]

## Atomic Vendor Integration

Every Archiso vendor integration will begin from a clean `main` worktree and use `git merge --no-ff --no-commit vendor/archiso-releng`. While the merge remains pending, the maintainer will review and deliberately resolve profile conflicts, update `image/archiso/UPSTREAM.md` with the adopted import identity and current local-delta summary, and run the required provenance and delta checks. The merge commit will be created only after those steps succeed; otherwise the merge will be aborted. This keeps adoption of a new upstream profile and its authoritative provenance atomic on `main`. [DEC-006]

Because `UPSTREAM.md` is never added on the vendor branch, its absence there does not normally conflict with the file added on `main`; Git retains the main-only file during later merges. If upstream ever introduces the same path, the conflict will be resolved manually while preserving the MirrorOS provenance record. A separate corrective commit may repair an error discovered later, but post-merge provenance updates are not the normal workflow. [DEC-005, DEC-006]

## Initial Profile Delta Boundary

The initial profile establishes a diagnostic upstream baseline rather than a personalized MirrorOS image. Every file consumed by `mkarchiso` will remain byte-for-byte identical to the selected official `releng` profile. `image/archiso/UPSTREAM.md`, which is not a functional Archiso input, will be the only additional file under that directory. Story 1.1 will not change image identity or labels, packages, boot configuration, repositories, live-system messages, services, scripts, branding, personal settings, or any other functional input. [DEC-007]

## Generated-Output Source-Control Boundary

The root `.gitignore` will contain root-anchored `/build/`, `/dist/`, and `/evidence/` entries. These generated, non-authoritative directories will be created only when an operation needs them and may be absent from a clean clone. They will not receive committed placeholder files. Docker-internal work, output staging, and package-cache volumes likewise have no representation in the repository source tree. [DEC-008]

The same `.gitignore` will also contain a root-anchored `/docs/.obsidian/` entry so local editor configuration never enters source control. [DEC-050]

## Pre-Import Governance Baseline

Before `vendor/archiso-releng` is created, `main` will contain and commit the architecture-defined governance foundation: the root project `LICENSE`, `AGENTS.md`, `.gitignore`, `.shellcheckrc`, `docs/attribution.md`, an ADR template, and `docs/procedures/update-archiso.md`. Establishing these files before incorporating external material makes licensing, attribution, generated-output handling, agent behavior, shell validation, decision records, and the upstream maintenance process effective from the first import. [DEC-009]

This prerequisite does not move lifecycle command implementation into Story 1.1. Story 1.2 remains responsible for completing and validating lifecycle discovery, entry-point behavior, normalized outcomes for unimplemented operations, and its broader governance acceptance criteria. [DEC-009]

## Initial Commit and Branch Point

Git initialization will produce one honest baseline commit named `chore: establish MirrorOS repository baseline`. It will contain all authoritative content already present (including the relocated brainstorming session), the technical-interview records, and the complete pre-import governance foundation, while excluding generated outputs and the ignored `docs/.obsidian/`. The history will not be artificially split to imply that pre-existing content evolved through earlier source-controlled steps. `vendor/archiso-releng` will branch only after this commit. [DEC-001, DEC-009, DEC-010, DEC-050]

## Boot-Path Scope

The complete upstream profile, including BIOS and Syslinux assets, will remain unchanged in the initial import. Their presence preserves the recognizable upstream baseline and does not imply a MirrorOS support commitment. `UPSTREAM.md` and the Archiso update procedure will state that only UEFI/OVMF is guaranteed and qualified for the MVP; BIOS/Syslinux receives neither personalization nor supported-path testing. Removing those assets later will require evidence and a separate approved decision. [DEC-007, DEC-011]

## Secret-Scanning Gate

Gitleaks is a required external dependency, but MirrorOS will not install, update, pin, or record its version. If it is unavailable, the procedure will report an unmet precondition and will not attempt automatic remediation. The exported profile will be scanned before its vendor commit, the complete working tree before the initial commit and vendor merge, and Git history after integration. Unreviewed findings block acceptance. Any exception must be narrow, justified, and version-controlled; retained scan evidence must communicate the outcome without reproducing a detected secret value. [DEC-012]

## Initial Acceptance Checks

Story 1.1 will not add a project-owned repository-check script. The Archiso update procedure will document native commands that require a clean worktree, detect tracked ignored files, compare the imported profile against its exported container source while excluding only `UPSTREAM.md`, inspect the complete vendor-to-main delta, invoke Gitleaks, and confirm that `build/`, `dist/`, and `evidence/` are untracked generated paths. A non-sensitive summary of the executed checks and outcomes will be retained as acceptance evidence. Automation may be reconsidered only after repeated execution demonstrates recurring value. [DEC-013]

## Import Evidence

Detailed generated evidence for an import will be written under `evidence/archiso-import/<UTC-timestamp>-<package-version>/` and remain outside source control. `image/archiso/UPSTREAM.md` will preserve the stable acceptance conclusion: check status, UTC execution date, checks performed, aggregate outcome, and the corresponding local evidence path. It will not embed complete logs or potentially sensitive values. This keeps diagnostic detail locally available while making the accepted result visible to future repository readers. [DEC-014]

## Vendor Snapshot Replacement

Every later official profile will first be exported and validated in temporary staging outside the active vendor tree. The validated snapshot will then completely replace `image/archiso/` on `vendor/archiso-releng`; overlay copying is forbidden because it could retain files removed upstream. The maintainer will review `git diff --name-status` so additions, modifications, and deletions are explicit, then run the approved integrity and secret checks before committing. A failed check restores the branch and worktree to the preceding vendor commit. [DEC-015]

## Upstream and Package Identity Chain

Every accepted import will identify both development and packaging provenance. `UPSTREAM.md` will record the Archiso upstream release tag and its resolved commit, the official Arch package's complete version together with its packaging-repository tag and resolved commit, and the binary package filename and SHA-256 checksum. The binary package is the effective source of the copied profile; the additional revisions explain which Archiso release and official packaging state produced it. The import is blocked if any required identity cannot be resolved unambiguously. [DEC-002, DEC-005, DEC-016]

## Container Image Selection, Authenticity, and Identity

Each import will use the Arch-owned signed daily image `docker.io/archlinux/archlinux:latest` only to select the current container environment. The procedure will resolve or pull that tag for `linux/amd64` without creating a container, obtain the selected manifest digest, verify the digest-qualified `image@sha256:...` reference with Cosign against the identity and issuer documented by Arch's official OCI-image project, and create containers from that same digest-qualified reference. This prevents a tag movement from causing verification and execution of different bytes. Cosign is an external prerequisite that MirrorOS identifies but does not install, update, pin, or otherwise manage. The exact digest will be recorded in `UPSTREAM.md` and generated evidence but will not be hard-coded as a permanent repository pin; retention or pinning of known-good build environments belongs to the later artifact strategy. [DEC-004, DEC-017, DEC-046, DEC-047]

## Canonical Upstream Authorities

The canonical Archiso source is `https://gitlab.archlinux.org/archlinux/archiso`, and the canonical official packaging source is `https://gitlab.archlinux.org/archlinux/packaging/packages/archiso`. The Archiso GitHub repository is a read-only consultation mirror and cannot provide authoritative provenance identity, even when its mirrored tags match GitLab. The binary package is resolved from the official Arch `extra` repository. [DEC-016, DEC-033, DEC-046]

## Remote Publication and Local Clone Validation

Story 1.1 does not require a repository remote because its destination remains deliberately undecided. Repository history, branch topology, tracked content, ignored outputs, and clean-clone inspection will be validated using a fresh local clone. Until hosting is selected, the absence of a remote will be recorded as an operational limitation rather than a story failure. [DEC-001, DEC-018]

When a remote is configured, both `main` and `vendor/archiso-releng` must be published and their roles documented. Publishing only `main` would retain the merged files but lose the pure vendor history needed for later upstream comparison and integration. [DEC-018, TODO-003]

## Agent and Contributor Rules

The root `AGENTS.md` will provide a concise set of actionable repository rules rather than duplicate the architecture. It will require agents and contributors to follow `docs/architecture.md` and accepted ADRs as normative, leave ignored local documentation tooling such as `docs/.obsidian/` untouched, keep MirrorOS-owned content off the vendor branch, exclude secrets, personal configuration, and generated outputs, respect language and privilege boundaries, avoid prematurely resolving prototype-gated decisions, and update attribution, tests, and documentation with the changes they govern. It will link to the architecture and Archiso update procedure for rationale and operational detail. [DEC-019, DEC-050]

Claude Code compatibility will be provided by a root `CLAUDE.md` containing only `@AGENTS.md`. This file belongs in the initial baseline commit but introduces no independent rules; `AGENTS.md` remains the single maintained instruction source. [DEC-020]

## Shell Validation Baseline

The initial `.shellcheckrc` will set `shell=bash` and `severity=style` without globally excluded or disabled diagnostic codes. ShellCheck applies to project-owned shell and must not drive edits to the unmodified vendor profile. Because no project-owned shell implementation exists yet, the baseline introduces policy rather than artificial scripts; future exceptions require focused justification near the affected code or a specific reviewed decision. [DEC-021]

## Architecture Decision Record Template

The repository will provide `docs/adr/0000-template.md` without a fictional example decision. Real records will use sequential `NNNN-short-title.md` names and one of the statuses `Proposed`, `Accepted`, `Rejected`, or `Superseded`. The template will capture identity, date, context and question, constraints and criteria, alternatives, prototype or other evidence, the decision, consequences and trade-offs, replacement or reversal boundaries, required validation, references, and a forward link when superseded. [DEC-022]

The ADR directory will also contain `docs/adr/README.md`. It will distinguish the consolidated, currently normative design in `docs/architecture.md` from the question, alternatives, evidence, trade-offs, and historical evolution preserved by an individual ADR. It will document numbering, statuses, when a new ADR is warranted, and forward-linked supersession without deletion. Existing architecture content will not be retroactively converted into ADRs; the process applies to future critical selections, prototype outcomes, and architectural exceptions. [DEC-023]

## Licensing Boundary

The root `LICENSE` will contain the complete official GNU General Public License version 3 text. Original MirrorOS material is licensed `GPL-3.0-only` unless explicitly stated otherwise. The copied Archiso profile is not relicensed: it retains its applicable `GPL-3.0-or-later` terms and original notices, with the distinction explained in both attribution records. Future project-owned source files will use SPDX identifiers where appropriate, while unmodified vendor files will receive no MirrorOS ownership or license headers. [DEC-005, DEC-024]

## Import and Qualification States

`UPSTREAM.md` will report import integrity, secret scan, build qualification, and UEFI/OVMF boot qualification as separate states. Story 1.1 may conclude with the first two passed while build and boot remain explicitly `not yet performed`; neither the profile nor any nonexistent artifact will be described as built or boot-qualified. After Stories 1.3 and 1.4 establish those operations, each subsequent Archiso update must rerun both build and UEFI/OVMF boot gates before receiving a fully qualified status. [DEC-011, DEC-014, DEC-025]

## Docker Host Boundary

Docker and an accessible operational daemon are external prerequisites. MirrorOS will not install or update Docker, enable or start its service, alter host groups, or modify daemon socket permissions. The procedure stops with an actionable unmet-precondition result when Docker is unavailable and performs no automatic host remediation. [DEC-004, DEC-026]

Initial secret scans will use the standard Gitleaks rules without a repository `.gitleaks.toml`. Custom configuration will be introduced only when a real false positive demonstrates the need, and the same reviewed change must constrain and document the exception as narrowly as possible. [DEC-012, DEC-027]

## Isolated Vendor Worktree

The primary checkout will remain on `main` throughout upstream maintenance. Profile staging, complete replacement, review, validation, and the vendor commit will occur in a temporary Git worktree at `build/worktrees/archiso-vendor/`. After the vendor commit, that worktree will be removed and the explicit pending merge will run from the primary checkout. A pre-commit failure discards the temporary worktree while leaving the vendor branch at its previous commit. The worktree path is generated and covered by the root `/build/` ignore rule. [DEC-008, DEC-015, DEC-028]

## Profile Integrity Semantics

An imported profile matches its official source when both trees have the same paths and path types, regular-file content is identical, symbolic links have identical targets, and files retain the same executable state. UID/GID, timestamps, directory modes, and permission bits Git cannot represent are not equality criteria. Upstream declarations such as `profiledef.sh` remain unchanged and continue to define installed-image ownership and special permissions. [DEC-007, DEC-029]

Every generated import-evidence directory will receive an explicit Gitleaks scan before acceptance because ignored content cannot be assumed to be covered by tracked-tree or history scans. A finding must not be copied into another report: the affected evidence is sanitized or removed and scanned again. Only the aggregate non-sensitive result enters `UPSTREAM.md`. [DEC-012, DEC-014, DEC-030]

## Local-Delta Reporting

`UPSTREAM.md` will identify the exact vendor baseline commit, summarize functional MirrorOS changes, report added/modified/deleted path statistics, and provide a reproducible command for the complete diff scoped to `image/archiso/`. The comparison excludes `image/archiso/UPSTREAM.md`, whose intentional main-only presence is provenance metadata rather than a functional profile delta. The full patch remains in Git rather than being duplicated in documentation, and the initial functional local-delta summary must be `None`. [DEC-005, DEC-007, DEC-031]

## Import Commit Convention

Vendor snapshot commits will use `vendor(archiso): import releng <package-version>`, and explicit main integration commits will use `vendor(archiso): merge releng <package-version>`. Their bodies will include the essential upstream and packaging revisions for searchability, while `image/archiso/UPSTREAM.md` remains the complete provenance and qualification record. [DEC-003, DEC-032]

## Package Authenticity

The Archiso binary package will come only from configured official Arch repositories and must pass Pacman signature validation against the container's Arch keyring. The procedure must not disable or weaken `SigLevel` or bypass package-signature checks. `UPSTREAM.md` will retain the aggregate validation result without copying keyring material or sensitive diagnostics. SHA-256 identifies the exact accepted package bytes but does not replace publisher authentication. [DEC-016, DEC-033]

## Online Resolution Requirement

Every new import requires online confirmation of the official Arch container image, package repositories, Archiso repository, and Arch packaging repository. If any required source cannot be reached or resolved unambiguously, the import stops as an unmet precondition. Caches may accelerate retrieval of already resolved matching content but cannot silently choose a stale image, package, or Git revision as the new current baseline. [DEC-002, DEC-016, DEC-017, DEC-034]

## Installed-Package Integrity

After Archiso is installed in the ephemeral container and before any profile export, the procedure will run `pacman -Qkk archiso`. Any missing or altered package file blocks the import. A passing package-integrity check connects the authenticated binary package to its installed profile, after which the exported tree must separately pass the approved path, type, content, symlink, and executable-state comparison. [DEC-029, DEC-033, DEC-035]

## Profile and Build-Tool Version Gate

Every future build will resolve Archiso in a fresh current Arch container and compare its exact package version with the profile package version recorded in `UPSTREAM.md`. A match permits construction; a mismatch stops before `mkarchiso` and requires a new official profile import and vendor merge. The process will neither combine an older profile with a newer tool silently nor preserve a mutable build container between runs. Other packages continue to resolve from current repositories for the current-package track and will be captured in later artifact metadata; exact historical reconstruction remains part of the future known-good strategy. [DEC-002, DEC-004, DEC-025, DEC-036]

## Build-to-Import Workflow

The normal change workflow invokes the build operation, which performs the exact Archiso version comparison as a lightweight preflight before starting `mkarchiso`. A match continues to construction. A mismatch stops without producing an ISO, reports an actionable unmet precondition, and links to `docs/procedures/update-archiso.md`. The build operation never imports or merges upstream automatically: the maintainer performs that separately, reviews any interaction with local MirrorOS changes, and then explicitly retries the build. The update procedure will document its side of this handoff. [DEC-036, DEC-037]

Story 1.3 must implement and document the build-side preflight, no-artifact failure behavior, normalized unmet-precondition outcome, update-procedure guidance, and explicit retry requirement before the Docker build path is declared supported. [DEC-037, TODO-004]

## Clean-Clone Acceptance Gate

The final Story 1.1 gate will create a temporary clone outside the repository using `git clone --no-local` from the local authoritative source. The clone must check out a clean `main`, expose `origin/vendor/archiso-releng`, contain the complete profile and required provenance, attribution, update, licensing, and agent-governance files, and omit `build/`, `dist/`, and `evidence/`. Applicable read-only repository inspections will run in the clone. A non-sensitive summary will be added to the original import evidence before the temporary clone is removed. This validates reconstruction from committed history only; it does not claim build or boot qualification. [DEC-018, DEC-038]

## Container Privilege Separation

The profile-acquisition container will run without additional privileges because package resolution, package integrity checks, provenance collection, and `docker cp` do not require mount or chroot capabilities. Privileged execution is reserved for the separate ephemeral build container only while `mkarchiso` needs it; a privileged build container will not be reused for import convenience. [DEC-004, DEC-039]

## Git Author Identity Boundary

A consciously configured Git author identity is an external prerequisite. Story 1.1 will not change local or global `user.name` or `user.email` and will not invent a fallback identity. If Git cannot determine an author, implementation stops before creating a commit and asks the maintainer to configure it. Author identity remains only in normal Git commit metadata and is not duplicated in `UPSTREAM.md` or generated evidence. [DEC-040]

## Architecture Scope

The initial Archiso profile and MVP bootstrap path support only `x86_64`, matching the target laptop and reference VM. Story 1.1 will preserve the official `releng` profile for that architecture and will not introduce ARM variants or a multi-architecture build and qualification matrix. [DEC-041]

Docker image acquisition and container creation for Archiso will explicitly select `--platform=linux/amd64`, matching the `x86_64` support boundary. Cross-platform emulation is outside the MVP and must not be treated as a supported build path. [DEC-041, DEC-042]

Normal imports and builds will reuse a Docker volume named `mirroros-pacman-cache` for `/var/cache/pacman/pkg`. The cache remains generated, removable, and non-authoritative; its absence or failure permits recreation or an uncached run rather than blocking correctness. Documentation will provide an explicit removal command, and qualification will include at least one no-cache execution to prove independence from cached state. [DEC-004, DEC-043]

## Initial Artifact Presentation

The first bootstrap artifact will retain the official profile's name, boot menus, labels, and visual presentation. Its identity as a MirrorOS-produced bootstrap derives from repository source identity, build metadata, and checksum rather than an early branding delta. Presentation or naming customization is deferred until the upstream baseline has built and booted successfully and a separate reviewed change justifies it. [DEC-007, DEC-025, DEC-044]

The baseline version of `docs/attribution.md` will define the repository's attribution policy and entry format without claiming that Archiso has already been incorporated. The Archiso index entry will be added during the initial pending vendor merge alongside `image/archiso/UPSTREAM.md`, making the copied material and both levels of attribution authoritative in the same merge commit. [DEC-006, DEC-009, DEC-045]

## Update Initiation Policy

Story 1.1 introduces no periodic Archiso update schedule. An import begins when the build preflight detects a profile/tool mismatch or when the maintainer deliberately chooses to evaluate a new upstream release. Scheduled current-package canaries and automated update qualification remain deferred until build and boot operations can execute the required gates. [DEC-036, DEC-037, DEC-048]

## Implementation Readiness

The Story 1.1 design interview is closed and this consolidated plan is ready to drive implementation. Story 1.1 completion is blocked by the branch-maintenance documentation in TODO-001 and the acquisition qualification in TODO-005. Remote publication in TODO-003 remains legitimately deferred until hosting is selected. The version preflight and privileged-build qualification in TODO-004 and TODO-006 belong to Story 1.3 and do not block Story 1.1. No critical Story 1.1 design choice remains implicit; an implementation finding that contradicts this plan must return to an explicit decision instead of being resolved silently. [DEC-049, TODO-001, TODO-003, TODO-004, TODO-005, TODO-006]

## Plan Decomposition

Story 1.1 will be implemented through two sequential plans separated by their external-prerequisite boundary. Plan 01-01 establishes the repository: Git initialization, the complete pre-import governance foundation including the Archiso update procedure, the working-tree secret scan, and the single baseline commit, stopping before the vendor branch exists. It depends only on Git and Gitleaks. Plan 01-02 then performs the Docker- and Cosign-dependent work: signed-container acquisition, the isolated vendor-worktree import, the atomic pending merge with provenance and attribution, evidence scanning, and the clean-clone acceptance gate. Executing the procedure in 01-02 validates and, where needed, corrects what 01-01 documented; it closes TODO-001 and TODO-005. A missing external prerequisite therefore blocks only 01-02 and leaves 01-01 independently verifiable. [DEC-009, DEC-010, DEC-051, TODO-001, TODO-005]

Procedure defects found while executing plan 01-02 are corrected in one dedicated commit on `main`, `docs(procedures): record first Archiso import execution`, which also removes the "Pending first execution" note. It follows the vendor merge commit, keeping upstream adoption atomic, and precedes the clean-clone gate, which therefore validates the final committed state. Only mechanical corrections are allowed; a finding that would change an accepted decision halts execution for an explicit decision. [DEC-003, DEC-006, DEC-038, DEC-052]

The failure-evidence obligation of TODO-005 is exercised through a controlled drill that precedes the real import. The drill induces a deterministic integrity-comparison failure against a deliberately tampered staging copy, then demonstrates that the unprivileged acquisition container survives the failure, that its diagnostics are exported to `evidence/archiso-import/<UTC-timestamp>-failure-drill/` and pass a Gitleaks scan, and that cleanup happens only afterwards. It never weakens signature policy or relies on network disruption, never modifies either branch, and contributes only an aggregate outcome to `UPSTREAM.md`. [DEC-033, DEC-039, DEC-053, TODO-005]

Cache behavior is qualified in a fixed order. The failure drill and the real import use the default `mirroros-pacman-cache` volume, with the import's evidence showing the cached Archiso package was reused at the same SHA-256. An ephemeral uncached acquisition then has to reproduce the same package version, checksum, and profile integrity result, which proves the cache did not influence the accepted baseline. The sequence ends with explicit removal of the volume and confirmation that it is gone. A rolling-repository version change between runs invalidates the attempt and restarts the sequence instead of accepting mixed identities. [DEC-029, DEC-043, DEC-054, TODO-005]

Under agent execution, the maintainer's merge review from DEC-006 becomes one blocking human checkpoint. The checkpoint comes after the `--no-commit` merge is prepared and before the merge commit. At that point the staged name-status diff, the complete `UPSTREAM.md`, the new attribution entry, and the check summary are presented, and only an explicit approval lets the merge commit proceed. Mechanical verification alone covers the pure vendor commit and the bounded procedure-correction commit. [DEC-006, DEC-052, DEC-055]
