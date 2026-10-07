# ADR 0003: Storage and Recovery Baseline

## Identifier and title

- **Identifier:** `0003`
- **Title:** Storage and Recovery Baseline

## Status

`Accepted`

## Date

`2026-10-07`

## Context and question

The architecture fixes UEFI, GPT, systemd-boot, and an unencrypted ext4 root with a resizeable swapfile, and does not defer them. Track 2 of Story 2.1 has no PRD, epic, or architecture anchor; it comes from the maintainer's handoff. The question is whether MirrorOS keeps the ext4/systemd-boot baseline with recovery through independent rescue media, or also offers a Btrfs/Snapper recovery model, with rescue-based rollback or with Limine snapshot boot entries.

Plan 02-02 built three non-production prototypes on the native installation engine selected by [ADR 0002](0002-installation-engine-selection.md). They install one shared scenario derived from the 02-01 fixed scenario, receive two reproducible damages, and are recovered and verified: D1 damages userspace inside `@` and D2 damages the boot path on the ESP.

## Constraints and decision criteria

- The ext4/systemd-boot baseline stays normative unless an Accepted ADR amends it; keeping it is a legitimate outcome.
- The prototypes are evidence, not production code. Nothing under `install/` and no `docs/procedures/recovery.md` is created by this decision.
- No CachyOS repository, no Chaotic-AUR, no Secure Boot, no qgroups, no `compress-force`, no `noatime`, no timeline snapshots, and no `@home` snapshots.
- Every external package is pinned and reviewed; AUR sources are explicitly reviewed external sources.
- The ten Story 2.1 Track 2 criteria: D1 recovery, D2 recovery, rescue-media need, diagnostics retention, `/home` retention, hibernation, dependencies and provenance, maintenance cost, ESP occupancy with several snapshots, and architecture impact.
- The agent drafts this record and does not select the outcome; the maintainer decides.

## Alternatives considered

1. **Keep the baseline only (ext4, systemd-boot).** No change, the smallest maintenance surface, official repositories only. It recovers from rescue media only and has no snapshot history.
2. **Adopt `btrfs-rescue` only (Btrfs, Snapper, systemd-boot).** Snapshot history and rollback of `@` using official packages. Recovery still needs rescue media, and D2 needs an extra initramfs regeneration.
3. **Adopt `btrfs-limine` only (Btrfs, Snapper, Limine).** Recovery by selecting a snapshot entry without rescue media. It depends on two AUR packages from a single maintainer, a Gradle and GraalVM native build over the network, and its ESP occupancy was not measured.
4. **Offer the three options with support tiers (chosen).** The maintainer wants the final distribution to let the user choose among them, with a different level of commitment for each.
5. **No decision (inconclusive).** It would keep Story 2.1 Track 2 open. It was not chosen because the evidence supports a tiered decision, and the unmeasured items are recorded below as conditions.

## Evidence

All counted runs used commit `331155d7fee84c0d19ab7c87523a925ea4b80231` with `dirty: false`, on the boot-qualified bundle A. Raw results are under the ignored `evidence/prototypes/storage/<variant>/<run-id>/`. The comparison, with the provenance of every cell, is in [`prototypes/storage/README.md`](../../prototypes/storage/README.md).

- **D1 and D2 recovery (measured for the automated rescue variants, observed manually for Limine).** In every case the system failed as confirmed and was recovered, the `/home` marker survived, and diagnostics were kept for D1 and not observable for D2 because the kernel never reached userspace.
  - `control`: D1 `20261007T155452Z-9db16ef8` and D2 `20261007T160124Z-46c3c2c4`; recovered from rescue media in 3 steps each.
  - `btrfs-rescue`: D1 `20261007T161057Z-99b85d90` (4 steps) and D2 `20261007T161735Z-5e1e7a85` (5 steps, including an initramfs regeneration).
  - `btrfs-limine`: D1 `20261007T181105Z-1b4408a0` and D2 `20261007T183708Z-0ddfe7ea`; recovered by selecting a snapshot entry, with no rescue media.
