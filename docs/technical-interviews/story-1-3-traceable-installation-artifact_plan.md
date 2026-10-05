# Story 1.3 Traceable Installation Artifact — Consolidated Plan

## Design Status

The design interview is closed, refined by implementation-planning deltas. Story 1.3 TODO-001 is obsolete because repository attribution and database capture were removed. [DEC-086] No implementation or qualification is declared complete. Concrete mechanical details are implementing-agent deliverables under the contracts and tests below. Any finding that requires changing an approved contract must return for an explicit decision. [DEC-077, DEC-086]

## Scope and Existing Foundation

Story 1.3 designs traceable installation-artifact construction using the existing attributed profile in `image/archiso/` and upstream `mkarchiso`. The design covers build prerequisites, isolated work and output, source and tool metadata, resolved package manifests, checksums, secret inspection, diagnostic evidence, and build acceptance. The interview does not implement runtime code or introduce functional personalization of the imported profile. [DEC-001]

Repository inspection found that `operations/build` currently provides help and refuses unimplemented domain execution, while `docs/procedures/build.md` leaves concrete build contracts pending. The upstream record identifies Archiso 91-1, no functional local delta, and no completed build or UEFI qualification. These are starting-state observations, not a tool-version pin or evidence of build readiness. [DEC-001]

## Repeatability and Traceability

The design must distinguish repeatability of a documented construction procedure from byte-identical reconstruction. Rolling repositories may resolve different package versions on later runs. Each result must remain attributable and diagnosable through its actual source state, repositories, resolved packages, and relevant tools; this story does not promise historical package reconstruction or binary-identical images. Development builds may use dirty source, while formal story acceptance requires a clean clone of a commit. A fixed temporary profile copy is the build input; its identity is the Git tree hash for clean builds and the dirty-path list for development builds, as defined below. [DEC-089] Archiso itself must satisfy the inherited exact profile/tool package-version gate described below; rolling resolution is not permission to combine unmatched Archiso versions. [DEC-001, DEC-002, DEC-003, DEC-008]

## Acceptance and Qualification Boundaries

Build acceptance means that construction and the required build controls have succeeded. It does not certify UEFI boot, networking, installation, environment configuration, hibernation, capability readiness, accepted-known-good status, or physical-laptop eligibility. Boot and networking qualification belong to Story 1.4; subsequent promotion requires its own evidence. A checksum establishes file-integrity comparison, not functional correctness or absence of secrets. [DEC-001]

## Secret Inspection and Diagnostic Constraints

Secret inspection covers content created by MirrorOS: the captured profile, retained logs, and generated metadata and evidence. Story 1.2 deferred internal ISO inspection to this story. This story satisfies that deferral by scanning MirrorOS's only contribution to the artifact, not by extracting and scanning upstream package content, as defined in the scan-scope section below. [DEC-001, DEC-085]

Diagnostic handling preserves useful upstream context. Non-exposure of secrets in terminal output, metadata, and retained logs rests on the invariant that the build container receives no host secrets; upstream output is therefore shown live and logged, and Gitleaks scanning of logs and records detects rather than prevents exposure. No custom live redaction subsystem is introduced. [DEC-001, DEC-045, DEC-063, DEC-085, DEC-088]

## Inherited Build Environment and Container Lifecycle

Docker is the approved environment for ISO construction, not an unresolved alternative to native-host construction. Do not update the work host or install Archiso on it. Resolve the current Arch-owned signed daily image `docker.io/archlinux/archlinux:latest` for `linux/amd64`, verify its digest-qualified reference with Cosign against the documented Arch CI identity and issuer, and execute that same verified digest. Record the actual digest; do not permanently pin the acquisition digest or require that build and import share it. Perform the complete package update and install Archiso inside the fresh container. These constraints carry forward Story 1.1 DEC-004, DEC-041, DEC-042, DEC-046, and DEC-047. [DEC-002]

Run `mkarchiso` in an ephemeral privileged build container with the profile mounted read-only and disposable `/work` and `/out` inside Docker. Do not use writable host output bind mounts or preserve mutable build containers between runs. The lifecycle is create, execute, export, verify, and remove: export artifacts and relevant success or failure evidence with `docker cp`, verify export and normal-user ownership, and only then clean up. Do not use automatic `--rm` that would destroy outputs or diagnostics prematurely. Privileged Docker provides operational isolation, not a VM-equivalent security boundary; acquisition remains unprivileged and separate. These constraints carry forward Story 1.1 DEC-004, DEC-039, and TODO-006. [DEC-002]

The automated build reads the Cosign certificate identity regexp and OIDC issuer from a reviewed, versioned configuration file under `image/builder/`, whose comments cite the official Arch Linux OCI image documentation and retrieval date. The values are taken from that documentation, never guessed, and confirmed by a real verification before the diff-review checkpoint. Verification failure, including after an upstream identity rotation, stops with normalized status 2 and guidance to update the file; verification is never skipped. The values are recorded in artifact metadata, and the manual import procedure is unchanged. [DEC-091]

Docker and an accessible daemon are external prerequisites. MirrorOS does not install or update Docker, start its service, alter host groups, or change socket permissions. Cosign is also an external prerequisite, not managed by MirrorOS. Missing prerequisites stop the operation with actionable guidance rather than automatic host remediation, following Story 1.1 DEC-026 and DEC-046. [DEC-002]

## Exact Archiso Profile/Tool Version Gate

Before `mkarchiso`, compare the container's resolved Archiso package version exactly with the complete profile package version recorded in `image/archiso/UPSTREAM.md`, including release and any epoch components. The current imported identity is `91-1`; equality of only the upstream major release is insufficient. A match permits construction. A mismatch stops without an ISO, returns the unmet-precondition outcome, and directs the maintainer to `docs/procedures/update-archiso.md`. The maintainer explicitly imports, reviews, and merges the new profile before separately retrying the build. Do not import or merge automatically, silently mix versions, or automatically select a historical package to bypass the mismatch. This carries forward Story 1.1 DEC-036, DEC-037, and TODO-004; `91-1` is not a permanent design pin. [DEC-002]

## Cache and Build Qualification Obligations

Normal builds use the Docker volume `mirroros-pacman-cache` for `/var/cache/pacman/pkg` by default. The cache is removable, non-authoritative, and not required for correctness; absence or failure allows recreation or an uncached run. Document explicit removal and qualify that construction does not depend on cached package contents through a build from an empty cache. [DEC-090] Story 1.3 must exercise privileged construction, read-only input, internal disposable storage, verified export with normal-user ownership, cache reuse and removal, preservation and secret scanning of failure evidence, and cleanup after verified export. These obligations carry forward Story 1.1 DEC-043 and TODO-006; their real build qualification sequence and failure drill are defined below and remain unexecuted. [DEC-002, DEC-067, DEC-072, DEC-090]

