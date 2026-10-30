# ADR 0022: Installer Coexistence and UEFI Boot Entry

## Identifier and title

- **Identifier:** `0022`
- **Title:** Installer Coexistence and UEFI Boot Entry

## Status

`Accepted`

## Date

`2026-10-30`

## Context and question

The current whole-disk installation destroys every partition on the selected disk. Reinstalling MirrorOS on a shared disk therefore risks destroying another operating system. This proposal asks how to identify and replace only an existing MirrorOS installation, preserve other partitions, and register a predictable UEFI boot entry without disturbing unrelated entries.

The ThinkPad T14s dual-boot machine is experimental and unqualified; it is not the physical target selected by [ADR 0005](0005-physical-target-change.md). Firmware boot-menu selection, such as F12 on that machine, is used instead of a shared Limine chainload menu.

## Constraints and decision criteria

- Preserve the whole-disk mode and add an in-place replacement mode; replacement never resizes or moves partitions or writes a new partition table.
- Replacement formats only the selected MirrorOS ESP and root. Ambiguous or incomplete identification must fail closed before destruction.
- Preserve unrelated NVRAM entries and their relative order; never clear NVRAM or delete entries outside the whole-disk cleanup rule.
- Keep the fallback loader, avoid automatic boot-order enforcement, and leave hibernation policy unchanged.
- The prototype and user decision checkpoint precede changes to accepted contracts, product code, and tests.

## Alternatives considered

The alternatives and prototype checks for each open design point are recorded in the corresponding decision sections below. More broadly, retaining only whole-disk installation cannot safely reinstall on a shared disk; a free-space installer or a single chainloading menu adds scope not selected for this work.

## Evidence

The [interview log](../technical-interviews/installer-coexistence-reinstall_log.md) records DEC-001 through DEC-008 and RISK-001. The current lab has a 32 GiB disk and private writable OVMF variables; its existing disk-and-firmware checkpoint is the restore point.

The [coexistence prototype](../../prototypes/coexistence/README.md) records the lab results and their limitations. Partition preservation and synthetic UEFI operations were exercised; the requested post-reboot `efibootmgr` evidence remains unavailable. The user accepted the corrected decision at the checkpoint with that limitation recorded. No T14s outcome is claimed here.

## Decision

The following decision was accepted at the blocking decision checkpoint.

### Interview decisions

- **DEC-001:** Offer whole-disk and replace-existing-installation modes, and register a MirrorOS UEFI entry. Chainloading, free-space installation and a resume splash are out of scope.
- **DEC-002:** Put the entry for the installed MirrorOS bootloader first in `BootOrder` in both modes, preserving the relative order of the remaining entries. The user subsequently clarified that this applies to systemd-boot as well as Limine.
- **DEC-003:** Continue deploying `EFI/BOOT/BOOTX64.EFI` on the MirrorOS ESP.
- **DEC-004:** Prototype on the current `~/qemu/mirroros-lab` disk using the existing checkpoint as the only restore point; do not create a new checkpoint.
- **DEC-005:** In whole-disk mode, capture the target disk's pre-wipe partition PARTUUIDs and remove only entries whose device paths reference those PARTUUIDs. Preserve firmware, removable-media and other-disk entries outside that set.
- **DEC-006:** Provide `sudo mirroros-boot-first` as an explicitly invoked command, never an automatic service. It finds or recreates the entry and moves it first without deleting entries.
- **DEC-007:** Share NVRAM logic in `operations/lib/uefi-boot-entry.sh`. The live engine sources it from the code root; the installed command and library are delivered under `/usr/local/lib/mirroros/operations/`, with `/usr/local/bin/mirroros-boot-first` linked to the command.
- **DEC-008:** Use one plan: Proposed ADR, lab prototype, blocking user decision, implementation, and final validation. If prototype findings invalidate an interview decision, stop at the checkpoint and revise the plan before implementation.

### TODO-001 (a): Candidate identification and binding