- **Hibernation (measured).** One real cycle resumed in each variant: `control` `20261007T160807Z-068dd7f5`, `btrfs-rescue` `20261007T162419Z-696e5e5a`, `btrfs-limine` `20261007T162711Z-d0a9bcc1`. The configuration postcondition passed in each.
- **Pending hibernation image (observed manually).** `control` `20261007T191629Z-ee1b3c98`, `btrfs-rescue` `20261007T193917Z-792f4175`, `btrfs-limine` `20261007T195628Z-e239b0d8`. In all three the disk boot after the session was a normal boot with no resume.
- **Dependencies and maintenance (source-reviewed and measured).** `control` uses official repositories only. The Btrfs options add `btrfs-progs`, `snapper`, `snap-pac`, and `compsize` from official repositories. `btrfs-limine` adds `limine` and two AUR packages, pinned by AUR and upstream commits in [`prototypes/storage/btrfs-limine/README.md`](../../prototypes/storage/btrfs-limine/README.md#limine-snapshot-tooling-provenance-review). MirrorOS-owned variant lines at commit `331155d`: 150 (`control`), 162 plus a 100-line shared Btrfs stage (`btrfs-rescue`), 135 plus the same shared stage (`btrfs-limine`).
- **DEC-007 working hypothesis.** It is consistent with the evidence within the limits below: the control repaired both damages from rescue media, `btrfs-rescue` rolled back D1 and still regenerated the initramfs for D2, and Limine recovered both by booting a snapshot entry.
- **Limits of the evidence.**
  - One reference VM and one run per case; nothing about the target laptop.
  - The Limine recoveries are attended observations; their session durations include human time.
  - A Limine snapshot boot is a temporary overlay, not a persistent restore of `@`, and it does not repair the damaged live entry.
  - ESP occupancy with several snapshots and the space after installation (`compsize` or `df`) were not measured.
  - The pending-image sessions record only that the next disk boot was normal; whether the image existed, why it was not resumed, and what a snapshot selection in Limine does were not recorded.
  - Real hibernation cycles were confirmed through the systemd-sleep journal message; the kernel's `Image restored successfully` line was not observed.

## Decision

MirrorOS offers three storage and boot options in the final distribution, with a different support level each:

1. **ext4 + systemd-boot: default and normative.** It remains the baseline and what the architecture describes unless the user selects another option. Recovery uses independent rescue media.
2. **Btrfs + Snapper + systemd-boot: supported alternative.** It uses the `btrfs-rescue` prototype as evidence: flat subvolumes `@`, `@home`, `@log`, `@pkg`, `@snapshots`, and `@swap` (NOCOW, never snapshotted), `compress=zstd:1`, a Snapper root configuration for `@` only with `snap-pac`, and a post-install baseline snapshot. Recovery restores `@` from a snapshot using rescue media.
3. **Btrfs + Snapper + Limine: experimental, with no support commitment.** It uses the `btrfs-limine` prototype as evidence. It may be offered only as an opt-in experimental option until these conditions are met and recorded in a superseding or amending ADR:
   - ESP occupancy with several snapshots is measured, and the ESP size is decided from that measurement. A larger ESP, for example 4 GiB, is a hypothesis to evaluate; any change to the 1 GiB FAT32 ESP of the shared scenario requires an ADR.
   - A persistent restore of `@` from a snapshot entry is validated, since the snapshot boot of the prototype is a temporary overlay.
   - Recovery with a pending hibernation image is validated with a stricter session.
   - The AUR dependencies are routed through Story 3.2 with pinned and reviewed sources, including a response to Gradle dependencies that are pinned by version only.

The prototype configurations are evidence and constrain the options only where this record says so. The selector's interaction, its place in the installation plan, and its handling by `install/engine/apply` are not defined here and belong to the later stories that implement them. The recovery scripts of the prototypes are input for later recovery work (Stories 5.5 and 6.x), not procedures.

## Consequences and trade-offs

- The test matrix, the qualification runs, and the recovery documentation grow by option. Each option has a different recovery procedure: rescue with package removal or `mkinitcpio -P`, rescue with restoration of `@`, and the Limine menu.
- The architecture and epics describe a storage selector with support tiers. The default stays ext4 and systemd-boot, so the existing baseline statements change only to admit the selection.
- The plan contract of the installation engine must carry the selected option and its resume parameters: the swapfile offset comes from `filefrag` on ext4 and from `btrfs inspect-internal map-swapfile -r` on Btrfs.
- Btrfs options bring snapshot history and rollback of `@`, at the cost of Snapper, a recovery script, and more packages. The Limine option also adds an AUR build path and a single-maintainer dependency.
- Every root filesystem remains unencrypted.
- No claim is made about the target laptop.

## Replacement or reversal boundary

Revisit this decision if any of the following occurs:

- A Btrfs option fails a qualification run that the default passes, or a defect makes its recovery unreliable.
- The experimental Limine tools cannot be pinned, or require the CachyOS repository or Chaotic-AUR, or become unmaintained.
- The measured ESP occupancy of the Limine option exceeds the ESP capacity even with the size an ADR would allow.
- Evidence from the target laptop contradicts the VM results, in particular for hibernation.
- Maintaining three options costs more than the maintainer accepts; the boundary is then to reduce the supported set through a superseding ADR.

## Required validation

- Before adoption: the maintainer reviews this ADR and the updated architecture and epics statements at the commit that records it.
- Target-laptop hibernation needs its own validation, including resume with each option; the VM results do not establish it.
- The experimental conditions listed in the decision are validated before the Limine option is promoted.
- Each option is qualified in the reference VM when the installation engine implements the selector.
- `install/` and `docs/procedures/recovery.md` are neither created nor populated by this decision.

## References

- [Architecture](../architecture.md)
- [Epics](../epics.md)
- [ADR 0002](0002-installation-engine-selection.md)
- [Storage and recovery comparison](../../prototypes/storage/README.md)
- [Control prototype](../../prototypes/storage/control/README.md)
- [Btrfs with rescue prototype](../../prototypes/storage/btrfs-rescue/README.md)
- [Btrfs with Limine prototype and provenance review](../../prototypes/storage/btrfs-limine/README.md)
- [Story 2.1 storage-recovery research plan](../technical-interviews/story-2-1-storage-recovery-research_plan.md) and [log](../technical-interviews/story-2-1-storage-recovery-research_log.md)
- AUR `limine-snapper-sync` 1.32.1-1, commit `b3c82aded52032687a76922f2dee9497600818f2`, upstream commit `b4c0da2d4532a993809219f9e5d51a1fa85fcb93`
- AUR `limine-mkinitcpio-hook` 1.40.0-1, commit `94ffde9c60808595b287edf9d4219da202a85a7a`, upstream commit `35dab4b732861f5e8d307a1a7873856a877913aa`

## Superseded by

`None`