The first artifact retains the imported upstream name, menus, labels, and visual presentation. MirrorOS build identity comes from source metadata and checksum rather than an early branding change, following Story 1.1 DEC-044. Subsequent presentation changes require separate approval after baseline build and boot qualification. [DEC-002]

## Readiness Dependency and Review Discipline

The supported environment, version gate, source-capture policy, invocation, privilege boundary, resource layout, metadata content and formats, package records, secret inspection, diagnostics, outcomes, recovery, and validation strategy are approved in the sections below. No readiness dependency remains: Story 1.3 TODO-001 is obsolete since repository attribution and database capture were removed. [DEC-086] Concrete command spelling, JSON fields, and mechanical details remain implementation deliverables subject to these contracts and tests; they are not unapproved alternatives or evidence that implementation and qualification have occurred. [DEC-001, DEC-002, DEC-003, DEC-064, DEC-067, DEC-077]

Before further recommendations, review the applicable preceding interview plans and logs and cross-check architecture, ADR guidance, procedures, and implementation records already used in the discussion. Cross-story IDs must identify their source story because numbering restarts in each interview. Distinguish approved design from present implementation state and unresolved detail; do not generalize a prior story's particular commit checkpoint or qualification sequence into a new approval. Any actual normative conflict must be surfaced rather than silently resolved. The native-host recommendation was unapproved and withdrawn; it is not a supported alternative in this plan. [DEC-002]

## Development Source State and Formal Acceptance

Development builds may use local uncommitted changes. Their metadata records the source commit, `dirty: true`, and the list of modified or untracked paths within the profile (paths only, no content). No content hash identifies dirty profile inputs: two dirty builds with the same changed paths but different content are not distinguishable from metadata. This is accepted because dirty builds are never acceptance evidence. New non-ignored files are included and tracked/ignored conflicts block construction under the inclusion rules below. All required build and secret-safety controls still apply to development builds. [DEC-003, DEC-005, DEC-006, DEC-019, DEC-089]

Formal Story 1.3 acceptance requires construction from a clean clone of a committed candidate, demonstrating reconstruction from Git rather than dependence on local changes. Its profile is identified by the commit and the Git tree hash of `image/archiso` (`git rev-parse HEAD:image/archiso`). Experimental dirty-build results must not be presented as acceptance evidence. This source-state requirement is additional to the construction gates, not a substitute for them, and does not itself confer boot or later artifact qualification. [DEC-001, DEC-002, DEC-003, DEC-011, DEC-089]

## Fixed Build Input and Profile Identity

Each build uses a fixed temporary copy of the profile as the effective read-only input to `mkarchiso`, rather than mounting the mutable working profile directly. Scan the captured copy with Gitleaks before construction. A clean repository materializes the copy from `git archive` of the source commit; a dirty repository copies the working profile under the inclusion rules below. Profile identity is the Git tree hash for clean builds and the dirty-path list for dirty builds; no identification archive, normalization, or content inventory is produced. The resolved-package manifest and final ISO checksum remain distinct required outputs. Concrete copy and enumeration commands are implementation deliverables. [DEC-003, DEC-008, DEC-011, DEC-059, DEC-077, DEC-089]

## New and Ignored Profile Files

Development capture includes new untracked, non-ignored files within `image/archiso/`, allowing new profile inputs to be tested before staging or committing. These files receive the same secret scanning as other captured inputs, and their presence marks the build dirty and appears in the dirty-path list. Ignored files are excluded from capture so ignored local residue cannot silently enter the image. Formal acceptance continues to use only the content available in a clean clone of a committed candidate. [DEC-003, DEC-005, DEC-089]

Concrete Git enumeration is an implementation deliverable governed by these inclusion rules and their tests. Paths that are both tracked and matched by ignore rules block construction under the conflict guard below; do not discard committed input or include ignored material silently. [DEC-005, DEC-006, DEC-077]

## Tracked/Ignored Input Conflict

If a profile path is tracked by Git and also matches an ignore rule, stop the build with normalized status `2` and identify the affected paths. The maintainer must correct the ignore rule or consciously remove the file from tracking before retrying. Neither silent omission of committed input nor silent inclusion of ignored material is permitted, and the build must not change Git state or ignore rules automatically. Repository inspection found no current conflicting profile files. [DEC-005, DEC-006]

## Capture Limitation and Comparative Rationale

Capture from an editable working tree is not atomic. Document that the maintainer must not edit profile inputs during capture; do not promise detection of concurrent changes. Once captured, only the fixed copy is used for construction. [DEC-008, DEC-089]

