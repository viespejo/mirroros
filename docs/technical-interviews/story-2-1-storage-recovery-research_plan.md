# Story 2.1 — Storage and Recovery Research (Plan 02-02): Consolidated Plan

## Scope and outcomes

Plan 02-02 executes Track 2 of the Story 2.1 research umbrella on top of the native installation engine selected by ADR 0002. Track 2 has no anchor in the PRD, epics, or architecture; it comes from the maintainer's Story 2.1 handoff. Because the architecture fixes systemd-boot and an unencrypted ext4 root and does not defer storage or boot-loader choices, adopting Btrfs or Limine would change the baseline, so the plan compares three variants rather than presupposing Btrfs: a control that keeps the current baseline (ext4, systemd-boot, recovery through independent rescue media, i.e. the 02-01 scenario), Btrfs/Snapper with rescue-based recovery, and Btrfs/Snapper with Limine snapshot integration [DEC-001].

The plan may end in an Accepted ADR 0003 that adopts a Btrfs variant and amends the architecture in the same change, in an Accepted ADR 0003 recording that the baseline is kept, or in no ADR when the evidence is inconclusive, in which case the next required experiment is recorded. Until an ADR is accepted the current baseline stays normative, and the Track 2 question in `prototypes/README.md` is reworded to include the control [DEC-001].

The frontend track is not part of this plan. Its Track 3 question still mentions Gum with mock data, while the maintainer is considering a Node.js frontend; that wording must be revisited before plan 02-03, and a custom TUI would need its own ADR [TODO-002].

## Hibernation

Hibernation is a mandatory MVP capability, and it is the point where storage variants couple most tightly. Every variant carries a configuration-level postcondition that the boot entry's `resume=UUID` and `resume_offset` match the real swapfile; on Btrfs the swapfile lives in a dedicated NOCOW subvolume that is never snapshotted and its offset comes from `btrfs inspect-internal map-swapfile -r` instead of `filefrag`. Btrfs subvolumes carry no size of their own; they share the filesystem's space, and whether qgroups are used is decided with the subvolume layout [DEC-002].

Beyond configuration, each variant, including the control, runs one real hibernate-and-resume cycle in the reference VM as a measured criterion. Because snapshots are not recursive, a rollback of the root subvolume never touches the swap subvolume; the real danger is modifying a filesystem offline while a hibernation image is pending and later resuming that stale image, which applies to ext4 repaired from rescue media as much as to Btrfs. Each of the three variants therefore records, as an observed case, what happens when recovery is attempted with a pending hibernation image [DEC-002].

If the VM cannot hibernate reliably even with the control, the cycle is recorded as `blocked_external` rather than as a failure of any variant, and the ADR states that target-laptop hibernation needs its own validation regardless of the VM result [DEC-002].

## Btrfs subvolume layout

Both Btrfs variants share one layout so that only the recovery mechanism differs between them. The disk keeps the control's partitioning, a 1 GiB FAT32 ESP and one Btrfs filesystem over the rest, with a flat set of subvolumes: `@` at `/` is the only snapshotted and rolled-back subvolume and keeps `/var/lib/pacman`, so the package database reverts together with the files it describes; `@home`, `@log`, and `@pkg` keep user data, diagnostics, and the package cache out of system rollback; `@snapshots` at `/.snapshots` lives outside `@` so `@` can be replaced from rescue media; and `@swap` at `/swap` is the NOCOW, never-snapshotted home of the swapfile [DEC-003, DEC-002].

Subvolumes carry no size limits, qgroups stay disabled, and Snapper cleans up by snapshot count rather than by space [DEC-003].

## Compression and mount options

Both Btrfs variants mount every subvolume with `compress=zstd:1` from the start of the installation, before `pacstrap`, so the installed system is compressed from its first write; the NOCOW swap subvolume stays uncompressed, which is what hibernation needs. Compression does not touch recovery and applies equally to both Btrfs variants, so it does not separate them, while it reflects the configuration that would actually be adopted. Mount options otherwise stay at `relatime`, matching the control, without `compress-force` or `noatime` [DEC-004].

Space used after installation (`compsize` on Btrfs, `df` on ext4) and installation duration are recorded for all three variants as secondary, informative metrics that cannot decide the ADR on their own [DEC-004].

## Snapshot policy

