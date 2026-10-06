# Native Arch prototype

Story 2.1, Track 1. Non-production: production never imports or sources this directory.

## Question

How much MirrorOS-owned code does it take to reproduce the shared installation scenario with plain
Arch commands (`sfdisk`, `pacstrap`, `genfstab`, `arch-chroot`, `bootctl`, `chpasswd`), following the
Arch Installation Guide?

## Scenario

The scenario and its classification are in the matrix of [`../README.md`](../README.md). The postconditions
are checked on the second boot by the shared verification unit (see [`../lib/README.md`](../lib/README.md)).
The guest script is [`guest/install`](guest/install); [`run`](run) only selects it for the shared harness.

Technical choices that go beyond a literal reading of the scenario:

- The ESP is mounted with `umask=0077`, so `bootctl status` does not warn that the random seed is
  world accessible.
- `loader.conf` sets `default arch.conf` in addition to `timeout 3` and `editor no`, so the default
  entry is deterministic.
- `MIRROROS_OMIT_ROOT_PASSWORD=1` skips the root password and leaves root locked. It exists only to
  check the omitted-root-password case at contract level; the harness always delivers both credentials.

## Usage

```bash
prototypes/installation/native-arch/run [--variant normal|unreachable-mirrors] BUNDLE_DIRECTORY
prototypes/installation/native-arch/run --attended BUNDLE_DIRECTORY
```

The default mode is the prototype-only unattended two-boot run. `--attended` runs boot 1 only, on the
serial console, with a minimal typed confirmation (no digest binding).

## Attended checklist

Run on a disposable disk over the serial console, together with the user. Record every observation as
"observed manually" with its run-id.

1. Plan visibility: before the confirmation, is the plan shown (disk, partitions, packages, steps)?
2. Editability: can the plan be changed before confirmation, or only cancelled?
3. Confirmation: which input confirms, and what does any other input do?
4. Rejection: answer anything but `install`. Record the exit status and confirm that the disk has no
   partition table (`sfdisk -d` and `wipefs` on the target).
5. SIGINT: confirm, then press Ctrl-C during `pacstrap`. Record the exit status, the diagnostics left
   on the console, and the partial disk state (partitions, mounts, files under `/mnt`).

## Result

Pending. To be completed from the counted runs and the attended session (Tasks 7–9).