Staging a fixed copy with existing tools follows inspection of [Omarchy's host build entry point](https://github.com/omacom/omarchy-iso/blob/quattro/bin/omarchy-iso-make), [its container build script](https://github.com/omacom/omarchy-iso/blob/quattro/builder/build-iso.sh), and [Ryoku's ISO build script](https://github.com/Ryoku-dev/ryoku/blob/main/installation/iso/build.sh). The examined scripts stage inputs and use existing tools without per-file inventories. Ryoku exports its embedded repository payload from `HEAD`, but copies or compiles other inputs from the working tree; this is not evidence that its entire image derives solely from a commit. Omarchy's automatic container removal and writable host output mounts are not adopted. These mutable-branch research references support the rationale, not a blanket guarantee about upstream projects or permission to import their implementation. [DEC-008]

## Committed Profile Export for Formal Acceptance

Clean builds, including formal acceptance builds from a clean clone, use `git archive` to export the profile from the evaluated commit, then materialize that export as the fixed copy used for construction. This excludes local files absent from the selected commit. Concrete invocation and path handling are implementation deliverables. [DEC-003, DEC-011, DEC-059]

The export preserves Git-represented content, symbolic-link targets, and executable state. It does not recover original UID/GID, timestamps, or arbitrary permission bits that Git does not represent, and the materialized copy is not otherwise normalized. Keep the imported `profiledef.sh` unchanged: its explicit permissions cover selected installed-image paths. Retain all secret-safety, construction, and normal-user output-ownership checks. [DEC-002, DEC-011, DEC-089]

## Temporary Source Access Protection

Create the temporary source area with filesystem mode 0700. This limits access to the invoking user and root, including before scanning can discover a secret. Do not change the captured contents' permissions to establish this protection; use the enclosing private directory. These permissions neither exclude root nor provide a security sandbox and do not change the installed-image permission declarations or host-export ownership contract. The per-run paths, conservative creation, and interruption policies are defined below. [DEC-002, DEC-016, DEC-025, DEC-075, DEC-089]

## End-of-Run Temporary Source Cleanup

Remove the current run's captured source copy on success, failure, or cancellation, after permitted diagnostic evidence has been retained and verified, including its secret scan. Do not preserve complete source material by default. Removal is limited to temporary resources owned by that execution and must not affect the original profile, other runs, or accepted artifacts. [DEC-017, DEC-089]

Respect the inherited container lifecycle: export and verify relevant diagnostics before removing the container. Source cleanup does not authorize premature destruction of failure evidence or general cleanup of generated trees. Forced termination and cleanup failures can leave residue; apply the outcome, evidence, and manual recovery contracts below without claiming unconditional cleanup guarantees. Concrete detection and reporting mechanics are implementation deliverables. [DEC-002, DEC-017, DEC-029, DEC-030, DEC-032, DEC-042, DEC-066, DEC-077]

## Repository-Wide Dirty-State Scope

Determine the dirty-state indication from the entire repository, not only `image/archiso/`. Local changes to any repository file, including new untracked, non-ignored files, mark the build dirty; this includes modifications to `operations/build` or `image/builder/` even when the profile itself matches its commit. Ignored generated outputs alone do not count as new dirty inputs. The dirty-path list in metadata covers the profile only; it does not identify changes in the executing constructor. [DEC-003, DEC-005, DEC-018, DEC-083, DEC-089]

## Experimental Constructor Traceability Limitation

Experimental builds may execute locally modified construction code or profile content. Mark the execution dirty using repository-wide detection and explicitly record that commit plus dirty indication and dirty paths do not exactly identify or enable reconstruction of the modified content. This is an accepted experimental limitation, not a claim of exact reconstruction. Formal Story 1.3 acceptance still requires a clean clone of a committed candidate, where Git identifies both the profile and the construction code. [DEC-003, DEC-018, DEC-019, DEC-089]

## Basic Build Invocation

In Story 1.3, `operations/build` without arguments starts construction from the fixed `image/archiso/` profile using the approved default cache and required controls. This replaces only the build command's current refusal of unimplemented domain behavior; it does not implement other lifecycle commands. On success, report the published artifact location (`dist/<run-id>/`) on stdout, as the Story 1.3 acceptance criteria require. Preserve the inherited side-effect-free, unprivileged help and caller-working-directory independence. The additional `--no-cache` invocation is defined below. The complete accepted invocation surface and early argument-rejection rules are defined below; no other options are selected. [DEC-002, DEC-020, DEC-021, DEC-022]

Do not introduce a separate acceptance mode or a flag that grants formal acceptance. Acceptance is established by construction from a clean clone and the required evidence, not command spelling. Do not automatically start boot testing: Story 1.4 retains that independently invoked qualification boundary. [DEC-001, DEC-003, DEC-020]

## No-Cache Build Invocation

`operations/build --no-cache` builds without mounting the persistent `mirroros-pacman-cache` volume. It neither deletes nor modifies that existing volume and does not change other executions' cache resources. Its behavior (no mount, volume untouched) is verified by Bats contract tests; real cache-independence qualification uses an empty-cache default build instead. [DEC-002, DEC-021, DEC-090]

The option bypasses the persistent Pacman package cache, not every possible Docker or upstream cache. All fresh-container, image resolution and signature, exact Archiso version, secret-safety, and evidence controls remain in force. Only a sole `--no-cache` argument is valid under the argument contract below; repeated or combined options are rejected before effects. [DEC-002, DEC-021, DEC-022]

## Minimum Build Argument Contract

Accept exactly three invocation forms: no arguments for the default-cache build, sole `--no-cache` for the cache-independent build, and sole `--help` for help without effects or privilege. Any other form, including unknown arguments, repeated options, or combining help with no-cache, returns normalized status 2 with a diagnostic on stderr before file creation or Docker invocation. This contract updates only the build command; other lifecycle entry points retain their existing discovery contracts until their own domain implementations are approved. [DEC-020, DEC-021, DEC-022]

## Root Invocation Boundary

Construction through `operations/build`, with no arguments or sole `--no-cache`, is rejected when the command runs as root. Return normalized status 2 and explain that construction must be invoked by a normal user with access to Docker. This enforces the architecture's unprivileged-orchestration boundary and avoids creating host temporary sources or evidence as root. The privilege required by `mkarchiso` remains inside the selected privileged build container. [DEC-002, DEC-020, DEC-021, DEC-023]

Sole `--help` remains available to root because help performs no changes or elevation. This exception does not authorize root construction or automatic remediation of Docker permissions, groups, or services. Argument handling still follows the exact accepted forms and early rejection rules. [DEC-022, DEC-023]

## Direct Docker Access Precondition

Check Docker daemon access as the invoking user. Inaccessibility returns normalized status 2 with an actionable diagnostic and stops construction. Do not fall back automatically to `sudo docker` or modify services, permissions, or groups to obtain access. This concretizes the inherited external-prerequisite boundary rather than authorizing host remediation. [DEC-002, DEC-023, DEC-024]

Documentation must warn that Docker access enables root-equivalent operations. Normal-user orchestration protects the intended privilege and host-output ownership boundaries but is not a security sandbox, and the privileged container is not VM-equivalent isolation. [DEC-002, DEC-024]

## Per-Run Host Directory Layout

Use one execution identifier consistently across `build/archiso/<run-id>/` for temporary sources and local preparation, `dist/<run-id>/` for exported artifacts, and `evidence/archiso-build/<run-id>/` for metadata and permitted diagnostics. Each build owns separate directories and must not overwrite previous results. All remain generated and excluded from authoritative source control. Publication follows the private-staging and post-validation sequence below. The bundle is published through a verified temporary directory in `dist/` and a final atomic rename. The identifier uses a compact UTC timestamp plus UUID as defined below. Private permissions and conservative collision handling follow the approved policies below. Concrete identifier generation, temporary publication names, and failure and durability mechanics are implementation deliverables within these contracts. [DEC-002, DEC-016, DEC-025, DEC-026, DEC-027, DEC-034, DEC-074, DEC-075, DEC-077]

Container build work and initial output remain in internal disposable `/work` and `/out`. The host `build/archiso/<run-id>/` area does not become a writable bind mount for privileged build work. Cleanup authority remains limited to the current run's temporary resources and is subject to evidence preservation. [DEC-002, DEC-017, DEC-025]

## Two-Phase Artifact Publication

Export the candidate ISO first into private preparation storage within `build/archiso/<run-id>/`. Verify export, calculate and check its checksum, validate required metadata, and complete the required secret scans before publishing the artifact in `dist/<run-id>/`. Incomplete or rejected candidates must not appear in the accepted-result location. Atomic bundle publication follows the mechanism below. Rejected and incomplete candidates follow the post-evidence cleanup policy below. Conservative collision handling, safe diagnostic retention, and cleanup-failure outcomes follow the approved policies below. Concrete temporary names and publication failure and durability mechanics are implementation deliverables. [DEC-016, DEC-025, DEC-026, DEC-027, DEC-028, DEC-029, DEC-030, DEC-075, DEC-077, DEC-088]

Publication certifies that construction and its required controls succeeded. It does not establish boot qualification or known-good status, and it does not turn an experimental dirty build into formal Story 1.3 acceptance evidence. Formal story acceptance still requires the clean-clone workflow and its evidence. [DEC-001, DEC-003, DEC-019, DEC-026]

## Atomic Artifact Bundle Publication

Publish the ISO, checksum file, required metadata, and native package manifest together. Prepare the complete bundle in a temporary directory inside `dist/`, check its completeness and equality with the previously validated private staging content, and atomically rename that directory to `dist/<run-id>/`. The final directory must not expose an ISO without its associated checksum and metadata. A transfer from `build/` to `dist/` may cross filesystems and is not itself the atomic publication step. Apply the collision and outcome policies below; concrete temporary names and durability checks are implementation deliverables. [DEC-025, DEC-026, DEC-027, DEC-054, DEC-057, DEC-075, DEC-077, DEC-086]

Diagnostic evidence remains under `evidence/archiso-build/<run-id>/`. Atomic bundle publication is not a transaction spanning the artifact and evidence roots and does not broaden construction acceptance into boot qualification or formal clean-clone story acceptance. [DEC-001, DEC-003, DEC-026, DEC-027]

## Rejected Candidate Retention and Cleanup

Do not retain incomplete or rejected ISO candidates by default. After permitted diagnostic evidence has been retained and verified, including secret scanning, remove failed candidates and incomplete publication copies owned by the current execution. Persistent diagnostics remain available without requiring indefinite retention of raw images that could contain sensitive content or be mistaken for accepted outputs. [DEC-017, DEC-026, DEC-028]

This removal does not affect already published bundles or results from previous runs. Respect the inherited export-and-verification-before-container-removal sequence. Cleanup failure after completed publication follows the status-5 and bundle-preservation contract below. Primary-outcome precedence follows the rule below. SIGINT and SIGTERM follow the interruption policy below. The signal stop deadlines, repeated-interruption behavior, manual recovery, and diagnostic retention policies are defined below; concrete reporting and cleanup mechanics remain implementation deliverables. Do not assume deletion or evidence export can always succeed. [DEC-002, DEC-025, DEC-027, DEC-028, DEC-029, DEC-030, DEC-031, DEC-042, DEC-061, DEC-062, DEC-077, DEC-088]

## Cleanup Failure after Publication

If publication succeeds but subsequent removal of the container or temporary material fails, return normalized status 5. Clearly distinguish completed artifact publication from incomplete cleanup, preserve the published bundle, and record the remaining resources with actionable safe-cleanup guidance. Do not report overall success or delete the valid bundle to hide the failed operation. [DEC-027, DEC-028, DEC-029]

A published bundle from this failed run is not automatically promoted to boot-qualified, known-good, or later states. Evidence and metadata must not equate publication completion with global execution success. Cleanup errors do not replace an earlier primary failure, explicit cancellation, or signal result under the precedence rule below. SIGINT and SIGTERM follow the stop-deadline and repeated-interruption policies below, with concrete command mechanics supplied during implementation. [DEC-001, DEC-029, DEC-030, DEC-031, DEC-061, DEC-062, DEC-077]

## Primary Outcome and Cleanup Error Precedence

When cleanup fails after an earlier primary failure, explicit cancellation, or signal termination, preserve the primary outcome and its applicable original status. Keep the normalized lifecycle status distinct from original child exit status and preserve ordinary shell signal conventions. Record the cleanup error separately with remaining resources and actionable recovery steps; do not let cleanup mask the responsible upstream operation or primary diagnostics. This does not introduce a new cancellation mechanism or map signals to normalized cancellation status 3. [DEC-002, DEC-030]

Cleanup converts an otherwise successful result to normalized status 5 as defined by DEC-029, but does not replace an existing non-success result. A preserved primary result does not mean cleanup succeeded: terminal diagnostics and evidence must expose both outcomes accurately. [DEC-029, DEC-030]

## Signal Interruption Policy

On SIGINT or SIGTERM, attempt to stop active work in the current run's container, retain and verify permitted diagnostics, and then clean up that execution's resources. Preserve the ordinary signal outcomes: 130 for SIGINT and 143 for SIGTERM, not normalized cancellation 3. Secondary cleanup failures remain separately reported and do not replace the primary signal status. Apply the stop deadlines and repeated-interruption behavior defined below; concrete command mechanics are implementation deliverables. [DEC-002, DEC-017, DEC-030, DEC-031, DEC-061, DEC-062, DEC-077]

Do not promise cleanup or diagnostic retention after SIGKILL or host failure: these events can prevent trap execution and leave resources for later recovery. Recovery must not infer that absent final evidence means the artifact or execution succeeded. Recovery follows the explicit previous-run procedure, recorded identity, per-run locking, and container-state policies below; concrete recovery commands are manual-procedure deliverables. [DEC-026, DEC-028, DEC-031, DEC-032, DEC-033, DEC-035, DEC-038, DEC-042, DEC-077]

## Explicit Recovery of Previous Runs

A new build must not automatically delete or reuse containers or temporary files belonging to earlier executions. Document an explicit recovery procedure that identifies the affected run, checks that it is no longer active, preserves permitted diagnostic evidence, and then removes only that run's resources. Resource age alone is not authorization for deletion. This preserves fresh construction, run isolation, and failure diagnosis without silently broadening cleanup scope. [DEC-002, DEC-025, DEC-031, DEC-032]

Container identification follows the run-specific name, labels, and recorded actual ID contract below. Orchestration activity is checked through the per-run flock below. The persistent lock location is defined below. Missing identity or lock evidence triggers the recovery refusal below. Container-state checks and authorization follow the approved policies below. Concrete identity-recording order, secure lock creation and descriptor lifecycle, recovery commands, and manual investigation instructions are implementation and manual-procedure deliverables. This policy does not introduce a new cleanup command or require automatic discovery of all orphaned resources. Absent final evidence must not be treated as successful completion. [DEC-031, DEC-032, DEC-033, DEC-035, DEC-036, DEC-037]

## Build Container Identity

Name the container `mirroros-archiso-build-<run-id>` and assign labels `org.mirroros.stage=build` and `org.mirroros.run-id=<run-id>`. Record its actual Docker container ID, name, and labels in execution evidence so recovery can compare the selected resource with the run's recorded identity. Concrete recording order is an implementation deliverable. Missing recorded identity triggers the conservative recovery refusal below. [DEC-025, DEC-032, DEC-033, DEC-037]

A matching name or label is not proof that a container is inactive and is not sufficient authorization to delete it. Recovery still needs the approved inactivity check and preservation of permitted diagnostics. The persistent `mirroros-pacman-cache` volume is shared and is not part of a run's exclusively owned cleanup resources. [DEC-002, DEC-021, DEC-032, DEC-033]

## Execution Identifier Format

The run identifier has the form `YYYYMMDDTHHMMSSZ-<uuid>`, combining a compact UTC timestamp with a UUID rather than relying on the start second alone. Generate it once and use it unchanged in host directories, container identity, and evidence. Do not include usernames or personal information. Concrete generation, UUID version, collision checks, and recording order are implementation deliverables. [DEC-025, DEC-033, DEC-034]

This identifier denotes an execution, not the source definition or the ISO's content. It does not replace commit and dirty-state metadata, the profile identity, or the artifact checksum, and it does not change the build's SOURCE_DATE_EPOCH. [DEC-003, DEC-018, DEC-034, DEC-089]

## Per-Run Orchestration Activity Lock

Hold an exclusive per-run `flock` throughout orchestration, including cleanup. Recovery attempts to acquire the same lock without waiting; an occupied lock prevents recovery actions on that run's resources. This avoids relying solely on a PID that may have been reused. The lock remains at `evidence/archiso-build/<run-id>/run.lock` as specified below. Concrete secure creation, descriptor lifecycle, and filesystem compatibility are implementation deliverables. Missing identity or lock evidence follows the recovery-refusal policy below. [DEC-032, DEC-035, DEC-036, DEC-037]

Acquiring a free lock does not establish that Docker work has stopped. Recovery must still verify the recorded container identity and its state before acting. Advisory locking is an activity-coordination mechanism, not a security boundary or authorization to delete resources. The current host provides flock from util-linux 2.40.4, an observed availability rather than a version pin. [DEC-033, DEC-035]

## Persistent Lock File Location

Keep the per-run lock file at `evidence/archiso-build/<run-id>/run.lock`. It remains with retained execution evidence and is not deleted during temporary-resource cleanup. Do not unlink and recreate it while coordinating the run: that can create different underlying files under the same name and invalidate locking assumptions. Concrete secure creation and descriptor lifecycle are implementation deliverables. Missing lock evidence triggers the conservative recovery refusal below. [DEC-025, DEC-035, DEC-036, DEC-037]

File existence does not indicate activity. The lock file may remain after completion; activity is determined by attempting the actual non-blocking lock acquisition and, separately, checking the recorded container identity and state. [DEC-033, DEC-035, DEC-036]

## Recovery with Missing Identity or Lock Evidence

If recovery lacks the recorded actual container ID or the existing `run.lock`, stop before modifying resources. Do not recreate the lock or replace recorded identity with an inference from the name or labels. Report the missing data and require manual investigation before authorizing removal. Keep resources intact while safe recovery cannot be established. Concrete investigation instructions belong to the manual recovery guide. [DEC-032, DEC-033, DEC-035, DEC-036, DEC-037]

A newly created lock does not establish inactivity of a process that may still hold the original, now-unlinked file. Likewise, a name or label match alone is not sufficient proof that a container belongs to the recorded execution or may be deleted. This policy does not introduce automatic resource adoption or orphan cleanup. [DEC-033, DEC-036, DEC-037]

## Recovery of Active Residual Containers

During explicit recovery, first acquire the existing per-run flock and verify the recorded container identity. A container in `running`, `paused`, or `restarting` state requires explicit maintainer authorization to stop it. After stopping, query and verify that it is stopped before preserving and verifying permitted diagnostic evidence and finally removing the container. A free orchestration lock alone does not establish that Docker work has ended. [DEC-032, DEC-033, DEC-035, DEC-037, DEC-038]

Block recovery without removing resources if authorization is absent, stopping fails, the stopped state cannot be verified, an unknown state is reported, or a state query fails. Forced removal is not a shortcut around this sequence, and recovery does not establish successful construction. Paused-state handling and stop deadlines follow the approved policies below; concrete commands and validation tests are implementation and manual-procedure deliverables. [DEC-002, DEC-038, DEC-039, DEC-040, DEC-041, DEC-042, DEC-077]

## Paused Container Recovery Authorization

When recovering a paused container, the explicit stop authorization must also describe the required resumption and the risk that its processes may execute briefly. Only after this authorization may recovery resume the container and immediately request its stop. If either step fails, block container removal. This does not waive acquisition of the existing per-run lock, recorded-identity verification, subsequent verification that the container is stopped, or preservation and verification of permitted diagnostics before removal. Stop deadlines follow the approved policies below; concrete commands are manual-procedure deliverables. [DEC-033, DEC-035, DEC-038, DEC-039, DEC-040, DEC-041, DEC-042, DEC-077]

## Recovery Stop Grace Period

Explicit recovery grants 30 seconds for orderly container stopping and then permits forced termination through Docker's stop mechanism. The authorization must disclose possible abrupt termination, which may interrupt writes and reduce diagnostic completeness. This permits termination of container processes, not forced container removal as a shortcut: stopped-state verification and preservation and verification of permitted diagnostics remain mandatory before removal. The global deadline for the Docker stop call is defined below. [DEC-038, DEC-039, DEC-040, DEC-041]

## Recovery Docker Stop Call Deadline

The Docker stop call during explicit recovery has a global deadline of 60 seconds, including the 30-second process-stop grace period. If it expires, terminate the client wait and block removal; leave resources for investigation and a new explicit recovery attempt. Deadline expiration proves neither that the daemon cancelled the stop operation nor that the container is stopped, and authorizes neither removal nor automatic retry. [DEC-038, DEC-040, DEC-041]

## Recovery Delivery and Complexity Boundary

Exceptional previous-run recovery is delivered as a concise manual guide for the single maintainer, with commands, checks, and warnings rather than a new recovery automation subsystem. The identity, locking, authorization, stop, deadline, and diagnostic safeguards above remain applicable as procedure requirements; they do not require an automated recovery state machine or prompts. Normal constructor controls remain in scope. Mechanical recovery details may be supplied during implementation without individual interview decisions unless they affect safety, evidence preservation, or inherited contracts. This delivery simplification does not supersede the substance of the approved recovery decisions. [DEC-032, DEC-033, DEC-035, DEC-036, DEC-037, DEC-038, DEC-039, DEC-040, DEC-041, DEC-042]

## Live Build Output and Stage Logs

Stream upstream build-tool output live to the terminal and write it with `tee` to a per-stage log, with a progress header for each stage. Scan retained logs with Gitleaks as part of evidence. Do not introduce a custom log filter, parser, or live redaction subsystem. Concrete log paths and stage boundaries are implementation deliverables. [DEC-043, DEC-077, DEC-088]

This relies on the DEC-085 invariant that the build container receives no host secrets. Accepted trade-off: if a secret ever reached upstream output despite the invariant, it would already have been displayed, so log scanning is detection, not prevention. Pre-commit source validation and clean-clone formal acceptance remain applicable. [DEC-003, DEC-085, DEC-088]

## Log Scan Findings

A finding in a retained log, or failure of its scan, blocks artifact acceptance. Preserve the log privately (mode `0600`) for maintainer review rather than discarding it; keep Gitleaks reports redacted. Do not implement automatic log sanitization. [DEC-063, DEC-074, DEC-088]

## Bounded Diagnostic Retention Scope

Retained logs cover specific preparation and construction operations, including Pacman and `mkarchiso`, and identify the responsible operation and its exit status. Keep this diagnostic allowlist explicit and small. Retained logs are secret-scanned and handled under the log-finding policy above. Do not indiscriminately collect environment variables, the complete filesystem, or full `docker inspect` dumps. This scope preserves attributable upstream context without turning diagnostic collection into an unrestricted container or host snapshot. [DEC-045, DEC-088]

## MirrorOS-Created Content Secret-Scan Scope

Gitleaks scans only MirrorOS content and what the run generates or retains: the captured profile before construction, retained diagnostic logs, and every record and evidence file the run writes, including artifact metadata, the execution result, the copied effective repository configuration, and the checksum file. Upstream content inside the ISO is not scanned. MirrorOS's only contribution to the ISO is the profile; everything else is signed public packages and files `mkarchiso` derives from them and from the profile. The ISO, SquashFS, initramfs, and UEFI FAT contents are therefore not extracted for secret scanning. The ISO is read only to extract the native package manifest. This avoids extraction tooling, runtime cost, and mass upstream false positives. [DEC-001, DEC-085, DEC-086]

The reduction rests on an invariant: the build container receives no host secrets, so there is no host `--env` or `--env-file` passthrough and no credential mounts. Contract tests verify this. Accepted trade-off: secrets inside upstream packages, or a leak from the build environment outside this invariant, would go undetected. PRD NFR7's artifact-inspection requirement is interpreted as satisfied by scanning MirrorOS's only contribution to the artifact, and the Story 1.3 acceptance criterion's "staging" means the captured profile copy, not the `mkarchiso` work tree. This interpretation is recorded in ADR `0001-build-secret-scan-scope` and `docs/procedures/build.md`; [DEC-087] the PRD and epics are unchanged. Scans do not certify absolute absence of secrets. [DEC-085]

## Artifact Package Manifest

The required artifact package manifest identifies every package installed in the ISO root filesystem with its actually resolved version, including dependencies and packages added during construction. The requested `packages.x86_64` list and the build container's package inventory are not substitutes for this final installed-package set; builder packages belong to construction-environment identification. [DEC-001, DEC-050]

Reuse Archiso's native installed-package manifest extracted from the ISO, retaining its text format of package name and resolved version. The current profile places it at `arch/pkglist.x86_64.txt`; canonical Archiso v91 generates it with `pacman -Q` against the constructed root filesystem. Do not introduce a JSON package inventory or per-package repository attribution. [DEC-050, DEC-051, DEC-086]

## Effective Repository Configuration

Record the effective repository configuration of each execution: the profile `pacman.conf`, identified through the captured profile, plus the build container's resolved `mirrorlist`, copied into execution evidence with its SHA-256 and referenced from artifact metadata. This satisfies the Story 1.3 repository-configuration requirement without capturing repository databases. [DEC-001, DEC-086]

## Package Records in the Published Bundle

Publish the native package manifest within `dist/<run-id>/`, together with the ISO, checksum, and required metadata, and validate it before atomic publication of the complete bundle. This keeps package diagnosis available when the bundle is moved or retained, while diagnostic evidence remains separately governed under `evidence/archiso-build/<run-id>/`. [DEC-027, DEC-051, DEC-054, DEC-086]

## Effective Build Timestamp

Set `SOURCE_DATE_EPOCH` once to the execution's start instant in UTC, pass it explicitly to `mkarchiso`, and record the value in build metadata. The unchanged upstream profile uses it for its ISO date, version, and label. Do not substitute the commit date. This establishes one effective construction date, not binary-identical reconstruction against rolling repositories. [DEC-001, DEC-002, DEC-055]

## Artifact Metadata and Execution Outcome Separation

Artifact metadata describes construction and artifact validation and remains immutable after bundle publication. Record the global execution outcome, including cleanup failure after successful publication, separately in execution evidence. Do not mutate the validated published bundle to update operational status or represent publication completion as full lifecycle success. The status-5 cleanup-failure contract and preservation of the published bundle remain applicable. [DEC-027, DEC-029, DEC-030, DEC-056]

## Published Bundle Checksum Coverage

Use a checksum file in native `sha256sum` format to cover the ISO, immutable artifact metadata, and native package manifest. Exclude the checksum file itself. This permits integrity checks of the accompanying records as well as the ISO when the bundle is retained or moved; it establishes neither publisher authentication nor replacement of construction or secret-inspection controls. [DEC-027, DEC-051, DEC-054, DEC-056, DEC-057, DEC-086]

## Artifact Metadata and Execution Result Formats

Artifact metadata and the separate execution-result document use JSON, with architecture-required fields and JavaScript ESM processing under the inherited language boundary. Preserve the distinction between immutable published artifact metadata and the global execution result retained in evidence. The minimum content contracts below govern concrete field names and validation during implementation. Do not replace the native package manifest and `sha256sum` formats with JSON. [DEC-051, DEC-056, DEC-057, DEC-058, DEC-065, DEC-066, DEC-077]

## Automatic Source Capture Selection

Select the source-capture mechanism from repository-wide clean or dirty state. A clean repository uses `git archive` to export the profile from the recorded source commit; a dirty repository uses working-profile capture with the approved development file-inclusion and protection rules. Mark dirty executions accordingly and record the dirty-path list. [DEC-089] This automatic selection introduces no acceptance mode and does not confer formal acceptance on a clean local execution: the clean-clone workflow and required qualification evidence still govern story acceptance. [DEC-003, DEC-008, DEC-011, DEC-018, DEC-020, DEC-059]

## Supported Profile Entry Types

Profile capture supports directories, regular files, and literal symbolic links. Devices, sockets, FIFOs, and Git submodules within the profile are unsupported: stop with normalized status `2` and identify the entry rather than incorporating it or introducing special support. FIFOs can block reads, device and socket entries are not ordinary source content, and submodules require additional repository identity and capture rules outside this scope. Inspection found none of these unsupported entries in the current profile. Preserve symbolic links and their literal targets without dereferencing them in the fixed copy. [DEC-059, DEC-060, DEC-089]

## Current-Run Interruption Stop Mechanism

For SIGINT or SIGTERM during the current execution, reuse the 30-second orderly-stop grace period and 60-second global Docker stop-call deadline without an additional stop confirmation. The signal requests interruption of this run only, not action on previous runs. Verify stopping before proceeding with the diagnostic-preservation and cleanup sequence; timeout expiration does not establish a stopped container. Preserve statuses `130` and `143` and report secondary failures separately under the existing precedence policy. Previous-run recovery retains its explicit authorization requirements. [DEC-030, DEC-031, DEC-038, DEC-040, DEC-041, DEC-061]

## Repeated Interruption during Cleanup

A second SIGINT or SIGTERM during interruption cleanup aborts that cleanup attempt rather than restarting it or forcing resource removal. Preserve the exit status associated with the first signal and, if still possible, warn about resources remaining for explicit manual recovery. This escape can leave incomplete diagnostics and residual resources; complete evidence preservation is not guaranteed after the abort. [DEC-030, DEC-031, DEC-032, DEC-061, DEC-062]

## Secret-Control Outcome Classification

A detected secret returns normalized status `2` for inadmissible content; a missing scanner also returns `2` but is reported as an unmet prerequisite. Scanner execution failure returns normalized status `5`, with its original exit status preserved. All block artifact acceptance. If diagnostic scanning follows an already established primary failure, keep that primary outcome and record the scan problem separately rather than masking the responsible upstream operation. Logs with findings are preserved privately for review under the log-finding policy. [DEC-030, DEC-063, DEC-088]

## Explicit JSON Contract Validation

Validate build JSON documents' fields, types, and cross-document coherence in JavaScript ESM, using Node.js and its built-in modules with corresponding tests. Do not introduce an npm library or schema framework for these small documents. Validation must detect inconsistencies such as metadata references or hashes that disagree with the bundle files, and incomplete artifact metadata, before publication. Concrete field names and checks are implementation deliverables under the minimum content contracts below; explicit validation is not permission to accept arbitrary JSON or incomplete records. [DEC-058, DEC-064, DEC-065, DEC-066, DEC-077, DEC-086]

## Minimum Immutable Artifact Metadata Content

Immutable artifact metadata identifies the execution, source commit, clean/dirty state, and captured profile. It records construction architecture, container digest, exact Archiso version, effective build date, and relevant tool versions. Include references to the effective repository configuration (profile `pacman.conf` and resolved `mirrorlist` hash) and the native package manifest, along with ISO filename, size, and SHA-256. Record required control outcomes and the secret-scan scope (MirrorOS-created content only). [DEC-085] Include applicable experimental traceability limitations and make clear that validated construction does not establish boot qualification. Exclude secret values and subsequent cleanup outcomes. Concrete field names and validation follow architecture conventions. [DEC-001, DEC-002, DEC-003, DEC-019, DEC-050, DEC-051, DEC-055, DEC-056, DEC-058, DEC-064, DEC-065, DEC-086]

## Minimum Execution Result Content

The separate execution-result JSON records execution ID and references to sources and artifacts; start, end, and duration; global outcome, exit status, and the stage or operation responsible for failure; original statuses of executed tools; validation outcomes and permitted diagnostic references; whether publication completed, separately from the global outcome; and cleanup outcome, remaining resources, and recovery guidance. Do not invent observations unavailable due to interruption or interpret unknown information as success. This document describes execution results, not a state machine, and does not replace permitted diagnostic logs. [DEC-029, DEC-030, DEC-031, DEC-056, DEC-058, DEC-063, DEC-064, DEC-066]

## Three-Layer Validation Strategy

Use Node's built-in `node:test` runner for JavaScript document and metadata-coherence tests. Use Bats with simulated tools and disposable directories for command contracts, failures, signals, publication, and cleanup, without constructing a complete ISO for every contract case. Separately qualify real Docker/Archiso construction from a clean clone, covering export, normal-user ownership, secret scans of MirrorOS-created content, empty-cache independence and cache reuse, and diagnostic preservation on failure. Simulations prove command contracts, not real construction; real build qualification remains distinct from Story 1.4 boot qualification. [DEC-001, DEC-002, DEC-003, DEC-064, DEC-067, DEC-090]

## Negative Secret-Control Coverage Tests

Use detectable synthetic values rather than real credentials in negative source and simulated-log tests. Verify that a synthetic value in the profile is rejected before construction, that a synthetic value in a log blocks acceptance while the log is preserved privately, and that Gitleaks reports and metadata never contain the value. [DEC-088] Keep any generated fixtures in ignored disposable directories, not committed secret-bearing content or formal acceptance artifacts. These expected detections are controlled test outcomes, not exceptions to clean final acceptance, and do not require a complete Archiso build. No image-layer fixtures are needed because ISO contents are not secret-scanned. Contract tests also verify that the build container receives no host secrets. [DEC-043, DEC-063, DEC-067, DEC-068, DEC-085, DEC-088]

## Removed Repository Attribution and Capture

Per-package repository attribution, repository-database capture and retention, and the PostTransaction staging-hook mechanism are removed. With only the official `core` and `extra` repositories, the native manifest's exact names and versions already identify packages. Build-to-build changes are visible by diffing manifests, and reinstalling historical versions needs the manifest and build date, not package origin. The mechanism's cost and fragility (hook injection, capture validation, assumptions about Archiso internals, an extra JSON record, an instrumentation-absence check, and renewed review on every Archiso update) outweigh that benefit. Accepted loss: no audit of which versions repositories offered at build time. Reconsider attribution in the story or ADR that first enables a non-official repository that could supply the same package name. Story 1.3 TODO-001 is obsolete. [DEC-086]

The earlier capture experiment demonstrated feasibility but is not used. Its untracked research artifacts are deleted by the implementation plan rather than versioned; its local evidence remains ignored and uncommitted. [DEC-078, DEC-086]

## ADR Responsibility

The repository-capture ADR task is withdrawn together with the mechanism. [DEC-081, DEC-086] Instead, the implementation prepares one small ADR, `docs/adr/0001-build-secret-scan-scope.md`, with status Proposed. It records the MirrorOS-created-content scan principle, the no-host-secrets container invariant, the interpretation of PRD NFR7 and the architecture's "staging" wording, and removal of per-package repository attribution for the live ISO with its reconsideration trigger. These narrow the architecture's literal statements that staging trees are scanned and that artifacts are inspected, so ADR guidance treats them as an exception. The maintainer accepts the ADR at the diff-review checkpoint before the candidate commit, and `docs/procedures/build.md` links it. The PRD, epics, and architecture text stay unchanged. Per-package provenance for installed target packages (PRD FR21/NFR12) belongs to later stories and is unaffected. [DEC-085, DEC-086, DEC-087]

## Candidate Commit and Human Review

After implementation and satisfactory local controls, present the diff for explicit maintainer approval before creating the candidate commit, including the Story 1.3 interview artifacts. Perform real construction qualification from a clean clone of that commit. If qualification fails, add corrective commits rather than rewriting the failed candidate, preserving its evidence trail. This flow does not authorize commits during the interview. [DEC-003, DEC-067, DEC-071]

## Real Upstream Failure Evidence Drill

Exercise real failure handling by adding a nonexistent package to the profile in a disposable clone and allowing `mkarchiso` to fail. Mark that execution dirty and treat it solely as a negative qualification drill, not formal clean-clone artifact acceptance. Demonstrate normalized status `5`, preservation of the original upstream status, no artifact publication, and permitted diagnostic export and secret inspection before container removal. Do not weaken package signatures, rely on network disruption, or modify the formal acceptance candidate. [DEC-002, DEC-003, DEC-019, DEC-043, DEC-067, DEC-072, DEC-088]

## Real Cache Qualification Sequence

First verify that `mirroros-pacman-cache` is absent, or remove it explicitly without forcing. Build A runs from a clean clone of the committed candidate with the default cache on the empty volume; it is the formal acceptance build and demonstrates independence from cached package contents. Build B runs from the same commit with the default cache and demonstrates reuse through Pacman log evidence. Each construction must pass its required controls. Afterwards, explicitly remove the shared cache when it is not in use, without forced deletion. The `--no-cache` flag is verified only by Bats contract tests; no real build exercises it. Record any rolling-resolution differences between A and B rather than requiring binary-identical artifacts or identical package versions. The exact Archiso profile/tool version gate remains mandatory for every execution. This interprets Story 1.1 DEC-043 and TODO-006 as cache-content independence. [DEC-001, DEC-002, DEC-021, DEC-067, DEC-090]

## Private Local Result Permissions

Execution-specific preparation, evidence, bundle, and temporary publication directories use mode `0700`. Logs, JSON records, manifests, checksum files, and the ISO use mode `0600` and belong to the invoking user. This limits accidental exposure independently of secret scanning and preserves the inherited normal-user ownership boundary. It does not alter captured-profile permissions or installed ISO contents. Sharing a bundle is an explicit subsequent action, not a constructor side effect. [DEC-002, DEC-016, DEC-025, DEC-027, DEC-074]

## Conservative Resource Creation

Reject execution with normalized status `2` if its reserved run paths already exist or generated base directories are symbolic links. Do not adopt, overwrite, delete, or change permissions of those resources to continue. Creation and checks must be safe rather than relying only on a preceding nonexistence observation. Concrete commands and race-resistant tests remain implementation deliverables within the per-run isolation and cleanup boundaries. [DEC-025, DEC-032, DEC-074, DEC-075]

## Bounded Normal Execution

Normal execution uses finite per-operation waiting limits. Establish concrete values during implementation and qualification, document them, and check them in qualification without adding CLI options. Timeout expiration returns normalized status `5`, preserves the available original tool status, and initiates the approved stopping, permitted diagnostic-preservation, and cleanup sequence. Existing primary-outcome precedence remains applicable, and a client timeout does not establish that container work has stopped. [DEC-030, DEC-040, DEC-041, DEC-043, DEC-061, DEC-076, DEC-088]

## Interview Closure and Implementation Readiness

The Story 1.3 design interview is closed with the contracts in this plan agreed. This does not declare the story implemented or qualified, and does not claim delivery of product code. TODO-001 is obsolete and no readiness blocker remains. [DEC-086] If implementation requires changing a contract, return for an explicit decision rather than silently choosing a different design. Closure does not authorize creation of commits. [DEC-071, DEC-077]

Concrete commands, JSON field names, source enumeration and copy arguments, helper organization, safe creation and cleanup mechanics, and other mechanical details are implementing-agent deliverables governed by the approved contracts and corresponding tests, not a continuing series of individual interview decisions. Preserve the distinctions between approved design, unexecuted formal qualification, and ordinary implementation work. Do not use this delegation to waive constraints, lose trade-offs, or resolve a genuine contract conflict. [DEC-042, DEC-064, DEC-065, DEC-066, DEC-067, DEC-075, DEC-076, DEC-077]

## Implementation Planning Deltas

These decisions were taken during implementation planning after interview closure. They fix delivery as one plan and the code location, reduce secret-scan scope to MirrorOS-created content, remove repository attribution, record both reductions in one Proposed ADR, restore live build output, drop the dirty-build identification archive, and reduce real qualification to two full builds. [DEC-082, DEC-083, DEC-085, DEC-086, DEC-087, DEC-088, DEC-089, DEC-090]

All of Story 1.3 is delivered through a single implementation plan, `01-04`, spanning any required ADR, implementation, tests, documentation, maintainer review of the diff before the candidate commit, and real clean-clone qualification. Because the plan is large, its tasks carry explicit checkpoints rather than relying on a later split. [DEC-082]

`operations/build` remains a thin lifecycle entry point that parses the approved invocation forms, serves help, and delegates. Versioned domain implementation lives in `image/builder/`, a sibling of the profile that is outside profile capture and identity, holding Bash orchestration and built-in-only JavaScript ESM modules. Tests mirror this in `tests/image/builder/`, and the existing build contract suite is updated. Root `build/`, `dist/`, and `evidence/` stay generated runtime outputs; source never lives there. Nothing is added under `image/archiso/` or `operations/lib/`, no JSON schema files are introduced, and the architecture tree is updated to show `image/builder/`. [DEC-064, DEC-083, DEC-086]

Gitleaks scans only MirrorOS-created content; public upstream data is not scanned. The principle arose from release-dependent false positives on public repository databases, first handled by excluding them (DEC-084), then moot once database capture was removed. [DEC-084, DEC-086] It extends to the artifact: layered extraction and scanning of ISO contents is removed. That scope, the build container's no-secret invariant, and the recorded interpretation of PRD NFR7 and the epic's "staging" criterion are defined in the scan-scope section above. [DEC-085]
