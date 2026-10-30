# Installer coexistence prototype

## Status

In progress. The lab layout and one partition-scoped replacement have been exercised; NVRAM rules and reboot validation remain incomplete. The Proposed [ADR 0022](../../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md) is not yet validated or accepted.

## Lab inspection

The live environment was accessed over SSH with a verified host key. Read-only inspection reported a 32 GiB `/dev/vda` with an unmounted 2 GiB FAT ESP and an unmounted 30 GiB Btrfs root labelled `mirroros`. The root's `@/etc/fstab` identifies the ESP by filesystem UUID, and the ESP's `limine.conf` references the root filesystem UUID. The root contained a swapfile subvolume and snapshots. `btrfs filesystem usage` reported approximately 9.63 GiB used; this observation alone does not establish that shrinking is safe.

The existing `after-greeter-lock-theme` checkpoint contains a disk image and an OVMF variables file. No new checkpoint was created. The user authorized destructive operations on this lab only. The initial Btrfs inspection used `ro` without disabling log replay, so it does not by itself prove that the mount made no recovery writes. A subsequent attempt with `ro,nologreplay` was rejected by the live kernel before mounting. A separate `ro,rescue=nologreplay,subvolid=5` mount succeeded and `findmnt` confirmed those options; it showed a 4 GiB swapfile. This does not establish that the planned shrink is safe.

## Preliminary detection check

`bash -n` and ShellCheck passed for `replace-partitions` and `test-detection`. An initial read-only detection run matched the existing Btrfs/Limine root and ESP and deliberately stopped before formatting. Later, `test-detection` created disposable loop images in the live guest: ext4/systemd-boot, Btrfs/systemd-boot and Btrfs/Limine all matched; simultaneous Limine and systemd-boot evidence, a missing ESP binding, and two labelled roots were rejected. These are synthetic configurations, not complete installations or boot validation. The loop-only inspection mode does not enter the replacement phase. A repeated run and the systemd-boot installation check are recorded in ignored `evidence/prototypes/coexistence.gH9PoXDl/loop-checks.log`.

## Setup preparation

`setup-layout` is a destructive lab-only script. Bash syntax and ShellCheck passed on the host. In the guest, `sfdisk --no-act -N 2` with the proposed 20 GiB size reported the original partition start and a 20 GiB result without writing the partition table; the output did not itself verify PARTUUID preservation. The script's preflight initially exposed an invalid `swapon` invocation; it was corrected and rerun successfully before execution.

The script then ran in the live guest and exited 0: Btrfs and partition 2 were reduced to 20 GiB, the root PARTUUID check passed, a 1 GiB ESP and approximately 9 GiB LUKS partition were created, and `Limine Other` was created as Boot0004 without changing the existing BootOrder. The stand-in ESP contains a copied Limine binary and minimal configuration. Its encrypted partition contains test data but uses a disposable key removed after setup, so it is a byte-preservation test object, not a bootable second operating system.

## Partition-scoped replacement

`replace-partitions` ran in the live guest and exited 0. It detected `/dev/vda1` and `/dev/vda2`, captured the non-target partition table lines, identities and SHA-256 hashes, wiped signatures only on those two target nodes, and reformatted the ESP and Btrfs root. It copied the previous fallback EFI binary onto the new ESP; this is not a complete MirrorOS installation and does not establish that MirrorOS can boot. Before/after filtered table dumps, non-target identities and stand-in partition hashes compared equal. Raw textual evidence was copied to ignored `evidence/prototypes/coexistence.gH9PoXDl/` before reboot. NVRAM rules and reboot behavior remain unverified.

## UEFI entry and ordering check

`bash -n` and ShellCheck passed for `nvram-rules`. In the live guest the script exited 0: it found `Limine Other` as Boot0004, created `Limine MirrorOS` as Boot0005 for the target ESP and fallback loader, and changed BootOrder from `0001,0002,0000,0003` to `0005,0001,0002,0000,0003,0004`. The existing entries retained their relative order, Boot0004 was appended for firmware-menu testing, and no pre-existing entry ID disappeared. Raw `efibootmgr -v` evidence is under ignored `evidence/prototypes/coexistence.gH9PoXDl/nvram/`.