Both Btrfs variants share one snapshot policy, so they differ only in how they return to a snapshot. A single Snapper `root` configuration covers `@`; `snap-pac` takes pre/post snapshots around every pacman transaction, which models the most realistic damage, a breaking update; and the installation ends with a `post-install baseline` snapshot so a known-good point exists before any pacman transaction. Timeline snapshots are disabled, cleanup keeps ten numbered snapshots through `snapper-cleanup.timer` without quotas, and snapshots are managed through `sudo` rather than `ALLOW_USERS`. User data in `@home` is not snapshotted because the mandatory external backup covers it [DEC-005, DEC-003].

## Limine snapshot integration

The Limine variant installs `limine` from `extra` and evaluates the integration that would actually be adopted: the AUR tools that generate per-snapshot boot entries and copy each snapshot's kernel and initramfs to the ESP, pinned to exact commits, reviewed, and built inside the prototype with `makepkg` as an unprivileged user, so `base-devel` and `git` appear only in this variant. Their AUR origin is to be confirmed by pinned source review, and the commits, review, and provenance cost become part of the comparison; adoption would route AUR provenance through Story 3.2 [DEC-006].

If the tools require the CachyOS repository or Chaotic-AUR, both deferred by the architecture, or cannot be pinned, the variant is marked unsupported without workarounds. The ESP keeps the control's 1 GiB, and its occupancy with several snapshots is measured so that any shortfall becomes a finding rather than an in-flight change. Limine is installed unsigned because Secure Boot remains deferred [DEC-006].

## Damage injection and recovery measures

Recovery is compared through two damages that every variant receives the same way: synthetic local packages, built by the prototype, recorded in evidence, and installed with `pacman -U` without network, so `snap-pac` snapshots around them exactly as it would around a real update. D1 damages userspace inside `@` with configuration that stops the system before login, modelling a breaking configuration update; D2 damages the boot path on the ESP through a post-install hook that makes the `/boot` initramfs unusable, modelling a failed kernel or initramfs update. D2 matters because the ESP sits outside snapshots in every variant, so only the Limine tooling's per-snapshot kernel copies are expected to cover it [DEC-007].

For each variant and damage the comparison records whether recovery succeeds, judged by the 02-01 verification unit passing the relevant postconditions again, the steps and time recovery takes, whether rescue media is needed, whether the failure's diagnostics survive in `/var/log` (`@log` on Btrfs), and whether a marker file written to `/home` after the baseline survives. The working hypothesis, which the evidence must confirm or refute, is that the control repairs both damages from rescue media, Btrfs with rescue rolls back D1 but still regenerates the initramfs for D2, and Limine recovers both by booting the previous snapshot [DEC-007].

## Execution model and runs

Each variant and damage gets one counted unattended run that installs, takes the baseline, writes the `/home` marker, injects the damage, confirms that the system really fails, recovers, and verifies again. Rescue-based recovery in the control and in Btrfs with rescue is automated through a third boot from the qualified ISO carrying the recovery script over NoCloud, which doubles as the candidate documented procedure, followed by a verifying boot from disk. The Limine variant is automated except for the boot-menu selection, a short attended step over the serial console recorded as observed manually, because automating the menu would be fragile or would stop measuring the real path [DEC-008].

The real hibernation cycle is automated in all three variants, while recovery with a pending hibernation image is observed in one attended session per variant [DEC-008, DEC-002]. Since engine repeatability was already shown in 02-01, one counted run per case suffices, and any case with an unexpected or inconsistent result is repeated once before it is recorded. Evidence follows the 02-01 rules under `evidence/prototypes/storage/<variant>/<run-id>/` [DEC-008].

## Code organization and harness reuse

The plan adds a `prototypes/storage/` track that reuses the 02-01 harness without destabilizing it: it sources the generic modules of `prototypes/installation/lib/` as they are and keeps in `prototypes/storage/lib/` only what differs, namely a multi-boot orchestrator for install, damage, rescue, verification, and hibernation boots, the `storage` build and evidence paths, and the per-variant postconditions. Any parameter a generic module needs is added backward-compatibly with a default that preserves 02-01 behavior, and an uncounted `native-arch` development run proves that Track 1 still works [DEC-009].

