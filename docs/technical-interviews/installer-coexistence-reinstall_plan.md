# Consolidated Plan — Installer coexistence: reinstall in place and NVRAM registration

## Scope

The installer gains a second target mode next to the current whole-disk installation: replacing an existing MirrorOS installation in place, reusing its ESP and root partition and formatting only those two, so that another operating system on the same disk (Omarchy on the T14s) survives a MirrorOS reinstallation. The installer also registers its own UEFI NVRAM entry. A single Limine menu chainloading Omarchy is paused; the firmware boot menu (F12) selects between systems. The free-space target mode and any resume splash are out of scope. [DEC-001]

## Boot entry policy

The engine registers a `Limine MirrorOS` NVRAM entry and always places it first in `BootOrder` in both target modes, preserving the relative order of every other entry; `efibootmgr --bootorder` only rewrites the list and deletes nothing. [DEC-002] The removable-media fallback `EFI/BOOT/BOOTX64.EFI` keeps being deployed on the MirrorOS ESP in case firmware ignores or loses NVRAM entries. [DEC-003]

In whole-disk mode, the engine records the PARTUUIDs of the target disk's partitions before wiping and removes only NVRAM entries whose device path references one of them (stale Windows, Omarchy or earlier MirrorOS entries). Firmware, USB and other-disk entries are preserved. [DEC-005]

Other actors may reorder `BootOrder` later: Omarchy's `limine-install` almost certainly does on updates, and the Lenovo firmware may too. A way to restore MirrorOS-first ordering from an installed MirrorOS is under discussion. [RISK-001]

## Prototype

The prototype runs on the current `~/qemu/mirroros-lab` disk (32 GiB, private writable OVMF variables): shrink the existing installation, add a second system with its own ESP, and exercise both modes and the NVRAM policy. The existing checkpoint (disk + UEFI variables) is the restore point. [DEC-004]

## Post-install boot order restoration

The installed system provides an explicit, sudo-invoked command (working name `mirroros-boot-first`) that finds or recreates the `Limine MirrorOS` entry by ESP PARTUUID and loader path and places it first in `BootOrder` without deleting any entry. It never runs automatically. It shares the NVRAM logic with the engine so both apply the same rules, and it is covered by the coexistence ADR with its own contract and tests. The shared-code location, delivery mechanism and final name are still open. This mitigates the reordering risk. [DEC-006, RISK-001]

The NVRAM logic lives in a shared Bash library, `operations/lib/uefi-boot-entry.sh`, sourced by the engine from the embedded code root and by the installed command `operations/boot-first`. The engine delivers both to `/usr/local/lib/mirroros/operations/` and links `/usr/local/bin/mirroros-boot-first`, the same way it delivers `mirroros-configure`; `operations/` is the tree that already runs on installed systems, while `install/` stays live-only. [DEC-007]

## Delivery

The work is a single plan, 02-23: the coexistence ADR is drafted as Proposed, the lab prototype exercises it, and a decision checkpoint lets the user accept or correct the ADR before any product contract or code changes. Implementation and a final T14s replace-mode validation follow; if the prototype invalidates a decision, execution stops at the checkpoint for plan revision. [DEC-008]

Several design points remain open and are resolved in the ADR and confirmed at the checkpoint: replace-mode identification of an existing installation, reuse constraints for its partitions, the typed confirmation identity, the plan format version bump, the untouched-partition postcondition, where `efibootmgr` runs and how `SKIP_UEFI` changes, and whether ADR 0003/0009 are amended or superseded. [TODO-001]
