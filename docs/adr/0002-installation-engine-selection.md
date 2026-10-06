# ADR 0002: Installation Engine Selection

## Identifier and title

- **Identifier:** `0002`
- **Title:** Installation Engine Selection

## Status

`Accepted`

## Date

`2026-10-06`

## Context and question

The architecture requires the installation engine to be selected from evidence before `install/engine/apply` is populated. Story 2.1 and PRD NFR46 require a comparison of Archinstall's JSON/CLI interface with native Arch installation commands, and an ADR that records the outcome.

Plan 02-01 built two non-production prototypes that install one shared fixed scenario onto a fresh reference-VM disk through one shared harness, so that the engine is the only difference. The scenario derives from the Arch Installation Guide and the maintainer's real preferences: UEFI, GPT, a 1 GiB FAT32 ESP at `/boot`, an ext4 root, a 4 GiB swapfile with resume parameters, systemd-boot, two locales, NetworkManager, one `wheel` user, and a small set of system options (29 scenario items in total).

The question is which engine, Archinstall JSON/CLI or native Arch commands, should populate `install/engine/apply`.

## Constraints and decision criteria

- Select from evidence rather than assumption; the prototypes are evidence, not production code.
- Follow the architecture's language policy: Bash for native Arch integration, JavaScript ESM on Node.js for non-trivial structured logic, and no project-owned Python. Invoking the packaged Archinstall CLI does not authorize project-owned Python.
- Credentials never travel as arguments or appear in retained evidence.
- Failures preserve the original upstream message and a non-success exit status; wrappers never convert upstream failure into success.
- MirrorOS introduces no custom TUI. Plan review, cancellation, and confirmation bound to the target and plan digest are MirrorOS contract requirements.
- The ten Story 2.1 criteria: plan visibility, editability, confirmation, cancellation, credentials, diagnostics, exits, recovery evidence, dependencies, and maintenance cost.
- The agent drafts this record and does not select the engine; the maintainer decides.

## Alternatives considered

1. **Archinstall JSON/CLI with bounded native finalization.** An upstream-maintained installer and configuration format. 19 of the 29 scenario items are expressed in its configuration; 10 need a native finalization step (swapfile and resume, the second locale, the hardware clock, the default initramfs hooks, the boot entry options, the fallback entry, loader settings, `sysrq`, two `pacman.conf` options, and the `wheel` sudoers drop-in). It adds Archinstall and Python to the live environment and depends on its configuration format, which changed shape between 4.0 and 4.5. Its interaction model does not provide the digest-bound confirmation that the architecture requires, and in the recorded runs it replaced pacman's error with a generic message and exited 0 when the menu was cancelled.
2. **Native Arch commands.** The sequence of the Arch Installation Guide (`sfdisk`, `mkfs`, `pacstrap`, `genfstab`, `arch-chroot`, `bootctl`) in Bash. It adds only `arch-install-scripts`, preserves pacman's own messages, and gives full control over exits and diagnostics. MirrorOS owns the whole installation sequence and its maintenance.
3. **No selection (inconclusive).** It avoids forcing a choice, keeps Story 2.1 open, and requires a further experiment. No further experiment was identified that would change the comparison.

## Evidence

All runs used the boot-qualified bundle A, commit `144eff7`, and `dirty: false`. Raw results are under the ignored `evidence/prototypes/installation/<engine>/<run-id>/`; the comparison, with the provenance of every cell, is in [`prototypes/installation/README.md`](../../prototypes/installation/README.md).

- **Counted unattended runs.** Each engine completed two runs with every postcondition passed. Native: `20261006T165554Z-f8e92294` (112 s) and `20261006T165859Z-5c61dee2` (84 s). Archinstall: `20261006T170225Z-04586fed` (110 s) and `20261006T170512Z-ace9ccf1` (121 s). Both engines pass the same postconditions, so the final installed state does not separate them.
- **Failure injection (unreachable mirrorlist).** Native `20261006T170130Z-bacdedaf`: engine exit 1, pacman's own error preserved, disk partitioned and mounted. Archinstall `20261006T170810Z-64e01275`: engine exit 1, generic message, disk untouched. Both runs exit 3 and neither reports success.
- **Attended sessions** (observed manually, read from the serial logs). Native `20261006T180251Z-e76ba9b8`, `20261006T181659Z-89c1afbc`, `20261006T182418Z-9e1ef754`. Archinstall `20261006T182807Z-c79529a2`, `20261006T183152Z-9d7e7092`, `20261006T184058Z-ffad3fa7`, `20261006T184658Z-bf5a1940`. Cancelling Archinstall's menu exits 0 while installing nothing; native exits 1. After SIGINT both leave two mounted partitions; Archinstall retains four files in `/var/log/archinstall/`, native only the console.
- **Maintenance metrics.** MirrorOS-owned lines excluding the shared harness: 483 (377 without blanks and comments) for Archinstall and 232 (190) for native. Archinstall depends on 13 top-level configuration keys plus 2 credential keys.
- **Source review (source-reviewed, not measured).** Archinstall tag `4.5` is commit `78982a624824aa415f59bf88c515676a589e3c55`; `parallel_downloads` moved to `pacman_config` between 4.0 and 4.5, and 4.5 still reads the old key through a path marked `DEPRECATED`. Between `arch-install-scripts` v28 and v31 the options used (`pacstrap -K`, `genfstab -U`, `arch-chroot DIR COMMAND`) are unchanged.
- **Limits of the evidence.**
  - Results come from one reference VM and one scenario; they say nothing about the target laptop or about hibernation correctness.
  - The Archinstall SIGINT session `20261006T184658Z-bf5a1940` has incomplete evidence (four empty result files and no canary search result); the maintainer accepted it as is.
  - Only `archinstall/lib/args.py` was compared across Archinstall tags, and `bootctl` was not source-reviewed.
  - The attended observations were read from the serial logs, not from a separate record.
  - The `scans.evidence` field is `not_run` in the counted `result.json` files.

