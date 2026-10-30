# Decision Log — Installer coexistence: reinstall in place and NVRAM registration

## DEC-001
- **Question**: What is the scope of the installer change for coexisting with another operating system on the same disk?
- **Context/Nuances**: The engine currently wipes the whole disk (`wipefs --all`, new GPT). On the T14s dual-boot (MirrorOS p1/p2, Omarchy p3/p4 with its own ESP), reinstalling MirrorOS would destroy Omarchy. A single Limine menu with chainload to Omarchy was explored but is paused; the firmware boot menu (F12) selects between `Limine MirrorOS` and `Limine Omarchy`. The free-space target mode is optional. The hibernation resume splash is dropped (hibernation resume has no splash).
- **User Response**: Agreed; chainload paused, F12 used instead; splash dropped.
- **Decision**: Two target modes: "whole disk" (current behaviour) and "replace an existing MirrorOS installation" (reuse its ESP and root partition, format only those two). The installer registers its own UEFI NVRAM entry. Out of scope: single-Limine chainload menu, resume splash, free-space mode (deferred).
- **Status**: Accepted

## DEC-002
- **Question**: Where must the MirrorOS entry be placed in `BootOrder`?
- **Context/Nuances**: `efibootmgr --bootorder` rewrites only the order list and deletes no entry, so other entries (e.g. `Limine Omarchy`) survive.
- **User Response**: MirrorOS always first.
- **Decision**: `Limine MirrorOS` is always placed first in `BootOrder`, in both target modes; the remaining entries keep their relative order.
- **Status**: Accepted

## DEC-003
- **Question**: Keep the removable-media fallback loader?
- **Context/Nuances**: Today boot relies only on `EFI/BOOT/BOOTX64.EFI` deployed by the Limine package (`SKIP_UEFI=yes`). Firmware may ignore or lose NVRAM entries.
- **User Response**: OK.
- **Decision**: Keep deploying `EFI/BOOT/BOOTX64.EFI` on the MirrorOS ESP in addition to the NVRAM entry.
- **Status**: Accepted

## DEC-004
- **Question**: Where is the prototype run?
- **Context/Nuances**: `~/qemu/mirroros-lab` has a 32 GiB qcow2 disk and a private writable `OVMF_VARS.fd`; the existing checkpoint (2026-10-29T22:57:41Z) saves both disk and UEFI variables. The prototype needs to shrink the current installation and add a second system with its own ESP.
- **User Response**: Use the current disk; the existing checkpoint is enough for now.
- **Decision**: Prototype on the current lab disk; restore from the existing checkpoint if needed. No additional checkpoint is required.
- **Status**: Accepted

## RISK-001
- **Question**: Can other actors change `BootOrder` after installation?
- **Context/Nuances**: Omarchy's `limine-install` almost certainly reorders `BootOrder` on updates; the Lenovo firmware may also reorder or drop entries. The user suggests a way to restore MirrorOS-first ordering from an installed MirrorOS.
- **User Response**: Aware that Omarchy will almost certainly reorder; wants a way to reorder later from an installed MirrorOS.
- **Decision**: Accepted risk; post-install reorder mechanism pending (see next question).
- **Status**: Pending

## DEC-005
- **Question**: In whole-disk mode, which existing NVRAM entries are removed?
- **Context/Nuances**: After wiping the disk, entries that pointed to its partitions (e.g. Windows Boot Manager, previous Omarchy or MirrorOS) are dead. Firmware entries (Setup, boot menu, Lenovo diagnostics, PXE), USB entries and entries on other disks must be preserved.
- **User Response**: Fully agreed; the intent was only stale entries such as Windows or previous Omarchy.
- **Decision**: In whole-disk mode, before wiping, record the PARTUUIDs of the target disk's partitions; remove only NVRAM entries whose `HD(...)` device path references one of those PARTUUIDs. All other entries are preserved.
- **Status**: Accepted

## DEC-006
- **Question**: How is MirrorOS-first ordering restored from an installed MirrorOS after another actor reorders `BootOrder`?
- **Context/Nuances**: Options were (A) a documented `efibootmgr` procedure, (B) an installed privileged command, (C) a systemd unit forcing MirrorOS first on every boot. C was rejected: it only runs after the user already reached MirrorOS and silently overrides deliberate reordering.
- **User Response**: B.
- **Decision**: The installed system ships a privileged command (working name `mirroros-boot-first`), run explicitly with sudo and never automatically. It finds the `Limine MirrorOS` entry by the PARTUUID of the ESP mounted at `/boot` and the loader path `\EFI\BOOT\BOOTX64.EFI`, recreates it if missing, places it first in `BootOrder` preserving the relative order of the rest, and deletes no entry. It shares the NVRAM logic (DEC-002 rules) with the engine. It is covered by the coexistence ADR with its own contract and tests. Open: shared-code location, delivery to the installed system, final name.
- **Status**: Accepted

## RISK-001 (update)
- **Decision**: Mitigated by DEC-006: the user can restore MirrorOS-first ordering with the installed command.
- **Status**: Accepted (mitigated)

## DEC-007
- **Question**: Where does the shared NVRAM logic live and how does it reach the installed system?
- **Context/Nuances**: Precedent in `install/engine/lib/configure.sh`: the engine copies `operations/configure` and `operations/lib/*.sh` from `$CODE_ROOT` to `/usr/local/lib/mirroros/` on the target and links `/usr/local/bin/mirroros-configure` (root-owned, 0755/0644). `install/` is live-only code; `operations/` already runs on the installed system.
- **User Response**: Yes (recommendation accepted).
- **Decision**: Shared Bash library `operations/lib/uefi-boot-entry.sh` (find entry by PARTUUID + loader path, create, move first preserving the rest, remove target-disk entries for DEC-005). The engine sources it from `$CODE_ROOT/operations/lib/`. The command `operations/boot-first` uses the same library; the engine copies both to `/usr/local/lib/mirroros/operations/` and links `/usr/local/bin/mirroros-boot-first`, following the `mirroros-configure` pattern. Final command name: `mirroros-boot-first`.
- **Status**: Accepted

## DEC-008
- **Question**: One plan or two (ADR + prototype, then implementation)?
- **Context/Nuances**: The change touches accepted contracts (target-facts, installation-plan with a format version bump, installation-confirmation, installation-engine, installation-postconditions), ADR 0003/0009 and a new ADR. Earlier work split prototypes from implementation.
- **User Response**: Single plan.
- **Decision**: Single plan 02-23 ordered as: coexistence ADR (Proposed) → lab prototype → decision checkpoint where the user accepts or corrects the ADR (no product contract or code changes before it) → implementation (discovery, plan, confirmation, engine, postconditions, contracts, `uefi-boot-entry.sh`, `mirroros-boot-first`, tests, docs) → final T14s validation in replace mode with p3/p4 verified untouched. If the prototype invalidates a decision, execution stops at the checkpoint and the plan is revised before implementation.
- **Status**: Accepted

## TODO-001
- **Question**: Open design points not resolved in the interview.
- **Context/Nuances**: The user asked to materialize the plan without a draft. These points are resolved inside the ADR task and confirmed at the decision checkpoint, not assumed: (a) how replace mode identifies an existing MirrorOS installation and ties its ESP to its root; (b) minimum sizes and filesystem constraints for reused partitions; (c) the partition identity the confirmation requires typing; (d) the installation-plan format version bump and per-partition operations; (e) the postcondition proving untouched partitions; (f) where the engine runs `efibootmgr` and how `SKIP_UEFI` changes; (g) whether ADR 0003/0009 are amended or superseded.
- **Status**: Pending