**Proposal:** Support existing installations of all three offered options: `ext4-systemd-boot`, `btrfs-rescue`, and `btrfs-limine`. A candidate has an ext4 or Btrfs root partition with filesystem label `mirroros` and the Linux filesystem partition type GUID. Read its `/etc/fstab` through a read-only mount of the installed root (including Btrfs `@` when applicable) and identify the ESP on the same disk by the volume ID recorded there; that partition must have the ESP type GUID. For Limine, its `limine.conf` must reference `root=UUID=` for that root filesystem UUID; for systemd-boot, the MirrorOS loader entry under `loader/entries/` must reference that root UUID. Require an unambiguous one-to-one binding and reject missing, conflicting, unreadable or ambiguous evidence with a reason. Inspection must not modify the filesystems.

**Alternatives:** Labels alone are simple but can be duplicated or spoofed; a dedicated marker would need migration of existing installations. Requiring the existing configuration and partition types trades broader compatibility for a conservative match.

**Prototype check:** Detect the existing Btrfs/Limine lab installation read-only alongside a second ESP and encrypted partition; also exercise representative ext4/systemd-boot and Btrfs/systemd-boot installations, plus missing and ambiguous evidence, and confirm that invalid layouts are not offered. Record separately which combinations have been demonstrated and which remain unverified.

### TODO-001 (b): Reuse constraints

**Proposal:** Reuse only unmounted partitions: the ESP must be at least the current policy ESP size (2 GiB under ADR 0009), and the root must meet the current policy root minimum (15 GiB under ADR 0009) and any applicable layout requirements. Reformat the selected ESP as FAT32 and root as the selected supported root filesystem; never resize either partition. Recheck identities, sizes and mount state immediately before destructive operations.

**Alternatives:** Accepting smaller partitions increases compatibility but violates policy; resizing adds destructive complexity outside replace mode. Preserving existing filesystems without formatting would not provide a clean reinstall.

**Prototype check:** Verify detection and partition-scoped reformat on the lab layout, and exercise mounted and undersized rejection without destructive writes.

### TODO-001 (c): Typed identity

**Proposal:** Require the full root PARTUUID in addition to the existing disk identity confirmation for replacement. Display both target partitions and their identities before approval.

**Alternatives:** A short PARTUUID is easier to type but risks collisions; disk-only confirmation does not distinguish installations on the same disk.

**Prototype check:** Record the detected disk and partition identities and verify that the full root PARTUUID uniquely identifies the intended replacement target in the lab layout.

### TODO-001 (d): Plan format and operations

**Proposal:** Bump the installation plan to format version 5 with `target_mode` and explicit partition identities. Whole-disk mode retains disk-level operations and captures pre-wipe PARTUUIDs; replacement uses partition-scoped wipe and format operations only, without partition-table operations. Both modes include UEFI entry registration. Reject earlier formats with regeneration guidance.

**Alternatives:** Reusing the old format hides the changed destructive boundary; separate plan formats add unnecessary interpretation paths.

**Prototype check:** Compare the prototype's actual partition-scoped operations and captured identities with the proposed operation model and confirm that no disk-node wipe or partition-table creation is required for replacement.

### TODO-001 (e): Untouched-partition postcondition

**Proposal:** Before replacement, record `sfdisk --dump` with the selected target partition entries excluded, together with per-partition identity fields for all non-target partitions. Compare the corresponding data after installation; report a mismatch rather than claiming preservation. This is a partition-table and identity guarantee, not a byte-for-byte production postcondition.

**Alternatives:** Comparing only partition counts misses changed entries; hashing every non-target partition in production is costly and may be impossible for mounted or inaccessible devices.

**Prototype check:** Compare the before and after filtered dumps and identities, and independently hash the stand-in partitions before and after to establish byte-level preservation in the lab.

### TODO-001 (f): UEFI registration and package hooks