## Decision

MirrorOS selects **native Arch installation commands** as the engine behind `install/engine/apply`. The engine is implemented in Bash around `sfdisk`, `mkfs`, `pacstrap`, `genfstab`, `arch-chroot`, and `bootctl`, with structured plan processing in JavaScript ESM on Node.js under the existing language policy.

The selection combines the measured evidence with the maintainer's preference for the native approach. The measurements alone do not decide it: both engines installed the scenario and passed every postcondition. The evidence that favors the native engine is the smaller MirrorOS-owned code (232 versus 483 lines), the 10 of 29 scenario items that Archinstall would have left to native finalization anyway, the preserved upstream error messages and exit statuses, and the absence of a Python runtime dependency and of an upstream configuration format to follow. The preference is recorded here as a criterion and not as a measurement.

Archinstall is not selected. The `archinstall-json-cli` prototype stays as evidence only. This decision does not authorize an Archinstall Python API, plugin, or project-owned Python.

## Consequences and trade-offs

- MirrorOS owns the complete installation sequence and its maintenance. That cost grows if the scope later includes encryption, disks with existing partitions, or other bootloaders, which Archinstall covers in part.
- The interaction contract becomes MirrorOS-owned: plan visibility, editability, cancellation, and confirmation bound to the target and plan digest. The architecture accepts reviewable paginated text for this.
- On failure the native engine can leave a disk partitioned and mounted. The `install/engine/apply` contract must define the retry and cleanup behavior and the need for a fresh disk; automatic retry was not tested.
- The install path does not depend on Python or on Archinstall's configuration format, so it is not exposed to the configuration changes recorded in the source review. It depends on the options of `arch-install-scripts`, which were stable across the versions reviewed.
- A future frontend is a separate decision (Track 3). The native engine exposes arguments, explicit files, and exit statuses, so a frontend does not determine the engine.
- No claim is made about the target laptop or about hibernation correctness.

## Replacement or reversal boundary

Revisit this decision if any of the following occurs:

- The supported scope adds encryption, disks with existing partitions, other bootloaders, or hardware setups whose native implementation cost materially exceeds the cost of Archinstall's configuration.
- A change in `pacstrap`, `genfstab`, `arch-chroot`, or `bootctl` breaks the options in use and cannot be absorbed by a bounded adapter change.
- Archinstall gains digest-bound confirmation, preserved upstream errors, and stable exits that remove the stated reasons for not selecting it.
- Evidence from the target laptop, or a later review of the limits above, contradicts the VM results.

Replacement happens behind `install/engine/apply` through a new ADR that supersedes this one; the boundary is the engine contract, not the callers.

## Required validation

- Before adoption: the maintainer reviews this ADR and the updated architecture statements at the commit that records it.
- `install/engine/apply` is neither created nor populated by this decision. Story 2.5 implements it, with contract tests for exit normalization, credential channels, and failure behavior, and a real qualification run on the reference VM.
- The target laptop is validated separately; hibernation correctness requires its own validation.
- Revisit the limits listed in the evidence section when the engine is implemented.

## References

- [Architecture](../architecture.md)
- [PRD — NFR46](../prd.md)
- [Epics — Story 2.1](../epics.md)
- [Installation engine comparison](../../prototypes/installation/README.md)
- [Native Arch prototype](../../prototypes/installation/native-arch/README.md)
- [Archinstall JSON/CLI prototype](../../prototypes/installation/archinstall-json-cli/README.md)
- [Story 2.1 installation-engine research plan](../technical-interviews/story-2-1-installation-engine-research_plan.md) and [log](../technical-interviews/story-2-1-installation-engine-research_log.md)
- Archinstall, `archlinux/archinstall`, tag `4.5`, commit `78982a624824aa415f59bf88c515676a589e3c55`
- `arch-install-scripts`, tags `v28` and `v31`
- Context only, not audited and not evidence: Ryoku installer backend, <https://github.com/neur0map/ryoku-arch/blob/7b0ad100/installation/backend/README.md> (plain Bash, no Archinstall); the Omarchy ISO configurator (`omacom-io/omarchy-iso`, not pinned), which drives Archinstall from generated JSON.

## Superseded by

`None`
