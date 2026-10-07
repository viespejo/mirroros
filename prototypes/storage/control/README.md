# control

ext4, systemd-boot, and recovery through independent rescue media (the current baseline). Story 2.1,
Track 2. Non-production: production never imports or sources this directory.

## Question

Does the baseline recover reproducible damage with only the bundle A ISO and a recovery script, and
what does that recovery cost in steps and time?

## Scenario

The control reproduces the 02-01 fixed scenario: [`stage.sh`](stage.sh) holds the 02-01 storage and
swap/boot stages of `native-arch/guest/install`, moved without changes (1 GiB FAT32 ESP, ext4 root,
a 4 GiB `/swapfile` with a `filefrag` resume offset, systemd-boot). It excludes no check group, so
the 02-01 postconditions run unchanged. It takes no snapshot.

Recovery is [`recover`](recover), run from the bundle A ISO over NoCloud:

- D1 (userspace damage inside the root): `pacman --root /mnt -Rns mirroros-damage-d1`.
- D2 (boot path damage on the ESP): `mkinitcpio -P` inside a chroot.

## Usage

```bash
prototypes/storage/control/run --scenario install|d1|d2|hibernate|pending BUNDLE_DIRECTORY
```

See [`../lib/README.md`](../lib/README.md) for the scenarios, boots, and deadlines.

## Attended checklist: recovery with a pending hibernation image

Run the `pending` scenario. After the hibernation boot powers off, the maintainer gets a rescue
session from the ISO on the serial console. Record every observation as "observed manually" with the
run-id.

1. Log in on the serial console and run `bash /run/mirroros-attended.sh`, then mount the installed
   system as `recover` does.
2. Note whether the ext4 root mounts and whether the kernel or `mount` warns about the hibernation
   image (the swapfile holds it).
3. Power off the guest, boot from disk, and record what happens: resume, or a normal boot that
   discards the image.

## Result

To be recorded in Task 9, with provenance and run-id for every cell.
