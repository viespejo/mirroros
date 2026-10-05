# Build procedure

The `operations/build` command constructs a traceable installation ISO from the unchanged `image/archiso/` profile. A successful build validates the construction controls and publishes a bundle; it does not establish that the ISO boots or qualifies in a VM. No byte-reproducibility claim is made.

## Purpose and qualification boundary

The build captures the Archiso profile, verifies the current official Arch Linux OCI image with Cosign, constructs the ISO with upstream `mkarchiso` inside a privileged Docker container, and publishes the ISO with its checksum, artifact metadata, and native package manifest. Run evidence is retained separately under `evidence/archiso-build/<run-id>/`.

Boot, VM, installation, and UEFI qualification are outside this procedure. The artifact metadata explicitly records that boot qualification has not been performed.

## Invocation

Run the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Behavior |
| --- | --- |
| `operations/build` | Builds with the shared `mirroros-pacman-cache` Docker volume mounted at the Pacman package cache path. |
| `operations/build --no-cache` | Builds without mounting the shared cache volume; it does not remove or change that volume. |
| `operations/build --help` | Prints help and exits `0` without performing construction. It is also available when invoked as root. |

These are the only accepted forms. Unknown, repeated, or combined arguments exit `2` before Docker is invoked or build files are created. Construction must run as a normal user, not root. The shared lifecycle help header currently retains generic “help only” availability wording; this procedure is authoritative for build-specific behavior.

## Prerequisites and privilege boundary

Construction requires all of the following to be installed and usable by the invoking user:

- Docker with direct access to its daemon (`docker info` must succeed).
- Cosign, Gitleaks, Git, Node.js, `flock`, and `timeout`.
- A readable repository checkout containing `image/archiso/`, `image/archiso/UPSTREAM.md`, and the builder implementation.

Docker daemon access is effectively root-equivalent: a user who can control the daemon can request privileged containers and access host resources. Run only with a Docker daemon you trust. The command rejects an effective UID of root and does not use `sudo`, start or repair Docker, change groups or socket permissions, install tools, or otherwise remediate the host. If a prerequisite is missing or Docker is inaccessible, resolve that condition yourself and retry; no construction is started.

The image signature identity and issuer are maintained in `image/builder/arch-image-signature.conf`. The build pulls `docker.io/archlinux/archlinux:latest` for `linux/amd64`, requires exactly one usable digest, verifies that digest with Cosign, and runs the verified digest. An ambiguous digest or failed verification prevents container creation.

Inside the container, the build performs a full Pacman update and installs Archiso. The installed Archiso package version must exactly match the version recorded in `image/archiso/UPSTREAM.md`. A mismatch stops before ISO construction with status `2`; evaluate and import the upstream change through [the Archiso update procedure](update-archiso.md), then retry explicitly. The build never updates the profile automatically.

### Updating the Cosign identity constants

When the official Arch image project's signing identity changes, retrieve the identity regexp and OIDC issuer from the official [Arch Linux OCI image project README](https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md). Do not infer or guess either value. Update `image/builder/arch-image-signature.conf` with the reviewed values and comments recording the source URL and retrieval date. Verify the current image digest against those values with Cosign before relying on a build; a failed or ambiguous verification must not be bypassed. Review the configuration change before committing it.

## Source capture and inputs

The fixed input is `image/archiso/`; there are no profile-selection options.

- For a clean repository, the build materializes `HEAD:image/archiso` with `git archive` and records the commit and profile tree identity.
- Any non-ignored working-tree change anywhere in the repository marks the run dirty. In that case the build copies tracked and untracked, non-ignored profile paths, preserves symbolic links, excludes ignored files, and records the profile's dirty-path list. Changes outside the profile still make the run dirty, even if the profile dirty-path list is empty.
- A profile path that is both tracked and ignored, a submodule, or an unsupported filesystem entry (such as a device, socket, or FIFO) is rejected before construction.
- Gitleaks scans the captured profile before a container is created. Findings block construction.