The installation script `prototypes/storage/guest/install` is derived once from `native-arch/guest/install`, keeping the common stages identical and making only the storage, boot, and snapshot stages variant-specific; its diff against the original is documented, and the 02-01 prototype that backs ADR 0002 stays untouched. Each variant directory (`control/`, `btrfs-rescue/`, `btrfs-limine/`) holds its `run` entry point, a README with question, attended checklist, and result, and its own guest files for storage, boot, and recovery, while `prototypes/storage/README.md` holds the comparison. Verification reuses `verify-postconditions.sh` and adds a storage check script covering subvolumes, compression, Snapper, Limine, and the `map-swapfile` hibernation offset [DEC-009]. Because that script hardcodes the ext4 root, `/swapfile` with its `filefrag` offset, and systemd-boot, it gains a backward-compatible parameter to exclude check groups, defaulting to none so 02-01 is unaffected: the control runs it in full, the Btrfs variants hand `storage_*` and `swap_*` to the storage script, the Limine variant also hands over `boot_*`, and the JSON report names every excluded group and its replacement so no postcondition disappears silently [DEC-010].

## Comparison and decision checkpoint

`prototypes/storage/README.md` compares the variants on ten criteria, each cell carrying its provenance and evidence run-id: recovery from D1 and from D2 (success, steps, duration), whether rescue media is required, retention of diagnostics and of `/home` data, hibernation (configuration, real cycle, and the pending-image case), dependencies and provenance, maintenance cost measured as MirrorOS-owned lines per variant plus the diff against the native installer, ESP occupancy with several snapshots, and the architecture statements each variant would change; space and installation duration remain secondary [DEC-011, DEC-004].

The maintainer decides at a checkpoint where the agent drafts and comments only on request. Adopting a Btrfs variant produces an Accepted `docs/adr/0003-storage-and-recovery-baseline.md` that amends the ext4 and systemd-boot statements of `docs/architecture.md` and corrects `docs/epics.md` in the same commit, without creating anything under `install/`; keeping the baseline produces an Accepted ADR 0003 that records the rejection and its reopening boundary with no architecture change; inconclusive evidence forces no ADR and the README records the next experiment. Work stops under the Limine provenance condition, records `blocked_external` when the bundle or mirrors fail, and halts for consultation whenever `vm/reference/` or production code would need to change [DEC-011, DEC-006].

## Validation, documentation, and commits

Prototype code is checked with `bash -n` and `shellcheck`, including any touched `installation/lib/` module, without Bats or contract suites. Boundary checks confirm that no production path sources `prototypes/`, that no `*.py` file exists, that `vm/reference/`, `reference-vm.conf`, and `native-arch/guest/install` are unchanged, and that `installation/lib/` carries only the permitted backward-compatible changes backed by the `native-arch` regression run. Redacted Gitleaks scans cover history, working tree, `build/`, and the new evidence without exceptions, and the 02-01 canary negative control is repeated only if `evidence.sh` changes. Rescue needs no ISO change because the qualified bundle already ships `btrfs-progs` and `arch-install-scripts` [DEC-012, DEC-009, DEC-010].

`prototypes/README.md` marks Track 2 as executed by plan 02-02 with its question reworded to include the control, and the `docs/architecture.md` tree gains `prototypes/storage/` and its evidence path. The prototype recovery scripts do not become `docs/procedures/recovery.md`; an adopting ADR only flags them as input for later recovery work. Pinned external references live in the READMEs and the ADR, while `docs/attribution.md` changes only if external code is copied [DEC-012, DEC-001].

Commit 1 introduces the Track 2 frame, the storage harness, the derived installer, the three variants, the backward-compatible harness changes, and the architecture tree update; counted runs execute from it on a clean tree, and a prototype defect is fixed in a new commit after consultation, repeating that variant's counted runs. Commit 2 records the comparison and, at the checkpoint, ADR 0003 with the architecture and, if Btrfs is adopted, `docs/epics.md` [DEC-012, DEC-011].

## Carried-over frontend work

Plan 02-02 leaves the Track 3 row of `prototypes/README.md` untouched, because rewording it from Gum with mock data toward a possible Node.js frontend is a scope decision for plan 02-03, which must first decide whether it is worth doing. So the item is not lost, the 02-02 plan lists it as an explicit exclusion, with the custom-TUI ADR requirement and the rule that the frontend never determines the engine, and the executor carries it into the 02-02 summary's follow-up candidates [DEC-013, TODO-002].