**Proposal:** Run `efibootmgr` from the live environment against the target ESP identity. For Limine keep `SKIP_UEFI=yes`, so its package hooks do not implicitly create or reorder entries. For systemd-boot use `bootctl --variables=no` to prevent implicit firmware entry changes and register `\EFI\systemd\systemd-bootx64.efi`. Identify the entry by ESP PARTUUID and the loader path selected for the installed bootloader; use `Limine MirrorOS` and `\EFI\BOOT\BOOTX64.EFI` for Limine, and `MirrorOS` for systemd-boot. Create without implicit ordering, then move the entry first while retaining the other entries' relative order. Keep `EFI/BOOT/BOOTX64.EFI` as the appropriate bootloader's fallback. The installed command identifies the bootloader using the boot configuration on the ESP unambiguously bound to the running root by the candidate rule; missing, conflicting or ambiguous evidence is rejected before NVRAM changes. No MirrorOS-created label may match `^Omarchy([[:space:]]|$)`. If multiple entries match the ESP PARTUUID and selected loader path, stop and report them before creating or reordering entries; delete none. A successful installation must satisfy the exactly-one-entry postcondition.

**Alternatives:** Letting package hooks manage NVRAM obscures ordering and deletion behavior; creating entries inside the target adds environment dependencies. Deleting duplicates conflicts with the no-deletion boundary outside DEC-005.

**Prototype check:** Exercise lookup, creation, ordering and target-PARTUUID-only stale-entry removal with another entry present; inspect output after reboot and confirm the fallback loader and both firmware-menu entries. The lab exercised both bootloader entry paths and `bootctl --variables=no`; installed-command detection and duplicate refusal still require implementation tests. Record the post-reboot ordering limitation explicitly.

### TODO-001 (g): Relationship to ADR 0003 and ADR 0009

**Proposal:** Do not rewrite historical decisions or supersede either record wholesale. If accepted, add narrowly scoped forward notes to ADR 0003 and ADR 0009 identifying ADR 0022 as the coexistence and UEFI-entry extension; preserve their storage choices, ESP policy and unrelated decisions. Update the architecture and index to describe the accepted boundary.

**Alternatives:** Partial supersession is appropriate if the prototype identifies an actual conflicting clause; amending historical decisions in place would obscure their original rationale. No forward note would leave the relationship unclear.

**Prototype check:** Compare the demonstrated reuse constraints and boot behavior against both records; identify any actual conflict for correction at the checkpoint rather than assuming supersession.

## Consequences and trade-offs

- Replacement becomes possible without repartitioning other installations, but conservative detection may reject otherwise usable layouts.
- Whole-disk installation remains destructive, with narrowly scoped removal of stale target-disk entries.
- **RISK-001:** Another system or firmware can reorder or remove entries later. The explicit boot-first command mitigates this but does not prevent it; users may still need the firmware menu.
- Duplicate matching entries cause a fail-closed result and require manual investigation; no duplicate is silently removed. The exact-one guarantee applies to successful installations.
- Existing installations using either supported bootloader must be detectable; registration and postconditions follow the bootloader selected for the new installation. The installed command's detection still needs implementation validation.
- This proposal does not qualify the T14s or change its local, non-product settings.

## Replacement or reversal boundary

Stop and revise the plan if the prototype invalidates DEC-001 through DEC-008 or cannot demonstrate safe identification, partition preservation, or the NVRAM boundaries. Revisit the decision if firmware behavior or later evidence makes these guarantees unreliable.

## Required validation

- Before acceptance: run and record the lab prototype, including filtered partition-table comparisons, stand-in partition checksums, NVRAM operations and reboot observations; resolve every TODO-001 point with the user at the blocking checkpoint.
- After acceptance: implement and test the contracts and code, including fail-closed prechecks, both target modes, command delivery and read-only postconditions.
- Validate replacement and whole-disk behavior in the lab and perform the separately attended T14s coexistence check. Keep raw evidence outside source control.

## References

- [Architecture](../architecture.md)
- [ADR 0003: Storage and Recovery Baseline](0003-storage-and-recovery-baseline.md)
- [ADR 0005: Physical Target Change](0005-physical-target-change.md)
- [ADR 0006: Guided Live Installation Boundaries](0006-guided-live-installation-boundaries.md)
- [ADR 0008: Installation Engine Execution Boundary](0008-installation-engine-execution-boundary.md)
- [ADR 0009: Storage Option Promotion and ESP Size](0009-storage-option-promotion-and-esp-size.md)
- [Interview plan](../technical-interviews/installer-coexistence-reinstall_plan.md) and [decision log](../technical-interviews/installer-coexistence-reinstall_log.md)

## Superseded by

`None`