**Capture is not atomic.** Git status checks and working-tree copying happen over time; the repository can change between those operations. Do not edit the checkout while a build is capturing it. The fixed private copy is the only profile mounted into the container, read-only, once capture is complete. A dirty run has reduced traceability: its recorded paths identify changes but do not constitute a content hash of the complete dirty source state.

## Construction and timeouts

The builder creates a privileged, run-labeled Docker container without `--rm`. It mounts only the captured profile as a read-only bind and, for the default invocation, the named Pacman cache volume. It does not pass the host environment, an env-file, or credential mounts. `/work` and `/out` remain inside the container. `SOURCE_DATE_EPOCH` is the run start time in seconds and is passed explicitly to `mkarchiso`.

Stage output is displayed live and recorded with `tee` in private per-stage logs under `evidence/archiso-build/<run-id>/logs/`. After the build, the native package manifest is extracted from the ISO inside the container, and the effective container mirrorlist is copied into evidence. The exported ISO, manifest, and mirrorlist are checked before the container is removed.

The current operation timeouts are:

| Stage | Limit |
| --- | ---: |
| Image pull | 10 minutes |
| Cosign verification | 10 minutes |
| Package update and Archiso installation | 30 minutes |
| `mkarchiso` | 120 minutes |
| ISO manifest and mirrorlist extraction | 30 minutes |
| Output export | 15 minutes |
| Individual Docker control requests | 2 minutes |

A timeout is an execution failure, not proof that work inside Docker has stopped. When the container may still be active, the builder requests a stop with a 30-second grace period, waits at most 60 seconds for the Docker client, and verifies the stopped state before removal. If stopping or state verification fails, it preserves the container and records recovery guidance rather than force-removing it.

## Outputs, evidence, and permissions

Each run uses an ID of the form `YYYYMMDDTHHMMSSZ-<uuid>`. Existing reserved run paths and symlinked `build/`, `dist/`, or `evidence/` bases are refused; paths are never adopted or overwritten.

| Path | Contents and handling |
| --- | --- |
| `build/archiso/<run-id>/` | Private temporary profile capture and exported construction files. Normally removed during cleanup; retained when safe cleanup cannot be completed. |
| `dist/<run-id>/` | Published bundle created by one atomic directory rename from staging inside `dist/`. Contains the ISO, `SHA256SUMS`, `artifact-metadata.json`, and `pkglist.x86_64.txt`. The checksum file covers the ISO, metadata, and manifest. |
| `evidence/archiso-build/<run-id>/` | Run evidence, including `execution-result.json`, the persistent `run.lock`, stage logs, redacted Gitleaks reports, the copied mirrorlist, and container identity when a container was created. |

Run-specific directories are mode `0700`; run files are mode `0600` and owned by the invoking user. The builder holds an exclusive lock for the run, including cleanup, and does not unlink `run.lock`. Generated build, distribution, and evidence paths are local outputs; preserve the evidence needed for review or recovery.

Artifact metadata records the execution and source identity, clean/dirty state and profile identity, architecture, verified image digest, exact Archiso version, `SOURCE_DATE_EPOCH`, tool versions, Cosign identity and issuer, the effective profile `pacman.conf` reference, mirrorlist hash, ISO name/size/SHA-256, manifest, control outcomes, traceability limitations, and the absence of boot qualification. The native package manifest records installed package names and versions, not per-package repository origin. Compare manifests between runs to review rolling-resolution changes; do not infer repository attribution from them.

## Secret-scan scope

The build scans the captured profile before construction and scans MirrorOS-created run content, including permitted logs, records, evidence, and staged bundle records. Gitleaks reports are redacted. A finding blocks publication and the relevant logs and report are retained privately for review. A missing scanner is an unmet prerequisite; a scanner execution failure is an operation failure. Either blocks publication.

The build does **not** extract or scan ISO, SquashFS, initramfs, or UEFI FAT layers for secrets. Reading the ISO to extract the native package manifest is a separate construction step, not a secret scan. A clean report is not proof that the complete ISO contains no secrets.

