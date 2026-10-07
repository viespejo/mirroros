# btrfs-rescue

Btrfs/Snapper with systemd-boot and rescue-based rollback. Story 2.1, Track 2. Non-production:
production never imports or sources this directory.

## Question

Does restoring `@` from a Snapper snapshot with `btrfs` commands from the bundle A ISO recover the
same damage as the control, in fewer steps or with less data loss, and at what maintenance cost?

## Scenario

[`stage.sh`](stage.sh) uses the shared Btrfs stage ([`../lib/guest/btrfs-stage.sh`](../lib/guest/btrfs-stage.sh)):
a 1 GiB FAT32 ESP and one Btrfs filesystem with flat subvolumes `@`, `@home`, `@log`, `@pkg`,
`@snapshots` (`/.snapshots`), and `@swap` (`/swap`, NOCOW), all mounted with
`compress=zstd:1,relatime`. Snapper has one root configuration for `@` (snap-pac, no timeline,
`NUMBER_LIMIT=10`, `snapper-cleanup.timer`), and the installation ends with a `post-install baseline`
snapshot. systemd-boot entries carry `rootflags=subvol=@`, `resume=UUID=`, and the `resume_offset`
from `btrfs inspect-internal map-swapfile -r`.

The generated `fstab` loses its `subvolid=` fields, so a replaced `@` still mounts.

Recovery is [`recover`](recover), run from the bundle A ISO over NoCloud: it mounts the top level,
selects the `post-install baseline` snapshot, keeps the damaged `@` as `@damaged-<timestamp>`, and
restores `@` as a snapshot of the baseline. For D2 it then regenerates the initramfs from a chroot,
because the ESP is outside every snapshot.

The verification excludes the `storage` and `swap` groups and replaces them with the `btrfs_*` and
`snapper_*` checks of [`../lib/guest/storage-checks.sh`](../lib/guest/storage-checks.sh).

## Usage

```bash
prototypes/storage/btrfs-rescue/run --scenario install|d1|d2|hibernate|pending BUNDLE_DIRECTORY
```

See [`../lib/README.md`](../lib/README.md) for the scenarios, boots, and deadlines.

## Attended checklist: recovery with a pending hibernation image

Run the `pending` scenario. After the hibernation boot powers off, the maintainer gets a rescue
session from the ISO on the serial console. Record every observation as "observed manually" with the
run-id.

1. Log in on the serial console and run `bash /run/mirroros-attended.sh`, then mount the top level
   (`mount -o subvolid=5 /dev/vda2 /mnt`) as `recover` does.
2. Note whether the Btrfs mounts warn about the hibernation image, and whether `@swap` still holds
   the image.
3. Restore `@` from the baseline as `recover` does, power off, boot from disk, and record what
   happens: resume into the old state, or a normal boot of the restored `@`.

## Result

To be recorded in Task 9, with provenance and run-id for every cell.