With separate user confirmation, `nvram-rules --stale` created temporary `/dev/vda5` in the remaining free sectors and Boot0006 for its PARTUUID, then deleted only partition 5 and removed only the resulting stale entry. The complete `sfdisk --dump`, pre-existing boot-entry IDs and BootOrder matched their pre-test values. This exercises one synthetic stale entry, not a general multi-entry cleanup implementation. Evidence is under ignored `evidence/prototypes/coexistence.gH9PoXDl/stale/`.

After a guest reboot, the user supplied an OVMF Boot Manager screenshot showing `Limine MirrorOS` first and `Limine Other` present. The selected MirrorOS device path referenced the target ESP PARTUUID and fallback loader. Limine itself displayed no valid configuration entries, as expected after formatting the root and ESP; neither prototype ESP is a complete bootable installation.

After the user returned to the live ISO, `efibootmgr -v` reported `BootCurrent: 0001` and `BootOrder: 0001,0005,0002,0004,0000,0003`, whereas the pre-reboot order was `0005,0001,0002,0000,0003,0004`. Both Limine entries remained, but MirrorOS was not first and other entries also changed relative order. A second user-approved trial restored the original order, set `BootNext` to the ISO and rebooted without manual firmware selection; the live again reported `0001,0005,0002,0004,0000,0003`. This excludes manual selection as a necessary cause in the second trial, but does not distinguish OVMF, QEMU boot configuration, or live behavior. Raw output is in ignored `evidence/prototypes/coexistence.gH9PoXDl/post-reboot-efibootmgr.log` and `bootnext-{before,after}-reboot.log`.

In a further user-approved test, the prior MirrorOS-first order was restored, the live was powered off, and the same lab was launched without the ISO. The user's OVMF Boot Manager and `bcfg boot dump -v` screenshots showed `Limine MirrorOS` first and `Limine Other` present. The firmware list also differed from the earlier list: automatic network entries appeared and the previous DVD entry was absent. This is evidence that MirrorOS can remain first in the no-ISO lab boot, not proof that all other entries retain their previous relative order or that the ISO caused the earlier changes. The specific planned post-reboot `efibootmgr` output with MirrorOS first was not obtained; this limitation and the real-hardware behavior require checkpoint review.

## systemd-boot installation check

In the live guest, systemd 262's `bootctl --variables=no --esp-path=<temporary-loop-esp> install` installed `/EFI/systemd/systemd-bootx64.efi` and `/EFI/BOOT/BOOTX64.EFI` as identical copies of the live systemd-boot binary. `efibootmgr -v` output was identical before and after. The first run warned that the temporary ESP was world accessible; the test was corrected to mount with `umask=0077`, and the second run passed without that warning. `test-systemd-boot` passes Bash syntax and ShellCheck. This does not establish that all EFI variables are unchanged or prove boot of a systemd-boot installation.

A separate approved `test-systemd-nvram` run created temporary partition 5 and a synthetic systemd-boot entry for its PARTUUID and `\\EFI\\systemd\\systemd-bootx64.efi`, moved that entry first while preserving the existing order, restored the original order, removed partition 5, and deleted only its now-stale entry. The full pre/post `sfdisk --dump` and `efibootmgr -v` outputs compared equal. Evidence is under ignored `evidence/prototypes/coexistence.gH9PoXDl/systemd-nvram/`. The temporary partition did not contain a bootable loader; this tests entry creation and ordering mechanics, not the future `mirroros-boot-first` command or actual boot.

All shell scripts in this directory passed ShellCheck with `find prototypes/coexistence -maxdepth 1 -type f ! -name '*.md' -print0 | xargs -0 shellcheck`. The plan's literal `shellcheck prototypes/coexistence/*` also matches this Markdown README and is not the check used.

## Required work

- Review the lab scripts and extend fail-closed and rejection-case coverage.
- Verify firmware behavior after reboot and exercise cleanup for multiple stale and unrelated entries.
- Extend candidate rejection coverage beyond the synthetic cases already tested. Validate the installed boot-first command and real boot behavior for both bootloaders after implementation; record unverified combinations explicitly.
- Record commands, outcomes and deviations here; keep raw evidence in ignored `evidence/`.