This is the proposed interpretation of architecture staging-tree language and PRD NFR7 for this artifact: “staging” means the captured MirrorOS profile and the run's MirrorOS-created content, not every upstream image layer. See [ADR 0001 — MirrorOS-Created Build Secret-Scan Scope](../adr/0001-build-secret-scan-scope.md), accepted at the maintainer review checkpoint.

## Cache management

The default build mounts the shared `mirroros-pacman-cache` volume. `--no-cache` omits that mount and leaves the volume untouched. Cache contents can affect download reuse, but do not pin rolling repository state or promise identical package resolution across runs.

Remove the cache only when it is unused and removal is explicitly intended:

```sh
docker volume rm mirroros-pacman-cache
```

Do not add `--force`. The build and recovery procedure never remove the shared volume.

## Outcomes

| Status | Meaning |
| ---: | --- |
| `0` | Build controls passed and the bundle was published. This does not mean the ISO was boot-qualified. |
| `2` | Invalid invocation, unmet prerequisite, rejected signature/version, or a Gitleaks finding. |
| `3` | Explicit cancellation status defined by the lifecycle convention; the build command does not currently use it. |
| `4` | Execution completed but verification is not ready; the build command does not currently use it. |
| `5` | Construction, upstream operation, timeout, scanner execution, or cleanup failure. A bundle published before a later failure is retained and reported as published-but-failed. |
| `6` | Damaged or incomplete checkout, or an internal document/bundle contract failure. |
| `130` | Interrupted by `SIGINT`; cleanup is attempted and evidence is retained. |
| `143` | Interrupted by `SIGTERM`; cleanup is attempted and evidence is retained. |

The first primary failure or signal status takes precedence over a later cleanup failure. A second signal can interrupt cleanup; the command warns that resources may remain. Inspect the recorded leftovers and recovery guidance. Never interpret a published directory alone as proof that every final scan and cleanup control passed; review `execution-result.json`.

## Recovering a previous run

Recovery is manual and applies only to resources positively tied to one run. Do not use it to recover, adopt, or remove resources from another run.

1. **Identify the run and ensure it is no longer active.** Use the reported run ID and inspect `evidence/archiso-build/<run-id>/execution-result.json` and `run.lock`. The lock file remains after the run; do not unlink it. Check whether the lock is held, for example with `flock -n evidence/archiso-build/<run-id>/run.lock true`. If it is held, stop: the build or cleanup may still be running. Do not recover concurrently.
2. **Confirm identity and authorization.** Read `container-identity.json` and use its actual container ID. Inspect that exact ID and verify both labels, `org.mirroros.stage=build` and `org.mirroros.run-id=<run-id>`, before acting. Docker access is root-equivalent; proceed only as an authorized normal user with direct access to the intended daemon. Do not identify a container by a guessed name alone.
3. **Refuse incomplete evidence.** If the run evidence directory, lock, execution result, or required container identity is missing, unreadable, or inconsistent with the resource, do not stop or remove a container based on assumptions. Preserve what exists and escalate for maintainer review.
4. **Preserve diagnostics before removal.** Save output from the recorded container ID under that run's evidence directory with private permissions, then run a redacted Gitleaks scan over the retained evidence and keep its report. Do not overwrite existing records or discard a finding. If the evidence cannot be preserved and scanned, do not remove the container.
5. **Stop only after confirming its state.** If the verified container is paused, unpause that exact ID only after confirming authorization and identity. Request `docker stop -t 30 <container-id>` under a 60-second client deadline, then inspect the same ID and verify its state is `exited` or `created`. If stop or verification fails, leave it in place for further authorized recovery; never use `docker rm -f`.
6. **Remove only the verified stopped container.** After diagnostics are preserved and scanned, remove the exact recorded ID with `docker rm <container-id>`. Do not remove another run's resources or the shared Pacman cache volume. Keep the run evidence and published bundle for review.

If the required identity or evidence is absent, the safe outcome is refusal to remove resources—not guessing, adopting, or deleting them.
