# Story 1.1 Archiso Starter — Decision Log

**Conventions.** The Consolidated Plan (`story-1-1-archiso-starter_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding entry, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: Should the existing `/home/its32ve1/mirroros` directory be initialized as the authoritative MirrorOS Git repository, using `main` as its integration branch while preserving existing workflow-managed directories?
- **Context/Nuances**: The directory is not currently a Git repository. Story 1.1 requires source-control status checks, a `vendor/archiso-releng` branch, traceable upstream revisions, merge-based update handling, and reviewable local deltas. Existing `.pi/`, `.sheaf/`, `.sheaf-runtime/`, and `docs/.obsidian/` directories are managed project workflow or documentation metadata and must not be removed or reorganized as incidental cleanup. No remote repository destination has yet been selected.
- **User Response**: Yes; register this directly.
- **Decision**: Initialize the existing directory as the authoritative MirrorOS Git repository. Use `main` as the integration branch and preserve the existing workflow-managed directories intact. Defer remote configuration until its destination is explicitly decided.
- **Status**: Accepted; directory-preservation scope partially revised by DEC-050

## DEC-002
- **Question**: What policy should determine the Archiso version used for the initial `releng` profile import?
- **Context/Nuances**: The implementation host currently has `archiso` 82-1 installed, while the architecture mentions 90-1 only as a dated observation and explicitly not as a version pin. Importing the currently installed profile without resolving freshness could establish an unintentionally stale baseline. Package and profile compatibility must remain diagnosable.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: At implementation start, resolve the latest official Archiso package version available from the supported Arch repositories. Import the `releng` profile from that official package rather than assuming the host's currently installed version is suitable. Record the exact package version, package checksum, and corresponding upstream revision or release tag. Qualify Archiso tool and profile updates together. Do not encode either 82-1 or 90-1 as the design-time version pin.
- **Status**: Accepted

## DEC-003
- **Question**: How should the `vendor/archiso-releng` branch be maintained and integrated into `main`?
- **Context/Nuances**: Directly copying each new profile onto `main` would obscure the boundary between exact upstream content and MirrorOS changes. An orphan vendor branch would introduce unrelated history without a demonstrated benefit. In this model, “pure” describes the scope of vendor import commits: they contain only the complete, unmodified upstream profile transition. It does not mean that the branch has no shared repository ancestry or contains no pre-existing project paths. MirrorOS attribution files, adaptations, and corrections remain exclusive to `main`.
- **User Response**: Accepted after clarification and requested that the explanation also be documented.
- **Decision**: Create `vendor/archiso-releng` once from the initial `main` baseline. Commit complete, unmodified upstream `releng` profile imports on that branch, with no MirrorOS-specific changes or `UPSTREAM.md` updates in vendor import commits. Integrate every upstream import into `main` with an explicit `--no-ff` merge. Apply attribution and all MirrorOS-local deltas only on `main`. Preserve the vendor branch between updates so each later import exposes upstream changes and merge conflicts against local deltas.
- **Status**: Accepted

## TODO-001
- **Question**: What branch-maintenance guidance must the implementation documentation include?
- **Context/Nuances**: The branch model was not immediately self-evident. Its value depends on maintainers understanding the boundary rather than mechanically copying commands.
- **User Response**: Requested that the clarified explanation be documented.
- **Decision**: `docs/procedures/update-archiso.md` must explain the initial branch creation, pure import commits, explicit `--no-ff` integration, main-only attribution and local changes, subsequent upstream imports, conflict review, and the meaning of “pure.” It should include a compact history diagram or equivalent worked example.
- **Status**: Pending

## DEC-004
- **Question**: What isolated environment and data-flow model should acquire the Archiso profile and later build the installation artifact without updating the work host or leaving root-owned outputs?
- **Context/Nuances**: Updating only Archiso on an outdated Arch host would be an unsupported partial upgrade, while a full host update may be disruptive on a work machine. A current Arch container avoids changing the host userspace. `mkarchiso` requires mount and chroot operations, so the build container requires elevated privileges; this is operational isolation, not a security boundary equivalent to a VM. Writable bind mounts would allow container root to create inconvenient host-owned files. A mutable long-lived container would also introduce hidden build state. Resolving current packages and recording them provides traceability but does not by itself guarantee an identical future reconstruction.
- **User Response**: Approved the final Docker-based proposal, including ephemeral containers and an optional persistent package cache.
- **Decision**: Use Docker as the supported Arch environment for both upstream profile acquisition and ISO construction. Do not update the work host or install Archiso on it. Resolve an official Arch Linux container image and record its immutable digest; perform a complete package update and install Archiso inside the container. Export the official `releng` profile with `docker cp` and recursively verify the exported copy against its container source before committing it on the vendor branch. For builds, mount the profile read-only and run `mkarchiso` in a privileged container. Keep `/work` and `/out` inside Docker and disposable. Export accepted artifacts, checksums, metadata, and relevant failure evidence with `docker cp` before cleanup so writable host bind mounts and root-owned repository outputs are avoided. Containers are ephemeral and are removed only after export and verification, so the lifecycle must not use automatic `--rm` before those steps complete. An optional persistent Docker volume may cache `/var/cache/pacman/pkg`; it is removable, non-authoritative, and must not be required for a clean build. QEMU/KVM with OVMF remains responsible for later boot qualification. An operational Docker daemon is a prerequisite.
- **Status**: Accepted

## TODO-002
- **Question**: What must be documented and qualified before the Docker acquisition and build path is declared supported?
- **Context/Nuances**: The approved model depends on explicit lifecycle ordering, provenance capture, safe cleanup, predictable ownership, and cache independence. Failure cleanup must not destroy diagnostics before they are exported.
- **User Response**: Approved documenting and testing these obligations.
- **Decision**: Document exact create, execute, export, verify, and remove commands; profile copy and recursive comparison; container image digest capture; Archiso package version and checksum capture; upstream revision/tag mapping; failure-evidence export; package-cache creation, reuse, pruning, and removal; and output ownership expectations. Test the complete path, including a no-cache build, normal-user ownership of exported files, and preservation of evidence on failure, before declaring it supported.
- **Status**: Superseded by TODO-005 and TODO-006

## DEC-005
- **Question**: How should `image/archiso/UPSTREAM.md` and `docs/attribution.md` divide responsibility without duplicating mutable provenance data?
- **Context/Nuances**: Archiso is the upstream project from which MirrorOS incorporates the `releng` profile. The profile needs nearby technical provenance, while the repository also needs a global inventory of externally incorporated material for review and license compliance. Repeating version-specific values in both locations would create drift risk. Local deltas are MirrorOS changes relative to the exact unmodified profile retained on `vendor/archiso-releng`. Existing upstream copyright, license, and notice text complements rather than being replaced by project attribution records.
- **User Response**: Accepted after clarification and requested direct registration.
- **Decision**: Make `image/archiso/UPSTREAM.md` the authoritative detailed provenance record for the incorporated profile. It records the upstream project and canonical URL, package version and checksum, upstream revision or tag, container image digest, UTC import date, SPDX license identifier, incorporation method and source path, vendor import commit, local-delta summary and inspection command, and supported boot scope. Make `docs/attribution.md` the repository-wide index of incorporated external material; its Archiso entry records the project, license, incorporated material, and a link to `UPSTREAM.md`, without duplicating version-specific import values. Preserve applicable notices in copied upstream files at their original locations.
- **Status**: Accepted

## DEC-006
- **Question**: When and where should `image/archiso/UPSTREAM.md` be updated while merging a new vendor profile into `main`?
- **Context/Nuances**: The vendor branch never carries the MirrorOS-owned `UPSTREAM.md`, so a normal later merge preserves the file added on `main` and does not conflict merely because it is absent on vendor. A conflict would require upstream to introduce the same path or another overlapping change. Updating provenance in a separate post-merge commit would temporarily leave `main` containing a new profile with stale metadata. Preparing the merge with a dirty worktree could accidentally include unrelated changes.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: Start every vendor integration from a clean worktree and run `git merge --no-ff --no-commit vendor/archiso-releng`. Before creating the merge commit, deliberately resolve profile conflicts, update `image/archiso/UPSTREAM.md` with the new import identity and local-delta summary, and run the required delta and provenance checks. Commit the merge only after all are complete. Abort the merge if provenance or checks cannot be completed. A later corrective commit is an exception for subsequently discovered errors, not the normal update flow. If upstream ever introduces the same `UPSTREAM.md` path, resolve that conflict manually while preserving MirrorOS's authoritative provenance record.
- **Status**: Accepted

## DEC-007
- **Question**: Which local changes are permitted inside `image/archiso/` for the initial Story 1.1 import?
- **Context/Nuances**: Story 1.1 requires a complete recognizable upstream foundation without functional personalization. Changing image metadata, packages, boot configuration, repositories, live services, scripts, messages, branding, or personal configuration would make it harder to distinguish upstream or environment failures from MirrorOS behavior. The local provenance record is not consumed by `mkarchiso` and does not functionally alter the image.
- **User Response**: Accepted the recommended boundary and requested direct registration.
- **Decision**: For the initial import, every file consumed by `mkarchiso` must remain identical to the selected official `releng` profile. The only additional file permitted inside `image/archiso/` is the MirrorOS-owned `UPSTREAM.md`. Do not alter image name or label, package lists, boot configuration, `pacman.conf`, live-system messages, services, scripts, branding, personal configuration, or any other functional profile input in Story 1.1.
- **Status**: Accepted

## DEC-008
- **Question**: Should generated Archiso work, distribution, and evidence directories be created or retained as empty directories in source control?
- **Context/Nuances**: The architecture defines `build/`, `dist/`, and `evidence/` as generated, ignored, non-authoritative outputs that may be absent from a clean clone. Docker-internal work, output, and cache storage also has no source-tree representation. Placeholder files would incorrectly suggest that generated directories are authoritative repository structure.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: Add root-anchored `/build/`, `/dist/`, and `/evidence/` patterns to the repository's root `.gitignore`. Do not create or commit those directories merely to preserve their presence, and do not add `.gitkeep` placeholders. Operations create generated host directories only when needed. Docker-internal work, staging output, and cache volumes remain outside the repository.
- **Status**: Accepted; ignore set extended by DEC-050

## DEC-009
- **Question**: Should Story 1.1 create the complete repository-governance foundation that the architecture orders before the Archiso import, even though Story 1.2 also references those files?
- **Context/Nuances**: The architecture's implementation order requires `LICENSE`, `AGENTS.md`, `.gitignore`, `.shellcheckrc`, attribution, an ADR template, and the Archiso update procedure before importing the profile. Deferring them solely because Story 1.2 also validates repository governance would permit externally licensed material to enter without the intended rules, attribution framework, and update process. This dependency does not require Story 1.1 to implement Story 1.2's lifecycle entry points or their runtime contracts.
- **User Response**: Accepted the recommended scope and requested direct registration.
- **Decision**: Include the architecture-defined repository-governance foundation in Story 1.1 and commit it on `main` before creating `vendor/archiso-releng`. This foundation comprises the root project license, contributor/agent rules, generated-path ignores, shell-validation configuration, repository attribution index, ADR template, and Archiso update procedure. Story 1.2 remains responsible for completing and validating lifecycle discovery, entry-point behavior, and the broader governance acceptance criteria.
- **Status**: Accepted

## DEC-010
- **Question**: How should the repository's first commit be structured before creating `vendor/archiso-releng`?
- **Context/Nuances**: All current planning, workflow-managed metadata, interview artifacts, and the newly required governance foundation predate Git initialization as one repository baseline. Splitting that state into multiple commits would manufacture an evolution that did not occur under source control. Generated outputs are non-authoritative and excluded.
- **User Response**: Accepted the recommended model and requested direct registration.
- **Decision**: Create one initial commit named `chore: establish MirrorOS repository baseline`. It includes all existing authoritative project content, preserved workflow-managed directories, the technical-interview artifacts, and the complete pre-import governance foundation. It excludes generated outputs. Create `vendor/archiso-releng` only after this baseline commit.
- **Status**: Accepted; baseline content partially revised by DEC-050

## DEC-011
- **Question**: Should BIOS and Syslinux assets be removed from the imported `releng` profile because the MVP guarantees only UEFI/OVMF?
- **Context/Nuances**: The complete official profile contains boot assets outside the MVP's qualified path. Removing them would create an immediate functional local delta and weaken the value of the exact upstream baseline. Retaining upstream content does not by itself create a support commitment.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: Retain the complete upstream BIOS and Syslinux assets unchanged in the initial profile. Explicitly state in `UPSTREAM.md` and the update procedure that their presence does not imply support: only the UEFI/OVMF path is guaranteed and qualified for the MVP. Do not personalize or test BIOS/Syslinux as part of the supported path. Any future removal requires evidence and a separate approved decision.
- **Status**: Accepted

## DEC-012
- **Question**: How should Story 1.1 depend on Gitleaks and apply secret scanning without taking ownership of host dependency management?
- **Context/Nuances**: Secret scanning is required before source and imported material are accepted. Installing or updating a host package from project procedures would exceed the project's responsibility and could trigger unsupported partial-update behavior on an older Arch host. Recording the scanner version is also outside the approved Story 1.1 plan. Scan evidence must not reproduce a detected secret value.
- **User Response**: Required the plan only to identify the dependency, not install it or record its version; then approved the corrected proposal.
- **Decision**: Identify Gitleaks as a required external dependency. Do not install, update, pin, or record its version. Scan the exported profile before its vendor commit, the complete working tree before the initial commit and vendor merge, and Git history after the merge. Reject unreviewed findings. Permit only narrow, justified, version-controlled exceptions. Retain non-sensitive scan evidence without reproducing detected values. If Gitleaks is unavailable, report an unmet precondition and do not attempt automatic remediation.
- **Status**: Accepted

## DEC-013
- **Question**: Should Story 1.1 introduce a project-owned script for repository and profile acceptance checks?
- **Context/Nuances**: The checks are required, but the project prohibits custom automation before a recurring need and demonstrated repetition justify it. Native Git, comparison, and Gitleaks commands can make the first import reviewable without adding an abstraction whose long-term contract is not yet known.
- **User Response**: Accepted the manual documented approach and requested direct registration.
- **Decision**: Do not introduce a custom repository-check script in Story 1.1. Document and execute native commands in `docs/procedures/update-archiso.md` to require a clean worktree, detect tracked ignored files, compare the imported profile with its exported source while excluding only `UPSTREAM.md`, inspect the vendor-to-main delta, run Gitleaks, and confirm that `build/`, `dist/`, and `evidence/` are not tracked. Retain a non-sensitive acceptance summary as evidence. Consider automation only after repeated use demonstrates recurring value.
- **Status**: Accepted

## DEC-014
- **Question**: Where should Archiso import acceptance evidence live when generated evidence is intentionally excluded from source control?
- **Context/Nuances**: Detailed command output is useful for local diagnosis but is generated, may be verbose, and can contain context inappropriate for authoritative source. Keeping only ignored evidence would leave future repository readers without a stable indication that the import was checked. The stable record should retain the conclusion without embedding full logs or potentially sensitive values.
- **User Response**: Accepted the recommended separation and requested direct registration.
- **Decision**: Store detailed generated import evidence under `evidence/archiso-import/<UTC-timestamp>-<package-version>/` and keep it ignored by Git. Record a stable, concise acceptance statement in `image/archiso/UPSTREAM.md` containing the check status, UTC date, checks performed, aggregate outcome, and local evidence path, without full logs or potentially sensitive values.
- **Status**: Accepted

## DEC-015
- **Question**: Should a later upstream profile update overlay the previous vendor tree or replace it completely?
- **Context/Nuances**: Overlay copying can silently retain files that upstream removed, causing the vendor snapshot to diverge from the selected official profile. A staged complete replacement allows Git to expose upstream additions, modifications, and deletions. The active vendor branch should not be left partially updated after failed checks.
- **User Response**: Accepted complete replacement and requested direct registration.
- **Decision**: Export each new official profile into temporary staging outside the active vendor tree and validate it there. Then completely replace `image/archiso/` on `vendor/archiso-releng` rather than overlaying files. Review `git diff --name-status` and run the approved scan and integrity checks before committing. If any check fails, restore the vendor branch and worktree to the previous vendor commit.
- **Status**: Accepted

## DEC-016
- **Question**: Which upstream and package revisions must identify an imported official Archiso profile?
- **Context/Nuances**: Archiso publishes release tags such as `v82`, while the official Arch packaging repository publishes package-release tags such as `82-1`; annotated tags can be resolved to exact commits. The binary package is the effective source of the imported profile, but package version alone does not fully explain the upstream release and packaging recipe that produced it. An approximate mapping would weaken traceability.
- **User Response**: Accepted the complete provenance chain and requested direct registration.
- **Decision**: Record the Archiso upstream release tag and resolved commit; the official Arch package's complete version, packaging-repository tag, and resolved commit; and the binary package filename and SHA-256 checksum. Treat the binary package as the effective source of the imported profile. Block the import if any required identity cannot be resolved unambiguously rather than recording an inferred approximation.
- **Status**: Accepted

## DEC-017
- **Question**: Should Story 1.1 permanently pin one Arch Linux Docker image digest in repository source?
- **Context/Nuances**: The initial import policy intentionally resolves the current official Archiso baseline. The `archlinux:latest` tag is mutable and cannot serve as an immutable provenance identity, but permanently pinning the first resolved digest would make later current-baseline updates awkward and would prematurely define the separate known-good retention strategy.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: Use `archlinux:latest` only to select the current official container image at each import. Immediately resolve and record the actual immutable image digest in `UPSTREAM.md` and generated evidence. Do not encode the initial digest as a permanent repository pin in Story 1.1. Defer retained or pinned known-good build environments to the later artifact strategy.
- **Status**: Superseded by DEC-046

## DEC-018
- **Question**: Must Story 1.1 publish `main` and `vendor/archiso-releng` to a remote before it can be considered complete?
- **Context/Nuances**: The remote destination is intentionally undecided. Requiring publication now would force an unrelated hosting decision, while Git can validate the branch topology and clean-clone behavior locally. Once a remote exists, omitting the vendor branch would make its update history unavailable to other clones.
- **User Response**: Accepted the recommended policy and requested direct registration.
- **Decision**: Remote publication is not a Story 1.1 completion requirement. Validate repository and branch behavior using a fresh local clone, and record the lack of a configured remote as an operational limitation rather than a story failure. When a remote is selected, publish both `main` and `vendor/archiso-releng`.
- **Status**: Accepted

## TODO-003
- **Question**: What branch-publication action is required after a repository remote is selected?
- **Context/Nuances**: Publishing only `main` would preserve the merged profile but omit the pure vendor history used for future upstream comparisons and updates.
- **User Response**: Approved later publication of both branches.
- **Decision**: After selecting and configuring the remote, publish both `main` and `vendor/archiso-releng` and document their intended roles.
- **Status**: Pending

## DEC-019
- **Question**: What scope should the initial root `AGENTS.md` have?
- **Context/Nuances**: Agents and contributors need immediately actionable repository rules, but reproducing the full architecture would create a second normative text likely to drift. Detailed rationale and contracts remain in the architecture, accepted ADRs, and focused procedures.
- **User Response**: Accepted the concise rule set and requested direct registration.
- **Decision**: Create a concise root `AGENTS.md` that requires agents and contributors to treat `docs/architecture.md` and accepted ADRs as normative; preserve workflow-managed directories; keep MirrorOS-owned content off the vendor branch; exclude secrets, personal configuration, and generated outputs; respect language and privilege boundaries; avoid resolving prototype-gated decisions prematurely; and update attribution, tests, and documentation with the implementation they govern. Link to the architecture and Archiso update procedure for details rather than duplicating them.
- **Status**: Accepted; preservation rule partially revised by DEC-050

## DEC-020
- **Question**: Should the repository include a root `CLAUDE.md`, and if so, how should it relate to `AGENTS.md`?
- **Context/Nuances**: Claude Code recognizes project instructions through `CLAUDE.md`, while maintaining duplicate agent rules would create drift. Its file-import syntax can delegate to the repository's canonical agent rules.
- **User Response**: Approved a minimal compatibility file and requested direct registration.
- **Decision**: Include a root `CLAUDE.md` in the initial baseline containing only `@AGENTS.md`. Keep `AGENTS.md` as the single maintained source of agent and contributor rules; do not add independent instructions to `CLAUDE.md`.
- **Status**: Accepted

## DEC-021
- **Question**: What initial policy should `.shellcheckrc` express before MirrorOS has project-owned shell implementation?
- **Context/Nuances**: The architecture requires ShellCheck to pass for project-owned shell. Global diagnostic exclusions established before code exists would hide future defects without evidence. The unmodified Archiso profile is vendor material and should not become subject to downstream style changes merely to satisfy MirrorOS linting.
- **User Response**: Accepted the minimal configuration and requested direct registration.
- **Decision**: Create `.shellcheckrc` with `shell=bash` and `severity=style`, with no globally excluded or disabled diagnostic codes. Apply ShellCheck to project-owned shell only, not the unmodified upstream profile. Any future exception must be justified near the affected code or through a specific reviewed decision.
- **Status**: Accepted

## DEC-022
- **Question**: What structure and naming convention should the initial ADR template establish?
- **Context/Nuances**: Future prototype-gated choices and architecture exceptions need a consistent, traceable decision format. The template itself must not imply that a fictional decision has been accepted.
- **User Response**: Accepted the recommended structure and requested direct registration.
- **Decision**: Create `docs/adr/0000-template.md`. Real ADRs use sequential `NNNN-short-title.md` filenames. The template contains title and identifier, status (`Proposed`, `Accepted`, `Rejected`, or `Superseded`), date, context and question, constraints and decision criteria, alternatives considered, evidence including applicable prototypes, decision, consequences and trade-offs, replacement or reversal boundary, required validation, references, and a superseding-ADR link when applicable. It contains no fictional decision.
- **Status**: Accepted

## DEC-023
- **Question**: Should the ADR directory include introductory guidance explaining why ADRs exist alongside `docs/architecture.md`?
- **Context/Nuances**: The architecture describes the currently normative design, whereas an ADR preserves the question, alternatives, evidence, trade-offs, and evolution behind one consequential choice. Git history alone does not reliably communicate that complete rationale. Existing architecture content does not need retroactive conversion into ADRs; the mechanism is primarily for future prototype-gated decisions and architectural exceptions.
- **User Response**: Requested clarification, then approved adding the recommended README.
- **Decision**: Add `docs/adr/README.md` explaining that `docs/architecture.md` is the consolidated current design while ADRs preserve the reasoning and history of individual decisions. Document ADR numbering, statuses, creation criteria, and supersession through forward links rather than deletion. Clarify that existing architecture decisions are not retroactively converted into ADRs and that future critical selections, prototype outcomes, and architecture exceptions use the ADR process.
- **Status**: Accepted

## DEC-024
- **Question**: How should the root MirrorOS license apply relative to the incorporated Archiso profile's upstream license?
- **Context/Nuances**: The architecture selects `GPL-3.0-only` for project-owned MirrorOS material, while the Archiso package declares `GPL-3.0-or-later`. Incorporation and attribution do not relicense copied upstream material. Adding MirrorOS headers to unmodified vendor files would falsely imply local authorship or changed licensing.
- **User Response**: Accepted the recommended licensing policy and requested direct registration.
- **Decision**: Place the complete official GPLv3 license text in the root `LICENSE` and distribute original MirrorOS material as `GPL-3.0-only` unless explicitly stated otherwise. Preserve the imported Archiso profile under its applicable `GPL-3.0-or-later` terms and retain its notices. Explain the distinction in `docs/attribution.md` and `image/archiso/UPSTREAM.md`. Use SPDX identifiers on future project-owned source files where appropriate. Do not add MirrorOS headers to unmodified vendor files.
- **Status**: Accepted

## DEC-025
- **Question**: What qualification state should `UPSTREAM.md` report when Story 1.1 can validate the import but build and boot qualification belong to later stories?
- **Context/Nuances**: Import identity and source safety can be established before the build and reference-VM operations exist. Collapsing these stages into one “validated” label would falsely represent an imported profile as a built or boot-qualified artifact. Future Archiso updates must eventually rerun all applicable gates.
- **User Response**: Accepted the explicit state model and requested direct registration.
- **Decision**: Report separate states in `UPSTREAM.md`: import integrity, secret scan, build qualification, and UEFI/OVMF boot qualification. Story 1.1 may complete with import integrity and secret scan passed while build and boot are explicitly `not yet performed`. Do not represent the profile as built or boot-qualified. Once Stories 1.3 and 1.4 provide those operations, every later Archiso update must rerun build and UEFI/OVMF boot qualification before being described as fully qualified.
- **Status**: Accepted

## DEC-026
- **Question**: Should the Story 1.1 procedure install, configure, enable, or start Docker when it is unavailable?
- **Context/Nuances**: Docker is the approved isolated Archiso environment, but changing host packages, services, group membership, or socket permissions would exceed repository bootstrap responsibilities and could disrupt a work machine. The Docker client is present on the current host, while its daemon is not currently reachable.
- **User Response**: Accepted the external-prerequisite boundary and requested direct registration.
- **Decision**: Identify Docker and an operational Docker daemon as external prerequisites. MirrorOS does not install or update Docker, enable or start its service, alter user groups, or change host socket permissions. If Docker is unavailable or inaccessible, report an actionable unmet precondition and stop without attempting remediation.
- **Status**: Accepted

## DEC-027
- **Question**: Should Story 1.1 create a `.gitleaks.toml` before any actual false positive is known?
- **Context/Nuances**: Preventive or empty custom configuration has no demonstrated need, while broad allowlists can silently weaken future scanning. The standard Gitleaks rules can establish the initial gate.
- **User Response**: Accepted the evidence-driven policy and requested direct registration.
- **Decision**: Run the initial scans with standard Gitleaks rules and do not create `.gitleaks.toml` preemptively. Add that file only in the reviewed change that addresses a real false positive, limiting the exception to the narrowest justified scope and documenting its rationale.
- **Status**: Accepted

## DEC-028
- **Question**: Should the primary checkout switch between `main` and `vendor/archiso-releng` during profile imports?
- **Context/Nuances**: Reusing one worktree for both branches increases the chance of carrying local state across branch switches and makes failure cleanup less clear. The ignored root `build/` area can host disposable Git worktrees without becoming authoritative source.
- **User Response**: Accepted the isolated worktree model and requested direct registration.
- **Decision**: Keep the primary checkout on `main`. Create a temporary vendor worktree at `build/worktrees/archiso-vendor/` for profile import, validation, complete replacement, and the vendor commit. Remove the worktree after the vendor commit, then perform the pending vendor merge from the primary `main` checkout. On failure before commit, discard the temporary worktree and leave the vendor branch at its preceding commit.
- **Status**: Accepted

## DEC-029
- **Question**: What does an identical imported profile mean when Git does not preserve ownership, timestamps, or every Unix permission bit?
- **Context/Nuances**: The official `releng` profile includes symbolic links and executable files. Git can preserve file content, path type for files and symlinks, symlink targets, and the executable bit, but it does not represent UID/GID, timestamps, directory modes, or arbitrary file-mode bits. Archiso expresses required installed-image ownership and special permissions through upstream profile declarations such as `profiledef.sh`.
- **User Response**: Accepted the Git-compatible integrity definition and requested direct registration.
- **Decision**: Profile integrity requires the same path set, the same path type (regular file, directory, or symbolic link), identical regular-file content, identical symbolic-link targets, and identical executable state for files. Do not require equality of UID/GID, timestamps, or permission metadata that Git cannot represent. Preserve upstream declarations of installed-image ownership and special permissions unchanged.
- **Status**: Accepted

## DEC-030
- **Question**: Must generated import evidence be scanned explicitly when it is ignored by Git and may not be covered by repository-oriented scanning?
- **Context/Nuances**: Detailed evidence is retained locally outside source control. A Git-history or tracked-tree scan cannot be assumed to inspect ignored files, yet retained evidence remains subject to the project's secret-safety requirements. Copying a detected value into a secondary report would compound exposure.
- **User Response**: Accepted the explicit evidence gate and requested direct registration.
- **Decision**: Run Gitleaks directly against each generated import-evidence directory before accepting the import. Do not rely on repository scanning to discover ignored evidence. If a finding occurs, do not reproduce its value in another report; sanitize or remove the affected evidence and rerun the scan. Record only the aggregate non-sensitive outcome in the stable acceptance record.
- **Status**: Accepted

## DEC-031
- **Question**: How should `UPSTREAM.md` represent MirrorOS-local deltas from the imported vendor profile?
- **Context/Nuances**: The record needs to be concise yet independently reproducible. Embedding a complete patch would duplicate Git and quickly become stale. `UPSTREAM.md` itself is intentionally absent from vendor, so including it in the comparison would create a permanent non-functional delta.
- **User Response**: Accepted the recommended format and requested direct registration.
- **Decision**: Record the exact vendor baseline commit, a concise list of functional MirrorOS changes, counts or statistics for added, modified, and deleted paths, and a reproducible command that displays the complete scoped diff. Exclude `image/archiso/UPSTREAM.md` from the local-delta comparison. Do not embed the full patch. The initial import's functional local-delta summary must be `None`.
- **Status**: Accepted

## DEC-032
- **Question**: Should Archiso import and merge commits use predictable messages that make upstream adoptions easy to locate?
- **Context/Nuances**: Vendor import commits and main integration commits have distinct responsibilities. Stable subjects improve history navigation, while duplicating the complete provenance record in commit bodies would create another mutable documentation surface.
- **User Response**: Accepted the recommended convention and requested direct registration.
- **Decision**: Name vendor snapshot commits `vendor(archiso): import releng <package-version>` and main integration commits `vendor(archiso): merge releng <package-version>`. Include the essential upstream and packaging revisions in each commit body, but keep the complete provenance and qualification state in `image/archiso/UPSTREAM.md`.
- **Status**: Accepted

## DEC-033
- **Question**: May an Archiso binary package be accepted based on its checksum alone without successful package-signature validation?
- **Context/Nuances**: A SHA-256 checksum identifies exact bytes but does not establish who published them. The official Arch container and repositories provide Pacman signature verification through the Arch keyring. Weakening repository signature policy would break the intended trust chain.
- **User Response**: Accepted mandatory signature validation and requested direct registration.
- **Decision**: Obtain Archiso only from configured official Arch repositories and require Pacman to validate its package signature using the container's Arch keyring. Do not disable or weaken `SigLevel` or otherwise bypass signature verification. Record the aggregate successful signature-validation state in `UPSTREAM.md` without copying keyring material or sensitive diagnostic content. The package SHA-256 remains an identity field, not a substitute for authenticity validation.
- **Status**: Accepted

## DEC-034
- **Question**: May a new import continue from cached container, package, or Git data when official registries or repositories are unavailable?
- **Context/Nuances**: Story 1.1 intentionally resolves the current official baseline and requires an unambiguous online provenance chain. Cached bytes may accelerate retrieval but cannot demonstrate that a selected version is current or that all official identities remain resolvable. Silent fallback would misrepresent a stale baseline as current.
- **User Response**: Accepted the fail-closed policy and requested direct registration.
- **Decision**: Require online confirmation of the official container image, Arch package repositories, Archiso upstream repository, and official packaging repository for every new import. If any required source is unavailable, stop with an unmet precondition. A cache may satisfy matching downloads after official resolution, but it must never silently select a stale image, package, or revision as the new baseline.
- **Status**: Accepted

## DEC-035
- **Question**: Must the installed Archiso files inside the ephemeral container be verified against package metadata before exporting the `releng` profile?
- **Context/Nuances**: Package-signature and checksum validation authenticate the package archive, while the import copies from the package's installed path. A native package-integrity check closes the gap between those stages even though the container is freshly created and ephemeral.
- **User Response**: Accepted the installation-integrity check and requested direct registration.
- **Decision**: Run `pacman -Qkk archiso` inside the container after package installation and before profile export. Abort the import if it reports any missing or altered Archiso package file. Only after this check passes may the procedure export `releng` and apply the approved source-to-export profile comparison.
- **Status**: Accepted

## DEC-036
- **Question**: How should a later build handle time passing between profile import and ISO construction on a rolling Arch base?
- **Context/Nuances**: A fresh build container may resolve a newer Archiso tool than the package that supplied the committed profile. That combination may work accidentally but would violate the requirement to qualify tool and profile together. Other image packages naturally continue to resolve from current repositories for the current-package track; exact historical reconstruction requires the separate future known-good snapshot strategy. Long-lived containers would introduce hidden state rather than solve this mismatch.
- **User Response**: Accepted an exact version gate and requested direct registration.
- **Decision**: Before every build, resolve Archiso in a fresh current Arch container and compare its exact package version with the profile package version recorded in `UPSTREAM.md`. Continue only when they match. If they differ, stop the build and complete a new official profile import and vendor merge before building. Do not silently build an older profile with a newer tool or retain a mutable container between runs. Record the packages actually resolved into the ISO in later build metadata; defer exact historical package reconstruction to the known-good artifact strategy.
- **Status**: Accepted

## DEC-037
- **Question**: How should the normal MirrorOS change-and-build workflow expose and recover from an Archiso profile/tool version mismatch?
- **Context/Nuances**: Starting `mkarchiso` before detecting a mismatch would waste time and could produce an unsupported artifact. Automatically updating the profile would combine a reviewed build action with a separate upstream import and merge, obscuring new upstream changes relative to the maintainer's local change. Import and build must remain independently invoked and reviewable.
- **User Response**: Confirmed the explicit preflight, import, and retry workflow and requested direct registration.
- **Decision**: Every build begins with a lightweight version preflight before invoking `mkarchiso` or producing an ISO. A matching version proceeds to construction. A mismatch stops without an artifact, reports an actionable unmet precondition, and directs the maintainer to the Archiso update procedure. The maintainer explicitly imports, reviews, and merges the new upstream profile, then invokes the build again. Document the update side in `docs/procedures/update-archiso.md` and the build side in the future Story 1.3 procedure; never update the profile automatically from the build operation.
- **Status**: Accepted

## TODO-004
- **Question**: What Archiso version-preflight behavior must Story 1.3 implement?
- **Context/Nuances**: DEC-036 and DEC-037 establish a cross-story contract before the build operation exists.
- **User Response**: Approved carrying the preflight into Story 1.3.
- **Decision**: Story 1.3 must resolve the container's Archiso package version before `mkarchiso`, compare it exactly with `UPSTREAM.md`, stop without an ISO on mismatch, return the applicable unmet-precondition outcome, point to the update procedure, and require an explicit later build retry after import and merge.
- **Status**: Pending

## DEC-038
- **Question**: How should Story 1.1 validate that a fresh clone contains all authoritative source and branch history without relying on uncommitted local state?
- **Context/Nuances**: Copying the current directory would retain untracked files and generated residue, so it would not test reconstruction from Git. A local clone can exercise committed object transfer before a remote destination exists. Build and boot behavior remain later-story gates.
- **User Response**: Accepted after a detailed explanation and requested direct registration.
- **Decision**: Make a fresh clone in a temporary directory outside the repository using `git clone --no-local` from the local authoritative repository. Require a clean `main` checkout, availability of `origin/vendor/archiso-releng`, presence of the imported profile, `UPSTREAM.md`, attribution, update procedure, license, and agent-governance files, and absence of `build/`, `dist/`, and `evidence/`. Run applicable read-only repository inspections there. Save a non-sensitive result summary into the original import evidence, then remove the temporary clone. Treat this as the final Story 1.1 acceptance gate, not as build or boot qualification.
- **Status**: Accepted

## DEC-039
- **Question**: Should the profile-acquisition container run with `--privileged` even though it does not execute `mkarchiso`?
- **Context/Nuances**: Package update, Archiso integrity verification, provenance collection, and `docker cp` do not require the mount and chroot capabilities needed during ISO construction. Reusing privileged execution for convenience would violate the project's narrow-privilege boundary.
- **User Response**: Accepted the privilege separation and requested direct registration.
- **Decision**: Run the Archiso profile-acquisition container without additional privileges. Reserve privileged Docker execution exclusively for the ephemeral build container while `mkarchiso` requires it. Do not reuse a privileged build container for profile import merely for convenience.
- **Status**: Accepted

## DEC-040
- **Question**: Should Story 1.1 automatically configure the Git author identity required for the initial and vendor commits?
- **Context/Nuances**: Git commits require an author name and email. Automatically changing local or global configuration could expose an unintended personal or work identity, while inventing a generic identity would weaken accountability. Git already stores the selected author in commit metadata, so duplicating it in provenance or evidence is unnecessary.
- **User Response**: Accepted the external-prerequisite policy and requested direct registration.
- **Decision**: Treat an explicitly configured Git author identity as an external prerequisite. Do not set or modify local or global `user.name` or `user.email`, and do not invent a fallback identity. If identity is unavailable, stop before the first commit and ask the maintainer to configure it consciously. Do not copy the author name or email into `UPSTREAM.md` or generated evidence beyond normal Git commit metadata.
- **Status**: Accepted

## DEC-041
- **Question**: Which CPU architecture should the initial imported Archiso profile support?
- **Context/Nuances**: The official `releng` profile and MirrorOS's target laptop and reference VM align on `x86_64`. Introducing ARM or another architecture would require additional profile, package, firmware, build, and qualification paths outside the MVP hardware boundary.
- **User Response**: Confirmed `x86_64` only and requested direct registration.
- **Decision**: Support only `x86_64` in the initial Archiso profile and MVP bootstrap path. Preserve the official `releng` profile for that architecture without adding ARM or any multi-architecture matrix.
- **Status**: Accepted

## DEC-042
- **Question**: Should Docker explicitly select a platform for Archiso acquisition and build containers?
- **Context/Nuances**: The MVP supports only `x86_64`, represented as `linux/amd64` by Docker. Relying on implicit host selection could choose another image variant on a different machine and obscure unsupported cross-architecture emulation.
- **User Response**: Accepted explicit platform selection and requested direct registration.
- **Decision**: Specify `--platform=linux/amd64` for Docker image acquisition and container creation used by the Archiso profile and build paths. Do not support cross-platform emulation in the MVP.
- **Status**: Accepted

## DEC-043
- **Question**: Should the optional persistent Pacman package cache be used by default for normal imports and builds?
- **Context/Nuances**: Reusing downloaded package archives materially improves repeated rolling-release operations, but correctness must not depend on cached state. The cache is internal to Docker and does not create host-tree ownership issues.
- **User Response**: Accepted default cache reuse and requested direct registration.
- **Decision**: Use a Docker volume named `mirroros-pacman-cache` by default for `/var/cache/pacman/pkg` in normal profile imports and builds. Document an explicit removal command. Treat absence or failure of the cache as non-blocking by allowing recreation or an uncached run. Require at least one no-cache execution during qualification so the cache never becomes an undeclared dependency.
- **Status**: Accepted

## DEC-044
- **Question**: May the first qualified bootstrap artifact retain Archiso's upstream name, boot menu, and visual identity rather than showing MirrorOS branding?
- **Context/Nuances**: The initial profile is deliberately functionally identical to upstream. Branding, volume-label, or menu changes would create local profile deltas before the official baseline has demonstrated successful construction and boot. Artifact provenance can establish MirrorOS ownership of the build process without altering live-media presentation.
- **User Response**: Accepted an upstream-visual first artifact and requested direct registration.
- **Decision**: Keep the first bootstrap artifact's name, menus, labels, and visual presentation unchanged from the imported official profile. Identify it as a MirrorOS-produced bootstrap through repository source identity, build metadata, and checksum rather than branding. Defer any presentation or naming customization until after the upstream baseline is built and boot-qualified and a separate change justifies the delta.
- **Status**: Accepted

## DEC-045
- **Question**: Should the pre-import baseline `docs/attribution.md` claim Archiso incorporation before the profile has actually been merged?
- **Context/Nuances**: The attribution framework must exist before external material enters the repository, but stating that Archiso has already been incorporated in the baseline would be historically false. The first vendor merge is the point at which the copied profile and its detailed provenance become part of `main`.
- **User Response**: Accepted the staged attribution order and requested direct registration.
- **Decision**: In the initial baseline commit, `docs/attribution.md` contains the repository attribution policy and entry format but does not claim completed Archiso incorporation. During the initial pending vendor merge, add the Archiso index entry together with `image/archiso/UPSTREAM.md`, so attribution and incorporated material become authoritative atomically in the same merge commit.
- **Status**: Accepted

## DEC-046
- **Question**: Which repositories and container image are canonical for Archiso provenance, and should the selected Arch container have publisher-signature verification?
- **Context/Nuances**: The technical research cited Archiso's GitHub repository, but that repository identifies itself as a read-only mirror whose homepage is the Arch GitLab project. The installed and synchronized official Arch package metadata also identifies GitLab as upstream. Matching release tags were verified to resolve to the same commits on both forges, so the research conclusions remain valid, while operational provenance should follow the canonical maintainer location. Arch's official OCI-image documentation distinguishes the weekly Docker Official Image, which is not Cosign-signed, from Arch-owned daily images that carry keyless Cosign signatures tied to Arch's GitLab CI. The exact tag remains mutable and therefore is not sufficient identity.
- **User Response**: Delegated the recommendation, accepted the canonical GitLab and signed-image proposal, and requested direct registration.
- **Decision**: Treat `https://gitlab.archlinux.org/archlinux/archiso` as the canonical Archiso source and `https://gitlab.archlinux.org/archlinux/packaging/packages/archiso` as the canonical official packaging source. Treat the GitHub Archiso repository only as a read-only consultation mirror, never as the provenance authority. Resolve the binary package from the official Arch `extra` repository. Replace the container selector from DEC-017 with the Arch-owned signed daily image `docker.io/archlinux/archlinux:latest`. Identify Cosign as an external prerequisite without installing, updating, pinning, or otherwise managing it. Verify the image's keyless signature against the documented Arch GitLab CI identity and issuer, then resolve and record its immutable digest before use. Preserve DEC-017's policy that the resolved digest is recorded per import rather than permanently pinned in Story 1.1.
- **Status**: Accepted

## DEC-047
- **Question**: In what order must the mutable container tag, immutable digest, Cosign verification, and container creation be handled to prevent a tag-change race?
- **Context/Nuances**: Verifying `latest` and later creating a container from `latest` could select different manifests if the tag moves between operations. Signature validity must apply to the exact bytes that Docker subsequently executes.
- **User Response**: Accepted digest-bound verification and requested direct registration.
- **Decision**: Resolve or pull `docker.io/archlinux/archlinux:latest` without creating a container, obtain the selected `linux/amd64` manifest digest, verify the `image@sha256:...` reference with Cosign, and create the acquisition or build container from that same digest-qualified reference. Record that exact digest. Never verify one mutable tag resolution and execute a later tag resolution.
- **Status**: Accepted

## DEC-048
- **Question**: Should Story 1.1 establish a periodic Archiso update schedule?
- **Context/Nuances**: Scheduled current-package canaries and automated qualification require build and boot operations that do not exist until later stories. A fixed cadence now would add maintenance and CI policy without an executable qualification path.
- **User Response**: Accepted event-driven updates and requested direct registration.
- **Decision**: Do not establish a periodic Archiso update schedule in Story 1.1. Start an update when the build preflight detects a profile/tool version mismatch or when the maintainer deliberately initiates an upstream evaluation. Defer scheduled canaries and automated update qualification until the build and boot gates exist.
- **Status**: Accepted

## TODO-005
- **Question**: What Docker acquisition behavior must Story 1.1 document and qualify before profile import is supported?
- **Context/Nuances**: Profile acquisition is unprivileged and belongs to Story 1.1. Combining it with privileged ISO construction obscured the story completion boundary.
- **User Response**: Approved separating acquisition from build qualification.
- **Decision**: Story 1.1 must document and exercise the exact acquisition-container lifecycle; `linux/amd64` digest resolution and Cosign verification; package signature, identity, checksum, and installed-file validation; profile export and recursive comparison; normal-user ownership after `docker cp`; default cache reuse and removal; one uncached acquisition; and preservation plus scanning of failure evidence. Only this acquisition scope blocks Story 1.1 completion.
- **Status**: Pending

## TODO-006
- **Question**: What Docker build behavior must Story 1.3 document and qualify before ISO construction is supported?
- **Context/Nuances**: Privileged `mkarchiso` execution, disposable work/output storage, and artifact export do not belong to Story 1.1 even though the shared Docker model was selected during this interview.
- **User Response**: Approved separating build qualification from acquisition.
- **Decision**: Story 1.3 must document and exercise the privileged build-container lifecycle; read-only profile input; internal disposable `/work` and `/out`; artifact and evidence export before cleanup; normal-user ownership after `docker cp`; cache reuse and removal; one no-cache build; failure-evidence preservation and scanning; and cleanup after verified export. This is additional to the exact profile/tool version preflight in TODO-004.
- **Status**: Pending

## DEC-049
- **Question**: Is the Story 1.1 technical interview complete with enough shared understanding to begin implementation without unresolved critical design choices?
- **Context/Nuances**: The consolidated plan now covers repository initialization and governance, upstream branch topology, canonical sources, signed container acquisition, profile integrity, provenance, attribution, licensing, secret scanning, evidence, update and merge behavior, architecture and boot scope, and clean-clone acceptance. Remaining work is explicitly scoped: Story 1.1 implementation documentation and acquisition qualification, later remote publication, and Story 1.3 build preflight and privileged-build qualification.
- **User Response**: Confirmed closure and requested direct registration.
- **Decision**: Close the Story 1.1 technical interview. The consolidated plan is ready to drive implementation. No critical Story 1.1 design decision remains implicit; implementation findings that contradict the plan must return to an explicit decision rather than being resolved silently.
- **Status**: Accepted

## DEC-050
- **Question**: Should the Sheaf/Pi/Claude workflow tooling directories remain in the repository baseline, and how should `docs/.obsidian/` be treated?
- **Context/Nuances**: `.pi/`, `.claude/`, `.sheaf/`, and `.sheaf-runtime/` held workflow tooling that the project will no longer use; `.claude/` had not been covered by DEC-001. The only project artifact among them was the brainstorming session, referenced from the frontmatter of the product brief, PRD, epics, architecture, and technical research. `docs/architecture.md` listed these directories in its project tree and forbade their removal. The repository was not yet under Git, so removal is irreversible locally. `docs/.obsidian/` is local editor configuration rather than authoritative source.
- **User Response**: Requested moving the brainstorming artifact into `docs/` and removing the four tooling directories; approved the proposal with the correction that `docs/.obsidian/` must be ignored by Git.
- **Decision**: Move the brainstorming session to `docs/brainstorming/brainstorming-session-2026-09-23-201236.md` and update every frontmatter reference. Remove `.pi/`, `.claude/`, `.sheaf/`, and `.sheaf-runtime/` before the baseline commit (executed during this interview). Keep `docs/.obsidian/` on disk but add a root-anchored `/docs/.obsidian/` entry to `.gitignore`, so it is excluded from the baseline commit. Update `docs/architecture.md` to drop the removed directories from the project tree and to describe `docs/.obsidian/` as ignored local editor configuration. `AGENTS.md` protects ignored local documentation tooling instead of "workflow-managed directories". This partially revises DEC-001, DEC-008, DEC-010, and DEC-019.
- **Status**: Accepted

## DEC-051
- **Question**: Should Story 1.1 be materialized as one implementation plan or split by external-prerequisite boundary?
- **Context/Nuances**: The governance baseline requires only Git and Gitleaks, whereas acquisition and vendor integration additionally require an operational Docker daemon, Cosign, and online access to official Arch sources. At interview time Gitleaks and Cosign were absent from the host and the Docker daemon was not reachable. A single plan would block governance work on those external prerequisites and lack an intermediate verifiable stopping point.
- **User Response**: Approved the recommended split.
- **Decision**: Materialize Story 1.1 as two plans. Plan 01-01 (`repository-governance-baseline`) covers Git initialization, the pre-import governance foundation including `docs/procedures/update-archiso.md`, the pre-commit secret scan, and the baseline commit, stopping before `vendor/archiso-releng` is created; it has no plan dependencies. Plan 01-02 (`archiso-releng-vendor-import`) depends on 01-01 and covers signed-container acquisition, the vendor worktree import, the pending `--no-ff` merge with `UPSTREAM.md` and the attribution entry, scans and evidence, and the clean-clone gate; it exercises and, where necessary, corrects the procedure written in 01-01 and closes TODO-001 and TODO-005.
- **Status**: Accepted

## DEC-052
- **Question**: Where should corrections to `docs/procedures/update-archiso.md` discovered during its first execution in plan 01-02, and removal of its "Pending first execution" status note, be committed?
- **Context/Nuances**: The procedure is written in plan 01-01 without being exercised. Committing corrections before creating `vendor/archiso-releng` would violate DEC-003's branch point and is impossible because defects surface only during execution. Folding them into the vendor merge commit would mix documentation fixes with upstream adoption, contrary to DEC-006's atomic adoption-plus-provenance scope.
- **User Response**: Accepted the recommended placement.
- **Decision**: Commit all first-execution procedure corrections and the removal of the status note in a single commit on `main`, `docs(procedures): record first Archiso import execution`, created after the vendor merge commit and before the clean-clone gate so that gate validates the final state. Corrections are limited to mechanical defects (syntax, flags, paths, ordering details); any correction that would alter an accepted decision stops execution and returns to an explicit decision.
- **Status**: Accepted

## DEC-053
- **Question**: How should plan 01-02 exercise the failure-evidence path required by TODO-005 when a clean import never traverses it?
- **Context/Nuances**: TODO-005 requires exercising, not only documenting, container retention on failure, diagnostic export, Gitleaks scanning of that evidence, and cleanup afterwards. Inducing failure by weakening package-signature policy is forbidden by DEC-033, and network interruption is nondeterministic. A deliberately tampered staging copy produces a deterministic integrity-comparison failure without side effects on the host, repositories, or branches.
- **User Response**: Accepted the recommended drill.
- **Decision**: Before the real import, run a controlled failure drill: create a normal unprivileged acquisition container from the verified digest, export the profile, deliberately tamper with a staging copy (for example, delete one file), run the integrity comparison and observe the failure, confirm the container still exists, export its diagnostics into `evidence/archiso-import/<UTC-timestamp>-failure-drill/`, scan that directory with Gitleaks, and only then remove the container and staging. The drill never touches `vendor/archiso-releng` or `main`, is not part of the accepted import, and only its aggregate outcome is recorded in `UPSTREAM.md`.
- **Status**: Accepted

## DEC-054
- **Question**: In what sequence should plan 01-02 qualify default cache reuse, one uncached acquisition, and explicit cache removal?
- **Context/Nuances**: DEC-043 makes `mirroros-pacman-cache` the default for normal imports while requiring at least one no-cache execution, and TODO-005 requires exercising reuse and removal. The strongest proof of cache independence is an uncached run that reproduces the accepted import's identity. Arch repositories are rolling, so a new Archiso release could appear between runs and cause a mismatch unrelated to caching.
- **User Response**: Accepted the recommended sequence.
- **Decision**: The failure drill and the real import both use `mirroros-pacman-cache`; the real import's evidence demonstrates reuse of the cached Archiso package with a matching SHA-256. A subsequent ephemeral acquisition without any cache volume must resolve the same package version and SHA-256 and export a profile identical to the imported one under DEC-029 semantics. The plan ends by running `docker volume rm mirroros-pacman-cache` and confirming its absence with `docker volume inspect`. If upstream publishes a different version between runs, the import is not accepted and the whole sequence restarts; mixed versions are never accepted.
- **Status**: Accepted

## DEC-055
- **Question**: How is DEC-006's maintainer review of the pending vendor merge preserved when plan 01-02 is executed by an agent?
- **Context/Nuances**: DEC-006 requires deliberate review and resolution while the merge is pending, before the merge commit exists. Agent execution would silently skip that review unless the plan makes it an explicit stopping point. The vendor import commit is fully verifiable mechanically (integrity comparison, `--name-status`, Gitleaks) and involves no judgment. The procedure-correction commit (DEC-052) is bounded to mechanical fixes and is validated by the clean-clone gate.
- **User Response**: Accepted the recommended checkpoint.
- **Decision**: Plan 01-02 contains exactly one blocking `checkpoint:human-verify`, placed after `git merge --no-ff --no-commit` has been prepared and before the merge commit. The agent presents `git diff --cached --name-status`, the complete `image/archiso/UPSTREAM.md`, the new `docs/attribution.md` entry, and the check summary. Only an explicit "approved" permits the merge commit; requested changes are applied inside the pending merge, or the merge is aborted. The vendor import commit and the procedure-correction commit have no human checkpoint.
- **Status**: Accepted
