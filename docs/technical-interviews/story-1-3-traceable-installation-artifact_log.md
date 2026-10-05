# Story 1.3 Traceable Installation Artifact — Decision Log

**Conventions.** The Consolidated Plan (`story-1-3-traceable-installation-artifact_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding entry, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: Should the interview establish the proposed Story 1.3 scope and boundaries before resolving individual build design choices?
- **Context/Nuances**: Story 1.3 implements traceable image construction using the existing attributed Archiso profile and `mkarchiso`. Repository inspection found `operations/build` supports discovery only, its procedure leaves domain contracts pending, and `image/archiso/UPSTREAM.md` records Archiso 91-1 with no functional local delta and no completed build or UEFI qualification. Repeatability of the documented process and traceability of resolved inputs do not promise byte-identical future images against rolling repositories. Build acceptance is distinct from boot qualification, installation validation, accepted-known-good promotion, and laptop eligibility. Internal image secret inspection was deferred to this story by the Story 1.2 plan; source-only or opaque binary scanning does not establish coverage of packaged image contents. No build environment, dirty-source policy, directory layout, evidence schema, or scanning implementation is selected by this scope decision.
- **User Response**: "yes, regitra directamente la decisión." Explicit approval to record the proposed scope summary.
- **Decision**: Interview the Story 1.3 build design over the existing profile and `mkarchiso`, covering prerequisites, isolation, metadata, checksum, secret inspection, diagnostics, and build acceptance. Do not promise binary-identical reconstruction, introduce profile personalization, or implement runtime code during the interview. Resolve the supported build environment first, then dependent choices individually. Keep unresolved choices explicitly pending.
- **Status**: Accepted for scope; pending-environment and inherited-contract wording superseded by DEC-002

## DEC-002
- **Question**: Should Story 1.3 carry forward the approved Docker construction and exact Archiso profile/tool version contracts from Story 1.1 rather than reopen them as pending choices?
- **Context/Nuances**: The assistant incorrectly recommended native-host construction without first reviewing the inherited interview decisions. That recommendation was never approved or recorded as a selected environment. Story 1.1 DEC-004 already selects Docker for acquisition and construction; DEC-036, DEC-037, and TODO-004 require exact package-version equality before `mkarchiso`; TODO-006 assigns privileged-build qualification to Story 1.3. Related inherited constraints include the Docker host boundary (DEC-026), privilege separation (DEC-039), x86_64 and explicit linux/amd64 selection without cross-platform emulation (DEC-041 and DEC-042), default non-authoritative cache (DEC-043), unchanged initial upstream presentation (DEC-044), and signed-image selection and digest-bound execution (DEC-046 and DEC-047). Exact tool-version equality does not require reuse of the acquisition image digest. The current profile package version is 91-1, an imported identity rather than a permanent design pin. The architecture's generic compatible-Arch-host wording and the build procedure's pending implementation details must not be mistaken for evidence that the approved Docker choice is absent. Earlier story-specific qualification sequences and commit checkpoints are not automatically new Story 1.3 choices.
- **User Response**: "yes, registra directamente la decisión." The user also requested checking previously used artifacts before making further recommendations to prevent recurrence.
- **Decision**: Carry the inherited Docker, version-preflight, and build-qualification contracts into the Story 1.3 consolidated plan with explicit cross-story references. Docker and exact Archiso version equality are established constraints, not pending design selections. Withdraw the unapproved native-host recommendation. Correct DEC-001's pending-contract wording without changing its approved scope. Review previous interview plans and logs, applicable architecture and ADR guidance, and the used implementation/procedure records before further recommendations; distinguish inherited approvals, present implementation state, and genuinely unresolved details. This registration changes interview artifacts only and does not declare any build qualification complete.
- **Status**: Accepted

## DEC-003
- **Question**: Should development builds allow uncommitted changes while formal Story 1.3 acceptance requires a clean clone of a commit?
- **Context/Nuances**: Build metadata must record the source commit and dirty-state indication, but those fields alone do not identify the actual uncommitted content used to construct an image. Requiring a commit for every experimental build would impede development; treating experimental output as clean-clone reconstruction evidence would weaken acceptance. This decision does not select the mechanism for capturing content identity, which files constitute build inputs, or how inputs are protected against concurrent changes. A clean source state does not waive secret scanning or any other build control.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the recommended separation.
- **Decision**: Permit development builds with local uncommitted changes. Mark them as dirty and record the identity of the content actually used, alongside the source commit. Reserve formal Story 1.3 acceptance for construction from a clean clone of a committed candidate. Do not conflate experimental dirty-build results with evidence of reconstruction from Git. Resolve the concrete source-content identification mechanism separately.
- **Status**: Accepted; dirty content identity reduced to a dirty-path list by DEC-089

## DEC-004
- **Question**: Should each build use a verified temporary copy of the profile as its fixed effective input instead of mounting the mutable working profile directly?
- **Context/Nuances**: A read-only container mount prevents container writes but does not prevent the host editor from changing the mounted source during construction. Source commit and dirty metadata would not reliably describe a build whose inputs change during execution. A content manifest can identify captured inputs without retaining a potentially sensitive source patch. Copying and hashing alone must not be represented as proof that concurrent source changes were absent; the capture verification mechanism still needs design. Exact file inclusion, manifest serialization, symlink handling, and snapshot protection remain unresolved implementation contracts.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the verified-copy recommendation.
- **Decision**: At the start of each build, create a temporary copy of the profile and verify that input capture did not suffer concurrent changes. Secret-scan the captured copy and calculate a SHA-256 manifest identifying paths, file content, symbolic-link targets, and executable state. Mount that verified copy read-only and use it as the fixed effective input to `mkarchiso`. Use the manifest alongside commit and dirty-state metadata; do not retain a source patch as this identification mechanism. Resolve the concrete verification and file-selection rules separately.
- **Status**: Superseded by DEC-008; fixed-copy and secret-scan requirements retained

## DEC-005
- **Question**: Should development builds include new untracked, non-ignored files within the profile while excluding ignored files from capture?
- **Context/Nuances**: New profile files may be needed to test a local change before staging or committing it. Excluding all untracked files would omit intended development inputs, while copying ignored residue could silently introduce unintended image content. File inclusion does not waive secret scanning or content identification. Formal acceptance continues to require a clean clone of a committed candidate. The concrete Git enumeration mechanism and treatment of conflicts between tracked paths and ignore rules remain to be specified rather than inferred from this decision.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed inclusion rule.
- **Decision**: Include new untracked, non-ignored files within `image/archiso/` in development input capture. Apply the same secret scan and manifest requirements as for other captured inputs, and mark the build dirty when such files are present. Exclude ignored files from capture. Preserve the clean-clone requirement for formal acceptance.
- **Status**: Accepted for file inclusion; per-file manifest requirement superseded by DEC-008

## DEC-006
- **Question**: Should a build stop when a tracked profile file also matches an ignore rule?
- **Context/Nuances**: Git ignore rules do not stop tracking files already committed. Silently excluding such a path could remove declared image input; including it would contradict the approved ignored-file exclusion. Repository inspection with `git ls-files -ci --exclude-standard -- image/archiso` found no current conflicting paths. The guard protects future changes rather than repairing an existing conflict.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of blocking construction on this conflict.
- **Decision**: Detect profile paths that are tracked and also match ignore rules. Stop the build with normalized status `2`, identify the affected paths, and require the maintainer to correct the ignore rule or consciously remove the file from Git tracking. Do not silently include or omit conflicting inputs, and do not automatically modify Git state or ignore rules.
- **Status**: Accepted

## DEC-007
- **Question**: Should capture consistency be checked by comparing source-before, captured-copy, and source-after manifests, with an explicit non-atomicity limitation?
- **Context/Nuances**: DEC-004 requires verified fixed inputs, but no capture consistency mechanism had been selected. Comparing the selected path set and content identity at three observations detects observable inconsistencies without requiring a filesystem snapshot facility. It is not an atomic filesystem snapshot and cannot guarantee detection of a transient source change reverted between observations. Once verification succeeds, construction uses only the verified copy, not the working profile. Snapshot protection remains a separate pending concern.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the three-manifest check and its stated limitation.
- **Decision**: Generate a manifest of the selected profile inputs before copying, a manifest of the captured copy, and another manifest of the selected source inputs after copying. Require all three to match, including the selected path set. On mismatch, stop with normalized status `2`, ask the maintainer to finish edits and invoke the build again, and perform no automatic retry. Document that this establishes observed capture consistency, not atomic capture or guaranteed detection of reverted transient changes.
- **Status**: Superseded by DEC-008

## DEC-008
- **Question**: Should source identification use standard-tool source packaging and SHA-256 instead of a custom per-file manifest and three-manifest capture check?
- **Context/Nuances**: The user requested comparative evidence after questioning the manifest complexity. Inspection of Omarchy's `quattro` ISO scripts found privileged Docker, read-only source mounts, staging copies, and optional debug commit/status records, but no per-source-file SHA-256 inventory or three-manifest capture check in the examined scripts. Inspection of Ryoku's `main` ISO script found profile staging, `git archive --format=tar HEAD` for its embedded repository payload, commit/version stamps, and final ISO checksums. Ryoku also copies or compiles other inputs from its working tree, so its full ISO cannot be described as solely derived from the archived commit. These observations concern the fetched mutable branches and examined scripts, not all project workflows or permanent upstream guarantees. The research supports staging and standard source-export mechanisms without establishing our previous custom checks as a required upstream practice. Omarchy's automatic container removal and writable host output mounts are not adopted because they conflict with inherited MirrorOS contracts. A source package contains original content, unlike a digest, and therefore requires secret scanning and protection. A deterministic packaging convention remains to be specified and does not imply a byte-reproducible ISO or atomic working-tree capture.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed simplification.
- **Decision**: Retain fixed profile capture, secret scanning, dirty development builds, and formal acceptance from a clean clone. For formal acceptance, identify sources by the commit and an export of version-controlled content. For development, identify captured inputs through a source archive created with standard tools under deterministic packaging rules and its SHA-256. Do not introduce a custom per-file JSON inventory or the three-manifest check. Explicitly accept that capture from an editable working tree is not atomic and instruct the maintainer not to edit during capture. Scan and protect the source package during use; do not retain it as evidence by default, retaining its checksum instead. Preserve the separate resolved-package manifest required by the story. Supersede DEC-004's per-file/capture-verification mechanism and DEC-007 while retaining the fixed copy and scanning requirements; revise only the identification mechanism referenced by DEC-005, not its file-inclusion policy. The previously proposed JSON format was never approved. Exact standard tools, archive format and deterministic rules, protection, and cleanup remain pending.
- **Status**: Accepted for fixed capture and `git archive`; source-archive identification removed by DEC-089

### DEC-008 Research References

- Omarchy host build entry point: https://github.com/omacom/omarchy-iso/blob/quattro/bin/omarchy-iso-make
- Omarchy container build script: https://github.com/omacom/omarchy-iso/blob/quattro/builder/build-iso.sh
- Ryoku ISO build script: https://github.com/Ryoku-dev/ryoku/blob/main/installation/iso/build.sh

These are research references, not runtime dependencies or immutable revision pins. Implementation must follow the approved MirrorOS contracts rather than importing upstream scripts.

## DEC-009
- **Question**: Should the development source package use uncompressed TAR?
- **Context/Nuances**: Standard TAR tooling can represent file contents, symbolic links, and permissions without a custom source-inventory format. Compression adds an unnecessary transformation for a small profile and may introduce additional byte-variation factors. Selecting TAR alone does not make packaging deterministic: entry order, metadata normalization, archive dialect, and tool behavior still require concrete rules. The package contains original source content and remains subject to DEC-008's scanning, protection, and retention boundary.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of uncompressed TAR for the development source package.
- **Decision**: Use an uncompressed TAR archive as the development source package. Keep it temporary, secret-scan and protect it during use, and retain only its SHA-256 as evidence by default. Resolve deterministic packaging rules separately. This does not select the committed-source export mechanism for formal acceptance or imply a binary-reproducible ISO.
- **Status**: Superseded by DEC-089

## DEC-010
- **Question**: Should normalization be limited to the identification TAR while preserving the metadata of the fixed copy used by `mkarchiso`?
- **Context/Nuances**: Normalized ownership and timestamps can affect image metadata or build tools if a normalized archive is extracted and used as build input. The assistant's initial normalization proposal did not make that distinction sufficiently explicit. Inspection of the imported `profiledef.sh` found explicit installed-image permissions for selected paths, including `/etc/shadow` and `/root`, but that list must not be treated as covering every file or proving that all metadata is irrelevant. Host ownership of exported ISO files is governed by the separate export contract, not by ownership stored within the source archive. An identification checksum must not be described as capturing all build-environment properties or guaranteeing identical ISO bytes.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of normalization only for identification and preservation of the build copy.
- **Decision**: Use the same captured source content in two representations: the fixed copy with its metadata unchanged as `mkarchiso` input, and the TAR with normalized identification metadata for hashing. Order archive entries by path and use constant UID/GID and timestamps in the identification representation without changing the original files or build copy. Preserve executable state and symbolic-link targets in source identification; exact TAR rules and tool options remain pending. Never construct the image from an extraction of the normalized identification TAR. Its SHA-256 identifies a normalized content representation, not every characteristic of the build environment or an assurance of identical ISO output. Leave `profiledef.sh` unchanged and preserve the independent normal-user export-ownership check.
- **Status**: Superseded by DEC-089

## DEC-011
- **Question**: Should formal acceptance builds export the version-controlled profile with `git archive`?
- **Context/Nuances**: Formal Story 1.3 acceptance already requires a clean clone of a committed candidate. Exporting that candidate's profile with the native Git mechanism avoids accidental inclusion of unrelated local files. The mechanism was observed for Ryoku's embedded repository payload, not established as its complete-image source policy. Git represents content, symbolic-link targets, and executable state, but not original UID/GID, timestamps, or arbitrary Unix permission metadata. A committed-source export is distinct from the normalized identification TAR forbidden as build input by DEC-010. Concrete export invocation and path handling remain implementation details to resolve within these limits.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of `git archive` for formal acceptance source export.
- **Decision**: Use `git archive` to export the profile from the evaluated commit in the clean clone for formal acceptance builds. Materialize that export as the fixed build copy; do not substitute an extraction of the normalized identification TAR. Preserve Git-represented content, symbolic links, and executable state without promising recovery of ownership, original timestamps, or other metadata Git does not store. Keep `profiledef.sh` unchanged and retain all independent build, scanning, and export checks.
- **Status**: Accepted; identification-TAR references obsolete per DEC-089

## DEC-012
- **Question**: Should permissions in the identification TAR be normalized to directories 0755, executable files 0755, and non-executable files 0644, with symbolic links preserved literally?
- **Context/Nuances**: Git preserves executable state rather than every Unix permission bit. The content-identification representation should not vary solely because of irrelevant local read/write permission differences. This normalization is limited to identification and must not change the original profile, the fixed build copy, installed-image permissions, or exported output ownership. Preserving symbolic-link targets is important for the upstream profile's absolute and relative links; archive creation must not dereference them into host file contents. Concrete command options and the test for executable state still need implementation details.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed normalized permission representation.
- **Decision**: Represent directories as 0755, executable regular files as 0755, and non-executable regular files as 0644 in the identification TAR. Preserve symbolic links and their literal targets without dereferencing them. Apply these rules only to the identification representation, leaving original source, the `mkarchiso` input copy, and output permissions unchanged. Retain the independent installed-image declarations in `profiledef.sh` and export checks.
- **Status**: Superseded by DEC-089

## DEC-013
- **Question**: Should GNU tar and sha256sum, invoked from Bash, implement development source packaging and identification?
- **Context/Nuances**: The approved responsibility is standard-tool TAR creation and SHA-256 hashing, not a custom structured-data serializer. Direct tool invocation fits the inherited Bash boundary without an npm dependency. Inspection found `/usr/bin/tar` reporting GNU tar 1.35 and `/usr/bin/sha256sum` on the current host; this establishes current availability only, not a permanent version pin or a portability guarantee for other hosts. Concrete TAR dialect, normalization constants, arguments, and tests remain to be specified.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of GNU tar and sha256sum for this responsibility.
- **Decision**: Use GNU tar and sha256sum, invoked from Bash, to generate and identify the source package. Treat them as checked external prerequisites without automatic installation. Do not introduce a custom TAR serializer or an npm dependency for this responsibility, and do not pin the observed GNU tar version. Keep non-trivial structured-data responsibilities under the inherited JavaScript ESM boundary.
- **Status**: Superseded by DEC-089

## DEC-014
- **Question**: Should the identification TAR use UID 0, GID 0, and Unix timestamp 0 as normalization constants?
- **Context/Nuances**: DEC-010 selects constant ownership and timestamps only in the identification representation, but leaves the values unresolved. Zero values are independent of the invoking user, machine, and build date. The epoch timestamp is an identification convention, not a build-time setting or a claim about the source's historical modification date. Archive dialect and concrete tool options still require specification.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed constants.
- **Decision**: Use numeric UID 0, numeric GID 0, and Unix timestamp 0 (1970-01-01T00:00:00Z) for normalized metadata in the identification TAR. Do not apply these constants to the fixed `mkarchiso` input copy, host-exported artifacts, or the build's SOURCE_DATE_EPOCH. Preserve the independently approved permission, symlink, and export contracts.
- **Status**: Superseded by DEC-089

## DEC-015
- **Question**: Should the identification archive use the GNU TAR dialect?
- **Context/Nuances**: GNU tar is already selected for this temporary archive. The GNU dialect supports long path names and symbolic links without introducing PAX extended headers whose additional metadata would need its own normalization policy. Public distribution and broad archive-reader interoperability are not requirements for this identification package. Selecting a dialect does not alone establish determinism; entry ordering, approved normalized values, command options, and tests remain necessary.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of GNU TAR for identification.
- **Decision**: Use GNU TAR (`--format=gnu`) for the uncompressed temporary identification archive. Preserve all approved normalization, permission, symlink, scanning, and retention rules. This does not change ISO format or select a different formal source-export mechanism than `git archive`.
- **Status**: Superseded by DEC-089

## DEC-016
- **Question**: Should the temporary source area use mode 0700 and the source TAR use mode 0600 without changing captured-content permissions?
- **Context/Nuances**: The source archive contains original files and can contain a secret before scanning discovers it. Its filesystem permissions are distinct from the normalized ownership and permissions recorded in archive entries. Restricting the enclosing directory protects access without mutating the fixed build copy's metadata. These Unix permissions do not prevent root access and are not a security sandbox. Concrete directory paths, creation ordering, and cleanup behavior remain to be specified.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed temporary-material protection.
- **Decision**: Create the temporary source area with mode 0700 and the source TAR file with mode 0600, accessible to the invoking user and root. Do not change permissions of captured source contents to implement this protection. Keep the container/archive permissions separate from identification-entry normalization and from installed-image and exported-output permissions.
- **Status**: Accepted for the 0700 area; source TAR removed by DEC-089

## DEC-017
- **Question**: Should temporary captured sources and their TAR be removed at build termination after permitted diagnostic evidence has been retained and checked?
- **Context/Nuances**: DEC-008 rejects default retention of complete source packages as evidence, and temporary material can contain sensitive content. Failure diagnosis still requires preservation of allowed, secret-scanned evidence, not raw sources. The inherited container lifecycle requires export and verification before container removal; source cleanup must not undermine that ordering. Cleanup authority is limited to resources owned by the current execution, not the source checkout or unrelated generated paths. Forced termination or cleanup failure may leave residue, so implementation must not imply that cleanup can always complete; concrete handling remains pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of end-of-run source cleanup after diagnostic preservation.
- **Decision**: On success, failure, or cancellation, remove the current execution's captured source copy and temporary TAR after retaining and verifying permitted, secret-scanned diagnostic evidence. Do not retain full sources by default. Restrict removal to the current execution's temporary resources; preserve the original profile, other executions, and accepted artifacts. Respect the inherited export-and-verification-before-container-removal contract. Concrete cleanup failure and interrupted-run recovery handling remain to be resolved.
- **Status**: Accepted; temporary TAR removed by DEC-089

## DEC-018
- **Question**: Should the build's dirty-state indication cover the whole repository rather than only `image/archiso/`?
- **Context/Nuances**: A clean profile does not imply that the executing constructor or other repository files match the recorded commit. Restricting dirty detection to the profile could misrepresent a locally modified `operations/build` as a committed-source execution. The profile archive checksum still identifies only captured profile inputs; it is not an identity for all repository content or executing orchestration code. This decision establishes the scope of dirty detection, not a new archive scope or a mechanism to preserve modified constructor content.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of repository-wide dirty detection.
- **Decision**: Mark the execution dirty if any repository file has local changes, including new untracked, non-ignored files. Inspect the complete repository rather than only the profile directory. Do not classify ignored generated outputs alone as new dirty inputs. Keep the profile archive checksum explicitly scoped to the captured profile and do not describe it as identifying the constructor or whole repository. Concrete status observation and treatment of changed orchestration-code identity remain pending.
- **Status**: Accepted; profile archive checksum replaced by Git tree hash or dirty-path list per DEC-089

## DEC-019
- **Question**: Should experimental builds with modified construction code be permitted with an explicit traceability limitation, without another source inventory?
- **Context/Nuances**: DEC-018 detects repository-wide dirty state, but the identification TAR covers only the captured profile. A commit and dirty flag cannot exactly identify or reconstruct uncommitted constructor changes. Extending the archive to the entire repository or introducing another per-file inventory would add complexity to the source-identification approach simplified in DEC-008. Formal acceptance from a clean clone already provides Git identity for both profile and constructor. This limited experimental traceability must not be presented as exact reconstruction of all executed code.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed experimental-build traceability limitation.
- **Decision**: Permit experimental builds with locally modified construction code and mark them dirty under the repository-wide rule. Explicitly record that commit plus dirty indication does not identify or enable exact reconstruction of that modified code. Do not broaden the profile TAR to the full repository or add another file inventory for this purpose at this stage. Keep formal acceptance restricted to a clean clone, where Git identifies both the profile and construction code.
- **Status**: Accepted; limitation extended to dirty profile content per DEC-089

## DEC-020
- **Question**: Should invoking `operations/build` without arguments start construction of the fixed profile using the approved defaults?
- **Context/Nuances**: The current Story 1.2 discovery implementation returns status 2 for unavailable domain behavior. Story 1.3 replaces that build-only refusal with real construction; it does not change the availability of unrelated lifecycle operations. Help remains a separate, side-effect-free contract. Formal acceptance depends on a clean clone and evidence, not on an invocation flag, and boot qualification remains independently invoked under Story 1.4. This decision establishes the default invocation, not additional options or complete argument handling.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed no-argument build invocation.
- **Decision**: In the Story 1.3 implementation, invoking `operations/build` without arguments starts construction from the fixed `image/archiso/` profile, with the default cache and all approved controls. Preserve side-effect-free, unprivileged help. Do not introduce a separate acceptance mode or a flag that confers formal acceptance, and do not automatically launch boot testing. Formal acceptance remains determined by the clean-clone workflow and its evidence.
- **Status**: Accepted

## DEC-021
- **Question**: Should `operations/build --no-cache` bypass the persistent Pacman cache without changing or deleting it?
- **Context/Nuances**: Story 1.1 DEC-043 and TODO-006 require a no-cache build to demonstrate that the supported construction path does not depend on cached package archives. Removing the shared cache to perform this test would alter resources potentially used by other executions. This option concerns the named persistent Pacman cache, not an implicit promise to disable every Docker or upstream caching layer. Fresh-container, current-image resolution, signature verification, and package-version preflight requirements remain unchanged.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed no-cache invocation.
- **Decision**: Add `operations/build --no-cache`. For that execution, do not mount `mirroros-pacman-cache`, and do not remove or modify the existing cache volume. Preserve all approved version, authenticity, secret-safety, and evidence controls. Use this supported invocation for the required cache-independent build qualification; concrete option-combination and argument-validation rules remain pending.
- **Status**: Accepted for the option; real no-cache qualification build replaced by Bats verification per DEC-090

## DEC-022
- **Question**: Should the build accept only no arguments, a sole `--no-cache`, or a sole `--help`, rejecting all other forms before effects?
- **Context/Nuances**: DEC-020 and DEC-021 establish the default and no-cache build invocations, while inherited discovery help succeeds without mutation or privilege. A small explicit argument surface avoids speculative options and ambiguous combinations. This build-specific contract replaces the initial help-only argument contract for `operations/build`, not for unrelated lifecycle commands. Argument rejection must precede file creation and Docker invocation; normalized status 2 identifies invalid input rather than a failed attempted build.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed minimum argument contract.
- **Decision**: Accept exactly three forms: no arguments starts a default-cache build, sole `--no-cache` starts a build without the persistent cache mount, and sole `--help` displays side-effect-free, unprivileged help. Reject all other arguments or combinations, including unknown arguments, repeated options, and `--help --no-cache`, with normalized status 2 and a diagnostic on stderr before creating files or invoking Docker.
- **Status**: Accepted

## DEC-023
- **Question**: Should build execution reject a root invocation while still allowing root to consult help?
- **Context/Nuances**: The architecture requires unprivileged lifecycle orchestration with narrow elevation. Running the host build command as root could create root-owned temporary sources or evidence despite the normal-user export contract. The construction privilege required by `mkarchiso` belongs inside the selected privileged Docker container, not to a globally privileged host workflow. Side-effect-free help has no reason to depend on the invoking user's privilege level. This decision does not authorize automatic changes to Docker access or select Docker-access remediation.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the root-build rejection and help exception.
- **Decision**: Reject construction invocations of `operations/build` when executed as root, returning normalized status 2 with guidance to run as a normal user with access to Docker. Keep sole `--help` available when invoked as root, without changes or privilege elevation. Preserve the privileged-container boundary for `mkarchiso` and the normal-user ownership requirements for temporary sources and retained evidence.
- **Status**: Accepted

## DEC-024
- **Question**: Should Docker require direct access by the invoking user, with no automatic sudo fallback?
- **Context/Nuances**: Story 1.1 already establishes an operational Docker daemon as an external prerequisite and prohibits automatic service, group, or socket remediation. DEC-023 requires unprivileged host orchestration, but that alone does not specify whether Docker calls could fall back to sudo. Direct access must be checked explicitly. Access to Docker permits root-equivalent operations; a normal-user invocation is a process and ownership boundary, not a guarantee of security isolation from host root.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of direct Docker access without sudo fallback.
- **Decision**: Check daemon access as the user invoking the build. If Docker is inaccessible, stop with normalized status 2 and an actionable diagnostic. Do not fall back automatically to `sudo docker`, start services, or change host permissions or groups. Document the root-equivalent authority of Docker access and do not imply that normal-user orchestration removes that risk.
- **Status**: Accepted

## DEC-025
- **Question**: Should each build use run-specific host directories for temporary preparation, exported artifacts, and evidence?
- **Context/Nuances**: The architecture already requires one run identifier propagated unchanged through execution and evidence. Shared host output directories could overwrite or confuse results from different builds. Host-side preparation and export do not authorize writable bind mounts for privileged Docker work: the inherited internal `/work` and `/out` storage remains separate. This decision selects the directory layout, not the identifier format, artifact publication sequence, directory collision handling, or permissions for all output classes.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed per-run organization.
- **Decision**: Use `build/archiso/<run-id>/` for temporary sources and local preparation, `dist/<run-id>/` for artifacts exported by that execution, and `evidence/archiso-build/<run-id>/` for metadata and permitted diagnostics. Propagate the same run identifier to all three. Give each build its own directories without overwriting prior results. Keep container `/work` and `/out` inside Docker; do not use the host `build/` directory as a writable build-work bind mount.
- **Status**: Accepted

## DEC-026
- **Question**: Should the artifact be published through private staging followed by transfer to `dist/<run-id>/` only after the required build checks pass?
- **Context/Nuances**: Exporting directly to the result location could make an incomplete or rejected image appear accepted. The selected per-run layout provides a host preparation area separate from published outputs. Candidate staging must receive the required export, integrity, metadata, and secret-inspection checks. Passing these construction controls is distinct from formal Story 1.3 acceptance from a clean clone and from boot or later known-good qualification. The decision selects sequencing, not atomic publication mechanics or failed-candidate retention.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of two-phase publication.
- **Decision**: Export the ISO first to private preparation storage within `build/archiso/<run-id>/`. Publish it in `dist/<run-id>/` only after export verification, checksum, metadata, and required secret scans pass. Do not present incomplete or rejected candidates in the accepted-result location. Publication certifies construction acceptance only, not boot qualification, known-good status, or automatic formal acceptance of the story.
- **Status**: Accepted

## DEC-027
- **Question**: Should the ISO, checksum, and metadata be published together by atomically renaming a verified temporary directory within `dist/`?
- **Context/Nuances**: DEC-026 selects private staging followed by publication after checks. Publishing individual files could expose a final ISO without its checksum or metadata. A transfer from `build/` to `dist/` might cross filesystems, so it must not be treated as an atomic rename. Preparing the complete bundle in a temporary directory inside `dist/` permits a same-filesystem final directory rename after completeness and identity checks. Diagnostic evidence remains separately retained; this is not a transaction across all evidence and output locations. Concrete temporary names, collision protection, failure handling, and durability checks remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of atomic artifact-bundle publication.
- **Decision**: Publish ISO, checksum, and metadata as one bundle. Transfer them into a temporary directory within `dist/`, verify completeness and equality with the validated staging content, then atomically rename that directory to `dist/<run-id>/`. Do not expose a partial final bundle or rely on cross-filesystem transfer as atomic publication. Retain diagnostic evidence under `evidence/archiso-build/<run-id>/` separately.
- **Status**: Accepted

## DEC-028
- **Question**: Should incomplete or rejected ISO candidates and incomplete publication copies be deleted by default after diagnostic preservation?
- **Context/Nuances**: Failed candidates may contain sensitive content and can be confused with valid outputs if retained indiscriminately. Persistent failure evidence is required, but that obligation does not require retaining raw ISO candidates. Cleanup must follow preservation and verification of permitted, secret-scanned diagnostics and the inherited export-before-container-removal ordering. Removal remains scoped to the current execution and excludes already published bundles and previous results. Concrete interruption and cleanup-failure handling remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed rejected-candidate cleanup policy.
- **Decision**: Do not retain incomplete or rejected ISO candidates by default. After retaining and verifying permitted, secret-scanned diagnostic evidence, remove the current run's failed candidates and incomplete publication copies. Do not remove already published bundles or results from earlier runs. Preserve the inherited requirement to export and verify diagnostics before retiring the build container.
- **Status**: Accepted

## DEC-029
- **Question**: Should a cleanup failure after successful publication return execution failure while preserving the published bundle?
- **Context/Nuances**: Construction checks and atomic publication can succeed before removal of the container or temporary resources fails. Artifact publication and overall lifecycle completion are distinct outcomes; deleting valid output would obscure that distinction. A retained bundle does not justify reporting a fully successful run or promoting it to later qualification states. Metadata and evidence must not incorrectly equate publication completion with global success. This decision concerns post-publication cleanup failure, not precedence when a primary failure or cancellation already exists.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed post-publication cleanup-failure behavior.
- **Decision**: If cleanup fails after successful publication, return normalized status 5, report that publication completed but cleanup did not, and preserve the published bundle. Record remaining resources and actionable safe-cleanup guidance in evidence. Do not announce overall success, delete a valid bundle to hide the failure, or automatically promote it to later qualification states. Resolve primary-failure and cancellation precedence separately.
- **Status**: Accepted

## DEC-030
- **Question**: Should an additional cleanup failure preserve an existing primary failure, cancellation, or signal result rather than replace it?
- **Context/Nuances**: A cleanup trap can obscure the operation that originally failed if its own error overwrites the lifecycle status or child diagnostics. DEC-029 addresses cleanup failure after otherwise successful publication; a run with an earlier non-success outcome needs separate precedence. The normalized primary lifecycle outcome and original child status are distinct and must remain attributable. Preserving an explicit cancellation or shell signal status does not select a new cancellation mechanism or authorize treating a signal as normalized cancellation 3.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of primary-result precedence.
- **Decision**: Preserve an existing primary failure, explicit cancellation, or signal-termination result and its applicable original status when cleanup also fails. Record the cleanup failure separately with remaining resources and recovery guidance, without masking the primary diagnostics. Cleanup changes an otherwise successful result to normalized execution failure 5 under DEC-029; it does not overwrite an earlier non-success outcome. Respect ordinary shell signal-status conventions.
- **Status**: Accepted

## DEC-031
- **Question**: Should SIGINT and SIGTERM stop the current run's container work and attempt evidence preservation and cleanup while retaining shell signal statuses?
- **Context/Nuances**: A signal sent to host orchestration must not be assumed to stop work running inside Docker automatically. Cleanup must be scoped to the interrupted execution and must not remove resources while ignoring the evidence-export contract. DEC-030 preserves the signal outcome if cleanup also fails. SIGKILL and host failure cannot be handled through normal traps, so unconditional cleanup or evidence preservation cannot be promised. Concrete stop commands, timeouts, and handling of repeated interruption remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed interruption treatment.
- **Decision**: On SIGINT or SIGTERM, attempt to stop active work in the current execution's container, retain and verify permitted diagnostic evidence, and then clean up its resources. Preserve status 130 for SIGINT and 143 for SIGTERM rather than mapping them to normalized cancellation 3. Record secondary cleanup errors without replacing those statuses. Document that SIGKILL and host failure may leave resources requiring later recovery and cannot guarantee this sequence.
- **Status**: Accepted

## DEC-032
- **Question**: Should leftover resources from previous executions require explicit documented recovery rather than automatic cleanup or reuse by a new build?
- **Context/Nuances**: SIGKILL or host failure may leave containers and temporary files without a completed lifecycle record. Such residue cannot safely be presumed inactive or disposable based solely on age. Reusing it would violate the fresh-container and isolated-run contracts, while deleting it could destroy active work or unexported diagnostics. This decision selects a recovery policy, not a new cleanup command, resource-identification mechanism, or automatic orphan scanner.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of explicit recovery without automatic cleanup of earlier runs.
- **Decision**: A new build must not automatically delete or reuse resources from previous executions. Document explicit recovery: identify the affected execution, check that it is no longer active, preserve permitted diagnostics, and remove only resources belonging to that execution. Age of a directory or container is not sufficient authorization for deletion. Resolve concrete identification and liveness checks separately.
- **Status**: Accepted

## DEC-033
- **Question**: Should each build container be identified by a run-specific name, labels, and its actual Docker container ID recorded in evidence?
- **Context/Nuances**: Explicit recovery needs a reliable relationship between a run and its container, not selection based only on age or a name prefix. Names can be reused and labels do not prove liveness or create a security boundary. Recovery must compare the recorded identity before acting and still perform the separately required activity checks. The persistent Pacman cache is shared rather than exclusively owned by a run and must not be included in per-run cleanup authority. Concrete recording order and behavior when identity evidence is missing remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed container identification contract.
- **Decision**: Name the build container `mirroros-archiso-build-<run-id>` and set labels `org.mirroros.stage=build` and `org.mirroros.run-id=<run-id>`. Record its actual Docker container ID together with its name and labels in run evidence. Recovery checks this correspondence before acting; names or labels alone neither prove inactivity nor authorize deletion. Keep the shared cache outside the run's exclusive resource set.
- **Status**: Accepted

## DEC-034
- **Question**: Should the run identifier combine a compact UTC timestamp and a UUID?
- **Context/Nuances**: Per-run directories and container identity need a shared identifier. A timestamp alone can collide when builds start within the same second. Adding a UUID avoids relying solely on start time while retaining human-sortable timestamps. This identifies an execution, not source content or ISO bytes, and is unrelated to the identification TAR's normalized timestamps. The generator, UUID version, collision checks, and recording order remain to be specified.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed run identifier format.
- **Decision**: Use `YYYYMMDDTHHMMSSZ-<uuid>` as the run identifier: a compact UTC timestamp followed by a UUID. Generate it once and propagate it unchanged through run directories, container identity, and evidence. Do not include usernames or personal data, and do not use it as source or artifact content identity.
- **Status**: Accepted

## DEC-035
- **Question**: Should a per-run exclusive flock serve as the activity check for host orchestration?
- **Context/Nuances**: Explicit recovery must avoid interfering with a live build. A PID alone can be reused, whereas a held native advisory lock can provide a conservative process-activity check without a custom state registry. Inspection found `/usr/bin/flock` from util-linux 2.40.4 on the current host; this is availability evidence, not a version pin. A free lock does not prove that Docker work has stopped, and advisory locking is not a security boundary. Lock placement, creation, descriptor handling, and filesystem compatibility remain to be specified.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of a per-run flock for orchestration activity.
- **Decision**: Hold an exclusive per-run flock for the entire execution, including cleanup. Recovery attempts non-blocking acquisition of that same lock; if it is occupied, do not act on the run's resources. Even when acquired, verify container identity and state separately before recovery. Use flock as the orchestration activity check rather than relying solely on a PID.
- **Status**: Accepted

## DEC-036
- **Question**: Should the per-run lock file remain at `evidence/archiso-build/<run-id>/run.lock` rather than inside removable temporary storage?
- **Context/Nuances**: Unlinking and recreating a lock path while a descriptor still holds a lock can create different underlying files with the same pathname, defeating coordination. The evidence directory is retained rather than removed during ordinary temporary-resource cleanup. A persistent lock file can exist after its lock has been released; existence alone is not evidence of an active process. Concrete secure file creation, descriptor lifecycle, and recovery when the evidence path is missing remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the persistent evidence-side lock location.
- **Decision**: Place the lock at `evidence/archiso-build/<run-id>/run.lock` and retain the file with execution evidence. Do not delete it during temporary-resource cleanup or replace it while coordinating that run. Determine activity through actual lock acquisition, not the file's existence. Preserve the per-run exclusive-lock and separate Docker-state check contracts.
- **Status**: Accepted

## DEC-037
- **Question**: Should recovery stop without mutations when the recorded container identity or run lock is missing?
- **Context/Nuances**: A residual container can outlive its evidence directory or identity record. Recreating a missing lock would not establish that the original orchestration is inactive, and names or labels alone cannot replace the recorded actual container ID. Conservatively leaving resources intact avoids deleting live work or unexported diagnostics. This policy calls for documented manual investigation, not a new automatic adoption or cleanup mechanism. Concrete investigation instructions remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of conservative recovery refusal when identity or locking evidence is missing.
- **Decision**: If the recorded container ID or `run.lock` is missing, stop the recovery procedure before modifying resources. Do not recreate the lock or infer sufficient identity solely from the container name or labels. Explain which required data is missing and require manual investigation before removal can be authorized. Leave resources intact while safe recovery cannot be established.
- **Status**: Accepted

## DEC-038
- **Question**: Should explicit recovery require authorized and verified stopping of a running, paused, or restarting container before diagnostic preservation and removal?
- **Context/Nuances**: Recovery first acquires the existing per-run flock and verifies the recorded container identity. A free orchestration lock does not establish that Docker work has ended. Stopping active residual work is a consequential recovery action requiring explicit maintainer authorization. Diagnostic preservation and verification must still precede removal. Unknown state or failed state queries cannot establish safe recovery. Concrete commands, paused-state handling, timeouts, and tests remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed registration summary.
- **Decision**: During explicit recovery, after acquiring the per-run flock and verifying recorded container identity, require explicit maintainer authorization to stop a container in running, paused, or restarting state. Query and verify that it has stopped before preserving and verifying permitted diagnostics and finally removing it. Block recovery without resource removal if authorization is absent, stopping fails, the stopped state cannot be verified, an unknown state is reported, or a state query fails. Do not use forced removal as a shortcut or represent recovery as successful construction. Resolve concrete commands, paused-state handling, timeouts, and tests separately.
- **Status**: Accepted

## DEC-039
- **Question**: Should authorization to stop a paused residual container explicitly cover resuming it and the risk of brief process execution?
- **Context/Nuances**: Stopping a paused container may require resuming it first. Resumption can allow its processes to execute briefly before the stop request takes effect; it must not be presented as a consequence-free administrative step. The existing recovery lock, recorded-identity verification, stopped-state verification, and diagnostic-preservation requirements remain in force. Concrete commands and timeouts remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the recommended paused-container recovery criterion.
- **Decision**: For recovery of a paused container, the explicit stop authorization must describe resumption and its risk of brief process execution. Only after that authorization may recovery resume the container and immediately request its stop. If either resumption or the stop operation fails, block container removal. Preserve DEC-038's separate stopped-state verification and diagnostic-preservation sequence before removal.
- **Status**: Accepted

## DEC-040
- **Question**: Should recovery allow 30 seconds for orderly container stopping, followed by forced termination through Docker's stop mechanism?
- **Context/Nuances**: Residual work may not respond to an orderly stop. A bounded grace period avoids waiting indefinitely for cooperative process termination, but forced termination can interrupt writes and reduce diagnostic completeness. Explicit authorization must disclose that possibility. Forced process termination within Docker's stop mechanism is distinct from forced container removal, which remains prohibited as a shortcut. The global deadline for a blocked Docker call is a separate unresolved concern.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the recommended 30-second stop grace policy.
- **Decision**: During explicit recovery, allow 30 seconds for orderly stopping, then permit forced termination through Docker's stop mechanism, never forced removal as a substitute. The stop authorization must warn of possible abrupt termination. Verify the stopped state and preserve and verify permitted diagnostics before container removal. Resolve the global deadline for a blocked Docker call separately.
- **Status**: Accepted

## DEC-041
- **Question**: Should the Docker stop call during explicit recovery have a global 60-second deadline?
- **Context/Nuances**: DEC-040's 30-second process-stop grace period does not bound a Docker client call blocked by daemon or communication problems. A client deadline bounds the maintainer's wait, not daemon-side execution. Expiration does not establish that the daemon cancelled the stop operation or that the container is stopped. The user approved this policy and separately raised concern about increasing process complexity; that concern does not itself approve a design revision.
- **User Response**: "yes, registra directamente la decisión." The user also questioned whether extensive controls are necessary for a single-maintainer workflow or whether good documentation is sufficient.
- **Decision**: Limit the Docker stop call during explicit recovery to 60 seconds in total, including the 30-second grace period. On expiration, terminate the client wait and block removal, leaving resources for investigation and a new explicit recovery attempt. Do not infer daemon-side cancellation or stopped container state from deadline expiration. Do not authorize removal or automatic retry on that basis. Discuss the user's complexity concern separately before selecting any simplification.
- **Status**: Accepted

## DEC-042
- **Question**: Should exceptional recovery remain a concise manual procedure, with mechanical details no longer split into individual interview decisions?
- **Context/Nuances**: The single maintainer questioned the growing complexity of recovery design. DEC-032 already selects documented explicit recovery rather than a new command. DEC-033 through DEC-041 establish identity, activity, authorization, stopping, and evidence safeguards, but do not require a recovery state machine, automated prompts, or an automatic recovery subsystem. These safeguards remain useful as manual procedure instructions and warnings. Simplifying delivery and interview granularity does not waive approved safety or evidence contracts.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed simplification approach.
- **Decision**: Keep the constructor's normal-execution controls, but deliver exceptional previous-run recovery as a concise manual guide with commands, checks, and warnings, not new recovery automation. Preserve the approved safeguards. Stop resolving each mechanical recovery detail as an individual interview decision unless it affects safety, evidence preservation, or inherited contracts. This changes delivery emphasis and interview granularity, not the substance of DEC-032 through DEC-041.
- **Status**: Accepted

## DEC-043
- **Question**: Should build diagnostics use simple private file capture and scanning before retention rather than live upstream output or a custom redaction filter?
- **Context/Nuances**: The user questioned additional diagnostic controls because source validation and secret scanning already precede commits, while formal acceptance requires a clean clone. Those gates protect evaluated source content but do not scan newly generated diagnostics before terminal exposure. Repository inspection found that operations/build still implements discovery only and provides no existing log filter. The acquisition procedure invokes Pacman with direct terminal output, while repository and import validation use redacted Gitleaks reports and scan retained evidence. That precedent does not demonstrate prevention of secrets in live upstream output. A simple file redirection avoids a custom streaming redactor, parser, or filtering subsystem, at the cost of losing detailed live upstream output. Pre-commit source validation remains in place without introducing another source-validation system through this decision.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of simple private capture to preserve terminal protection without detailed live upstream output.
- **Decision**: Capture upstream build-tool diagnostics through ordinary redirection into a private temporary file rather than forwarding detailed upstream output live to the terminal. Show progress by stage. Scan captured logs with Gitleaks before retaining them as evidence. Do not implement a custom log filter, parser, or live redaction mechanism. Preserve pre-commit source validation and the existing requirement not to expose secret values in terminal output or retained evidence. Concrete capture paths, scan-failure handling, and diagnostic retention mechanics remain pending.
- **Status**: Revised by DEC-088 (live output with `tee`; private-only capture removed)

## DEC-044
- **Question**: Should a captured log be discarded without exposure or retention when it contains a detected secret or its scan fails?
- **Context/Nuances**: DEC-043 selects private temporary capture and Gitleaks inspection before diagnostic retention. A finding or scanner failure cannot establish that the captured output is safe. Automatically sanitizing and revalidating raw diagnostics would introduce the filtering complexity deliberately avoided. Discarding an unvalidated log sacrifices detailed upstream context, so retain a minimal safe account of the stage, scan outcome, and available exit statuses without detected values. Evidence preservation never authorizes retaining secret values.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of discarding unvalidated logs and retaining only a minimal safe diagnostic.
- **Decision**: If a captured log contains a detected secret or its scan fails, block artifact acceptance. Do not display or retain that log; discard it. Record only the affected stage, scan outcome, and available exit statuses without detected values. Do not attempt automatic sanitization of the log. Preserve only this minimal safe diagnostic when detailed captured output cannot be validated.
- **Status**: Superseded by DEC-088

## DEC-045
- **Question**: Should retained diagnostic logs be limited to specific preparation and construction operations rather than indiscriminate environment or container dumps?
- **Context/Nuances**: Useful upstream diagnosis requires operation-attributable output, while broad collection increases sensitive-content exposure and maintenance cost. The architecture requires allowlisted evidence. Capturing operation output is distinct from collecting all environment variables, a complete filesystem, or full Docker inspection dumps. DEC-043 and DEC-044 still require private capture, successful scanning before retention, and discarding unvalidated logs. Concrete operation coverage can be supplied within this bounded scope during implementation.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed bounded retention scope.
- **Decision**: Retain successfully scanned output from the specific preparation and construction operations, including Pacman and mkarchiso, identifying the responsible operation and its exit status. Use a small explicit diagnostic allowlist. Do not indiscriminately collect environment variables, the complete filesystem, or full docker inspect dumps. Preserve the private-capture and unvalidated-log handling contracts.
- **Status**: Accepted for the allowlist; capture and discard handling revised by DEC-088

## DEC-046
- **Question**: Should the build retain minimal inspection of final artifact contents in addition to source, profile, and evidence controls?
- **Context/Nuances**: The user questioned the value of ISO inspection when source and profile are already scanned. Final contents also include files supplied by packages, hooks, and construction tools, so source scanning does not establish final-content coverage. Extraction introduces dependencies, runtime cost, and possible false positives in upstream files; Gitleaks does not certify absolute absence of secrets. Internal artifact inspection is already included in DEC-001 and inherited from Story 1.2. The initial affirmative response was ambiguous between retaining inspection and revising the requirement; explicit clarification confirmed minimal final-content inspection. No extraction mechanism was approved.
- **User Response**: "si...puedes explorar más en el mecanismo" in response to explicit confirmation of retaining minimal final-content inspection with the mechanism pending.
- **Decision**: Retain minimal inspection of final artifact contents alongside source, profile, and evidence controls. Do not expand this into a general system audit or claim absolute absence of secrets. Explore the concrete mechanism before recommending its selection; extraction tools and coverage remain pending.
- **Status**: Superseded by DEC-085

## DEC-047
- **Question**: Should unprivileged extraction with xorriso and unsquashfs implement the base inspection of the exported ISO and its root filesystem?
- **Context/Nuances**: Inspection of image/archiso/profiledef.sh confirms SquashFS as the current root filesystem format. Local tool help confirms ISO extraction with xorriso and SquashFS extraction with unsquashfs. Gitleaks documents archive traversal but its referenced archive library does not list ISO or SquashFS among supported archive formats; scanning an opaque ISO is therefore not evidence of internal coverage. The host's installed Archiso is 82-1, while the imported profile is 91-1, so the host constructor is not authoritative for the exact output layout. Inspecting the exported candidate rather than only pre-packaging staging covers the artifact intended for publication. Extraction requires additional temporary space and time. Initramfs and any UEFI FAT image remain separate pending coverage concerns; this base mechanism does not establish complete internal coverage.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed unprivileged base mechanism on the exported ISO.
- **Decision**: Use xorriso to extract files from the exported candidate ISO and unsquashfs to extract its SquashFS root filesystem into private temporary inspection directories. Perform this inspection without privilege elevation, filesystem mounting, or execution of extracted content. Scan extracted files with Gitleaks, preserve only safe inspection results, and remove inspection copies after permitted evidence preservation. Extraction failures or unreadable files block the inspection rather than producing a clean result. Keep initramfs and UEFI-image coverage explicitly pending and do not claim complete internal coverage from this base mechanism alone.
- **Status**: Superseded by DEC-085

### DEC-047 Research References

- Gitleaks archive-scanning documentation: https://github.com/gitleaks/gitleaks#archive-scanning
- Referenced archive-library supported formats: https://github.com/mholt/archives#supported-archive-formats

These mutable upstream references explain the mechanism rationale; they are not tool-version pins or runtime dependencies. Local tool availability is an observation, not a portability guarantee.

## DEC-048
- **Question**: Should internal artifact inspection include initramfs extraction with lsinitcpio and subsequent Gitleaks scanning?
- **Context/Nuances**: Initramfs images can contain configuration and files added during construction. Scanning the extracted SquashFS does not automatically inspect the contents of these packed images. Local lsinitcpio help and implementation confirm extraction support for both the early CPIO archive and the main CPIO archive. This extends the selected extraction approach with an existing tool rather than a custom archive parser. Concrete invocation, image enumeration, dependency checks, and tests remain implementation details; local availability is not a version pin or portability guarantee.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of initramfs coverage through lsinitcpio.
- **Decision**: Include the ISO's initramfs images in artifact inspection by extracting them with lsinitcpio and scanning the extracted files with Gitleaks. Cover both the early CPIO archive, when present, and the main CPIO archive. Perform extraction without privilege elevation or execution of extracted content. Extraction failure blocks inspection. Preserve the existing private temporary storage, safe evidence retention, and inspection-copy cleanup requirements.
- **Status**: Superseded by DEC-085

## DEC-049
- **Question**: Should artifact inspection cover the contents of a UEFI FAT boot image using mtools without mounting it?
- **Context/Nuances**: Extracting the ISO filesystem tree alone does not inspect files inside an embedded UEFI FAT image. Existing mtools can access its contents without filesystem mounting or privilege elevation. Initramfs found inside that image require the separately approved unpacking and scanning treatment. The image's absence is distinct from inability to locate or extract a present image; only actual absence supports a not-applicable result. Concrete image discovery, extraction arguments, dependency checks, and tests remain implementation deliverables.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of UEFI image coverage through mtools.
- **Decision**: If the ISO contains a UEFI FAT boot image, extract its contents with mtools without mounting it or elevating privileges, and scan the extracted files with Gitleaks. Apply DEC-048 to initramfs within that image. Extraction failure blocks inspection; if the image is absent, record this coverage as not applicable. Preserve the existing private temporary storage, safe evidence retention, and inspection-copy cleanup requirements.
- **Status**: Superseded by DEC-085

## DEC-050
- **Question**: Should the artifact package manifest cover every package installed in the ISO root filesystem with its actually resolved version?
- **Context/Nuances**: The requested package list does not enumerate all resolved dependencies or packages added during construction. The build container's installed packages describe the construction environment rather than the artifact's installed package set. Keeping these identities separate prevents attributing builder packages to the ISO or treating declared requests as proof of final contents. Manifest format and repository association remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed artifact package-manifest scope.
- **Decision**: The required artifact package manifest identifies all packages installed in the ISO root filesystem and their actually resolved versions, including dependencies and packages added during construction. Do not substitute packages.x86_64 or the build container's package inventory for this manifest. Treat builder packages separately as construction-environment identification. Resolve manifest format and repository association separately.
- **Status**: Accepted

## DEC-051
- **Question**: Should the artifact reuse Archiso's native installed-package manifest extracted from the ISO?
- **Context/Nuances**: Inspection of the canonical Archiso v91 mkarchiso source confirms that _make_pkglist generates the ISO's <install_dir>/pkglist.<arch>.txt using pacman -Q against the constructed root filesystem, after customization in _build_iso_base. With the current profile this is arch/pkglist.x86_64.txt. Its native text records package names and resolved versions; it does not by itself establish package-to-repository attribution. Reusing upstream output avoids a redundant JSON package inventory while retaining DEC-050's artifact-specific scope. The observed v91 behavior is evidence for the current baseline, not a permanent Archiso version pin.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of reuse of Archiso's native manifest.
- **Decision**: Use Archiso's native installed-package manifest extracted from the ISO as the artifact package manifest, retaining its package version text format. For the current profile its ISO path is arch/pkglist.x86_64.txt. Do not introduce another JSON package inventory for this purpose. Keep package attribution to repositories as a separate requirement to resolve.
- **Status**: Accepted

### DEC-051 Research Reference

- Canonical Archiso v91 mkarchiso source: https://gitlab.archlinux.org/archlinux/archiso/-/raw/v91/archiso/mkarchiso

## DEC-052
- **Question**: Should artifact packages be attributed using the repository databases used by that construction, with exact name/version matching and configured priority?
- **Context/Nuances**: The current profile enables core and extra. Archiso's native manifest records names and installed versions but not repository origin. Later repository queries may describe a different package set because Arch repositories roll. Repository association must remain tied to the evaluated execution rather than inferred from current online availability. Matching must respect the configured repository priority; unresolved or ambiguous origin cannot be silently invented. Concrete capture and association mechanisms and output format remain pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of execution-bound repository attribution.
- **Decision**: Associate each artifact package with the repository databases used in its construction, requiring an exact package-name and version match and respecting configured repository priority. Do not substitute repositories refreshed after construction for those execution inputs. Block artifact acceptance if a package cannot be attributed unambiguously. Resolve the concrete mechanism and format separately.
- **Status**: Superseded by DEC-086

## DEC-053
- **Question**: Should package-to-repository attribution use a complementary JSON record while preserving the native package manifest?
- **Context/Nuances**: DEC-051 selects the native package version text manifest, and DEC-052 separately requires execution-bound repository attribution. A complementary structured record can express that relationship without replacing the native manifest or creating an independently resolved package inventory. It must agree with the package set and versions extracted from the ISO. Non-trivial structured processing belongs to JavaScript ESM under the inherited language boundary and does not require npm dependencies. Exact schema remains pending.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of JSON as the complementary attribution format.
- **Decision**: Keep the native package manifest unchanged and add a complementary JSON record associating each package with its name, version, and repository. Require agreement with the ISO's native manifest rather than treating the JSON as an independent inventory. Process this structured responsibility in JavaScript ESM without requiring npm dependencies. Resolve the exact schema separately.
- **Status**: Superseded by DEC-086

## DEC-054
- **Question**: Should the native package manifest and complementary repository-attribution JSON be included in the published artifact bundle?
- **Context/Nuances**: Retaining package records only in a separate evidence tree would allow an ISO bundle to be moved or preserved without the records required to diagnose its package contents. DEC-027 already requires atomic publication of a verified complete bundle. Adding these approved records to that bundle does not turn publication into boot qualification or create a transaction across dist and evidence.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of including both package records in the published bundle.
- **Decision**: Include the native package manifest and complementary package-to-repository attribution JSON in dist/<run-id>/ alongside the ISO, checksum, and required metadata. Validate both files before the already approved atomic bundle publication. Preserve the existing separation between artifact publication and diagnostic evidence retention.
- **Status**: Accepted for the native manifest; attribution JSON removed by DEC-086

## DEC-055
- **Question**: Should SOURCE_DATE_EPOCH use the execution start instant rather than the commit date or the identification TAR's zero timestamp?
- **Context/Nuances**: The imported profile uses SOURCE_DATE_EPOCH for the upstream ISO date, version, and label. Fixing it once avoids relying on separately observed times during construction while retaining upstream presentation. The identification TAR's timestamp zero is an unrelated normalization convention. Using a single build date neither fixes rolling package resolution nor promises byte-identical images.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the execution start instant as SOURCE_DATE_EPOCH.
- **Decision**: Set SOURCE_DATE_EPOCH once at execution start using that UTC instant, pass it explicitly to mkarchiso, and record the value in build metadata. Do not use the source commit date or the identification TAR's zero timestamp for this purpose. Keep the date consistent across the execution without claiming binary-identical reconstruction.
- **Status**: Accepted; identification-TAR timestamp reference obsolete per DEC-089

## DEC-056
- **Question**: Should published artifact metadata remain immutable while overall execution results, including cleanup failure, are recorded separately in evidence?
- **Context/Nuances**: DEC-029 permits completed publication followed by cleanup failure with normalized status 5 and preservation of the valid bundle. Updating metadata inside an already validated bundle to represent later operational outcomes would mutate published artifact records. Construction and artifact-validation outcomes are distinct from completion of the entire lifecycle. Separate evidence can describe the global result without presenting publication as overall success or changing the published bundle.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed metadata and execution-result separation.
- **Decision**: Published artifact metadata describes construction and artifact validation and remains immutable after publication. Record the overall execution result, including any cleanup failure, separately in execution evidence. Do not modify the validated bundle to update operational status or equate artifact publication with fully successful execution.
- **Status**: Accepted

## DEC-057
- **Question**: Should the published checksum file cover the ISO, immutable artifact metadata, native package manifest, and complementary attribution JSON?
- **Context/Nuances**: A checksum for the ISO alone does not check integrity of accompanying source and package records when a bundle is moved or retained. DEC-056 keeps published metadata immutable, allowing those records to be included in the same integrity-check set. The checksum file cannot include its own digest. Checksums provide integrity comparison, not publisher authentication or a substitute for construction and secret-inspection controls. The user separately requested an estimate of remaining decision branches.
- **User Response**: "yes, registra directamente la decisión." The user also asked how many decision branches are estimated to remain.
- **Decision**: Publish a checksum file in native sha256sum format covering the ISO, immutable artifact metadata, native package manifest, and complementary package-attribution JSON. Exclude the checksum file itself. Do not describe this integrity coverage as publisher authentication or as replacing required validations.
- **Status**: Accepted; attribution JSON removed from coverage by DEC-086

## DEC-058
- **Question**: Should artifact metadata and the separate execution-result document use JSON?
- **Context/Nuances**: DEC-056 separates immutable artifact metadata from the global execution outcome retained in evidence. Both are structured responsibilities governed by the architecture's field and language conventions. Selecting JSON does not finalize their schemas or replace the native package manifest and checksum formats. Non-trivial processing belongs to JavaScript ESM under the inherited boundary.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of JSON for both documents.
- **Decision**: Use JSON for artifact metadata and the separate execution-result document. Respect architecture-required fields and process these structured responsibilities in JavaScript ESM. Keep the native package manifest and checksum file in their already selected formats. Concrete schemas remain pending.
- **Status**: Accepted

## DEC-059
- **Question**: Should the constructor automatically select committed export or working-profile capture according to repository-wide clean or dirty state?
- **Context/Nuances**: DEC-020 rejects a separate acceptance mode. DEC-011 selects git archive for formal clean-clone builds, while DEC-003 and DEC-008 permit identified dirty development inputs. Repository-wide dirty state includes changes outside the profile under DEC-018. Choosing the capture mechanism from that state provides a concrete normal invocation behavior without adding an acceptance flag. A clean local execution is not automatically formal story acceptance, which still requires the clean-clone workflow and qualification evidence.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of automatic capture selection by clean or dirty repository state.
- **Decision**: When the repository is clean, export the profile from the source commit using git archive. When the repository is dirty, capture the working profile under the approved development inclusion and protection rules, mark the execution dirty, and identify captured content using the temporary TAR and SHA-256. Select these paths automatically without adding an acceptance mode. Formal acceptance still requires the clean clone and prescribed validation evidence.
- **Status**: Accepted; dirty identification by TAR/SHA-256 replaced by dirty-path list per DEC-089

## DEC-060
- **Question**: Should profile capture support only directories, regular files, and literal symbolic links, rejecting special files and Git submodules?
- **Context/Nuances**: Repository inspection found no special files or Git submodules in image/archiso/. A FIFO is a process communication channel whose read can block, a device represents system access rather than ordinary source content, and a Git submodule points to another repository requiring additional capture and identity rules. Sockets likewise are not ordinary source files. Supporting these types would broaden the approved capture model unnecessarily. This guard does not remove or change existing profile content and does not waive literal symbolic-link preservation.
- **User Response**: After requesting a plain-language explanation, the user explicitly approved the restriction: "yes, registra directamente la decisión."
- **Decision**: Limit profile capture to directories, regular files, and literal symbolic links. If a device, socket, FIFO, or Git submodule appears within the profile, stop with normalized status 2 and identify the unsupported entry. Do not attempt to incorporate it or add special support implicitly. Preserve the approved non-dereferencing symbolic-link policy.
- **Status**: Accepted

## DEC-061
- **Question**: Should SIGINT/SIGTERM handling for the current execution reuse the approved stop deadlines without an additional stop confirmation?
- **Context/Nuances**: DEC-031 already requires attempting to stop the current container, preserve permitted diagnostics, and clean up while retaining signal statuses. DEC-040 and DEC-041 establish a 30-second orderly-stop grace period and a 60-second global Docker stop-call deadline for previous-run recovery. Applying those deadlines to the interrupted current run avoids a separate timing policy. A signal requests interruption of this execution; it does not authorize acting on another run. Previous-run recovery remains subject to its explicit authorization requirements.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed current-run interruption policy.
- **Decision**: On SIGINT or SIGTERM, use a 30-second stop grace period and a 60-second global stop-call deadline for the current run's container, without requesting an additional stop confirmation. Verify stopping, then attempt permitted diagnostic preservation and cleanup under the existing contracts. Preserve statuses 130 and 143 and report secondary failures separately. Do not extend this authorization to previous runs or treat timeout expiration as proof of stopped state.
- **Status**: Accepted

## DEC-062
- **Question**: Should a second SIGINT/SIGTERM during interruption cleanup abort that cleanup attempt rather than restart it?
- **Context/Nuances**: The first signal triggers bounded stopping, diagnostic preservation, and cleanup under DEC-031 and DEC-061. A second signal provides an escape from that attempt rather than recursively entering cleanup or authorizing forced deletion. Aborting can leave resources and incomplete diagnostics; warning and evidence preservation remain best effort and must not be guaranteed. The first signal's outcome remains primary.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed repeated-interruption behavior.
- **Decision**: If a second SIGINT or SIGTERM arrives during interruption cleanup, abort the cleanup attempt without restarting it or forcing resource removal. Preserve the first signal's exit status. If still possible, warn about resources left for explicit manual recovery. Do not promise complete diagnostic preservation after this abort.
- **Status**: Accepted

## DEC-063
- **Question**: How should secret-control outcomes map to normalized build statuses without masking an earlier primary failure?
- **Context/Nuances**: A detected secret is inadmissible content, an unavailable scanner is an unmet external prerequisite, and scanner execution failure is a failed attempted operation. These causes must be distinguishable even though all block acceptance. Inspecting diagnostics after a primary build failure must not replace the responsible operation's outcome with a secondary scan problem. Native scanner status remains attributable and is distinct from normalized lifecycle status. This classification does not authorize retention or exposure of an unvalidated log.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed outcome classification and primary-failure preservation.
- **Decision**: Use normalized status 2 for a detected secret and for a missing scanner, with diagnostics distinguishing inadmissible content from an unmet prerequisite. Use normalized status 5 for scanner execution failure and preserve its original exit status. All these outcomes block artifact acceptance. When diagnostic scanning follows an already established primary failure, preserve that primary outcome and record the scan problem separately. Retain the existing unvalidated-log discard policy.
- **Status**: Accepted for status classification; discard policy removed by DEC-088

## DEC-064
- **Question**: Should the small build JSON documents use explicit JavaScript ESM validation and tests without additional npm schema dependencies?
- **Context/Nuances**: The selected JSON responsibilities require validation of fields, types, and cross-document coherence, not only syntactic JSON parsing. Examples include disagreement between the native package manifest and complementary attribution record or incomplete artifact metadata. Node.js and its built-in modules suffice for explicit validation of these bounded documents. This avoids a schema framework and dependency maintenance without waiving document contracts or testing. Exact document schemas remain to be defined.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of explicit validation without additional npm dependencies.
- **Decision**: Validate the build JSON documents' fields, types, and coherence using JavaScript ESM and tests with Node.js and built-in modules only. Do not add an npm library or schema framework for these small documents. Detect inconsistencies and incomplete metadata before artifact publication. Preserve the existing document format and lifecycle outcome contracts.
- **Status**: Accepted; attribution-coherence example removed by DEC-086

## DEC-065
- **Question**: What minimum information should immutable artifact metadata contain?
- **Context/Nuances**: Story 1.3 and the architecture already require source, tool, repository, package, timestamp, checksum, and validation traceability. Approving these as one bounded content contract avoids separate decisions for every field. Dirty constructor executions retain the explicit traceability limitation of DEC-019, and validated construction does not confer boot qualification. Published metadata must not contain secrets or represent subsequent cleanup as an artifact property. Concrete field names and validation follow architecture conventions.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed minimum immutable metadata content.
- **Decision**: Include execution identity, source commit, clean/dirty indication, and captured-profile identity; construction architecture, container digest, exact Archiso version, effective build date, and relevant tool versions; effective repository configuration and references to the native package manifest and complementary attribution record; ISO filename, size, and SHA-256; required control outcomes and inspection scope; and applicable experimental traceability limitations plus the distinction between validated construction and boot qualification. Exclude secrets and subsequent cleanup outcomes. Use architecture conventions for concrete field names and validation.
- **Status**: Accepted; attribution-record reference removed by DEC-086

## DEC-066
- **Question**: What minimum information should the separate execution-result JSON contain?
- **Context/Nuances**: The architecture requires attributable lifecycle outcomes, original child statuses, timing, and safe diagnostic references. Publication can complete while cleanup fails, so neither outcome can substitute for the global execution result. Interruption may prevent complete observations; missing information must not be invented or interpreted as success. A result document describes observed execution rather than introducing a recovery state machine or replacing allowed logs.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed minimum execution-result content.
- **Decision**: Record execution ID and references to sources and artifacts; start, end, and duration; global outcome, exit status, and the stage or operation responsible for failure; original statuses of executed tools; validation outcomes and permitted diagnostic references; whether publication completed, separately from the global result; and cleanup outcome, remaining resources, and recovery guidance. Do not invent data unavailable due to interruption or convert unknown information into success. Keep the document distinct from logs and do not turn it into a state machine.
- **Status**: Accepted

## DEC-067
- **Question**: Should Story 1.3 validation use JavaScript unit tests, Bats command contract tests, and separate real build qualification?
- **Context/Nuances**: A complete ISO build for every contract case would be slow and make deterministic failure testing difficult. The inherited Bats mechanism can exercise command behavior with tool doubles and disposable directories, but simulations do not demonstrate actual Docker/Archiso construction. Node's built-in test runner avoids an npm test dependency for structured responsibilities. Real qualification must still meet the inherited clean-clone, export, ownership, cache-independent build, inspection, and failure-evidence requirements. Boot qualification remains Story 1.4.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the three-layer test strategy.
- **Decision**: Use node:test for JavaScript document and metadata-coherence tests; Bats with simulated tools and disposable directories for command contracts, failures, signals, publication, and cleanup; and separate real Docker/Archiso qualification from a clean clone covering export, ownership, inspection, cache behavior, a no-cache build, and failure diagnostic preservation. Do not build a complete ISO for every automated contract test. Simulated tests establish contracts only, real qualification establishes construction, and neither substitutes for Story 1.4 boot qualification.
- **Status**: Accepted; real no-cache build removed by DEC-090

## DEC-068
- **Question**: Should negative secret-control tests use synthetic values and small disposable images to prove coverage and non-exposure?
- **Context/Nuances**: Clean scans alone do not demonstrate that a control detects secret-like content inside the approved artifact layers or prevents its terminal/evidence exposure. Synthetic detectable values can exercise these contracts without real credentials. Small generated image fixtures avoid a complete Archiso build for each case and must remain generated, ignored, and disposable rather than become acceptance artifacts or committed secret-bearing fixtures. Expected detections are test conditions, not acceptance exceptions.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed negative coverage and non-exposure tests.
- **Decision**: Use detectable synthetic values, never real credentials, in source and simulated-log negative tests to verify blocking and absence of the value from terminal output and retained evidence. Use small disposable generated images to demonstrate detection inside ISO, SquashFS, initramfs, and UEFI FAT layers. Generate these images in ignored disposable directories, without requiring a complete Archiso ISO build or inserting synthetic secrets into the formal acceptance artifact.
- **Status**: Accepted for source and log tests; image-layer fixtures superseded by DEC-085

## DEC-069
- **Question**: Should evidence retain copies and SHA-256 hashes of the repository databases actually used for construction before Archiso removes them?
- **Context/Nuances**: Canonical Archiso v91 removes the root filesystem's synchronized repository databases during cleanup before packaging. The ISO therefore cannot supply these databases afterwards to justify DEC-052's execution-bound attribution. Preserving their actual construction inputs allows later audit without querying changed rolling repositories. This is bounded provenance retention, not retention of all downloaded package archives or a complete container snapshot. The capture point and upstream-compatible integration have not yet been established and must not be treated as solved.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of retaining the used repository databases and their hashes as provenance evidence.
- **Decision**: Retain copies of the repository databases actually used during construction, together with their SHA-256 hashes, in execution evidence. Capture them before Archiso's cleanup removes them. Do not broaden this policy into retention of all downloaded packages or a complete container copy. Keep the capture point and integration mechanism pending, to be checked without assuming upstream modifications are required or approved. Apply the existing evidence inspection and secret-safety requirements.
- **Status**: Superseded by DEC-086 (scan scope earlier revised by DEC-084)

## DEC-070
- **Question**: Should a bounded integration experiment gate selection of the repository-database capture mechanism?
- **Context/Nuances**: DEC-069 requires preservation before Archiso cleanup, but a reliable capture point has not been demonstrated. The builder container's databases may differ from those used to construct the ISO and cannot silently substitute for them. Selecting wrappers or upstream patches before demonstrating a simpler mechanism would add unproven complexity. This approval establishes a pending experiment, not permission to execute it during the interview or acceptance of a capture implementation.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the pending bounded integration experiment without mechanism selection.
- **Decision**: Require a bounded integration experiment demonstrating preservation of the repository databases actually used for the ISO without modifying the imported profile or Archiso code. Do not select a capture mechanism yet. If no simple solution within those boundaries is demonstrated, return for explicit design review before introducing wrappers or patches. Track the unresolved experiment as Story 1.3 TODO-001.
- **Status**: Superseded by DEC-086

## TODO-001
- **Question**: What evidence must establish the repository-database capture mechanism before implementation readiness?
- **Context/Nuances**: This TODO belongs to Story 1.3; numbering is local to this interview. DEC-052 and DEC-069 require actual execution-bound databases, not an earlier builder snapshot or subsequently refreshed repository state. Archiso's cleanup removes the target sync databases before packaging.
- **User Response**: Explicitly approved the experiment requirement through DEC-070.
- **Decision**: Demonstrate a bounded, upstream-compatible capture of the databases actually used for ISO package resolution before their deletion, preserving copies and SHA-256 hashes under the approved provenance and secret-safety contracts. Leave the imported profile and Archiso code unchanged. If no simple mechanism is demonstrated, bring the finding back for an explicit decision rather than adding wrappers or patches silently. The experiment is pending and is not executed or qualified by this interview entry.
- **Status**: Resolved by DEC-079; obsolete per DEC-086

## DEC-071
- **Question**: How should Story 1.3 create and review the committed candidate for clean-clone acceptance?
- **Context/Nuances**: Formal acceptance requires a clean clone of a committed candidate, but that requirement does not itself authorize creation of a commit. Previous stories' particular checkpoints are not automatically Story 1.3 approvals. Reviewing the implementation diff after successful local controls establishes an explicit human checkpoint before committing. Preserving failed candidates and adding corrective commits keeps qualification history attributable. The pending repository-capture experiment remains a readiness dependency.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed Story 1.3 candidate creation and review flow.
- **Decision**: After implementation and satisfactory local controls, present the diff for explicit maintainer approval before creating the candidate commit, including this interview's artifacts. Qualify real construction from a clean clone of that commit. If qualification fails, make corrections in additional commits rather than rewriting the failed candidate. This design approval does not authorize commits during the interview or waive pending design and readiness dependencies.
- **Status**: Accepted

## DEC-072
- **Question**: Should a real failure-evidence drill induce mkarchiso failure with a nonexistent package in a disposable dirty clone?
- **Context/Nuances**: Simulated failures establish command contracts but not real container retention and diagnostic export. A deliberately nonexistent package provides a deterministic upstream failure without weakening package signatures or depending on network disruption. Modifying the disposable clone makes the drill dirty, so it cannot serve as formal clean-source artifact acceptance. Successful-build qualification and the original candidate remain separate.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the real nonexistent-package failure drill.
- **Decision**: In a disposable clone, add a nonexistent package to the profile to induce real mkarchiso failure. Mark the execution dirty and use it solely as a negative qualification drill. Demonstrate normalized status 5, preservation of the upstream exit status, no artifact publication, and export and secret inspection of permitted diagnostics before container removal. Do not weaken signatures, rely on a network outage, modify the formal acceptance candidate, or present the dirty drill as clean-clone acceptance evidence.
- **Status**: Accepted

## DEC-073
- **Question**: What real qualification sequence should demonstrate cache population, reuse, independence, and explicit removal?
- **Context/Nuances**: Story 1.1's inherited obligations require cache reuse and removal plus a no-cache build, but its particular acquisition qualification sequence is not automatically a Story 1.3 selection. Multiple real builds make reuse and independence explicit. Rolling repositories may change resolved package versions between executions, so binary or complete package-set equality is not promised. The exact Archiso profile/tool version gate remains mandatory for each build. The shared cache must not be forcibly removed while in use.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed cache qualification sequence.
- **Decision**: Against the same committed candidate, perform a default-cache build to populate the cache, another default-cache build demonstrating reuse, and a build with --no-cache. Each build must pass its required controls. Then explicitly remove the shared cache when it is not in use, without forced deletion. Record rolling-resolution differences instead of requiring byte-identical artifacts or identical versions of every package. Preserve exact Archiso profile/tool version equality on every execution.
- **Status**: Superseded by DEC-090

## DEC-074
- **Question**: Should run directories and local output files use private permissions by default?
- **Context/Nuances**: Captured inputs and generated diagnostics can contain sensitive content before inspection, and clean scan results do not provide an absolute absence guarantee. Private default access reduces accidental exposure independently of scanning. The inherited normal-user ownership contract remains mandatory. Host output permissions are distinct from captured profile metadata, identification TAR entry permissions, and installed-image permissions. Sharing a bundle can remain an explicit later action rather than a constructor side effect.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of private default output permissions.
- **Decision**: Use mode 0700 for each execution's preparation, evidence, bundle, and temporary publication directories. Use mode 0600 for its logs, JSON records, manifests, checksum files, and ISO, owned by the invoking user. Do not change captured-profile permissions or ISO contents to implement this protection. Treat bundle sharing as an explicit subsequent action.
- **Status**: Accepted

## DEC-075
- **Question**: Should resource creation refuse existing reserved run paths or symbolic-link generated base directories rather than adopt or overwrite them?
- **Context/Nuances**: Per-run isolation and private storage depend on using the intended newly created resources. A prior existence check alone is not sufficient safe creation. Existing paths or symbolic-link bases must not silently redirect construction or broaden cleanup authority. Refusal is a safety precondition, not permission to repair permissions, remove residue, or adopt earlier executions. Concrete commands and race-resistant creation tests remain implementation deliverables. The user separately requested an assessment of what remains before interview closure through shared understanding.
- **User Response**: "yes, registra directamente la decisión." The user also asked what remains to close the interview upon reaching shared understanding.
- **Decision**: Reject execution with normalized status 2 if its reserved run paths already exist or if generated directories used as bases are symbolic links. Do not adopt, overwrite, delete, or change those resources' permissions to continue. Implement safe creation and checks rather than relying solely on a preceding nonexistence observation. Supply concrete commands and tests during implementation.
- **Status**: Accepted

## DEC-076
- **Question**: Should normal build execution use finite per-operation waiting limits with concrete values established during implementation and qualification?
- **Context/Nuances**: Stop deadlines are already selected, but they do not bound ordinary external-tool operations. The architecture requires bounded execution and useful failure evidence. Concrete limits need documented operational values checked during qualification, not a new interview decision for each command or additional CLI options. Deadline expiration does not establish that Docker work has stopped; the approved stop-and-verification policy remains applicable. Existing primary-outcome precedence also remains in force.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of finite per-operation waiting limits for normal execution.
- **Decision**: Apply finite per-operation waiting limits during normal execution. Document their concrete values and check them during qualification, establishing those values during implementation and qualification without expanding the CLI. A timeout returns normalized status 5, preserves the available original tool status, and initiates the approved stopping, permitted diagnostic-preservation, and cleanup sequence. Respect existing outcome precedence and do not infer stopped container state merely from a timeout.
- **Status**: Accepted

## DEC-077
- **Question**: Should the interview close with the agreed design, an explicit repository-capture readiness blocker, and a final consolidation of the artifacts?
- **Context/Nuances**: The design contracts are agreed, while Story 1.3 TODO-001 still needs to demonstrate an upstream-compatible capture mechanism. Interview closure is distinct from implementation readiness, implementation completion, and successful qualification. Earlier plan sections retain obsolete pending wording even where later decisions resolved the policy. Consolidation must correct that wording without deleting trade-offs or historical log entries. Concrete commands, field names, and mechanical details can be implemented under approved contracts and tests; findings requiring a contract change must return for an explicit decision.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed closure and final consolidation of both artifacts.
- **Decision**: Close the Story 1.3 design interview with the agreed design, without declaring the story implemented or qualified. Keep Story 1.3 TODO-001 as an explicit implementation-readiness blocker. Consolidate the plan to remove obsolete unresolved-policy wording while preserving nuances and traceability. Delegate concrete commands, fields, and mechanical implementation details to the implementing agent under approved contracts and tests. Return for an explicit decision if the capture experiment or implementation requires changing those contracts. Do not execute the experiment or create commits as part of this closure.
- **Status**: Accepted; TODO-001 blocker resolved by DEC-079 and obsolete per DEC-086

## DEC-078
- **Question**: Should the original interview artifacts record and link the repository-capture research results without selecting a mechanism or closing TODO-001?
- **Context/Nuances**: The [repository-database capture research](../research/story-1-3-repository-database-capture-experiment.md) records native smoke tests and real Archiso `91-1` construction. In execution `20261005T013354Z-d80eaada-a140-4cb4-a444-fa36845c820d`, actual target repository databases were preserved before cleanup, with byte comparisons and SHA-256 verification, and attributed all 455 packages in the native manifest extracted from the ISO. The imported profile and installed Archiso code remained unchanged. Retained provenance and database scans passed; SquashFS file inspection found no capture instrumentation. However, complete artifact inspection stopped at boot-image extraction because `-osirrox on` was missing. File-content extraction excluded extended attributes. The experimental dirty build is not clean-clone qualification; no ISO was accepted, published, or retained. Safe local evidence is under `evidence/archiso-build/20261005T013354Z-d80eaada-a140-4cb4-a444-fa36845c820d/`, including `capture-feasibility-result.json` and `iso-capture/`. Generated evidence remains outside source control. Positive capture evidence must not be represented as successful completion of the entire experiment protocol.
- **User Response**: "yes" — explicit confirmation of the proposed result registration, research linkage, qualification limitations, and continued pending mechanism review.
- **Decision**: Record capture feasibility as demonstrated and link the research report from the Consolidated Plan. Replace current wording that describes the experiment as awaiting execution with evidence available pending review. Keep TODO-001 open and implementation readiness blocked until explicit review resolves the mechanism and gate. Do not select the demonstrated hook as the production mechanism, waive incomplete artifact inspection, declare implementation or qualification complete, authorize publication, or create commits. Preserve earlier log entries as historical records; this entry records subsequent evidence, not a superseding design selection.
- **Status**: Accepted as historical record; research artifacts not versioned per DEC-086

## DEC-079
- **Question**: Is the demonstrated capture evidence sufficient to resolve TODO-001 while retaining complete artifact inspection as an implementation and qualification obligation?
- **Context/Nuances**: DEC-078 records real Archiso `91-1` integration preserving actual target databases and hashes and attributing all 455 packages in the extracted native ISO manifest, without modifying the imported profile or Archiso code. This satisfies the bounded capture-feasibility question. Auxiliary artifact inspection remains incomplete because boot-image extraction lacked `-osirrox on`; file-content extraction excluded extended attributes. Resolving the feasibility dependency must not turn this partial overall experiment into artifact acceptance or waive the approved inspection contracts. Mechanism selection is a separate decision.
- **User Response**: "si", followed by "yes" confirming the proposed DEC-079 registration, resolution of TODO-001, and preservation of qualification obligations.
- **Decision**: Resolve TODO-001 on the capture-feasibility evidence linked through DEC-078 and the research report. Replace the pending-experiment readiness blocker with pending explicit production-mechanism selection. Do not select the hook by this decision or declare implementation readiness, implementation completion, ISO acceptance, publication, or qualification. Complete artifact inspection remains a mandatory implementation and qualification obligation under the existing contracts; no requirement is weakened. Resolve mechanism selection next.
- **Status**: Accepted; complete-artifact-inspection obligation removed by DEC-085; capture dependency obsolete per DEC-086

## DEC-080
- **Question**: Should production repository-database capture use the demonstrated native Pacman PostTransaction hook injected only into disposable staging, with external capture and mandatory independent validation?
- **Context/Nuances**: DEC-078 records real integration evidence and DEC-079 resolves TODO-001 as the capture-feasibility dependency. A native PostTransaction hook can copy the actual target sync databases through shared container `/run` before upstream cleanup removes them, without modifying the imported profile or installed Archiso. PostTransaction execution does not provide fail-closed acceptance merely through Pacman's exit status. Root-mode shared-`/run` behavior, ordering before cleanup, and absence of later resolution transactions are evaluated assumptions, not universal guarantees. Instrumentation must remain attributable and absent from packaged contents.
- **User Response**: "yes", followed by "yes" explicitly confirming the proposed DEC-080 mechanism, boundaries, validation requirements, and dependency checks.
- **Decision**: Select a native Pacman PostTransaction capture hook injected only into disposable staging. Preserve actual construction repository databases outside the packaged tree before their deletion; do not modify the imported profile or Archiso code or introduce replacement wrappers. Identify the extra instrumentation with hashes. Require independent validation that rejects collisions and repeated, absent, or failed captures, verifies integrity and exact package attribution respecting repository priority, and checks absence of instrumentation from the ISO. Pacman success is not sufficient to accept capture. Verify the privileged execution, shared-`/run`, cleanup ordering, and no-later-resolution assumptions; incompatibilities require explicit review rather than silent wrappers or patches. Resolve the pending production-mechanism selection, but do not declare product implementation or qualification complete. All artifact-inspection and other approved acceptance contracts remain intact.
- **Status**: Superseded by DEC-086 (artifact-inspection obligation earlier revised by DEC-085)

## DEC-081
- **Question**: Should ADR preparation be included in the implementation-planning agent's responsibilities rather than performed during this interview?
- **Context/Nuances**: The repository's ADR guidance requires recording prototype outcomes that validate a critical choice or constrain the design. DEC-078 records the research evidence, DEC-079 resolves capture feasibility, and DEC-080 selects the native staging-hook mechanism. Preparing its ADR is distinct from accepting that ADR, implementing the mechanism, or qualifying the artifact. The implementation-planning agent can include ADR preparation as a task using the already approved decisions and linked research; no new capture-feasibility experiment is required by this delegation.
- **User Response**: "yes" — explicit confirmation that the implementation-planning agent should include preparation of a Proposed ADR, with acceptance reserved for explicit maintainer review, without creating the ADR during this interview.
- **Decision**: Delegate inclusion of ADR preparation as a task in the implementation plan to the implementation-planning agent. The task must use DEC-078 through DEC-080 and the linked repository-capture research, preserving their evidence, trade-offs, boundaries, and qualification limitations. Prepare the ADR with status Proposed; acceptance requires explicit maintainer review. Do not create the ADR during this interview or change the approved capture decisions through this delegation. Planning handoff does not authorize construction, commits, or declarations of implementation or qualification completion.
- **Status**: Superseded by DEC-086

## DEC-082
- **Question**: Should Story 1.3 implementation be planned as several sequential plans or as a single implementation plan?
- **Context/Nuances**: Raised during implementation planning (`/plan:save`) after interview closure. The approved scope is large: Bash orchestration, source capture, signed-image and version gates, container lifecycle, repository capture and attribution, layered artifact inspection, metadata and validation, atomic publication, tests, ADR, procedures, candidate commit, and real qualification. The assistant recommended a three-plan split; the user chose a single plan. Plan size increases review and context load, so explicit checkpoints are needed.
- **User Response**: "unico plan".
- **Decision**: Plan all of Story 1.3 as one implementation plan, `01-04`, covering the Proposed ADR, implementation, tests, documentation, human diff review before the candidate commit, and real clean-clone qualification. Use explicit task checkpoints, including maintainer approval of the diff before committing.
- **Status**: Accepted

## DEC-083
- **Question**: Where should Story 1.3 build implementation and tests live?
- **Context/Nuances**: The architecture assigns lifecycle orchestration to `operations/`, domain implementation to its owning component directory, and shared `operations/lib/` helpers only to multiple callers. Root `build/` is generated, ignored, non-authoritative runtime output (Story 1.1 DEC-008; Story 1.3 DEC-025) and absent from clean clones, so it cannot hold source. Adding files under `image/archiso/` would alter the captured profile identity and feed `mkarchiso`. An initially proposed `image/build/` name was rejected as easily confused with root `build/`. The architecture tree currently shows only `image/archiso/` under `image/`.
- **User Response**: "yes" after reviewing the folder roles.
- **Decision**: Keep `operations/build` as a thin entry point (arguments, help, delegation). Place versioned domain implementation in `image/builder/` (Bash, built-in-only `.mjs` modules, and a `staging/` area for the capture hook and helper), outside profile capture and identity. Mirror tests in `tests/image/builder/` and update `tests/operations/build.contract.bats`. Add nothing under `image/archiso/` or `operations/lib/`, and no `contracts/*.schema.json`. Root `build/`, `dist/`, and `evidence/` remain runtime outputs only. Update the `docs/architecture.md` tree to show `image/builder/`. Concrete file names inside `image/builder/` are implementation deliverables.
- **Status**: Accepted; `staging/` hook area removed by DEC-086

## DEC-084
- **Question**: Should captured repository databases be secret-scanned, given default Gitleaks heuristics produce release-dependent false positives on them?
- **Context/Nuances**: The experiment's three `generic-api-key` findings came from `%FILENAME%` lines in public `extra` descriptors (for example, `xapian` contains the keyword `api`). Gitleaks is not misconfigured; its heuristic rule is applied to public mirror metadata. The experiment's exact-release allowlist would require new reviewed exceptions after ordinary repository updates, blocking most future builds. A structural allowlist was offered; the user preferred not scanning these public, non-MirrorOS-generated data. This revises only the scan scope of DEC-069; retention, hashes, integrity, and attribution remain. A secret appearing in public mirror data would not be detected; this is accepted as outside the threat model. Gitleaks false-positive volume for final ISO-content inspection remains a separate, unassessed concern.
- **User Response**: "prefiero C...como ya dices son datos ya públicos y no son generados por nosotros", then "yes" confirming the summary.
- **Decision**: Do not Gitleaks-scan captured repository databases or their adjacent signatures. Control them through original/copy byte equality, SHA-256, post-export verification, and exact manifest attribution (DEC-052, DEC-080). Limit the exclusion to the run's captured-database directory and only when it contains exactly the expected `<repo>.db` files (and optional `.sig`) for configured repositories with hashes matching capture; any other file is rejected. Do not retain unpacked databases; unpacking for attribution is temporary. All other evidence, configuration, logs, JSON, and extracted ISO content remain scanned with default rules. Remove `docs/research/gitleaks-repository-databases.toml` and `tests/research/gitleaks-repository-databases.contract.test.mjs`; version the research report with a note that DEC-084 supersedes its exception. Document this evolution in the ADR.
- **Status**: Superseded by DEC-086

## DEC-087
- **Question**: Does the reduced secret-scan scope and removed repository attribution require an ADR?
- **Context/Nuances**: DEC-086 withdrew the capture ADR (DEC-081). The ADR guidance requires an ADR for an exception to the architecture. The architecture states that Gitleaks scans staging directories and staging trees and names artifact inspection as a security driver; DEC-085 interprets "staging" as the captured profile copy and does not scan ISO contents. Per-package provenance in PRD FR21/NFR12 and the architecture's package-trust rules concerns installed target packages in later stories, not the live ISO, so DEC-086 does not conflict with it. An ADR prevents future agents from reintroducing ISO scanning from the architecture's literal text. Only `0000-template.md` exists, so `0001` is the next free number.
- **User Response**: "es correcto".
- **Decision**: Prepare one small ADR, `docs/adr/0001-build-secret-scan-scope.md`, with status Proposed, recording: the MirrorOS-created-content scan principle, the no-host-secrets container invariant, the NFR7 and "staging" interpretation, and removal of per-package repository attribution for the live ISO with its reconsideration trigger. The maintainer accepts it at the diff-review checkpoint before the candidate commit. Link it from `docs/procedures/build.md`. Leave the PRD, epics, and architecture text unchanged.
- **Status**: Accepted

## DEC-091
- **Question**: Where does the automated build obtain the Cosign certificate identity regexp and OIDC issuer for verifying the Arch image?
- **Context/Nuances**: Story 1.1 DEC-046 and DEC-047 require Cosign verification of the digest-qualified Arch image against Arch's documented CI identity and issuer. The manual import procedure tells a human to obtain these from Arch's current documentation and not hard-code them in the procedure. An automated `operations/build` needs the values on every run; per-run environment variables would add friction, break clean-clone builds without local setup, and leave the values unreviewed.
- **User Response**: "es correcto".
- **Decision**: Store the identity regexp and issuer as reviewed, versioned constants in a small configuration file under `image/builder/`, with comments citing the official Arch Linux OCI image documentation URL and retrieval date. Changes go through commit review. If verification fails (including after an upstream identity rotation), stop with normalized status 2 and guidance to update the file; never skip verification. Record the values in artifact metadata. The implementer takes the values from official documentation, never guesses them, and confirms them with a real verification before the diff-review checkpoint. `docs/procedures/update-archiso.md` is unchanged.
- **Status**: Accepted
