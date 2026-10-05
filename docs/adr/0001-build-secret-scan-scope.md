# ADR 0001: MirrorOS-Created Build Secret-Scan Scope

## Identifier and title

- **Identifier:** `0001`
- **Title:** MirrorOS-Created Build Secret-Scan Scope

## Status

`Accepted`

## Date

`2026-10-05`

## Context and question

The architecture describes scanning staging directories or trees and identifies artifact inspection as a security control. PRD NFR7 calls for automated inspection of the repository, generated installation artifacts, verification summaries, and diagnostic logs before artifact acceptance. Story 1.2 deferred internal ISO inspection to Story 1.3.

The ISO combines MirrorOS's captured Archiso profile with files supplied or derived by upstream Archiso and official Arch Linux packages. The captured profile is MirrorOS's only contribution to the image under this build design. The build also writes MirrorOS-owned logs, metadata, checksums, configuration copies, and execution evidence. Scanning the ISO's filesystem layers would therefore inspect large amounts of public upstream content in addition to MirrorOS inputs. An earlier repository-database experiment encountered release-dependent Gitleaks matches in public package descriptor filenames; a narrowly versioned allowlist was considered, but its maintenance cost became moot when repository-database capture was removed.

The design also previously considered recording the repository origin of every package in the live ISO. The native Archiso package manifest records package names and resolved versions, but not repository origin. The current profile uses the official `core` and `extra` repositories.

The question is how to satisfy the build's secret controls without claiming coverage of upstream image layers, and whether the live ISO requires per-package repository attribution.

## Constraints and decision criteria

- Inspect the captured MirrorOS profile before construction and the records and evidence that the build writes.
- Do not pass host environment values or credentials into the build container.
- Keep scan results redacted and preserve findings privately for review; a scan is detection, not proof of absolute absence of secrets.
- Avoid introducing brittle, release-specific scanner exceptions or an instrumentation hook that depends on Archiso internals without sufficient benefit.
- Preserve the native installed-package manifest and reconsider package-origin attribution if repository policy changes.
- Record the interpretation as a Proposed ADR for maintainer review; do not modify the PRD, epics, or architecture text in this decision.

## Alternatives considered

1. **Extract and scan all ISO layers.** This could inspect upstream package files, SquashFS, initramfs, and UEFI FAT contents in addition to MirrorOS inputs. It adds extraction tools, temporary storage, runtime, format-specific failure modes, and exposure to large volumes of upstream content and false positives. It would still not prove the absolute absence of secrets. This broader inspection is not selected for Story 1.3.
2. **Keep scanning captured repository data with a structural or release-specific allowlist.** A narrowly scoped allowlist could preserve Gitleaks coverage while permitting known public descriptor fields. However, release-specific exceptions require recurring review as rolling package metadata changes, and a path/line rule cannot establish the semantic meaning or authenticity of a matched field. Database capture is removed, so this exception is not needed by the build.
3. **Capture repository databases through a temporary package-manager hook and attribute each package.** This could associate installed package versions with the construction repositories, but requires staging instrumentation, independent capture validation, assumptions about Archiso and package-manager behavior, additional records, and renewed review as those tools change. With only official repositories enabled, that complexity is not justified for the live ISO. Reconsider it if a non-official repository that could provide the same package name is enabled.

## Evidence

The Story 1.3 consolidated plan and decision log record the evolution of the scan and attribution scope. DEC-084 documents Gitleaks matches on public repository metadata and the trade-offs of a narrow allowlist. DEC-085 selects scanning MirrorOS-created content rather than ISO layers. DEC-086 removes repository-database capture and per-package repository attribution for the live ISO. DEC-087 requires this ADR because the interpretation narrows literal architecture wording.

The earlier capture experiment is not product implementation or Story 1.3 qualification. Its research files are being removed as specified by DEC-086; ignored local experiment evidence is outside this ADR and remains untouched. No real build qualification is claimed here.

## Decision

Gitleaks scans the fixed captured profile before construction and the MirrorOS-created or retained content produced by the run, including logs, metadata, execution records, the copied effective repository configuration, checksums, and evidence. Secret-scan reports remain redacted. Synthetic test values must not appear in metadata or reports, and a finding blocks publication while the relevant log or evidence remains private for review.

For this build, the architecture's staging scan means scanning the fixed captured profile copy. The build does not extract the ISO, SquashFS, initramfs, or UEFI FAT contents for secret scanning. The ISO may still be read for the separate purpose of extracting Archiso's native package manifest. PRD NFR7 is interpreted for this artifact as inspection of MirrorOS's contribution to the image and of the generated verification and diagnostic records, rather than a claim that every upstream package layer has been scanned. This is an explicit scope interpretation; it does not change the PRD, epics, or architecture text.

The build container receives no host secrets: orchestration must not pass host environment values, use an environment file, or mount credentials. Contract tests must verify this invariant. The scan detects findings in its defined scope; it cannot guarantee that the ISO contains no secrets.

The live ISO uses Archiso's native package manifest of installed package names and resolved versions without per-package repository attribution or retained repository databases. Build-to-build package changes can be reviewed by comparing manifests. Reconsider repository attribution in the decision that enables a non-official repository capable of supplying a package with the same name. This decision does not change later-story provenance requirements for packages installed on a target system.

## Consequences and trade-offs

The scan scope is bounded to MirrorOS-controlled inputs and run outputs, avoiding extraction machinery and routine scanning of public upstream layers. The no-host-secrets invariant is essential: a violation could expose a value in upstream output before a later log scan detects it. Tests and real qualification must enforce and exercise the invariant.

Secrets in upstream packages, or secrets introduced through a breach of the no-host-secrets invariant, are not covered by this scan scope. A clean scan is not a certification that the complete ISO is secret-free. Package manifests do not identify which official repository supplied each package, so this build does not provide that per-package audit trail or repository-database snapshot. These are accepted losses within the current official-repository boundary.

## Replacement or reversal boundary

Revisit this decision if a non-official repository is enabled and could supply a package name also available elsewhere, if the build begins adding MirrorOS content to the ISO outside the captured profile, or if the architecture/security requirements are explicitly changed to require scanning upstream ISO layers. Any broader scan or attribution mechanism must be reviewed for its coverage, false-positive behavior, failure handling, and maintenance cost rather than silently added.

## Required validation

- Contract tests verify that the build passes no host environment, environment file, or credential mount to the container.
- A synthetic secret in the captured profile is rejected before construction; a synthetic secret in a simulated log blocks publication and the log remains privately retained.
- Tests verify that synthetic values do not appear in metadata or redacted reports and that permitted run records and evidence are scanned.
- Real qualification scans the captured profile and retained MirrorOS-created run content and records the outcomes. It must not describe this as scanning ISO layers or as boot qualification.
- The maintainer reviews and accepts this ADR at the Story 1.3 diff-review checkpoint before the candidate commit.

## References

- [Architecture](../architecture.md)
- [PRD — NFR7](../prd.md)
- [Epics — Story 1.3](../epics.md)
- [Story 1.3 consolidated plan](../technical-interviews/story-1-3-traceable-installation-artifact_plan.md), including DEC-084 through DEC-087
- [Story 1.3 decision log](../technical-interviews/story-1-3-traceable-installation-artifact_log.md), DEC-084 through DEC-087
- [ADR guidance](README.md)
- [Build procedure](../procedures/build.md) (to document this scope)

## Superseded by

`None`
